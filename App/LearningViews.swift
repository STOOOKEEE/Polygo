import SwiftUI
import PolygoCore

public struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var recentErrors: [String] = []

    public init() {}
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top) {
                        greetingBlock
                        Spacer(minLength: 12)
                        streakBadge
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        greetingBlock
                        streakBadge
                    }
                }

                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(SylluneColor.error)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sylluneCard(radius: 12)
                }

                resumeCard
                reviewCard
                objectiveCard

                if !recentErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mes erreurs récentes").font(.title3.weight(.semibold)).foregroundStyle(SylluneColor.ink)
                        ForEach(recentErrors, id: \.self) { value in
                            Text(value).font(.body).foregroundStyle(SylluneColor.inkMuted)
                        }
                    }
                    .padding(18)
                    .sylluneCard()
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(SylluneColor.canvas)
        .navigationTitle("Aujourd’hui")
        .task { recentErrors = model.snapshot.lessonProgress.values.flatMap { $0.mistakeExerciseIDs.map(\.rawValue) }.sorted() }
    }

    private var resumeCard: some View {
        Group {
            if let lessonID = model.nextLessonID {
                NavigationLink(destination: LessonView(lessonID: lessonID)) {
                    HStack(spacing: 16) {
                        ProgressRing(value: model.snapshot.lessonProgress[lessonID]?.completionRate ?? 0)
                            .frame(width: 58, height: 58)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Reprendre").font(.headline).foregroundStyle(SylluneColor.ink)
                            Text(lessonTitle(lessonID)).font(.body).foregroundStyle(SylluneColor.inkMuted)
                            Text(progressText(for: lessonID)).font(.caption).foregroundStyle(SylluneColor.inkMuted)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill").font(.title2).foregroundStyle(SylluneColor.jade)
                    }
                    .padding(20)
                }
                .buttonStyle(.plain)
                .sylluneCard(radius: 24)
                .accessibilityHint("Ouvre la leçon suivante")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Parcours terminé", systemImage: "checkmark.circle.fill")
                        .font(.headline).foregroundStyle(SylluneColor.success)
                    Text("Toutes les leçons disponibles sont terminées. Les cartes restent accessibles pour réviser.")
                        .font(.body).foregroundStyle(SylluneColor.inkMuted)
                }
                .padding(20).sylluneCard(radius: 24)
            }
        }
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.greeting)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(SylluneColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Une syllabe à la fois.")
                .font(.body)
                .foregroundStyle(SylluneColor.inkMuted)
        }
    }

    private var streakBadge: some View {
        Label("\(model.streakDays) jours", systemImage: "flame.fill")
            .font(.callout.weight(.semibold))
            .foregroundStyle(SylluneColor.inkOnSun)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(SylluneColor.sun, in: Capsule())
            .accessibilityLabel("Série actuelle : \(model.streakDays) jours")
            .frame(minHeight: 44, alignment: .leading)
    }

    private var reviewCard: some View {
        let count = model.snapshot.dueCards(at: model.dependencies.clock.now()).count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Révisions dues", systemImage: "rectangle.stack")
                    .font(.headline).foregroundStyle(SylluneColor.ink)
                Spacer()
                Badge("\(count)", color: SylluneColor.surfaceRaised)
            }
            if count > 0 {
                Text("Les cartes sont triées par échéance et restent disponibles hors ligne.")
                    .font(.body).foregroundStyle(SylluneColor.inkMuted)
                        NavigationLink(destination: ReviewCardsView()) { Text("Réviser") }
                            .buttonStyle(SyllunePrimaryButtonStyle())
            } else {
                Text("Rien à revoir pour le moment.")
                    .font(.body).foregroundStyle(SylluneColor.inkMuted)
            }
        }
        .padding(18).sylluneCard()
    }

    private var objectiveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Objectif du jour", systemImage: "target")
                .font(.headline).foregroundStyle(SylluneColor.ink)
            Text("\(model.snapshot.profile?.dailyMinutes ?? 10) min")
                .font(.title2.weight(.semibold)).foregroundStyle(SylluneColor.jadeDeep)
            Text("Commence une leçon pour avancer dans ton objectif.")
                .font(.callout).foregroundStyle(SylluneColor.inkMuted)
        }
        .padding(18).sylluneCard()
    }

    private func lessonTitle(_ id: LessonID) -> String {
        model.loadedLessons[id]?.title.resolve(preferred: model.preferredLanguageCodes) ?? "Leçon \(id.rawValue)"
    }

    private func progressText(for id: LessonID) -> String {
        let progress = model.snapshot.lessonProgress[id]
        return "\(progress?.answeredCount ?? 0) exercices répondus"
    }
}

public struct LearningPathView: View {
    @EnvironmentObject private var model: AppModel
    @State private var lessons: [LessonID: LessonDocument] = [:]

    public init() {}
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let course = model.course {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(course.title.resolve(preferred: model.preferredLanguageCodes) ?? "Parcours")
                            .font(.largeTitle.weight(.semibold)).foregroundStyle(SylluneColor.ink)
                        Text(course.description.resolve(preferred: model.preferredLanguageCodes) ?? "")
                            .font(.body).foregroundStyle(SylluneColor.inkMuted)
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                Badge("HSK 1")
                                Badge("A1")
                                completedLessonsLabel
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Badge("HSK 1")
                                    Badge("A1")
                                }
                                completedLessonsLabel
                            }
                        }
                    }
                }
                ForEach(model.course?.modules.sorted(by: { $0.order < $1.order }) ?? [], id: \.id) { module in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(module.title.resolve(preferred: model.preferredLanguageCodes) ?? "Unité")
                            .font(.title2.weight(.semibold)).foregroundStyle(SylluneColor.ink)
                        ForEach(module.lessonIDs, id: \.self) { lessonID in
                            lessonRow(lessonID)
                        }
                    }
                }
                if model.course == nil {
                    ContentUnavailableView("Parcours indisponible", systemImage: "books.vertical", description: Text(model.errorMessage ?? "Le contenu n’est pas encore chargé."))
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(SylluneColor.canvas)
        .navigationTitle("Parcours")
        .task {
            for lessonID in model.orderedLessonIDs {
                if let lesson = await model.loadLesson(lessonID) { lessons[lessonID] = lesson }
            }
        }
    }

    private var completedLessonsLabel: some View {
        Text("\(model.snapshot.lessonProgress.values.filter { $0.completedAt != nil }.count) leçons terminées")
            .font(.caption)
            .foregroundStyle(SylluneColor.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func lessonRow(_ lessonID: LessonID) -> some View {
        let progress = model.snapshot.lessonProgress[lessonID]
        let unlocked = model.isLessonUnlocked(lessonID)
        let title = lessons[lessonID]?.title.resolve(preferred: model.preferredLanguageCodes) ?? "Leçon \(lessonID.rawValue)"
        if unlocked {
            NavigationLink(destination: LessonView(lessonID: lessonID)) {
                HStack(spacing: 14) {
                    Image(systemName: progress?.completedAt == nil ? "circle" : "checkmark.circle.fill")
                        .font(.title2).foregroundStyle(progress?.completedAt == nil ? SylluneColor.jade : SylluneColor.success)
                    VStack(alignment: .leading, spacing: 4) {
                            Text(title).font(.body.weight(.semibold)).foregroundStyle(SylluneColor.ink).fixedSize(horizontal: false, vertical: true)
                        Text(lessons[lessonID].map { "\($0.estimatedMinutes) min · \($0.blocks.filter { if case .exercise = $0 { return true }; return false }.count) exercices" } ?? "Chargement…")
                            .font(.caption).foregroundStyle(SylluneColor.inkMuted)
                    }
                    Spacer()
                    if let progress, progress.completedAt != nil { Text("Terminé").font(.caption.weight(.semibold)).foregroundStyle(SylluneColor.success) }
                    else { Image(systemName: "chevron.right").foregroundStyle(SylluneColor.inkMuted) }
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            .sylluneCard(radius: 14)
        } else {
            HStack(spacing: 14) {
                Image(systemName: "lock.fill").foregroundStyle(SylluneColor.inkMuted)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(SylluneColor.inkMuted)
                            Text("Termine la leçon précédente pour déverrouiller cette étape.").font(.caption).foregroundStyle(SylluneColor.inkMuted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(16).sylluneCard(radius: 14)
            .accessibilityLabel("\(title), verrouillée. Termine la leçon précédente.")
        }
    }
}

public struct ExplorerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var stories: [StoryDocument] = []
    @State private var showingDictionary = false

    public init() {}
    public var body: some View {
        List {
            Section {
                Button { showingDictionary = true } label: {
                    Label("Dictionnaire de l’unité 1", systemImage: "magnifyingglass")
                }
                .foregroundStyle(SylluneColor.jadeDeep)
            }
            Section("Histoires") {
                if stories.isEmpty {
                    Text("Les histoires locales apparaîtront ici dès que leur contenu est installé.")
                        .font(.body).foregroundStyle(SylluneColor.inkMuted)
                } else {
                    ForEach(stories) { story in
                        NavigationLink(destination: StoryDetailView(storyID: story.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(story.title.resolve(preferred: model.preferredLanguageCodes) ?? "Histoire").font(.body.weight(.semibold))
                                Text("\(story.level) · \(story.estimatedMinutes) min · Disponible hors ligne")
                                    .font(.caption).foregroundStyle(SylluneColor.inkMuted)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SylluneColor.canvas)
        .navigationTitle("Explorer")
        .sheet(isPresented: $showingDictionary) { NavigationStack { DictionaryView() } }
        .task {
            if let store = model.dependencies.content as? any StoryContentStore { stories = (try? await store.stories()) ?? [] }
        }
    }
}

public struct DictionaryView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    public var initialQuery: String?
    @State private var query: String
    @State private var entries: [VocabularyEntry] = []
    @FocusState private var searchFocused: Bool

    public init(initialQuery: String? = nil) {
        self.initialQuery = initialQuery
        _query = State(initialValue: initialQuery ?? "")
    }

    private var filtered: [VocabularyEntry] {
        let normalized = TextNormalizer.normalize(query)
        guard !normalized.isEmpty else { return entries }
        return entries.filter { entry in
            [entry.hanzi, entry.traditionalHanzi ?? "", entry.pinyin, entry.meaning.resolve(preferred: ["fr", "en"]) ?? ""].contains {
                let candidate = TextNormalizer.normalize($0)
                return candidate == normalized || candidate.hasPrefix(normalized)
            }
        }
    }

    public var body: some View {
        Group {
            if filtered.isEmpty && !query.isEmpty {
                ContentUnavailableView("Aucun mot pour « \(query) »", systemImage: "character.book.closed", description: Text("Parcours l’unité 1 pour découvrir son vocabulaire."))
            } else {
                List(filtered) { entry in
                        NavigationLink(destination: WordDetailView(vocabularyID: entry.id)) {
                            HStack(spacing: 14) {
                            Text(entry.hanzi)
                                .font(.title2)
                                .foregroundStyle(SylluneColor.ink)
                                .accessibilityLanguage("zh-CN")
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.pinyin)
                                    .font(.body)
                                    .foregroundStyle(SylluneColor.jadeDeep)
                                    .accessibilityLanguage("fr-FR")
                                Text(entry.meaning.resolve(preferred: ["fr", "en"]) ?? "—")
                                    .font(.callout)
                                    .foregroundStyle(SylluneColor.inkMuted)
                                    .accessibilityLanguage("fr-FR")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $query, prompt: "Caractère, pinyin ou sens")
        .searchFocused($searchFocused)
        .navigationTitle("Dictionnaire")
        .background(SylluneColor.canvas)
        .task {
            entries = await model.dictionaryEntries()
            if initialQuery?.isEmpty ?? true { searchFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sylluneFocusDictionarySearch)) { _ in
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .sylluneEscape)) { _ in
            dismiss()
        }
    }
}

public struct WordDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    public let vocabularyID: VocabularyID
    public let autoPlayAudio: Bool
    @State private var entry: VocabularyEntry?
    @State private var added = false
    @State private var audioMessage: String?

    public init(vocabularyID: VocabularyID, autoPlayAudio: Bool = false) {
        self.vocabularyID = vocabularyID
        self.autoPlayAudio = autoPlayAudio
        _entry = State(initialValue: nil)
    }
    public var body: some View {
        ScrollView {
            if let entry {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        ChineseSelectableText(hanzi: entry.hanzi, font: .largeTitle.weight(.semibold), vocabulary: [entry])
                            .foregroundStyle(SylluneColor.ink)
                        Text(entry.pinyin)
                            .font(.title2)
                            .foregroundStyle(SylluneColor.jadeDeep)
                            .accessibilityLabel("Pinyin : \(entry.pinyin)")
                            .accessibilityLanguage("fr-FR")
                        if !entry.toneNumbers.isEmpty {
                            Text("Ton \(entry.toneNumbers.map(String.init).joined(separator: " · "))")
                                .font(.caption)
                                .foregroundStyle(SylluneColor.inkMuted)
                                .accessibilityLabel("Tons : \(entry.toneNumbers.map(String.init).joined(separator: ", "))")
                                .accessibilityLanguage("fr-FR")
                        }
                        Text(entry.meaning.resolve(preferred: ["fr", "en"]) ?? "—")
                            .font(.title3)
                            .foregroundStyle(SylluneColor.ink)
                            .accessibilityLabel("Sens : \(entry.meaning.resolve(preferred: ["fr", "en"]) ?? "—")")
                            .accessibilityLanguage("fr-FR")
                    }
                    .accessibilityElement(children: .contain)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            audioButton(for: entry)
                            audioAvailability(for: entry)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            audioButton(for: entry)
                            audioAvailability(for: entry)
                        }
                    }
                    if let audioMessage { Text(audioMessage).font(.callout).foregroundStyle(SylluneColor.inkMuted) }
                    if let example = entry.example {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exemple").font(.headline).foregroundStyle(SylluneColor.ink)
                            ChineseSelectableText(hanzi: example.hanzi, font: .title3, vocabulary: model.loadedLessons.values.flatMap(\.vocabulary))
                                .foregroundStyle(SylluneColor.ink)
                            Text(example.pinyin)
                                .font(.body)
                                .foregroundStyle(SylluneColor.jadeDeep)
                                .accessibilityLabel("Pinyin : \(example.pinyin)")
                                .accessibilityLanguage("fr-FR")
                            Text(example.translation.resolve(preferred: ["fr", "en"]) ?? "")
                                .font(.body)
                                .foregroundStyle(SylluneColor.inkMuted)
                                .accessibilityLabel("Traduction : \(example.translation.resolve(preferred: ["fr", "en"]) ?? "")")
                                .accessibilityLanguage("fr-FR")
                        }
                        .padding(16).sylluneCard()
                    }
                    if let memory = entry.memoryStory?.resolve(preferred: ["fr", "en"]) {
                        Label(memory, systemImage: "lightbulb").font(.callout).foregroundStyle(SylluneColor.inkMuted)
                    }
                    Button {
                        if let card = model.card(for: entry.id) { Task { added = await model.addCard(card.id) } }
                    } label: {
                        Label(added ? "Déjà dans mes cartes" : "Ajouter aux cartes", systemImage: added ? "checkmark" : "plus")
                    }
                    .buttonStyle(SyllunePrimaryButtonStyle())
                    .disabled(added || model.card(for: entry.id) == nil)
                    if model.card(for: entry.id) == nil {
                        Text("Cette entrée n’a pas encore de carte dans le contenu embarqué.").font(.caption).foregroundStyle(SylluneColor.inkMuted)
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(24)
            } else { ProgressView("Chargement du mot…") }
        }
        .background(SylluneColor.canvas)
        .navigationTitle("Fiche mot")
        .onReceive(NotificationCenter.default.publisher(for: .sylluneEscape)) { _ in dismiss() }
        .task {
            let loadedEntry = await model.dictionaryEntries().first(where: { $0.id == vocabularyID })
            entry = loadedEntry
            added = model.snapshot.reviewStates.values.contains(where: { model.card(for: vocabularyID)?.id == $0.cardID })
            if autoPlayAudio, let loadedEntry {
                await playAudio(for: loadedEntry)
            }
        }
    }

    private func playAudio(for entry: VocabularyEntry) async {
        do {
            if let asset = entry.audio {
                do {
                    try await model.dependencies.audio.play(asset: asset)
                } catch {
                    try await model.dependencies.audio.speak(text: entry.hanzi, localeIdentifier: "zh-CN", rate: .normal)
                }
            } else {
                try await model.dependencies.audio.speak(text: entry.hanzi, localeIdentifier: "zh-CN", rate: .normal)
            }
            audioMessage = "Lecture en cours."
        } catch {
            audioMessage = "Audio indisponible hors ligne."
        }
    }

    private func audioButton(for entry: VocabularyEntry) -> some View {
        Button {
            Task { await playAudio(for: entry) }
        } label: {
            Label("Écouter", systemImage: "speaker.wave.2.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(SylluneColor.skyButton)
        .frame(minHeight: 44)
    }

    private func audioAvailability(for entry: VocabularyEntry) -> some View {
        Text(entry.audio == nil ? "Voix locale si disponible" : "Disponible hors ligne")
            .font(.caption)
            .foregroundStyle(SylluneColor.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
