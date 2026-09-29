import SwiftUI
import PolygoCore
import PolygoApple

/// Tap-to-pair exercise: touch a Chinese item, then touch its counterpart in
/// the right-hand column. Pairs are only submitted once every item is tied.
struct MatchingAnswerView: View {
    let exercise: MatchingExercise
    @Binding var answer: ExerciseAnswer?
    @EnvironmentObject private var model: AppModel
    @Environment(\.isEnabled) private var isEnabled
    @State private var pairs: [String: String] = [:]
    @State private var selectedLeft: String?

    init(exercise: MatchingExercise, answer: Binding<ExerciseAnswer?>) {
        self.exercise = exercise
        self._answer = answer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Touche un mot, puis touche ce qui lui correspond. Touche une paire pour la défaire.")
                .font(.callout)
                .foregroundStyle(SylluneColor.inkMuted)
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 8) {
                    ForEach(Array(exercise.pairs.enumerated()), id: \.element.id) { index, pair in
                        leftTile(pair, number: index + 1)
                    }
                }
                VStack(spacing: 8) {
                    ForEach(exercise.rightColumn) { pair in
                        rightTile(pair)
                    }
                }
            }
        }
        .onAppear { syncFromAnswer() }
        .onChange(of: answer) { _, _ in syncFromAnswer() }
    }

    private func number(ofLeft id: String) -> Int? {
        exercise.pairs.firstIndex(where: { $0.id == id }).map { $0 + 1 }
    }

    private func partner(ofRight id: String) -> String? {
        pairs.first(where: { $0.value == id })?.key
    }

    /// After feedback, a tied item shows whether its pair is right.
    private func feedbackColor(leftID: String) -> Color? {
        guard !isEnabled, pairs.count == exercise.pairs.count, let right = pairs[leftID] else { return nil }
        return right == leftID ? SylluneColor.success : SylluneColor.error
    }

    private func leftTile(_ pair: MatchPair, number: Int) -> some View {
        let isSelected = selectedLeft == pair.id
        let isTied = pairs[pair.id] != nil
        let accent = feedbackColor(leftID: pair.id) ?? (isSelected || isTied ? SylluneColor.jade : SylluneColor.border)
        return Button {
            tapLeft(pair)
        } label: {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SylluneColor.inkMuted)
                    .accessibilityHidden(true)
                VStack(spacing: 2) {
                    ChineseSelectableText(pair.left, font: .title3, speechEnabled: false, wordInteractionEnabled: false)
                    if let pinyin = pair.pinyin { Text(pinyin).font(.callout).foregroundStyle(SylluneColor.inkMuted) }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(SylluneColor.ink)
        .background(SylluneColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent, lineWidth: isSelected || isTied ? 2 : 1)
        )
        .accessibilityLabel("\(pair.left), élément \(number)")
        .accessibilityValue(isTied ? "Associé" : (isSelected ? "Sélectionné" : "Non associé"))
        .accessibilityIdentifier("lesson.exercise.\(exercise.header.id.rawValue).left.\(pair.id)")
    }

    private func rightTile(_ pair: MatchPair) -> some View {
        let partnerID = partner(ofRight: pair.id)
        let isTied = partnerID != nil
        let accent = partnerID.flatMap { feedbackColor(leftID: $0) } ?? (isTied ? SylluneColor.jade : SylluneColor.border)
        let label = pair.right.resolve(preferred: ["fr", "en"]) ?? ""
        return Button {
            tapRight(pair)
        } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let partnerID, let partnerNumber = number(ofLeft: partnerID) {
                    Text("\(partnerNumber)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SylluneColor.jade)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(SylluneColor.ink)
        .background(SylluneColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent, lineWidth: isTied ? 2 : 1)
        )
        .accessibilityLabel(label)
        .accessibilityValue(partnerID.flatMap(number(ofLeft:)).map { "Associé à l’élément \($0)" } ?? "Non associé")
        .accessibilityIdentifier("lesson.exercise.\(exercise.header.id.rawValue).right.\(pair.id)")
    }

    private func tapLeft(_ pair: MatchPair) {
        if pairs[pair.id] != nil {
            pairs.removeValue(forKey: pair.id)
            selectedLeft = pair.id
        } else {
            selectedLeft = selectedLeft == pair.id ? nil : pair.id
        }
        publish()
        Task { try? await model.dependencies.audio.speak(text: pair.left, localeIdentifier: "zh-CN", rate: .normal) }
    }

    private func tapRight(_ pair: MatchPair) {
        if let selectedLeft {
            // One right-hand item belongs to one left-hand item.
            if let other = partner(ofRight: pair.id) { pairs.removeValue(forKey: other) }
            pairs[selectedLeft] = pair.id
            self.selectedLeft = nil
        } else if let other = partner(ofRight: pair.id) {
            pairs.removeValue(forKey: other)
        }
        publish()
    }

    private func publish() {
        answer = pairs.isEmpty ? nil : .matching(pairs: pairs)
    }

    private func syncFromAnswer() {
        if case .matching(let restored) = answer {
            pairs = restored
        } else {
            pairs = [:]
            selectedLeft = nil
        }
    }
}

/// Puts the shuffled lines of a dialogue back in order, by touching them in turn.
struct DialogueOrderAnswerView: View {
    let exercise: DialogueOrderExercise
    @Binding var answer: ExerciseAnswer?
    @EnvironmentObject private var model: AppModel
    @State private var selected: [String] = []

    init(exercise: DialogueOrderExercise, answer: Binding<ExerciseAnswer?>) {
        self.exercise = exercise
        self._answer = answer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Touche les répliques dans l’ordre de la conversation. Touche une réplique numérotée pour la retirer.")
                .font(.callout)
                .foregroundStyle(SylluneColor.inkMuted)
            ForEach(exercise.lines) { line in
                lineButton(line)
            }
        }
        .onAppear { syncFromAnswer() }
        .onChange(of: answer) { _, _ in syncFromAnswer() }
    }

    private func lineButton(_ line: DialogueOrderLine) -> some View {
        let position = selected.firstIndex(of: line.id).map { $0 + 1 }
        let isSelected = position != nil
        let speakerPrefix = line.speaker.map { $0 + " : " } ?? ""
        let positionText = position.map { String($0) } ?? "non choisie"
        return Button {
            if let index = selected.firstIndex(of: line.id) { selected.remove(at: index) }
            else { selected.append(line.id) }
            answer = selected.isEmpty ? nil : .wordOrder(tokenIDs: selected)
            Task { try? await model.dependencies.audio.speak(text: line.hanzi, localeIdentifier: "zh-CN", rate: .normal, asset: line.audio) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? SylluneColor.jade : SylluneColor.border, lineWidth: isSelected ? 2 : 1)
                        .frame(width: 30, height: 30)
                    if let position {
                        Text("\(position)").font(.callout.weight(.bold)).foregroundStyle(SylluneColor.jade)
                    }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    if let speaker = line.speaker {
                        Text(speaker).font(.caption.weight(.semibold)).foregroundStyle(SylluneColor.inkMuted)
                    }
                    ChineseSelectableText(line.hanzi, font: .title3, speechEnabled: false, wordInteractionEnabled: false)
                    if let pinyin = line.pinyin { Text(pinyin).font(.callout).foregroundStyle(SylluneColor.inkMuted) }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(SylluneColor.ink)
        .background(SylluneColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? SylluneColor.jade : SylluneColor.border, lineWidth: isSelected ? 2 : 1)
        )
        .accessibilityLabel("\(speakerPrefix)\(line.hanzi), position \(positionText)")
        .accessibilityIdentifier("lesson.exercise.\(exercise.header.id.rawValue).line.\(line.id)")
    }

    private func syncFromAnswer() {
        if case .wordOrder(let tokenIDs) = answer {
            selected = tokenIDs
        } else {
            selected = []
        }
    }
}

/// Mini-conversation: hear the interlocutor's line, then choose the best of
/// three replies. Every reply can be heard before it is chosen.
struct ConversationAnswerView: View {
    let exercise: ConversationChoiceExercise
    @Binding var answer: ExerciseAnswer?
    @EnvironmentObject private var model: AppModel
    @State private var audioMessage: String?
    @AppStorage(SlowAudioToggle.storageKey) private var slowAudio = false

    init(exercise: ConversationChoiceExercise, answer: Binding<ExerciseAnswer?>) {
        self.exercise = exercise
        self._answer = answer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let speaker = exercise.speaker {
                        Text(speaker).font(.caption.weight(.semibold)).foregroundStyle(SylluneColor.inkMuted)
                    }
                    if let promptText = exercise.promptText {
                        ChineseSelectableText(promptText, font: .title3, speechEnabled: false, wordInteractionEnabled: false)
                            .foregroundStyle(SylluneColor.ink)
                    }
                }
                Spacer(minLength: 8)
                speakerButton(label: "Écouter la réplique", identifier: "prompt.play") {
                    play(audio: exercise.promptAudio, text: exercise.promptText)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sylluneCard(radius: 12)
            SlowAudioToggle()
            if let audioMessage { Text(audioMessage).font(.caption).foregroundStyle(SylluneColor.inkMuted) }
            ForEach(exercise.replies) { reply in
                replyRow(reply)
            }
        }
    }

    private func speakerButton(label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title3)
                .foregroundStyle(SylluneColor.sky)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("lesson.exercise.\(exercise.header.id.rawValue).\(identifier)")
    }

    private func replyRow(_ reply: ConversationReply) -> some View {
        let isSelected: Bool = {
            if case .choice(let selected) = answer { return selected == reply.id }
            return false
        }()
        return HStack(spacing: 8) {
            Button {
                answer = .choice(choiceID: reply.id)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        ChineseSelectableText(reply.hanzi, font: .title3, speechEnabled: false, wordInteractionEnabled: false)
                        if let pinyin = reply.pinyin { Text(pinyin).font(.callout).foregroundStyle(SylluneColor.inkMuted) }
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(SylluneColor.jade)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(SylluneColor.ink)
            .accessibilityLabel(reply.hanzi)
            .accessibilityValue(isSelected ? "Sélectionnée" : "Non sélectionnée")
            .accessibilityIdentifier("lesson.exercise.\(exercise.header.id.rawValue).reply.\(reply.id)")
            speakerButton(label: "Écouter la réponse", identifier: "reply.\(reply.id).play") {
                play(audio: reply.audio, text: reply.hanzi)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .background(SylluneColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? SylluneColor.jade : SylluneColor.border, lineWidth: isSelected ? 2 : 1)
        )
    }

    private func play(audio: AssetReference?, text: String?) {
        guard let text else {
            audioMessage = "Aucune source audio n’est fournie. Le texte reste disponible."
            return
        }
        Task {
            do {
                try await model.dependencies.audio.speak(text: text, localeIdentifier: "zh-CN", rate: SlowAudioToggle.rate(slow: slowAudio), asset: audio)
                audioMessage = nil
            } catch is CancellationError {
                audioMessage = nil
            } catch {
                audioMessage = "Audio indisponible. Le texte reste disponible."
            }
        }
    }
}
