import SwiftUI
import PolygoCore
import PolygoApple

/// Explicit symbols follow bundled lesson themes; unknown IDs keep a generic book.
/// Reviews, unit bosses and module 0 (`review-NN`, `boss-unit-NN`, `pinyin-NN`) have their own symbols.
private func lessonPathSymbol(for lessonID: LessonID) -> String {
    if lessonID.rawValue.hasPrefix("review-") { return "arrow.triangle.2.circlepath" }
    if lessonID.rawValue.hasPrefix("boss-") { return "crown.fill" }
    if lessonID.rawValue.hasPrefix("pinyin-") { return "waveform" }
    switch lessonID.rawValue {
    case "lesson-01": return "hand.wave.fill"
    case "lesson-02": return "person.fill"
    case "lesson-03": return "mappin.and.ellipse"
    case "lesson-04", "lesson-20": return "bubble.left.and.bubble.right.fill"
    case "lesson-05", "lesson-11", "lesson-56", "lesson-58": return "fork.knife"
    case "lesson-06", "lesson-44": return "house.fill"
    case "lesson-07", "lesson-13", "lesson-23", "lesson-45", "lesson-60": return "calendar"
    case "lesson-08", "lesson-35", "lesson-43": return "basket.fill"
    case "lesson-09", "lesson-59": return "figure.walk"
    case "lesson-10": return "bed.double.fill"
    case "lesson-12", "lesson-27", "lesson-36": return "person.2.fill"
    case "lesson-14", "lesson-65", "lesson-70": return "airplane"
    case "lesson-15", "lesson-21", "lesson-55": return "phone.fill"
    case "lesson-16", "lesson-34", "lesson-40", "lesson-64": return "checkmark.circle.fill"
    case "lesson-17", "lesson-38": return "graduationcap.fill"
    case "lesson-18": return "pawprint.fill"
    case "lesson-19", "lesson-28", "lesson-37": return "cross.case.fill"
    case "lesson-22": return "cloud.rain.fill"
    case "lesson-24": return "clock.fill"
    case "lesson-25": return "figure.run"
    case "lesson-26", "lesson-47", "lesson-54", "lesson-63": return "book.closed.fill"
    case "lesson-29", "lesson-32", "lesson-61": return "tshirt.fill"
    case "lesson-30", "lesson-33", "lesson-41", "lesson-49", "lesson-62", "lesson-69": return "map.fill"
    case "lesson-31", "lesson-42": return "shippingbox.fill"
    case "lesson-39", "lesson-46", "lesson-48", "lesson-52", "lesson-53": return "person.3.fill"
    case "lesson-50": return "heart.fill"
    case "lesson-51": return "building.2.fill"
    case "lesson-57": return "briefcase.fill"
    case "lesson-66": return "leaf.fill"
    case "lesson-67": return "music.note"
    case "lesson-68": return "paintpalette.fill"
    default: return "book.closed.fill"
    }
}

public struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @ScaledMetric(relativeTo: .title) private var homeMascotSize: CGFloat = 96

    public init() {}
    public var body: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                desktopHome
                compactHome
            }
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(SylluneColor.canvas)
        .navigationTitle("Aujourd’hui")
        .task(id: previewLessonIDs) {
            for lessonID in previewLessonIDs {
                _ = await model.loadLesson(lessonID)
            }
        }
    }

    @ViewBuilder
    private var desktopHome: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let error = model.errorMessage {
                errorBanner(error)
            }
            homeHeader
            HStack(alignment: .top, spacing: 24) {
                resumeCard(compact: false)
                    .frame(minWidth: 560, maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 18) {
                    flashcardsCard
                    pathCard
                }
                .frame(width: 360)
            }
        }
        .frame(minWidth: 944, maxWidth: 1180, alignment: .leading)
    }

    @ViewBuilder
    private var compactHome: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let error = model.errorMessage {
                errorBanner(error)
            }
            homeHeader
            resumeCard(compact: true)
            flashcardsCard
            pathCard
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
            let progress = lessonProgressFraction(for: lessonID)
            let actionTitle = model.snapshot.lessonProgress[lessonID]?.lastOpenedAt == nil
                ? "Commencer"
                : "Continuer"
            VStack(alignment: .leading, spacing: compact ? 14 : 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("PROCHAINE ÉTAPE", systemImage: "play.circle")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(SylluneColor.jadeDeep)
                    Text(lessonTitle(lessonID))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(SylluneColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(progressText(for: lessonID))
                        .font(.callout)
                        .foregroundStyle(SylluneColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                SylluneProgressBar(value: progress)
                    .accessibilityLabel("Progression de la leçon")
                    .accessibilityValue(progressText(for: lessonID))
                if let session = model.dailyPlanSession,
                   session.lessonID == lessonID,
                   model.dailyPlanTotalDays > 0 {
                    dailyPlanSummary(session)
                }
                NavigationLink(value: AppRoute.lesson(lessonID)) {
                    Label(actionTitle, systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SyllunePrimaryButtonStyle())
                .accessibilityIdentifier("home.primaryAction")
                .accessibilityHint("Ouvre la leçon suivante")
            }
            .padding(compact ? 18 : 22)
            .background(SylluneColor.jade.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .sylluneCard(style: .interactive, radius: 20)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Label("Parcours terminé", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SylluneColor.success)
                Text("Toutes les leçons disponibles sont terminées. Les cartes restent accessibles pour réviser.")
                    .font(.body)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(compact ? 18 : 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sylluneCard(style: .quiet, radius: 20)
        }
    }

    private func dailyPlanSummary(_ session: CoursePlanSession) -> some View {
        let day = model.dailyPlanDay ?? session.day
        return VStack(alignment: .leading, spacing: 3) {
            Text("JOUR \(day) / \(model.dailyPlanTotalDays)")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(SylluneColor.inkMuted)
            Text("\(session.courseMinutes) min de cours · \(session.reviewMinutes) min de révision")
                .font(.caption)
                .foregroundStyle(SylluneColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Jour \(day) sur \(model.dailyPlanTotalDays), \(session.courseMinutes) minutes de cours et \(session.reviewMinutes) minutes de révision")
    }

    private var homeHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            todayHeader
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) {
                    homeGreeting
                    Spacer(minLength: 4)
                    homeMascot
                }
                VStack(alignment: .leading, spacing: 8) {
                    homeGreeting
                    HStack {
                        Spacer(minLength: 0)
                        homeMascot
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sylluneCard(style: .hero, radius: 24)
    }

    private var homeGreeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.greeting)
                .font(.title.weight(.bold))
                .foregroundStyle(SylluneColor.inkOnDeep)
                .fixedSize(horizontal: false, vertical: true)
            Text("Une syllabe à la fois.")
                .font(.body)
                .foregroundStyle(SylluneColor.inkOnDeep.opacity(0.9))
        }
    }

    private var homeMascot: some View {
        TaviMascot(pose: .welcome)
            .frame(width: homeMascotSize, height: homeMascotSize)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private var todayHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                Label("AUJOURD’HUI", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(SylluneColor.inkOnDeep.opacity(0.9))
                Spacer(minLength: 10)
                streakBadge
            }
            VStack(alignment: .leading, spacing: 10) {
                Label("AUJOURD’HUI", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(SylluneColor.inkOnDeep.opacity(0.9))
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
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    Label("Ton parcours", systemImage: "map")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SylluneColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
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
                VStack(alignment: .leading, spacing: 6) {
                    Label("Ton parcours", systemImage: "map")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SylluneColor.ink)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(completed) / \(total)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(SylluneColor.jadeDeep)
                        Text("étapes")
                            .font(.caption)
                            .foregroundStyle(SylluneColor.inkMuted)
                    }
                }
            }
            SylluneProgressBar(value: value)
                .frame(height: 8)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(previewLessonIndices, id: \.self) { index in
                    homeLessonRow(model.orderedLessonIDs[index], index: index)
                }
            }
            if previewLessonIndices.count < total {
                Text("… \(total - previewLessonIndices.count) autres étapes dans le parcours")
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .padding(.top, 4)
            }
            NavigationLink(value: AppRoute.path) {
                Label("Voir le parcours complet", systemImage: "arrow.right")
            }
            .buttonStyle(.bordered)
            .tint(SylluneColor.jadeDeep)
            .frame(minHeight: 44)
        }
        .padding(20)
        .sylluneCard(style: .interactive, radius: 24)
        .accessibilityIdentifier("home.path")
    }

    private var previewLessonIDs: [LessonID] {
        previewLessonIndices.map { model.orderedLessonIDs[$0] }
    }

    private var previewLessonIndices: [Int] {
        let ids = model.orderedLessonIDs
        guard ids.count > 4 else { return Array(ids.indices) }
        let anchor = model.resumeLessonID.flatMap { ids.firstIndex(of: $0) } ?? 0
        let start = max(0, min(anchor - 1, ids.count - 4))
        return Array(start..<min(start + 4, ids.count))
    }

    private var flashcardsCard: some View {
        let dueCount = model.snapshot.dueCards(at: model.dependencies.clock.now()).count
        let plannedCount = min(dueCount, model.dailyReviewLimit)
        let sessionMessage = dueCount == 0
            ? "Prête quand tu le seras."
            : "Une courte session suffit."
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                flashcardMark
                VStack(alignment: .leading, spacing: 4) {
                    Text("Flashcards")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SylluneColor.ink)
                    Text(dueCount == 0 ? "Aucune carte à revoir maintenant." : "\(plannedCount) carte\(plannedCount == 1 ? "" : "s") pour cette session · \(dueCount) due\(dueCount == 1 ? "" : "s") au total")
                        .font(.body)
                        .foregroundStyle(SylluneColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    Text(sessionMessage)
                        .font(.callout)
                        .foregroundStyle(SylluneColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    flashcardsLink(dueCount: dueCount, dailyLimit: model.dailyReviewLimit)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(sessionMessage)
                        .font(.callout)
                        .foregroundStyle(SylluneColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    flashcardsLink(dueCount: dueCount, dailyLimit: model.dailyReviewLimit)
                }
            }
        }
        .padding(20)
        .sylluneCard(style: .interactive, radius: 24)
        .accessibilityIdentifier("home.review")
    }

    private var flashcardMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SylluneColor.coral)
                .frame(width: 38, height: 32)
                .offset(x: -6, y: -5)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SylluneColor.skyButton)
                .frame(width: 42, height: 36)
            Image(systemName: "rectangle.stack.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(SylluneColor.inkOnDeep)
        }
        .frame(width: 48, height: 44)
        .accessibilityHidden(true)
    }

    private func flashcardsLink(dueCount: Int, dailyLimit: Int) -> some View {
        NavigationLink(value: AppRoute.shortReview(dailyLimit)) {
            Text(dueCount == 0 ? "Ouvrir" : "Réviser")
        }
        .buttonStyle(.bordered)
        .tint(SylluneColor.jadeDeep)
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
        let status = completed ? "Terminée" : active ? "En cours" : unlocked ? "À commencer" : "À débloquer"
        let row = HStack(alignment: .top, spacing: 12) {
            LessonPathNode(
                lessonID: lessonID,
                status: LessonPathStatus(completed: completed, unlocked: unlocked, current: model.resumeLessonID == lessonID),
                diameter: 34
            )
            .allowsHitTesting(false)
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
                    .foregroundStyle(completed ? SylluneColor.success : SylluneColor.jadeDeep)
                    .frame(minWidth: 30, minHeight: 30)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .frame(minWidth: 30, minHeight: 30)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(active ? SylluneColor.jade.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        VStack(alignment: .leading, spacing: 0) {
            if unlocked {
                NavigationLink(value: AppRoute.lesson(lessonID)) { row }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title), \(status)")
                    .accessibilityHint(active ? "Reprend cette leçon" : "Ouvre cette leçon")
            } else {
                row
                    .accessibilityLabel("\(title), \(status)")
                    .accessibilityHint("Cette étape est verrouillée")
            }
            if index < model.orderedLessonIDs.count - 1 {
                Capsule()
                    .fill(completed ? SylluneColor.success : SylluneColor.progressTrack)
                    .frame(width: 3, height: 22)
                    .padding(.leading, 23.5)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
    }

    private func lessonTitle(_ id: LessonID) -> String {
        model.loadedLessons[id]?.title.resolve(preferred: model.preferredLanguageCodes) ?? "Leçon en cours"
    }

    private func progressText(for id: LessonID) -> String {
        let progress = model.snapshot.lessonProgress[id]
        let isPlanLesson = model.dailyPlan?.session(for: id) != nil
        guard let lesson = model.loadedLessons[id] else {
            if model.dailyPlan != nil && !isPlanLesson {
                return "Préparation au programme"
            }
            return progress?.lastOpenedAt == nil ? "Première leçon" : "Reprise de ta leçon"
        }
        let count = lesson.blocks.reduce(into: 0) { result, block in
            if case .exercise = block { result += 1 }
        }
        let index = min(progress?.currentExerciseIndex ?? 0, count)
        if model.dailyPlan != nil && !isPlanLesson {
            return progress?.lastOpenedAt == nil
                ? "Préparation au programme"
                : "Préparation au programme · exercice \(min(index + 1, max(1, count))) sur \(count)"
        }
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
    @Environment(\.sylluneReduceMotion) private var reduceMotion
    /// Units the learner opened or closed, as `unit-id=1` / `unit-id=0`
    /// pairs; the other units follow `isExpanded(_:openLessonIDs:)`.
    @SceneStorage("learningPath.unitChoices") private var unitChoices = ""
    @State private var currentNodeRealized = false
    @State private var currentNodeFits = false
    @State private var currentNodeVisible = true
    @State private var currentNodeIsAbove = false

    public init() {}
    public var body: some View {
        GeometryReader { geometry in
            let columnWidth = max(0, min(LearningPathLayout.maxColumnWidth, geometry.size.width - 40))
            let currentLessonID = model.resumeLessonID
            let openLessonIDs = [currentLessonID, nextMainLessonID].compactMap { $0 }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if let course = model.course {
                            pathHeader(course)
                            ForEach(course.modules.sorted(by: { $0.order < $1.order }), id: \.id) { module in
                                let expanded = isExpanded(module, openLessonIDs: openLessonIDs)
                                LearningPathUnit(
                                    module: module,
                                    currentLessonID: currentLessonID,
                                    isExpanded: expanded,
                                    toggle: { setExpanded(!expanded, for: module) },
                                    model: model
                                )
                                .id(module.id)
                            }
                        } else {
                            ContentUnavailableView(
                                "Parcours indisponible",
                                systemImage: "books.vertical",
                                description: Text(model.errorMessage ?? "Le contenu n’est pas encore chargé.")
                            )
                        }
                    }
                    .frame(width: columnWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .coordinateSpace(.named(LearningPathLayout.coordinateSpace))
                .onPreferenceChange(CurrentPathNodeFrameKey.self) { frame in
                    updateCurrentNode(frame, viewportHeight: geometry.size.height)
                }
                .overlay(alignment: .bottomTrailing) {
                    if let currentLessonID, !currentNodeVisible {
                        backToCurrentButton {
                            Task { await scrollToLesson(currentLessonID, proxy: proxy, animated: true, expandsUnit: true) }
                        }
                        .transition(.opacity)
                    }
                }
                .task(id: currentLessonID) {
                    guard let currentLessonID else { return }
                    await revealLesson(currentLessonID, proxy: proxy)
                }
            }
        }
        .background(SylluneColor.canvas)
        .navigationTitle("Parcours")
    }

    private func pathHeader(_ course: CourseManifest) -> some View {
        let total = model.orderedLessonIDs.count
        let completed = completedLessonCount
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("TON CHEMIN", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(SylluneColor.jadeDeep)
                Spacer(minLength: 8)
                Text("\(completed) sur \(total) terminées")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SylluneColor.inkMuted)
            }
            SylluneProgressBar(value: total == 0 ? 0 : Double(completed) / Double(total))
            DisclosureGroup("À propos de ce parcours") {
                VStack(alignment: .leading, spacing: 12) {
                    if let milestone = model.nextDailyPlanMilestone ?? model.dailyPlanMilestone {
                        planMilestoneCard(milestone, reached: model.dailyPlanMilestone?.id == milestone.id)
                    }
                    pathIntroHeading(course)
                    ForEach(Array(model.curriculumLabels.enumerated()), id: \.offset) { _, label in
                        pathMeta(label, icon: label.uppercased().hasPrefix("HSK") ? "graduationcap" : "globe.europe.africa")
                    }
                }
                .padding(.top, 12)
            }
            .font(.callout)
            .tint(SylluneColor.jadeDeep)
        }
        .padding(16)
        .sylluneCard(radius: 24)
    }

    private func pathIntroHeading(_ course: CourseManifest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(course.title.resolve(preferred: model.preferredLanguageCodes) ?? "Parcours")
                .font(.title2.weight(.bold))
                .foregroundStyle(SylluneColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(course.description.resolve(preferred: model.preferredLanguageCodes) ?? "")
                .font(.body)
                .foregroundStyle(SylluneColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func planMilestoneCard(_ milestone: CourseMilestone, reached: Bool) -> some View {
        let title = milestone.title.resolve(preferred: model.preferredLanguageCodes) ?? "Palier"
        let coverage = (milestone.coverage?.vocabularyTarget)
            .map { "Vocabulaire visé : \($0) mots" }
        return VStack(alignment: .leading, spacing: 6) {
            Label(
                reached ? "Palier couvert · jour \(milestone.day)" : "Prochain palier · jour \(milestone.day)",
                systemImage: reached ? "checkmark.seal.fill" : "flag.fill"
            )
            .font(.caption.weight(.bold))
            .foregroundStyle(reached ? SylluneColor.success : SylluneColor.jadeDeep)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(SylluneColor.ink)
            if let coverage {
                Text(coverage)
                    .font(.callout)
                    .foregroundStyle(SylluneColor.inkMuted)
            }
            Text("Ce repère décrit le contenu rencontré ; il ne valide pas à lui seul un niveau acquis.")
                .font(.caption)
                .foregroundStyle(SylluneColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reached ? "Palier couvert" : "Prochain palier"), jour \(milestone.day), \(title)\(coverage.map { ", \($0)" } ?? ""). Ce repère ne valide pas à lui seul un niveau acquis.")
    }

    private func pathMeta(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(SylluneColor.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(SylluneColor.surfaceRaised, in: Capsule())
    }

    private func backToCurrentButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: currentNodeIsAbove ? "arrow.up" : "arrow.down")
                .font(.title3.weight(.bold))
                .foregroundStyle(SylluneColor.inkOnJade)
                .frame(width: 54, height: 54)
                .background(SylluneColor.jadeButton, in: Circle())
                .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .padding(20)
        .accessibilityLabel("Revenir à l’étape actuelle")
        .accessibilityIdentifier("learningPath.backToCurrent")
    }

    private var completedLessonCount: Int {
        model.orderedLessonIDs.filter {
            model.snapshot.lessonProgress[$0]?.completedAt != nil
        }.count
    }

    // MARK: Units

    /// Module 0 is optional, so a beginner has two open fronts: the pinyin
    /// lesson and the first lesson of the main track.
    private var nextMainLessonID: LessonID? {
        model.orderedLessonIDs.first { lessonID in
            !lessonID.rawValue.hasPrefix("pinyin-")
                && model.snapshot.lessonProgress[lessonID]?.completedAt == nil
                && model.isLessonUnlocked(lessonID)
        }
    }

    private var unitChoiceMap: [String: Bool] {
        var choices: [String: Bool] = [:]
        for pair in unitChoices.split(separator: ";") {
            let parts = pair.split(separator: "=")
            if parts.count == 2 {
                choices[String(parts[0])] = parts[1] == "1"
            }
        }
        return choices
    }

    /// A unit the learner has not opened or closed yet is expanded when it
    /// holds an open lesson; finished and future units stay collapsed.
    private func isExpanded(_ module: ModuleSummary, openLessonIDs: [LessonID]) -> Bool {
        unitChoiceMap[module.id.rawValue] ?? module.lessonIDs.contains { openLessonIDs.contains($0) }
    }

    private func setExpanded(_ expanded: Bool, for module: ModuleSummary) {
        var choices = unitChoiceMap
        choices[module.id.rawValue] = expanded
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            unitChoices = choices.keys.sorted()
                .map { "\($0)=\(choices[$0] == true ? 1 : 0)" }
                .joined(separator: ";")
        }
    }

    // MARK: Scrolling

    /// The current node reports its frame in the scroll view's space; a nil
    /// frame means its row is not realized: off-screen or in a collapsed unit.
    private func updateCurrentNode(_ frame: CGRect?, viewportHeight: CGFloat) {
        currentNodeRealized = frame != nil
        currentNodeFits = frame.map { $0.minY >= 0 && $0.maxY <= viewportHeight } ?? false
        let visible = frame.map { $0.maxY > 0 && $0.minY < viewportHeight } ?? false
        if let frame, !visible {
            currentNodeIsAbove = frame.midY < 0
        }
        guard visible != currentNodeVisible else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            currentNodeVisible = visible
        }
    }

    /// Opening the path keeps the header in view when the current step
    /// already fits; otherwise it centers the current step. A unit the
    /// learner collapsed stays collapsed.
    @MainActor
    private func revealLesson(_ lessonID: LessonID, proxy: ScrollViewProxy) async {
        // Give the lazy stack a layout pass to report the current node.
        try? await Task.sleep(for: .milliseconds(50))
        guard !Task.isCancelled, !currentNodeFits else { return }
        await scrollToLesson(lessonID, proxy: proxy, animated: false, expandsUnit: false)
    }

    @MainActor
    private func scrollToLesson(_ lessonID: LessonID, proxy: ScrollViewProxy, animated: Bool, expandsUnit: Bool) async {
        // Units are lazy and collapsible: open and bring the lesson's unit on
        // screen first so its row exists before centering on it.
        if !currentNodeRealized,
           let module = model.course?.modules.first(where: { $0.lessonIDs.contains(lessonID) }) {
            if unitChoiceMap[module.id.rawValue] == false {
                guard expandsUnit else { return }
                setExpanded(true, for: module)
            }
            proxy.scrollTo(module.id, anchor: .top)
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
        }
        withAnimation(animated && !reduceMotion ? .easeInOut(duration: 0.35) : nil) {
            proxy.scrollTo(lessonID, anchor: .center)
        }
    }
}

private enum LearningPathLayout {
    static let maxColumnWidth: CGFloat = 600
    static let coordinateSpace = "learningPath.scroll"
}

private struct CurrentPathNodeFrameKey: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

/// Where a lesson stands for the learner. Home and Parcours draw it with the
/// same node so both screens read alike.
private enum LessonPathStatus {
    case completed
    case current
    case available
    case locked

    init(completed: Bool, unlocked: Bool, current: Bool) {
        if completed {
            self = .completed
        } else if !unlocked {
            self = .locked
        } else if current {
            self = .current
        } else {
            self = .available
        }
    }

    var fill: Color {
        switch self {
        case .completed: return SylluneColor.success
        case .current: return SylluneColor.jadeButton
        case .available: return SylluneColor.jade.opacity(0.14)
        case .locked: return SylluneColor.surfaceRaised
        }
    }

    var foreground: Color {
        switch self {
        case .completed: return SylluneColor.inkOnSuccess
        case .current: return SylluneColor.inkOnJade
        case .available: return SylluneColor.jadeDeep
        case .locked: return SylluneColor.inkMuted
        }
    }
}

/// A flat lesson node: theme symbol on a status fill, a check or lock badge,
/// and an exercise ring for the current lesson. Unit challenges wear a sun
/// outline.
private struct LessonPathNode: View {
    let lessonID: LessonID
    let status: LessonPathStatus
    let diameter: CGFloat
    var progress: Double? = nil

    var body: some View {
        Circle()
            .fill(status.fill)
            .frame(width: diameter, height: diameter)
            .overlay {
                if lessonID.rawValue.hasPrefix("boss-") {
                    Circle().strokeBorder(SylluneColor.sun, lineWidth: 3)
                } else if status == .available {
                    Circle().strokeBorder(SylluneColor.jade, lineWidth: 1.5)
                } else if status == .locked {
                    Circle().strokeBorder(SylluneColor.border, lineWidth: 1)
                }
            }
            .overlay {
                Image(systemName: lessonPathSymbol(for: lessonID))
                    .font(.system(size: diameter * 0.4, weight: .semibold))
                    .foregroundStyle(status.foreground)
            }
            .overlay {
                if let progress {
                    ZStack {
                        Circle()
                            .stroke(SylluneColor.progressTrack, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: min(1, max(0, progress)))
                            .stroke(SylluneColor.jade, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .padding(-6)
                }
            }
            .overlay(alignment: .bottomTrailing) { badge }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var badge: some View {
        switch status {
        case .completed: badgeSymbol("checkmark", color: SylluneColor.success)
        case .locked: badgeSymbol("lock.fill", color: SylluneColor.inkMuted)
        case .current, .available: EmptyView()
        }
    }

    private func badgeSymbol(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: max(7, diameter * 0.2), weight: .bold))
            .foregroundStyle(color)
            .frame(width: diameter * 0.42, height: diameter * 0.42)
            .background(SylluneColor.surface, in: Circle())
            .overlay(Circle().stroke(SylluneColor.border, lineWidth: 1))
            .offset(x: diameter * 0.1, y: diameter * 0.1)
    }
}

/// One unit of the path: a card whose header folds the lesson list.
private struct LearningPathUnit: View {
    let module: ModuleSummary
    let currentLessonID: LessonID?
    let isExpanded: Bool
    let toggle: () -> Void
    @ObservedObject var model: AppModel

    @ScaledMetric(relativeTo: .body) private var scaledNodeDiameter: CGFloat = 44
    @ScaledMetric(relativeTo: .title) private var mascotSize: CGFloat = 48

    private let rowPadding: CGFloat = 10
    private var nodeDiameter: CGFloat { min(scaledNodeDiameter, 72) }
    private var holdsCurrentLesson: Bool { module.lessonIDs.contains { $0 == currentLessonID } }

    var body: some View {
        let completedCount = module.lessonIDs.filter {
            model.snapshot.lessonProgress[$0]?.completedAt != nil
        }.count
        VStack(alignment: .leading, spacing: 0) {
            header(completedCount: completedCount)
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(module.lessonIDs.enumerated()), id: \.element) { index, lessonID in
                        lessonRow(lessonID, index: index, isLast: index == module.lessonIDs.count - 1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sylluneCard(style: holdsCurrentLesson ? .interactive : .standard, radius: 24)
    }

    // MARK: Unit header

    private func header(completedCount: Int) -> some View {
        let title = module.displayName?.resolve(preferred: model.preferredLanguageCodes)
            ?? module.title.resolve(preferred: model.preferredLanguageCodes)
            ?? "Unité"
        let total = module.lessonIDs.count
        let finished = total > 0 && completedCount == total
        return Button(action: toggle) {
            HStack(alignment: .center, spacing: 14) {
                unitMark(finished: finished)
                VStack(alignment: .leading, spacing: 4) {
                    Text("UNITÉ \(module.order)")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(SylluneColor.jadeDeep)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(SylluneColor.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        SylluneProgressBar(
                            value: total == 0 ? 0 : Double(completedCount) / Double(total),
                            tint: finished ? SylluneColor.success : SylluneColor.jade
                        )
                        .frame(maxWidth: 110)
                        Text("\(completedCount)/\(total) leçons")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(SylluneColor.inkMuted)
                    }
                }
                Spacer(minLength: 8)
                if holdsCurrentLesson {
                    TaviMascot(pose: finished ? .celebration : .encouragement)
                        .frame(width: mascotSize, height: mascotSize)
                        .accessibilityHidden(true)
                }
                Image(systemName: "chevron.down")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(SylluneColor.inkMuted)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .frame(minWidth: 28, minHeight: 44)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Unité \(module.order), \(title), \(completedCount) sur \(total) leçons terminées")
        .accessibilityValue(isExpanded ? "Dépliée" : "Repliée")
        .accessibilityHint(isExpanded ? "Masque les leçons de l’unité" : "Affiche les leçons de l’unité")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("learningPath.unit.\(module.id.rawValue)")
    }

    private func unitMark(finished: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(finished ? SylluneColor.success.opacity(0.14) : SylluneColor.jade.opacity(0.14))
            if finished {
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SylluneColor.success)
            } else {
                Text("\(module.order)")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(SylluneColor.jadeDeep)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }

    // MARK: Lesson rows

    /// Reviews and unit challenges carry a word next to their symbol, so they
    /// stand apart from daily lessons without relying on colour.
    private func lessonKind(_ lessonID: LessonID) -> (label: String, color: Color)? {
        if lessonID.rawValue.hasPrefix("review-") { return ("Révision", SylluneColor.sky) }
        if lessonID.rawValue.hasPrefix("boss-") { return ("Défi de l’unité", SylluneColor.coral) }
        return nil
    }

    @ViewBuilder
    private func lessonRow(_ lessonID: LessonID, index: Int, isLast: Bool) -> some View {
        let progress = model.snapshot.lessonProgress[lessonID]
        let unlocked = model.isLessonUnlocked(lessonID)
        let completed = progress?.completedAt != nil
        let isCurrent = unlocked && lessonID == currentLessonID
        let active = isCurrent && progress?.lastOpenedAt != nil && !completed
        let title = model.loadedLessons[lessonID]?.title.resolve(
            preferred: model.preferredLanguageCodes
        ) ?? "Leçon \(index + 1)"
        let kind = lessonKind(lessonID)
        let status = completed
            ? "Terminée"
            : active
                ? "En cours"
                : unlocked
                    ? "À commencer"
                    : "Verrouillée"
        let progressText = lessonProgressText(lessonID, completed: completed)
        let detail = completed
            ? "Terminée"
            : unlocked ? progressText : "Verrouillée · termine l’étape précédente"
        let accessibilityTitle = kind.map { "\($0.label), \(title)" } ?? title
        let rowShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let content = HStack(alignment: .top, spacing: 14) {
            LessonPathNode(
                lessonID: lessonID,
                status: LessonPathStatus(completed: completed, unlocked: unlocked, current: isCurrent),
                diameter: nodeDiameter,
                progress: isCurrent ? exerciseFraction(lessonID) : nil
            )
            .background {
                if isCurrent {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: CurrentPathNodeFrameKey.self,
                            value: proxy.frame(in: .named(LearningPathLayout.coordinateSpace))
                        )
                    }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                if let kind {
                    Text(kind.label.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(kind.color)
                }
                Text(title)
                    .font(.body.weight(isCurrent ? .semibold : .medium))
                    .foregroundStyle(unlocked ? SylluneColor.ink : SylluneColor.inkMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(completed ? SylluneColor.success : isCurrent ? SylluneColor.jadeDeep : SylluneColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if isCurrent {
                    Label(active ? "Continuer" : "Commencer", systemImage: "arrow.right")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(SylluneColor.inkOnJade)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(SylluneColor.jadeButton, in: Capsule())
                        .padding(.top, 6)
                }
            }
            Spacer(minLength: 4)
            if unlocked && !isCurrent {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SylluneColor.inkMuted)
                    .frame(minWidth: 24, minHeight: nodeDiameter)
            }
        }
        .padding(rowPadding)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(isCurrent ? SylluneColor.jade.opacity(0.12) : Color.clear, in: rowShape)
        .contentShape(rowShape)

        Group {
            if unlocked {
                NavigationLink(value: AppRoute.lesson(lessonID)) { content }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("learningPath.lesson.\(lessonID.rawValue)")
                    .accessibilityLabel("\(accessibilityTitle), \(status), \(progressText)")
                    .accessibilityHint(active ? "Reprend cette leçon" : "Ouvre cette leçon")
            } else {
                content
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("learningPath.lesson.\(lessonID.rawValue)")
                    .accessibilityLabel("\(accessibilityTitle), \(status), \(progressText)")
                    .accessibilityHint("Termine l’étape précédente pour déverrouiller cette leçon")
            }
        }
        .background(alignment: .topLeading) {
            if !isLast {
                connector(reached: completed)
            }
        }
        .id(lessonID)
        .task(id: lessonID) {
            _ = await model.loadLesson(lessonID)
        }
    }

    /// Joins this row's node to the next row's node, in success colour once
    /// the lesson is done.
    private func connector(reached: Bool) -> some View {
        Capsule()
            .fill(reached ? SylluneColor.success : SylluneColor.progressTrack)
            .frame(width: 3)
            .frame(maxHeight: .infinity)
            .padding(.top, rowPadding + nodeDiameter + 8)
            .padding(.bottom, -(rowPadding - 8))
            .offset(x: rowPadding + nodeDiameter / 2 - 1.5)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    // MARK: Progress

    private func exerciseCount(_ lesson: LessonDocument) -> Int {
        lesson.blocks.reduce(into: 0) { count, block in
            if case .exercise = block {
                count += 1
            }
        }
    }

    private func exerciseFraction(_ lessonID: LessonID) -> Double {
        guard let lesson = model.loadedLessons[lessonID] else { return 0 }
        let count = exerciseCount(lesson)
        guard count > 0 else { return 0 }
        return Double(model.snapshot.lessonProgress[lessonID]?.currentExerciseIndex ?? 0) / Double(count)
    }

    private func lessonProgressText(_ lessonID: LessonID, completed: Bool) -> String {
        guard let lesson = model.loadedLessons[lessonID] else {
            return completed
                ? "Leçon terminée"
                : "Progression en cours de chargement"
        }
        let count = exerciseCount(lesson)
        guard count > 0 else {
            return completed ? "Leçon terminée" : "Prête à commencer"
        }
        guard let progress = model.snapshot.lessonProgress[lessonID],
              progress.lastOpenedAt != nil else {
            return "Prête à commencer"
        }
        if completed {
            return "Tous les exercices terminés"
        }
        return "Exercice \(min(progress.currentExerciseIndex + 1, count)) sur \(count)"
    }
}


public struct ExplorerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var stories: [StoryDocument] = []
    @State private var showingDictionary = false

    public init() {}

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                explorerHeader

                Button { showingDictionary = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "magnifyingglass")
                            .font(.title3.weight(.semibold))
                            .accessibilityHidden(true)
                        Text(model.dictionaryTitle)
                            .font(.title3.weight(.bold))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                            .font(.callout.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(SyllunePrimaryButtonStyle())
                .accessibilityIdentifier("explorer.dictionary")

                VStack(alignment: .leading, spacing: 12) {
                    Text("Histoires")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SylluneColor.ink)
                    if stories.isEmpty {
                        Text("Les histoires locales apparaîtront ici dès que leur contenu est installé.")
                            .font(.body)
                            .foregroundStyle(SylluneColor.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(SylluneColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(stories.indices, id: \.self) { index in
                                let story = stories[index]
                                NavigationLink(value: AppRoute.story(story.id)) {
                                    HStack(alignment: .center, spacing: 14) {
                                        explorerMark(systemImage: "book.closed.fill", tint: SylluneColor.sky)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(story.title.resolve(preferred: model.preferredLanguageCodes) ?? "Histoire")
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(SylluneColor.ink)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text("\(story.level) · \(story.estimatedMinutes) min · \(model.offlineContentLabel)")
                                                .font(.caption)
                                                .foregroundStyle(SylluneColor.inkMuted)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(SylluneColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sylluneCard(style: .interactive, radius: 24)
            }
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(SylluneColor.canvas)
        .navigationTitle("Explorer")
        .sheet(isPresented: $showingDictionary) {
            NavigationStack { DictionaryView() }
                .environment(\.sylluneShellWordNavigation, nil)
        }
        .task {
            if let store = model.dependencies.content as? any StoryContentStore { stories = (try? await store.stories()) ?? [] }
        }
    }

    private var explorerHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                explorerHeaderText
                Spacer(minLength: 0)
                explorerMark(systemImage: "sparkles", tint: SylluneColor.sky)
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            VStack(alignment: .leading, spacing: 8) {
                explorerHeaderText
                HStack {
                    Spacer(minLength: 0)
                    explorerMark(systemImage: "sparkles", tint: SylluneColor.sky)
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SylluneColor.sky.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .sylluneCard(style: .interactive, radius: 24)
    }

    private var explorerHeaderText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("À découvrir")
                .font(.title.weight(.bold))
                .foregroundStyle(SylluneColor.ink)
            Text("Un mot ou une histoire, à ton rythme.")
                .font(.body)
                .foregroundStyle(SylluneColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func explorerMark(systemImage: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.14))
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 14, height: 14)
                .offset(x: 12, y: -12)
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}

public struct DictionaryView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    public var initialQuery: String?
    private let usesShellNavigation: Bool
    @State private var query: String
    @State private var entries: [VocabularyEntry] = []
    @FocusState private var searchFocused: Bool

    public init(initialQuery: String? = nil) {
        self.init(initialQuery: initialQuery, usesShellNavigation: false)
    }

    init(initialQuery: String?, usesShellNavigation: Bool) {
        self.initialQuery = initialQuery
        self.usesShellNavigation = usesShellNavigation
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
                ContentUnavailableView("Aucun mot pour « \(query) »", systemImage: "character.book.closed", description: Text("Parcours \(model.primaryContentLabel) pour découvrir son vocabulaire."))
            } else {
                List(filtered) { entry in
                    let label = HStack(spacing: 14) {
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
                    if usesShellNavigation {
                        NavigationLink(value: AppRoute.word(entry.id)) { label }
                    } else {
                        NavigationLink(destination: WordDetailView(vocabularyID: entry.id)) { label }
                    }
                }
                .listStyle(.plain)
            }
            }
            .searchable(text: $query, prompt: "Caractère, pinyin ou sens")
        )
        .navigationTitle(model.dictionaryTitle)
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
                            ChineseSelectableText(
                                hanzi: example.hanzi,
                                font: .title3,
                                speechEnabled: true,
                                vocabulary: model.loadedLessons.values.flatMap(\.vocabulary),
                                audio: example.audio,
                                wordInteractionEnabled: false
                            )
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

    private func playAudio(for entry: VocabularyEntry, rate: SpeechRate = .normal) async {
        do {
            try await model.dependencies.audio.speak(text: entry.hanzi, localeIdentifier: "zh-CN", rate: rate, asset: entry.audio)
            audioMessage = rate == .slow ? "Lecture lente terminée." : "Lecture terminée."
        } catch is CancellationError {
            audioMessage = "Lecture arrêtée."
        } catch {
            audioMessage = "Audio indisponible hors ligne."
        }
    }

    private func audioButton(for entry: VocabularyEntry) -> some View {
        HStack(spacing: 8) {
            Button {
                Task { await playAudio(for: entry) }
            } label: {
                Label("Écouter", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(SylluneColor.skyButton)
            .frame(minHeight: 44)
            Button {
                Task { await playAudio(for: entry, rate: .slow) }
            } label: {
                Label("Lentement", systemImage: "tortoise")
            }
            .buttonStyle(.bordered)
            .tint(SylluneColor.skyButton)
            .frame(minHeight: 44)
            .accessibilityLabel("Écouter lentement")
        }
    }

    private func audioAvailability(for entry: VocabularyEntry) -> some View {
        Text(entry.audio == nil ? "Voix locale si disponible" : "Disponible hors ligne")
            .font(.caption)
            .foregroundStyle(SylluneColor.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
