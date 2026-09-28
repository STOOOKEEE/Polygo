import SwiftUI
import Foundation
import PolygoCore
#if os(iOS)
import UIKit
#endif

public extension Notification.Name {
    static let sylluneFocusDictionarySearch = Notification.Name("syllune.focusDictionarySearch")
    static let sylluneEscape = Notification.Name("syllune.escape")
}

public enum AppRoute: Hashable {
    case today
    case path
    case explorer
    case cards
    case shortReview(Int)
    case profile
    case settings
    case lesson(LessonID)
    case word(VocabularyID)
    case story(StoryID)
    case dictionary(String)
    case oral(ExerciseID)
    case writing(ExerciseID)

    public var rawValue: String {
        switch self {
        case .today: return "today"
        case .path: return "path"
        case .explorer: return "explorer"
        case .cards: return "cards"
        case .shortReview(let maxCards): return "shortReview/\(maxCards)"
        case .profile: return "profile"
        case .settings: return "settings"
        case .lesson(let id): return "lesson/\(id.rawValue)"
        case .word(let id): return "word/\(id.rawValue)"
        case .story(let id): return "story/\(id.rawValue)"
        case .dictionary(let query): return "dictionary/\(query)"
        case .oral(let id): return "oral/\(id.rawValue)"
        case .writing(let id): return "writing/\(id.rawValue)"
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "today": self = .today
        case "path": self = .path
        case "explorer": self = .explorer
        case "cards": self = .cards
        case "profile": self = .profile
        case "settings": self = .settings
        default:
            let pieces = rawValue.split(separator: "/", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else { return nil }
            switch pieces[0] {
            case "lesson": guard let id = LessonID(rawValue: pieces[1]) else { return nil }; self = .lesson(id)
            case "word": guard let id = VocabularyID(rawValue: pieces[1]) else { return nil }; self = .word(id)
            case "story": guard let id = StoryID(rawValue: pieces[1]) else { return nil }; self = .story(id)
            case "dictionary": self = .dictionary(pieces[1])
            case "shortReview":
                guard let maxCards = Int(pieces[1]), maxCards > 0 else { return nil }
                self = .shortReview(maxCards)
            case "oral": guard let id = ExerciseID(rawValue: pieces[1]) else { return nil }; self = .oral(id)
            case "writing": guard let id = ExerciseID(rawValue: pieces[1]) else { return nil }; self = .writing(id)
            default: return nil
            }
        }
    }
}
private struct SylluneFocusedExercisePreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

public extension View {
    func sylluneFocusedExercise(_ focused: Bool = true) -> some View {
        preference(key: SylluneFocusedExercisePreferenceKey.self, value: focused)
    }
}


public struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("syllune.appearance") private var storedAppearance = AppearanceMode.system.rawValue
    @AppStorage("syllune.reduceMotion") private var storedReduceMotion = false

    public init() {}
    public var body: some View {
        Group {
            if model.isLoading && model.index == nil {
                ProgressView("Préparation de ton espace…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.needsOnboarding {
                OnboardingView()
            } else {
                BottomNavigationShell()
            }
        }
        .background(SylluneColor.canvas)
        .preferredColorScheme(preferredColorScheme)
        .environment(\.sylluneReduceMotion, reduceMotion)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .task { await model.reload() }
    }

    private var appearance: AppearanceMode {
        if let stored = AppearanceMode(rawValue: storedAppearance), stored != .system {
            return stored
        }
        return model.snapshot.profile?.preferences.appearance ?? .system
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    private var reduceMotion: Bool {
        systemReduceMotion || storedReduceMotion || (model.snapshot.profile?.preferences.reduceMotion ?? false)
    }
}

private enum BottomTab: String, CaseIterable, Identifiable {
    case today
    case path
    case explorer
    case cards
    case profile

    var id: String { rawValue }

    var route: AppRoute {
        switch self {
        case .today: return .today
        case .path: return .path
        case .explorer: return .explorer
        case .cards: return .cards
        case .profile: return .profile
        }
    }

    var title: String {
        switch self {
        case .today: return "Aujourd’hui"
        case .path: return "Parcours"
        case .explorer: return "Explorer"
        case .cards: return "Cartes"
        case .profile: return "Profil"
        }
    }

    var symbolName: String {
        switch self {
        case .today: return "sun.max"
        case .path: return "list.bullet.rectangle.portrait"
        case .explorer: return "book.pages"
        case .cards: return "rectangle.stack"
        case .profile: return "person.crop.circle"
        }
    }

    var accent: Color {
        switch self {
        case .today: return SylluneColor.sun
        case .path: return SylluneColor.pathCoral
        case .explorer: return SylluneColor.pathSky
        case .cards: return SylluneColor.pathViolet
        case .profile: return SylluneColor.pathJade
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .today: return "1"
        case .path: return "2"
        case .explorer: return "3"
        case .cards: return "4"
        case .profile: return "5"
        }
    }
}

#if os(macOS)
private struct SylluneNavigationTabCommandKey: FocusedValueKey {
    typealias Value = (BottomTab) -> Void
}

private extension FocusedValues {
    var sylluneNavigationTabCommand: ((BottomTab) -> Void)? {
        get { self[SylluneNavigationTabCommandKey.self] }
        set { self[SylluneNavigationTabCommandKey.self] = newValue }
    }
}

private struct SylluneNavigationSettingsCommandKey: FocusedValueKey {
    typealias Value = () -> Void
}

private extension FocusedValues {
    var sylluneNavigationSettingsCommand: (() -> Void)? {
        get { self[SylluneNavigationSettingsCommandKey.self] }
        set { self[SylluneNavigationSettingsCommandKey.self] = newValue }
    }
}

struct BottomNavigationCommands: Commands {
    @FocusedValue(\.sylluneNavigationTabCommand) private var selectTab
    @FocusedValue(\.sylluneNavigationSettingsCommand) private var openSettings

    var body: some Commands {
        let settingsAction = openSettings
        CommandMenu("Navigation") {
            tabCommand(.today)
            tabCommand(.path)
            tabCommand(.explorer)
            tabCommand(.cards)
            tabCommand(.profile)
        }
        CommandGroup(after: .appSettings) {
            Button("Réglages") { settingsAction?() }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(settingsAction == nil)
        }
    }

    private func tabCommand(_ tab: BottomTab) -> some View {
        // Capture the scene action while constructing the command, not when
        // keyboard dispatch temporarily changes the focused responder.
        let action = selectTab
        return Button(tab.title) { action?(tab) }
            .keyboardShortcut(tab.shortcut, modifiers: .command)
            .disabled(action == nil)
    }
}
#endif

#if os(iOS)
private struct SylluneKeyboardContent<Content: View>: View {
    let content: Content
    let values: EnvironmentValues

    var body: some View {
        content.environment(\.self, values)
    }
}

private struct SylluneKeyboardHost<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let selectTab: (BottomTab) -> Void
    let openSettings: () -> Void

    func makeUIViewController(context: Context) -> SylluneKeyboardController<SylluneKeyboardContent<Content>> {
        let controller = SylluneKeyboardController(
            rootView: SylluneKeyboardContent(content: content, values: context.environment)
        )
        controller.selectTab = selectTab
        controller.openSettings = openSettings
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(
        _ controller: SylluneKeyboardController<SylluneKeyboardContent<Content>>,
        context: Context
    ) {
        controller.rootView = SylluneKeyboardContent(content: content, values: context.environment)
        controller.selectTab = selectTab
        controller.openSettings = openSettings
    }
}

// The controller stays in the responder chain when the bottom bar is absent
// and when a descendant text field owns keyboard focus.
private final class SylluneKeyboardController<Content: View>: UIHostingController<Content> {
    var selectTab: ((BottomTab) -> Void)?
    var openSettings: (() -> Void)?

    private lazy var navigationCommands: [UIKeyCommand] = {
        let tabs = BottomTab.allCases
        var commands: [UIKeyCommand] = []
        commands.reserveCapacity(tabs.count + 1)
        for tab in tabs {
            commands.append(UIKeyCommand(
                title: tab.title,
                action: #selector(selectNavigationTab(_:)),
                input: String(tab.shortcut.character),
                modifierFlags: .command,
                propertyList: tab.rawValue
            ))
        }
        commands.append(UIKeyCommand(
            title: "Réglages",
            action: #selector(openNavigationSettings),
            input: ",",
            modifierFlags: .command
        ))
        for command in commands {
            command.wantsPriorityOverSystemBehavior = true
        }
        return commands
    }()

    override var keyCommands: [UIKeyCommand]? {
        guard let inherited = super.keyCommands, !inherited.isEmpty else { return navigationCommands }
        return inherited + navigationCommands
    }
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    @objc private func selectNavigationTab(_ command: UIKeyCommand) {
        guard let rawValue = command.propertyList as? String,
              let tab = BottomTab(rawValue: rawValue) else { return }
        selectTab?(tab)
    }

    @objc private func openNavigationSettings() {
        openSettings?()
    }
}
#endif


struct BottomNavigationShell: View {
    @EnvironmentObject private var model: AppModel
    #if os(macOS)
    @Environment(\.controlActiveState) private var controlActiveState
    #endif
    @State private var selectedTab: BottomTab = .today
    @State private var todayPath: [AppRoute] = []
    @State private var pathPath: [AppRoute] = []
    @State private var explorerPath: [AppRoute] = []
    @State private var cardsPath: [AppRoute] = []
    @State private var profilePath: [AppRoute] = []
    @State private var stackRevision = 0
    @State private var pendingTabRootRoute: AppRoute?
    @State private var exerciseChromeHidden = false

    var body: some View {
        #if os(iOS)
        SylluneKeyboardHost(content: shellContent, selectTab: select, openSettings: openSettings)
            .ignoresSafeArea()
        #else
        shellContent
        #endif
    }

    private var shellContent: some View {
        VStack(spacing: 0) {
            NavigationStack(path: pathBinding(for: selectedTab)) {
                routeView(selectedTab.route)
                    // Each destination value owns its view state. Without an
                    // explicit identity, a destination pushed after a pop can
                    // inherit the previous value's @State (for example a
                    // finished lesson recap opening under the next lesson).
                    .navigationDestination(for: AppRoute.self) { routeView($0).id($0) }
            }
            .id("\(selectedTab.rawValue)-\(stackRevision)")
            .environment(\.sylluneShellWordNavigation, { id in
                pushWord(id)
            })
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !exerciseChromeHidden {
                    bottomNavigation
                }
            }
        }
        #if os(macOS)
        .focusedSceneValue(\.sylluneNavigationTabCommand, { tab in
            select(tab)
        })
        .focusedSceneValue(\.sylluneNavigationSettingsCommand, {
            openSettings()
        })
        #endif
        .onAppear { apply(route: model.selectedRoute) }
        .onChange(of: model.selectedRoute) { _, route in
            if pendingTabRootRoute == route {
                pendingTabRootRoute = nil
                return
            }
            pendingTabRootRoute = nil
            #if os(macOS)
            // Progress is shared, but another window's navigation is not.
            guard controlActiveState == .key else { return }
            #endif
            apply(route: route)
        }
        .onReceive(NotificationCenter.default.publisher(for: .sylluneEscape)) { _ in
            #if os(macOS)
            guard controlActiveState == .key else { return }
            #endif
            popToRoot()
        }
        .onPreferenceChange(SylluneFocusedExercisePreferenceKey.self) {
            exerciseChromeHidden = $0
        }
    }

    private var bottomNavigation: some View {
        ScrollViewReader { proxy in
            ViewThatFits(in: .horizontal) {
                tabBar(fillsWidth: true)
                ScrollView(.horizontal, showsIndicators: false) {
                    tabBar(fillsWidth: false)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .background {
                SylluneColor.surface
                    .overlay(alignment: .top) {
                        SylluneColor.border.opacity(0.35).frame(height: 1)
                    }
                    .ignoresSafeArea(edges: .bottom)
            }
            .onAppear { proxy.scrollTo(selectedTab.id, anchor: .center) }
            .onChange(of: selectedTab) { _, tab in
                proxy.scrollTo(tab.id, anchor: .center)
            }
        }
    }

    private func tabBar(fillsWidth: Bool) -> some View {
        HStack(spacing: 4) {
            if fillsWidth { Spacer(minLength: 0) }
            ForEach(BottomTab.allCases) { tab in
                tabButton(tab)
                if fillsWidth { Spacer(minLength: 0) }
            }
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil)
    }

    private func tabButton(_ tab: BottomTab) -> some View {
        let isSelected = tab == selectedTab
        return Button {
            select(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbolName)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? tab.accent : SylluneColor.inkMuted)
                    .accessibilityHidden(true)
                Text(tab.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? SylluneColor.ink : SylluneColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .frame(minWidth: 64, minHeight: 54)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tab.accent.opacity(0.14))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("BottomTab.\(tab.rawValue)")
        .id(tab.id)
    }

    private func select(_ tab: BottomTab) {
        guard tab != selectedTab else {
            popToRoot()
            return
        }
        selectedTab = tab
        guard model.selectedRoute != tab.route else {
            pendingTabRootRoute = nil
            return
        }
        pendingTabRootRoute = tab.route
        model.persistRoute(tab.route)
    }

    private func openSettings() {
        apply(route: .settings)
        guard model.selectedRoute != .settings else { return }
        pendingTabRootRoute = .settings
        model.persistRoute(.settings)
    }

    private func pathBinding(for tab: BottomTab) -> Binding<[AppRoute]> {
        Binding(
            get: { path(for: tab) },
            set: { setPath($0, for: tab) }
        )
    }

    private func path(for tab: BottomTab) -> [AppRoute] {
        switch tab {
        case .today: return todayPath
        case .path: return pathPath
        case .explorer: return explorerPath
        case .cards: return cardsPath
        case .profile: return profilePath
        }
    }

    private func setPath(_ path: [AppRoute], for tab: BottomTab) {
        switch tab {
        case .today: todayPath = path
        case .path: pathPath = path
        case .explorer: explorerPath = path
        case .cards: cardsPath = path
        case .profile: profilePath = path
        }
    }

    private func pushWord(_ id: VocabularyID) {
        let route = AppRoute.word(id)
        var path = path(for: selectedTab)
        guard path.last != route else { return }
        path.append(route)
        setPath(path, for: selectedTab)
    }

    private func apply(route: AppRoute) {
        let tab = route.baseTab
        if route == tab.route, tab != selectedTab {
            // An explicit return leaves the current detail; an ordinary tab
            // switch uses select(_:) and preserves its independent stack.
            setPath([], for: selectedTab)
        }
        selectedTab = tab
        setPath(routePath(route, root: tab.route, existing: path(for: tab)), for: tab)
    }

    private func routePath(_ route: AppRoute, root: AppRoute, existing: [AppRoute]) -> [AppRoute] {
        if route == root {
            return []
        }
        return existing == [route] ? existing : [route]
    }

    private func popToRoot() {
        setPath([], for: selectedTab)
        // Rebuilding the active stack also resets its transient view state.
        stackRevision += 1
        if model.selectedRoute != selectedTab.route {
            model.persistRoute(selectedTab.route)
        }
    }

    @ViewBuilder
    private func routeView(_ route: AppRoute) -> some View {
        Group {
            switch route {
            case .today: TodayView()
            case .path: LearningPathView()
            case .explorer: ExplorerView()
            case .cards: ReviewCardsView()
            case .shortReview(let maxCards): ReviewCardsView(maxCards: maxCards)
            case .profile: ProfileView()
            case .settings: SettingsView()
            case .lesson(let id): LessonView(lessonID: id)
            case .word(let id): WordDetailView(vocabularyID: id)
            case .story(let id): StoryDetailView(storyID: id)
            case .dictionary(let query): DictionaryView(initialQuery: query, usesShellNavigation: true)
            case .oral(let id): OralView(exerciseID: id)
            case .writing(let id): WritingView(exerciseID: id)
            }
        }
        .toolbar {
            if !exerciseChromeHidden {
                ToolbarItem(placement: .automatic) {
                    SylluneCoinBadge(balance: model.coinBalance)
                        .accessibilityIdentifier("ProgressCoinBalance")
                }
            }
        }
    }
}

private extension AppRoute {
    var baseTab: BottomTab {
        switch self {
        case .path: return .path
        case .explorer, .story, .dictionary, .word: return .explorer
        case .cards, .shortReview: return .cards
        case .profile, .settings: return .profile
        default: return .today
        }
    }
}
