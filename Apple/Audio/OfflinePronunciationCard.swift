import SwiftUI
import PolygoCore

/// Result of the on-device analysis: verdict and score, one chip per
/// syllable (expected and heard tone), the learner's pitch against the
/// expected tone shapes, and the word check or how to enable it.
struct OfflinePronunciationCard: View {
    let analysis: PronunciationAnalysis
    let transcriptionHelp: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(verdictTitle, systemImage: verdictIcon)
                .font(.headline)
                .foregroundStyle(analysis.verdict == .pass ? .green : .orange)
            if let score = analysis.score {
                Text("Score : \(Int((score * 100).rounded())) / 100 · \(analysis.words == nil ? "tons seulement" : "tons et mots")")
                    .font(.callout.weight(.medium))
            }
            Text(analysis.summary)
                .font(.callout)
                .foregroundStyle(.secondary)

            if analysis.issue != nil {
                Text("Aucun score n’est donné. Réessaie, ou continue sans note.")
                    .font(.callout)
                    .foregroundStyle(.orange)
            } else {
                tones
                words
            }
            Text("Analyse sur l’appareil : tons et mots, pas les consonnes ni les voyelles. Rien ne quitte l’appareil.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("speech-pronunciation-result")
    }

    private var verdictTitle: String {
        switch analysis.verdict {
        case .pass: return "Prononciation réussie"
        case .needsPractice: return "Prononciation à corriger"
        case .inconclusive: return "Résultat incertain"
        }
    }

    private var verdictIcon: String {
        switch analysis.verdict {
        case .pass: return "checkmark.circle.fill"
        case .needsPractice: return "arrow.counterclockwise.circle.fill"
        case .inconclusive: return "questionmark.circle.fill"
        }
    }

    @ViewBuilder
    private var tones: some View {
        if !analysis.syllables.isEmpty {
            Text("Tons")
                .font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(Array(analysis.syllables.enumerated()), id: \.offset) { index, syllable in
                    ToneChip(syllable: syllable)
                        .accessibilityIdentifier("speech-tone-chip-\(index)")
                }
            }
            ToneContourChart(syllables: analysis.syllables)
            let corrections = analysis.syllables.filter { $0.isCorrect == false }
            ForEach(Array(corrections.enumerated()), id: \.offset) { _, syllable in
                Label(syllable.feedback, systemImage: "arrow.turn.down.right")
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var words: some View {
        Text("Mots")
            .font(.subheadline.weight(.semibold))
        if let words = analysis.words {
            if words.missing.isEmpty && words.extra.isEmpty {
                Label("Tous les mots attendus ont été reconnus.", systemImage: "checkmark")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                if !words.missing.isEmpty {
                    Text("Non reconnus : " + words.missing.joined(separator: "、"))
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                if !words.extra.isEmpty {
                    Text("Entendus en plus : " + words.extra.joined(separator: "、"))
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
        } else {
            Label("Transcription indisponible : seuls les tons sont notés.", systemImage: "text.badge.xmark")
                .font(.callout)
                .foregroundStyle(.orange)
            Text(transcriptionHelp)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("speech-dictation-help")
        }
    }
}

private func toneColor(_ syllable: SyllableToneAssessment) -> Color {
    switch syllable.isCorrect {
    case .some(true): return .green
    case .some(false): return .orange
    case .none: return .gray
    }
}

private struct ToneChip: View {
    let syllable: SyllableToneAssessment

    var body: some View {
        VStack(spacing: 2) {
            if let hanzi = syllable.expected.hanzi {
                Text(hanzi)
                    .font(.title3.weight(.semibold))
            }
            Text(syllable.expected.pinyin)
                .font(.caption.weight(.medium))
            Text(detail)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(toneColor(syllable).opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(toneColor(syllable).opacity(0.6))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(syllable.feedback)
    }

    private var detail: String {
        guard let expected = syllable.expected.spokenTone else { return "neutre" }
        guard let heard = syllable.heardTone else { return "\(expected) → ?" }
        return "\(expected) → \(heard)"
    }
}

/// One small plot per syllable: the expected tone shape dashed, the
/// learner's pitch solid, both in semitones around the learner's own level.
private struct ToneContourChart: View {
    let range = 8.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(syllables.enumerated()), id: \.offset) { _, syllable in
                        VStack(spacing: 2) {
                            Canvas { context, size in draw(syllable, in: &context, size: size) }
                                .frame(width: 44, height: 56)
                                .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                            Text(syllable.expected.hanzi ?? syllable.expected.pinyin)
                                .font(.caption2)
                        }
                    }
                }
            }
            Text("Pointillés : forme attendue. Trait : ta voix.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Courbe de hauteur de ta voix, syllabe par syllabe")
        .accessibilityValue(syllables.map(\.feedback).joined(separator: ". "))
    }

    private func draw(_ syllable: SyllableToneAssessment, in context: inout GraphicsContext, size: CGSize) {
        func point(_ index: Int, of count: Int, _ semitones: Double) -> CGPoint {
            let x = count > 1 ? CGFloat(index) / CGFloat(count - 1) * (size.width - 8) + 4 : size.width / 2
            let clamped = min(range, max(-range, semitones))
            let y = size.height / 2 - CGFloat(clamped / range) * (size.height / 2 - 4)
            return CGPoint(x: x, y: y)
        }
        func path(_ values: [Double]) -> Path {
            var path = Path()
            for (index, value) in values.enumerated() {
                let location = point(index, of: values.count, value)
                if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
            }
            return path
        }
        var middle = Path()
        middle.move(to: CGPoint(x: 0, y: size.height / 2))
        middle.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(middle, with: .color(.secondary.opacity(0.25)), lineWidth: 0.5)
        if let tone = syllable.expected.spokenTone {
            context.stroke(
                path(MandarinToneShape.template(tone)),
                with: .color(.secondary),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 3])
            )
        }
        if syllable.contour.count > 1 {
            context.stroke(
                path(syllable.contour),
                with: .color(toneColor(syllable)),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
