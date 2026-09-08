import SwiftUI
import PolygoCore

public struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    public init() {}
    public var body: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                desktopHome
                compactHome
            }
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
        }
        .background(SylluneColor.canvas)
        .navigationTitle("Aujourd’hui")
        .task(id: model.orderedLessonIDs) {
            for lessonID in model.orderedLessonIDs {
                _ = await model.loadLesson(lessonID)
            }
        }
    }

    @ViewBuilder
    private var desktopHome: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let error = model.errorMessage {
                errorBanner(error)
            }
            HStack(alignment: .top, spacing: 24) {
                resumeCard(compact: false)
                    .frame(minWidth: 560, maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 18) {
                    pathCard
                    flashcardsCard
                }
                .frame(width: 360)
            }
        }
        .frame(minWidth: 944, maxWidth: 1180, alignment: .leading)
    }

    @ViewBuilder
    private var compactHome: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let error = model.errorMessage {
                errorBanner(error)
            }
            resumeCard(compact: true)
            pathCard
            flashcardsCard
        }
    }

    private func errorBanner(_ error: String) -> some View {
        Label(error, systemImage: "exclamationmark.triangle")
            .font(.callout.weight(.medium))
            .foregroundStyle(SylluneColor.error)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sylluneCard(style: .quiet, radius: 16)
    }

    @ViewBuilder
    private func resumeCard(compact: Bool) -> some View {
        if let lessonID = model.resumeLessonID {
            VStack(spacing: 0) {
                NavigationLink(destination: LessonView(lessonID: lessonID)) {
                    heroContent(lessonID: lessonID, compact: compact)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.primaryAction")
                .accessibilityHint("Ouvre la leçon suivante")
            }
            .sylluneCard(style: .hero, radius: compact ? 26 : 30)
            .accessibilityIdentifier("home.hero")
        } else {
            VStack(alignment: .leading, spacing: 18) {
                heroHeader
                HStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(SylluneColor.heroAccent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Parcours terminé")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(SylluneColor.heroInk)
                        Text("Toutes les leçons disponibles sont terminées. Les cartes restent accessibles pour réviser.")
                            .font(.body)
                            .foregroundStyle(SylluneColor.heroMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(compact ? 22 : 30)
            .frame(maxWidth: .infinity, minHeight: compact ? 240 : 280, alignment: .leading)
            .sylluneCard(style: .hero, radius: compact ? 26 : 30)
            .accessibilityIdentifier("home.hero")
        }
    }

    private func heroContent(lessonID: LessonID, compact: Bool) -> some View {
        let progress = lessonProgressFraction(for: lessonID)
        let actionTitle = model.snapshot.lessonProgress[lessonID]?.lastOpenedAt == nil ? "Commencer" : "Continuer"
        return ZStack(alignment: .topTrailing) {
            Text("学")
                .font(.system(size: compact ? 112 : 172, weight: .bold, design: .serif))
                .foregroundStyle(SylluneColor.heroInk.opacity(0.10))
                .offset(x: compact ? 8 : 18, y: compact ? -18 : -34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: compact ? 18 : 22) {
                heroHeader

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.greeting)
                        .font(.system(size: compact ? 31 : 42, weight: .bold, design: .rounded))
                        .foregroundStyle(SylluneColor.heroInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Une syllabe à la fois.")
                        .font(.title3)
                        .foregroundStyle(SylluneColor.heroMuted)
                }

                heroProgressBlock(lessonID: lessonID, progress: progress, compact: compact)
                if !compact {
                    Spacer(minLength: 24)
                }
                HStack(spacing: 9) {
                    Text(actionTitle)
                        .font(.headline.weight(.bold))
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(SylluneColor.heroEnd)
                .padding(.horizontal, 17)
                .frame(minHeight: 44)
                .background(SylluneColor.heroAccent, in: Capsule())
            }
        }
        .padding(compact ? 22 : 30)
        .frame(maxWidth: .infinity, minHeight: compact ? 286 : 500, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func heroProgressBlock(lessonID: LessonID, progress: Double, compact: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                heroProgressRing(lessonID: lessonID, progress: progress, compact: compact)
                heroProgressDetails(lessonID: lessonID, progress: progress, compact: compact, includesBar: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 16) {
                    heroProgressRing(lessonID: lessonID, progress: progress, compact: compact)
                    heroProgressDetails(lessonID: lessonID, progress: progress, compact: compact, includesBar: false)
                }
                SylluneProgressBar(value: progress, tint: SylluneColor.heroAccent)
                    .frame(maxWidth: compact ? 240 : 360)
            }
        }
    }

    private func heroProgressRing(lessonID: LessonID, progress: Double, compact: Bool) -> some View {
        ProgressRing(value: progress, tint: SylluneColor.heroAccent)
            .frame(width: compact ? 64 : 76, height: compact ? 64 : 76)
            .accessibilityLabel("Progression de la leçon")
            .accessibilityValue(progressText(for: lessonID))
    }

    @ViewBuilder
    private func heroProgressDetails(lessonID: LessonID, progress: Double, compact: Bool, includesBar: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PROCHAINE ÉTAPE")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(SylluneColor.heroMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text(lessonTitle(lessonID))
                .font(.title3.weight(.bold))
                .foregroundStyle(SylluneColor.heroInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(progressText(for: lessonID))
                .font(.callout)
                .foregroundStyle(SylluneColor.heroMuted)
                .fixedSize(horizontal: false, vertical: true)
            if includesBar {
                SylluneProgressBar(value: progress, tint: SylluneColor.heroAccent)
                    .frame(maxWidth: compact ? 190 : 280)
                    .padding(.top, 4)
            }
        }
    }

    private var heroHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                Label("AUJOURD’HUI", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(SylluneColor.heroMuted)
                Spacer(minLength: 10)
                streakBadge
            }
            VStack(alignment: .leading, spacing: 10) {
                Label("AUJOURD’HUI", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(SylluneColor.heroMuted)
                streakBadge
            }
        }
    }

    private var streakBadge: some View {
        let dayLabel = model.streakDays == 1 ? "jour" : "jours"
        return Label("\(model.streakDays) \(dayLabel)", systemImage: "flame.fill")
            .font(.callout.weight(.bold))
            .foregroundStyle(SylluneColor.inkOnSun)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SylluneColor.sun, in: Capsule())
            .accessibilityLabel("Série actuelle : \(model.streakDays) \(dayLabel)")
            .frame(minHeight: 44, alignment: .leading)
    }

    private var pathCard: some View {
        let total = model.orderedLessonIDs.count
        let completed = model.snapshot.lessonProgress.values.filter { $0.completedAt != nil }.count
        let value = total == 0 ? 0 : Double(completed) / Double(total)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Label("Ton parcours", systemImage: "map")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SylluneColor.ink)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(completed) / \(total)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SylluneColor.jadeDeep)
                    Text("étapes")
                        .font(.caption)
                        .foregroundStyle(SylluneColor.inkMuted)
                }
            }
            SylluneProgressBar(value: value, tint: SylluneColor.pathJade)
                .frame(height: 8)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.orderedLessonIDs.enumerated()), id: \.element) { index, lessonID in
                    homeLessonRow(lessonID, index: index)
                }
            }
            NavigationLink(destination: LearningPathView()) {
                Label("Voir le parcours complet", systemImage: "arrow.right")
            }
            .buttonStyle(.bordered)
            .tint(SylluneColor.pathJade)
            .frame(minHeight: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sylluneCard(style: .interactive, radius: 24)
        .accessibilityIdentifier("home.path")
    }

    private var flashcardsCard: some View {
        let dueCount = model.snapshot.dueCards(at: model.dependencies.clock.now()).count
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                flashcardMark
                VStack(alignment: .leading, spacing: 4) {
                    Text("Flashcards")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SylluneColor.ink)
                    Text(dueCount == 0 ? "Aucune carte à revoir maintenant." : "\(dueCount) carte\(dueCount == 1 ? "" : "s") à revoir")
                        .font(.body)
                        .foregroundStyle(SylluneColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if dueCount > 0 {
                    Badge("\(dueCount) à revoir", color: SylluneColor.pathCoral.opacity(0.16))
                }
            }
            HStack(alignment: .center, spacing: 12) {
                Text(dueCount == 0 ? "Prête quand tu le seras." : "Une courte session suffit.")
                    .font(.callout)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                flashcardsLink(dueCount: dueCount)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sylluneCard(style: .quiet, radius: 24)
        .accessibilityIdentifier("home.review")
    }

    private var flashcardMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SylluneColor.pathCoral.opacity(0.72))
                .frame(width: 38, height: 32)
                .offset(x: -6, y: -5)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SylluneColor.pathSky)
                .frame(width: 42, height: 36)
            Image(systemName: "rectangle.stack.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: 48, height: 44)
        .accessibilityHidden(true)
    }

    private func flashcardsLink(dueCount: Int) -> some View {
        NavigationLink(destination: ReviewCardsView()) {
            Text(dueCount == 0 ? "Ouvrir" : "Réviser")
        }
        .buttonStyle(.borderedProminent)
        .tint(SylluneColor.pathCoral)
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private func homeLessonRow(_ lessonID: LessonID, index: Int) -> some View {
        let progress = model.snapshot.lessonProgress[lessonID]
        let completed = progress?.completedAt != nil
        let unlocked = model.isLessonUnlocked(lessonID)
        // A newly unlocked lesson is the next lesson to start, but it is not
        // an in-progress lesson until the learner has opened it once.
        let active = progress?.lastOpenedAt != nil && model.resumeLessonID == lessonID && !completed
        let title = model.loadedLessons[lessonID]?.title.resolve(preferred: model.preferredLanguageCodes) ?? "Leçon \(index + 1)"
        let accent = SylluneColor.pathAccent(for: index)
        let status = completed ? "Terminée" : active ? "En cours" : unlocked ? "À commencer" : "À débloquer"
        let row = HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(completed ? SylluneColor.success : accent)
                        .frame(width: 30, height: 30)
                    Text(completed ? "✓" : "\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(completed ? SylluneColor.inkOnSuccess : Color.white)
                }
                if index < model.orderedLessonIDs.count - 1 {
                    Capsule()
                        .fill(accent.opacity(0.42))
                        .frame(width: 3, height: 22)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(active || completed ? .semibold : .medium))
                    .foregroundStyle(unlocked ? SylluneColor.ink : SylluneColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(completed ? SylluneColor.success : active ? SylluneColor.jadeDeep : SylluneColor.inkMuted)
            }
            Spacer(minLength: 4)
            if unlocked {
                Image(systemName: completed ? "checkmark" : "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(completed ? SylluneColor.success : accent)
                    .frame(minWidth: 30, minHeight: 30)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .frame(minWidth: 30, minHeight: 30)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(active ? accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        if unlocked {
            NavigationLink(destination: LessonView(lessonID: lessonID)) { row }
                .buttonStyle(.plain)
                .accessibilityHint(active ? "Reprend cette leçon" : "Ouvre cette leçon")
        } else {
            row
            .accessibilityLabel("\(title), \(status)")
            .accessibilityHint("Cette étape est verrouillée")
        }
    }

    private func lessonTitle(_ id: LessonID) -> String {
        model.loadedLessons[id]?.title.resolve(preferred: model.preferredLanguageCodes) ?? "Leçon en cours"
    }

    private func progressText(for id: LessonID) -> String {
        let progress = model.snapshot.lessonProgress[id]
        guard let lesson = model.loadedLessons[id] else {
            return progress?.lastOpenedAt == nil ? "Première leçon" : "Reprise de ta leçon"
        }
        let count = lesson.blocks.reduce(into: 0) { result, block in
            if case .exercise = block { result += 1 }
        }
        let index = min(progress?.currentExerciseIndex ?? 0, count)
        return progress?.lastOpenedAt == nil ? "Prête à commencer" : "Exercice \(min(index + 1, max(1, count))) sur \(count)"
    }

    private func lessonProgressFraction(for id: LessonID) -> Double {
        guard let lesson = model.loadedLessons[id] else {
            return model.snapshot.lessonProgress[id]?.completedAt == nil ? 0 : 1
        }
        let count = lesson.blocks.reduce(into: 0) { result, block in
            if case .exercise = block { result += 1 }
        }
        guard count > 0 else { return 0 }
        return min(1, Double(model.snapshot.lessonProgress[id]?.currentExerciseIndex ?? 0) / Double(count))
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
                    pathHeader(course)
                }
                ForEach(model.course?.modules.sorted(by: { $0.order < $1.order }) ?? [], id: \.id) { module in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(module.title.resolve(preferred: model.preferredLanguageCodes) ?? "Unité", systemImage: "flag.checkered")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(SylluneColor.ink)
                            Spacer()
                            Text("\(module.lessonIDs.count) étapes")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SylluneColor.inkMuted)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(module.lessonIDs.enumerated()), id: \.element) { index, lessonID in
                                lessonRow(lessonID, index: index, isLast: index == module.lessonIDs.count - 1)
                            }
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sylluneCard(style: .interactive, radius: 24)
                }
                if model.course == nil {
                    ContentUnavailableView("Parcours indisponible", systemImage: "books.vertical", description: Text(model.errorMessage ?? "Le contenu n’est pas encore chargé."))
                }
            }
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
        }
        .background(SylluneColor.canvas)
        .navigationTitle("Parcours")
        .task {
            for lessonID in model.orderedLessonIDs {
                if let lesson = await model.loadLesson(lessonID) { lessons[lessonID] = lesson }
            }
        }
    }

    private func pathHeader(_ course: CourseManifest) -> some View {
        ZStack(alignment: .topTrailing) {
            Text("路")
                .font(.system(size: 170, weight: .bold, design: .serif))
                .foregroundStyle(SylluneColor.heroInk.opacity(0.10))
                .offset(x: 14, y: -34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 16) {
                Label("PARCOURS D’APPRENTISSAGE", systemImage: "map.fill")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(SylluneColor.heroMuted)
                Text(course.title.resolve(preferred: model.preferredLanguageCodes) ?? "Parcours")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(SylluneColor.heroInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(course.description.resolve(preferred: model.preferredLanguageCodes) ?? "")
                    .font(.body)
                    .foregroundStyle(SylluneColor.heroMuted)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        pathBadge("HSK 1")
                        pathBadge("A1")
                        completedLessonsLabel.foregroundStyle(SylluneColor.heroMuted)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            pathBadge("HSK 1")
                            pathBadge("A1")
                        }
                        completedLessonsLabel.foregroundStyle(SylluneColor.heroMuted)
                    }
                }
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sylluneCard(style: .hero, radius: 28)
    }

    private func pathBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(SylluneColor.heroEnd)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(SylluneColor.heroAccent, in: Capsule())
    }

    private var completedLessonsLabel: some View {
        Text("\(model.snapshot.lessonProgress.values.filter { $0.completedAt != nil }.count) leçons terminées")
            .font(.caption)
            .foregroundStyle(SylluneColor.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func lessonRow(_ lessonID: LessonID, index: Int, isLast: Bool) -> some View {
        let progress = model.snapshot.lessonProgress[lessonID]
        let unlocked = model.isLessonUnlocked(lessonID)
        let title = lessons[lessonID]?.title.resolve(preferred: model.preferredLanguageCodes) ?? "Leçon \(lessonID.rawValue)"
        let completed = progress?.completedAt != nil
        let active = progress?.lastOpenedAt != nil && model.resumeLessonID == lessonID && !completed
        let accent = SylluneColor.pathAccent(for: index)
        let status = completed ? "Terminée" : active ? "En cours" : unlocked ? "À commencer" : "À débloquer"
        let row = HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(completed ? SylluneColor.success : accent)
                        .frame(width: 36, height: 36)
                    Text(completed ? "✓" : "\(index + 1)")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(completed ? SylluneColor.inkOnSuccess : Color.white)
                }
                if !isLast {
                    Capsule()
                        .fill(accent.opacity(0.42))
                        .frame(width: 3, height: 30)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(unlocked ? SylluneColor.ink : SylluneColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lessons[lessonID].map { "\($0.estimatedMinutes) min · \($0.blocks.filter { if case .exercise = $0 { return true }; return false }.count) exercices" } ?? "Chargement…")
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(completed ? SylluneColor.success : active ? SylluneColor.jadeDeep : SylluneColor.inkMuted)
            }
            Spacer(minLength: 8)
            if unlocked {
                Image(systemName: completed ? "checkmark" : "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(completed ? SylluneColor.success : accent)
                    .frame(minWidth: 34, minHeight: 34)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .frame(minWidth: 34, minHeight: 34)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(active ? accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        if unlocked {
            NavigationLink(value: AppRoute.lesson(lessonID)) { row }
            .buttonStyle(.plain)
            .accessibilityHint(active ? "Reprend cette leçon" : "Ouvre cette leçon")
        } else {
            row
                .accessibilityLabel("\(title), \(status). Termine la leçon précédente pour déverrouiller cette étape.")
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
        applySearchFocus(
            VStack(spacing: 0) {
            if filtered.isEmpty && !query.isEmpty {
                ContentUnavailableView("Aucun mot pour « \(query) »", systemImage: "character.book.closed", description: Text("Parcours l’unité 1 pour découvrir son vocabulaire."))
            } else {
                List(filtered) { entry in
                        NavigationLink(destination: WordDetailView(vocabularyID: entry.id)) {
                            HStack(spacing: 14) {
                            Text(entry.hanzi)
                                .font(.title2)
                                .foregroundStyle(SylluneColor.ink)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.pinyin)
                                    .font(.body)
                                    .foregroundStyle(SylluneColor.jadeDeep)
                                Text(entry.meaning.resolve(preferred: ["fr", "en"]) ?? "—")
                                    .font(.callout)
                                    .foregroundStyle(SylluneColor.inkMuted)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            }
            .searchable(text: $query, prompt: "Caractère, pinyin ou sens")
        )
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

    @ViewBuilder
    private func applySearchFocus<Content: View>(_ content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.searchFocused($searchFocused)
        } else {
            content
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
                        if !entry.toneNumbers.isEmpty {
                            Text("Ton \(entry.toneNumbers.map(String.init).joined(separator: " · "))")
                                .font(.caption)
                                .foregroundStyle(SylluneColor.inkMuted)
                                .accessibilityLabel("Tons : \(entry.toneNumbers.map(String.init).joined(separator: ", "))")
                        }
                        Text(entry.meaning.resolve(preferred: ["fr", "en"]) ?? "—")
                            .font(.title3)
                            .foregroundStyle(SylluneColor.ink)
                            .accessibilityLabel("Sens : \(entry.meaning.resolve(preferred: ["fr", "en"]) ?? "—")")
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
                            Text(example.translation.resolve(preferred: ["fr", "en"]) ?? "")
                                .font(.body)
                                .foregroundStyle(SylluneColor.inkMuted)
                                .accessibilityLabel("Traduction : \(example.translation.resolve(preferred: ["fr", "en"]) ?? "")")
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
