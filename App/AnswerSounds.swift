import Foundation
import PolygoCore
import PolygoApple

/// Original answer sounds bundled in `Sounds/` (see docs/AUDIO.md), played
/// when an answer is checked unless « Sons de réponse » is off in Réglages.
enum AnswerSounds {
    static let storageKey = "syllune.answerSounds"

    static func play(for evaluation: ExerciseEvaluation, audio: any AudioService) {
        guard let sound = evaluation.feedbackSound else { return }
        play(sound, audio: audio)
    }

    static func play(_ sound: AnswerFeedbackSound, audio: any AudioService) {
        guard UserDefaults.standard.object(forKey: storageKey) as? Bool ?? true else { return }
        let name = switch sound {
        case .correct: "answer-correct"
        case .incorrect: "answer-incorrect"
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Sounds") else { return }
        audio.playEffect(at: url)
    }
}
