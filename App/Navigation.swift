import SwiftUI
import Foundation
import PolygoCore

public extension Notification.Name {
    static let sylluneFocusDictionarySearch = Notification.Name("syllune.focusDictionarySearch")
    static let sylluneEscape = Notification.Name("syllune.escape")
}

public enum AppRoute: Hashable {
    case today
    case path
    case explorer
    case cards
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
            case "oral": guard let id = ExerciseID(rawValue: pieces[1]) else { return nil }; self = .oral(id)
            case "writing": guard let id = ExerciseID(rawValue: pieces[1]) else { return nil }; self = .writing(id)
            default: return nil
            }
        }
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
                AdaptiveShellView()
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

public struct AdaptiveShellView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init() {}
    public var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            PhoneTabShell()
        } else {
            SplitShell()
        }
        #else
        SplitShell()
        #endif
    }
}

public struct PhoneTabShell: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedTab: AppRoute = .today
    @State private var todayPath: [AppRoute] = []
    @State private var pathPath: [AppRoute] = []
    @State private var explorerPath: [AppRoute] = []
    @State private var cardsPath: [AppRoute] = []
    @State private var profilePath: [AppRoute] = []

    public init() {}

    public var body: some View {
        TabView(selection: tabSelection) {
            NavigationStack(path: $todayPath) {
                TodayView()
                    .navigationDestination(for: AppRoute.self) { routeView($0) }
            }
            .tabItem { Label("Aujourd’hui", systemImage: "sun.max") }
            .tag(AppRoute.today)

            NavigationStack(path: $pathPath) {
                LearningPathView()
                    .navigationDestination(for: AppRoute.self) { routeView($0) }
            }
            .tabItem { Label("Parcours", systemImage: "list.bullet.rectangle.portrait") }
            .tag(AppRoute.path)

            NavigationStack(path: $explorerPath) {
                ExplorerView()
                    .navigationDestination(for: AppRoute.self) { routeView($0) }
            }
            .tabItem { Label("Explorer", systemImage: "book.pages") }
            .tag(AppRoute.explorer)

            NavigationStack(path: $cardsPath) {
                ReviewCardsView()
                    .navigationDestination(for: AppRoute.self) { routeView($0) }
            }
            .tabItem { Label("Cartes", systemImage: "rectangle.stack") }
            .tag(AppRoute.cards)

            NavigationStack(path: $profilePath) {
                ProfileView()
                    .navigationDestination(for: AppRoute.self) { routeView($0) }
            }
            .tabItem { Label("Profil", systemImage: "person.crop.circle") }
            .tag(AppRoute.profile)
        }
        .tint(SylluneColor.jade)
        .onAppear { apply(route: model.selectedRoute) }
        .onChange(of: model.selectedRoute) { _, route in
            apply(route: route)
        }
        .onReceive(NotificationCenter.default.publisher(for: .sylluneEscape)) { _ in
            popToRoot()
        }
    }

    private var tabSelection: Binding<AppRoute> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                // A second tap on the active tab is a familiar way to return
                // to that tab's root. It also clears a pending lesson route.
                if newTab == selectedTab, model.selectedRoute != newTab {
                    popToRoot()
                    model.persistRoute(newTab)
                    return
                }
                selectedTab = newTab
                if model.selectedRoute != newTab {
                    model.persistRoute(newTab)
                }
            }
        )
    }

    private func apply(route: AppRoute) {
        let baseTab = route.baseTab
        if selectedTab != baseTab {
            selectedTab = baseTab
        }

        switch baseTab {
        case .today:
            todayPath = routePath(route, root: .today, existing: todayPath)
        case .path:
            pathPath = routePath(route, root: .path, existing: pathPath)
        case .explorer:
            explorerPath = routePath(route, root: .explorer, existing: explorerPath)
        case .cards:
            cardsPath = routePath(route, root: .cards, existing: cardsPath)
        case .profile:
            profilePath = routePath(route, root: .profile, existing: profilePath)
        default:
            break
        }
    }

    private func routePath(_ route: AppRoute, root: AppRoute, existing: [AppRoute]) -> [AppRoute] {
        if route == root {
            return []
        }
        return existing == [route] ? existing : [route]
    }

    private func popToRoot() {
        switch selectedTab {
        case .today: todayPath.removeAll()
        case .path: pathPath.removeAll()
        case .explorer: explorerPath.removeAll()
        case .cards: cardsPath.removeAll()
        case .profile: profilePath.removeAll()
        default: break
        }
        if model.selectedRoute != selectedTab {
            model.persistRoute(selectedTab)
        }
    }

    @ViewBuilder
    private func routeView(_ route: AppRoute) -> some View {
        switch route {
        case .today: TodayView()
        case .path: LearningPathView()
        case .explorer: ExplorerView()
        case .cards: ReviewCardsView()
        case .profile: ProfileView()
        case .settings: SettingsView()
        case .lesson(let id): LessonView(lessonID: id)
        case .word(let id): WordDetailView(vocabularyID: id)
        case .story(let id): StoryDetailView(storyID: id)
        case .dictionary(let query): DictionaryView(initialQuery: query)
        case .oral(let id): OralView(exerciseID: id)
        case .writing(let id): WritingView(exerciseID: id)
        }
    }
}

public struct SplitShell: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: AppRoute? = .today
    public init() {}
    public var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Apprendre") {
                    NavigationLink(value: AppRoute.today) { Label("Aujourd’hui", systemImage: "sun.max") }.keyboardShortcut("1", modifiers: .command)
                    NavigationLink(value: AppRoute.path) { Label("Parcours", systemImage: "list.bullet.rectangle.portrait") }.keyboardShortcut("2", modifiers: .command)
                    NavigationLink(value: AppRoute.cards) { Label("Cartes", systemImage: "rectangle.stack") }.keyboardShortcut("4", modifiers: .command)
                }
                Section("Découvrir") {
                    NavigationLink(value: AppRoute.explorer) {
                        Label("Explorer", systemImage: "book.pages")
                    }
                    .accessibilityLabel("Explorer : histoires et dictionnaire")
                    .keyboardShortcut("3", modifiers: .command)
                }
                Section("Compte") {
                    NavigationLink(value: AppRoute.profile) { Label("Profil", systemImage: "person.crop.circle") }.keyboardShortcut("5", modifiers: .command)
                    NavigationLink(value: AppRoute.settings) { Label("Réglages", systemImage: "gearshape") }.keyboardShortcut(",", modifiers: .command)
                }
            }
            .navigationTitle("Syllune")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 280)
        } detail: {
            NavigationStack {
                routeView(model.selectedRoute)
                    .navigationDestination(for: AppRoute.self) { routeView($0) }
            }
        }
        .onChange(of: selection) { _, value in
            if let value { model.persistRoute(value) }
        }
        .onAppear { selection = model.selectedRoute.baseTab }
        .onReceive(NotificationCenter.default.publisher(for: .sylluneEscape)) { _ in
            model.persistRoute(model.selectedRoute.baseTab)
        }
    }

    @ViewBuilder private func routeView(_ route: AppRoute) -> some View {
        switch route {
        case .today: TodayView()
        case .path: LearningPathView()
        case .explorer: ExplorerView()
        case .cards: ReviewCardsView()
        case .profile: ProfileView()
        case .settings: SettingsView()
        case .lesson(let id): LessonView(lessonID: id)
        case .word(let id): WordDetailView(vocabularyID: id)
        case .story(let id): StoryDetailView(storyID: id)
        case .dictionary(let query): DictionaryView(initialQuery: query)
        case .oral(let id): OralView(exerciseID: id)
        case .writing(let id): WritingView(exerciseID: id)
        }
    }
}

private extension AppRoute {
    var baseTab: AppRoute {
        switch self {
        case .path: return .path
        case .explorer, .story, .dictionary, .word: return .explorer
        case .cards: return .cards
        case .profile, .settings: return .profile
        default: return .today
        }
    }
}
