import SwiftUI
import PolygoCore
import PolygoApple

public struct StoryDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    public let storyID: StoryID
    @State private var story: StoryDocument?
    @State private var vocabulary: [VocabularyEntry] = []
    @State private var showPinyin = true
    @State private var message: String?
    @State private var isStoryAudioPlaying = false

    public init(storyID: StoryID) { self.storyID = storyID }
    public var body: some View {
        ScrollView {
            if let story {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(story.title.resolve(preferred: model.preferredLanguageCodes) ?? "Histoire").font(.largeTitle.weight(.semibold)).foregroundStyle(SylluneColor.ink)
                        Text(story.summary.resolve(preferred: model.preferredLanguageCodes) ?? "").font(.body).foregroundStyle(SylluneColor.inkMuted)
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                Badge(story.level)
                                Badge("\(story.estimatedMinutes) min")
                                Badge("Disponible hors ligne", color: SylluneColor.surfaceRaised)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Badge(story.level); Badge("\(story.estimatedMinutes) min") }
                                Badge("Disponible hors ligne", color: SylluneColor.surfaceRaised)
                            }
                        }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Toggle("Afficher le pinyin", isOn: $showPinyin).toggleStyle(.switch)
                            Spacer(minLength: 12)
                            storyAudioControls(story)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Afficher le pinyin", isOn: $showPinyin).toggleStyle(.switch)
                            storyAudioControls(story)
                        }
                    }
                    if let message { Text(message).font(.caption).foregroundStyle(SylluneColor.inkMuted) }
                    ForEach(Array(story.paragraphs.enumerated()), id: \.element.id) { index, paragraph in
                        paragraphView(paragraph, index: index)
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            } else if let message {
                ContentUnavailableView("Histoire indisponible", systemImage: "book.closed", description: Text(message))
            } else { ProgressView("Chargement de l’histoire…") }
        }
        .background(SylluneColor.canvas)
        .navigationTitle("Lecture")
        .task {
            guard let store = model.dependencies.content as? any StoryContentStore else { message = "Ce contenu n’est pas fourni par le bundle local."; return }
            do {
                story = try await store.story(id: storyID)
                vocabulary = await model.dictionaryEntries()
            }
            catch { message = error.localizedDescription }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sylluneEscape)) { _ in
            model.dependencies.audio.stopPlayback()
            model.dependencies.audio.stopSpeaking()
            isStoryAudioPlaying = false
            dismiss()
        }
    }

    @ViewBuilder private func paragraphView(_ paragraph: ReadingParagraph, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(index + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SylluneColor.inkMuted)
                    .accessibilityLabel("Phrase \(index + 1)")
                ChineseSelectableText(
                    hanzi: paragraph.hanzi,
                    font: .title3,
                    speechEnabled: true,
                    vocabulary: vocabulary,
                    segmentation: paragraph.segmentation,
                    pinyin: showPinyin ? paragraph.pinyin : nil,
                    translation: paragraph.translation.resolve(preferred: ["fr", "en"]),
                    audio: paragraph.audio
                )
                .foregroundStyle(SylluneColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16).sylluneCard(radius: 14)
    }

    @ViewBuilder private func storyAudioControls(_ story: StoryDocument) -> some View {
        if let audio = story.audio {
            Button {
                if isStoryAudioPlaying {
                    model.dependencies.audio.stopPlayback()
                    isStoryAudioPlaying = false
                    message = "Lecture arrêtée."
                } else {
                    Task { @MainActor in
                        do {
                            try await model.dependencies.audio.play(asset: audio)
                            isStoryAudioPlaying = true
                            message = "Lecture en cours."
                        } catch {
                            isStoryAudioPlaying = false
                            message = "Audio indisponible hors ligne."
                        }
                    }
                }
            } label: {
                Label(isStoryAudioPlaying ? "Arrêter" : "Écouter", systemImage: isStoryAudioPlaying ? "stop.fill" : "speaker.wave.2.fill")
            }
            .buttonStyle(.bordered)
            .tint(SylluneColor.skyButton)
            .frame(minHeight: 44)
            .accessibilityLabel(isStoryAudioPlaying ? "Arrêter l’audio de l’histoire" : "Écouter l’histoire")
            .accessibilityHint("Lecture locale de l’histoire, disponible hors ligne si l’audio est fourni.")
        }
    }
}
