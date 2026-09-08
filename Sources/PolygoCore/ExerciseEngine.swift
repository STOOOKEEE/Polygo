import Foundation

public enum TextNormalizer {
    /// Normalizes user-entered Chinese and pinyin without changing its meaning.
    /// Punctuation and whitespace are ignored; diacritics are folded so that
    /// `ni hao`, `nǐ hǎo`, and their case variants can be compared.
    public static func normalize(_ value: String, caseSensitive: Bool = false) -> String {
        let folded = value.precomposedStringWithCanonicalMapping
            .folding(options: caseSensitive ? [] : [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        var output = String()
        for scalar in folded.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) || CharacterSet.punctuationCharacters.contains(scalar) {
                continue
            }
            output.unicodeScalars.append(scalar)
        }
        return String(output).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct DefaultExerciseEngine: ExerciseEngine, Sendable {
    public init() {}

    private func evaluation(_ id: ExerciseID, _ outcome: EvaluationOutcome, _ score: Double, _ message: String, accepted: Bool, answer: String? = nil) -> ExerciseEvaluation {
        try! ExerciseEvaluation(exerciseID: id, outcome: outcome, score: score, feedback: .unchecked(["fr": message, "en": message]), accepted: accepted, normalizedAnswer: answer)
    }

    public func evaluate(spec: ExerciseSpec, answer: ExerciseAnswer) -> ExerciseEvaluation {
        evaluateSubmitted(spec: spec, answer: answer, id: spec.id)
    }

    private func evaluateSubmitted(spec: ExerciseSpec, answer: ExerciseAnswer, id: ExerciseID) -> ExerciseEvaluation {
        switch answer {
        case .skipped:
            return evaluation(
                id,
                .skipped,
                0,
                "Exercice passé sans évaluation. Il ne compte pas comme une réussite.",
                accepted: false
            )
        default:
            break
        }

        switch spec {
        case .choice(let exercise):
            guard case .choice(let choiceID) = answer else {
                return evaluation(id, .incorrect, 0, "Choisis une réponse proposée.", accepted: false)
            }
            let correct = choiceID == exercise.correctChoiceID
            return evaluation(id, correct ? .correct : .incorrect, correct ? 1 : 0, correct ? "Bonne réponse." : "Ce n’est pas la bonne réponse. Relis l’explication puis réessaie.", accepted: correct, answer: choiceID)

        case .wordOrder(let exercise):
            guard case .wordOrder(let tokenIDs) = answer else {
                return evaluation(id, .incorrect, 0, "Remets les mots dans l’ordre proposé.", accepted: false)
            }
            let correct = tokenIDs == exercise.correctOrder
            return evaluation(id, correct ? .correct : .incorrect, correct ? 1 : 0, correct ? "La phrase est dans le bon ordre." : "L’ordre de la phrase doit être corrigé.", accepted: correct, answer: tokenIDs.joined(separator: " "))

        case .fillBlank(let exercise):
            guard case .text(let text) = answer else {
                return evaluation(id, .incorrect, 0, "Choisis une réponse proposée.", accepted: false)
            }
            let normalized = TextNormalizer.normalize(text, caseSensitive: exercise.caseSensitive)
            let accepted = exercise.acceptedAnswers.contains { TextNormalizer.normalize($0, caseSensitive: exercise.caseSensitive) == normalized }
            return evaluation(id, accepted ? .correct : .incorrect, accepted ? 1 : 0, accepted ? "Le mot convient à la phrase." : "Vérifie le mot choisi et réessaie.", accepted: accepted, answer: normalized)

        case .listeningChoice(let exercise):
            guard case .choice(let choiceID) = answer else {
                return evaluation(id, .incorrect, 0, "Écoute le mot puis choisis une réponse.", accepted: false)
            }
            let correct = choiceID == exercise.correctChoiceID
            return evaluation(id, correct ? .correct : .incorrect, correct ? 1 : 0, correct ? "Tu as reconnu le mot." : "Réécoute le mot et compare les propositions.", accepted: correct, answer: choiceID)

        case .speaking(let exercise):
            switch answer {
            case .speech(let speech):
                if let assessment = speech.pronunciationAssessment {
                    guard assessment.isEvaluable,
                          let providerScore = assessment.providerScore else {
                        return evaluation(
                            id,
                            .unavailable,
                            0,
                            "L’évaluation de prononciation est incertaine. Tu peux passer cet exercice sans le noter.",
                            accepted: false
                        )
                    }
                    switch assessment.verdict {
                    case .pass:
                        return evaluation(
                            id,
                            .correct,
                            providerScore,
                            "La prononciation est validée par " + assessment.providerID + ".",
                            accepted: true,
                            answer: speech.normalizedTranscript
                        )
                    case .needsPractice:
                        return evaluation(
                            id,
                            .incorrect,
                            providerScore,
                            "La prononciation demande encore un peu de pratique.",
                            accepted: false,
                            answer: speech.normalizedTranscript
                        )
                    case .inconclusive:
                        return evaluation(
                            id,
                            .unavailable,
                            0,
                            "L’évaluation de prononciation est incertaine. Tu peux passer cet exercice sans le noter.",
                            accepted: false
                        )
                    }
                }
                let normalized = TextNormalizer.normalize(speech.normalizedTranscript.isEmpty ? speech.transcript : speech.normalizedTranscript)
                let matches = exercise.acceptedTranscripts.contains { TextNormalizer.normalize($0) == normalized }
                if matches {
                    return evaluation(id, .correct, 1, "La transcription correspond à la phrase.", accepted: true, answer: normalized)
                }
                if exercise.allowSelfRating {
                    return evaluation(id, .partial, 0.5, "La transcription ne permet pas de confirmer la phrase. Évalue ta réponse.", accepted: false, answer: normalized)
                }
                return evaluation(id, .incorrect, 0, "La phrase transcrite ne correspond pas encore.", accepted: false, answer: normalized)
            case .selfRating(let rating):
                guard exercise.allowSelfRating else {
                    return evaluation(id, .unavailable, 0, "L’auto-évaluation n’est pas disponible pour cet exercice.", accepted: false)
                }
                return selfReported(id: id, rating: rating)
            default:
                return evaluation(id, .unavailable, 0, "Enregistre ta réponse ou choisis une auto-évaluation.", accepted: false)
            }

        case .handwriting(let exercise):
            switch answer {
            case .handwriting(let handwriting):
                if let expected = exercise.expectedStrokeCount, expected > 0, handwriting.strokeCount != expected {
                    return evaluation(id, .partial, 0.5, "Le nombre de traits diffère du modèle. Tu peux revoir le tracé.", accepted: handwriting.selfChecked, answer: exercise.targetHanzi)
                }
                return evaluation(id, handwriting.selfChecked ? .selfReported : .incorrect, handwriting.selfChecked ? 1 : 0, handwriting.selfChecked ? "Tracé enregistré comme réussi." : "Revois le modèle puis réessaie.", accepted: handwriting.selfChecked, answer: exercise.targetHanzi)
            case .selfRating(let rating):
                guard exercise.allowSelfRating else {
                    return evaluation(id, .unavailable, 0, "L’auto-évaluation n’est pas disponible pour cet exercice.", accepted: false)
                }
                return selfReported(id: id, rating: rating)
            default:
                return evaluation(id, .unavailable, 0, "Trace le caractère ou choisis une auto-évaluation.", accepted: false)
            }

        case .flashcard:
            guard case .selfRating(let rating) = answer else {
                return evaluation(id, .unavailable, 0, "Révèle la carte puis évalue ta réponse.", accepted: false)
            }
            return selfReported(id: id, rating: rating)
        }
    }

    private func selfReported(id: ExerciseID, rating: SelfRating) -> ExerciseEvaluation {
        let score: Double
        switch rating {
        case .again: score = 0.2
        case .hard: score = 0.6
        case .good: score = 0.9
        case .easy: score = 1
        }
        let message: String
        switch rating {
        case .again: message = "La carte est planifiée pour être revue bientôt."
        case .hard: message = "La réponse est enregistrée comme difficile."
        case .good: message = "Réponse enregistrée comme correcte."
        case .easy: message = "Réponse enregistrée comme facile."
        }
        return evaluation(id, .selfReported, score, message, accepted: true, answer: rating.rawValue)
    }
}
