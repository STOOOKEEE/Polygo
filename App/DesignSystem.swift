import SwiftUI
import PolygoCore
import PolygoApple

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private struct SylluneRGB {
    let red: Double
    let green: Double
    let blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

private extension Color {
    /// SwiftUI's `Color(red:green:blue:)` is fixed to one appearance. This
    /// small platform bridge keeps the design tokens adaptive without
    /// requiring an asset catalog in the package's shared project.
    static func sylluneAdaptive(light: SylluneRGB, dark: SylluneRGB) -> Color {
        #if os(iOS)
        let lightColor = UIColor(red: CGFloat(light.red), green: CGFloat(light.green), blue: CGFloat(light.blue), alpha: 1)
        let darkColor = UIColor(red: CGFloat(dark.red), green: CGFloat(dark.green), blue: CGFloat(dark.blue), alpha: 1)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
        #elseif os(macOS)
        let lightColor = NSColor(calibratedRed: CGFloat(light.red), green: CGFloat(light.green), blue: CGFloat(light.blue), alpha: 1)
        let darkColor = NSColor(calibratedRed: CGFloat(dark.red), green: CGFloat(dark.green), blue: CGFloat(dark.blue), alpha: 1)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkColor : lightColor
        })
        #else
        return Color(red: light.red, green: light.green, blue: light.blue)
        #endif
    }
}

public enum SylluneColor {
    // One charter for every tab: cream/indigo neutrals, jade as the primary
    // accent, sun for rewards (coins, streak, unit challenges), sky and coral
    // as secondary accents, success/error for feedback. Every screen follows
    // the system appearance through these adaptive tokens; none forces a theme.
    public static let canvas = Color.sylluneAdaptive(light: SylluneRGB(1, 0.973, 0.914), dark: SylluneRGB(0.063, 0.082, 0.176))
    public static let surface = Color.sylluneAdaptive(light: SylluneRGB(1, 0.988, 0.961), dark: SylluneRGB(0.102, 0.129, 0.263))
    public static let surfaceRaised = Color.sylluneAdaptive(light: SylluneRGB(0.949, 0.910, 0.843), dark: SylluneRGB(0.141, 0.176, 0.337))
    public static let ink = Color.sylluneAdaptive(light: SylluneRGB(0.161, 0.137, 0.247), dark: SylluneRGB(1, 0.973, 0.914))
    public static let inkMuted = Color.sylluneAdaptive(light: SylluneRGB(0.427, 0.400, 0.506), dark: SylluneRGB(0.749, 0.780, 0.898))
    public static let border = Color.sylluneAdaptive(light: SylluneRGB(0.886, 0.855, 0.800), dark: SylluneRGB(0.224, 0.263, 0.396))
    public static let jade = Color.sylluneAdaptive(light: SylluneRGB(0.080, 0.560, 0.480), dark: SylluneRGB(0.278, 0.843, 0.761))
    public static let jadeDeep = Color.sylluneAdaptive(light: SylluneRGB(0.090, 0.435, 0.392), dark: SylluneRGB(0.455, 0.906, 0.835))
    public static let jadeButton = Color.sylluneAdaptive(light: SylluneRGB(0.090, 0.435, 0.392), dark: SylluneRGB(0.278, 0.843, 0.761))
    public static let coral = Color.sylluneAdaptive(light: SylluneRGB(0.737, 0.275, 0.231), dark: SylluneRGB(1, 0.475, 0.353))
    public static let sun = Color.sylluneAdaptive(light: SylluneRGB(0.953, 0.773, 0.369), dark: SylluneRGB(0.961, 0.780, 0.369))
    public static let sky = Color.sylluneAdaptive(light: SylluneRGB(0.153, 0.376, 0.588), dark: SylluneRGB(0.550, 0.718, 0.992))
    public static let skyButton = Color.sylluneAdaptive(light: SylluneRGB(0.122, 0.314, 0.482), dark: SylluneRGB(0.240, 0.490, 0.733))
    public static let success = Color.sylluneAdaptive(light: SylluneRGB(0.086, 0.435, 0.286), dark: SylluneRGB(0.443, 0.871, 0.655))
    public static let error = Color.sylluneAdaptive(light: SylluneRGB(0.710, 0.200, 0.278), dark: SylluneRGB(0.980, 0.480, 0.550))

    public static let heroStart = Color.sylluneAdaptive(light: SylluneRGB(0.090, 0.435, 0.392), dark: SylluneRGB(0.235, 0.180, 0.373))
    public static let heroEnd = Color.sylluneAdaptive(light: SylluneRGB(0.031, 0.286, 0.318), dark: SylluneRGB(0.102, 0.129, 0.263))
    /// Text on the deep fills that stay dark in both appearances: the hero
    /// gradient, coral and `skyButton`.
    public static let inkOnDeep = Color.white
    public static let progressTrack = Color.sylluneAdaptive(light: SylluneRGB(0.886, 0.855, 0.800), dark: SylluneRGB(0.224, 0.263, 0.396))
    public static let inkOnSuccess = Color.sylluneAdaptive(light: SylluneRGB(1, 0.973, 0.914), dark: SylluneRGB(0.063, 0.082, 0.176))
    public static let pathJade = Color.sylluneAdaptive(light: SylluneRGB(0.080, 0.435, 0.384), dark: SylluneRGB(0.278, 0.843, 0.761))
    public static let pathCoral = Color.sylluneAdaptive(light: SylluneRGB(0.750, 0.275, 0.220), dark: SylluneRGB(1, 0.475, 0.353))
    public static let pathSky = Color.sylluneAdaptive(light: SylluneRGB(0.122, 0.360, 0.588), dark: SylluneRGB(0.550, 0.718, 0.992))
    public static let pathViolet = Color.sylluneAdaptive(light: SylluneRGB(0.350, 0.230, 0.580), dark: SylluneRGB(0.770, 0.630, 0.996))

    public static let inkOnJade = Color.sylluneAdaptive(light: SylluneRGB(1, 0.973, 0.914), dark: SylluneRGB(0.063, 0.082, 0.176))
    public static let inkOnCoral = Color.sylluneAdaptive(light: SylluneRGB(1, 0.973, 0.914), dark: SylluneRGB(0.063, 0.082, 0.176))
    public static let inkOnSky = Color.sylluneAdaptive(light: SylluneRGB(1, 0.973, 0.914), dark: SylluneRGB(0.063, 0.082, 0.176))
    public static let inkOnViolet = Color.sylluneAdaptive(light: SylluneRGB(1, 0.973, 0.914), dark: SylluneRGB(0.063, 0.082, 0.176))

    /// Rotating accents of the path's unit banners, tracks and nodes.
    public static func pathAccent(for index: Int) -> Color {
        switch index % 4 {
        case 0: return pathJade
        case 1: return pathCoral
        case 2: return pathSky
        default: return pathViolet
        }
    }

    public static func pathAccentForeground(for index: Int) -> Color {
        switch index % 4 {
        case 0: return inkOnJade
        case 1: return inkOnCoral
        case 2: return inkOnSky
        default: return inkOnViolet
        }
    }

    public static let inkOnSun = Color.sylluneAdaptive(light: SylluneRGB(0.161, 0.137, 0.247), dark: SylluneRGB(0.161, 0.137, 0.247))
}

/// A single environment value combines the system Reduce Motion setting with
/// Syllune's persisted preference. It is supplied at the application root so
/// controls added later inherit the same behavior automatically.
private struct SylluneReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var sylluneReduceMotion: Bool {
        get { self[SylluneReduceMotionKey.self] }
        set { self[SylluneReduceMotionKey.self] = newValue }
    }
}

private struct SylluneShellWordNavigationKey: EnvironmentKey {
    static let defaultValue: ((VocabularyID) -> Void)? = nil
}

extension EnvironmentValues {
    var sylluneShellWordNavigation: ((VocabularyID) -> Void)? {
        get { self[SylluneShellWordNavigationKey.self] }
        set { self[SylluneShellWordNavigationKey.self] = newValue }
    }
}

/// The app commands use the same local speech service as the visible audio
/// controls. The most recently visible Chinese phrase owns the keyboard
/// command; unregistering it on disappearance prevents stale text from being
/// read after navigation.
@MainActor
public final class SylluneAudioCommandCenter {
    public static let shared = SylluneAudioCommandCenter()

    private struct Registration {
        let id: UUID
        let text: String
        let asset: AssetReference?
        let audio: any AudioService
    }

    private var registrations: [UUID: Registration] = [:]
    private var order: [UUID] = []
    private var speakingID: UUID?

    private init() {}

    @discardableResult
    public func register(text: String, asset: AssetReference? = nil, audio: any AudioService) -> UUID {
        let id = UUID()
        registrations[id] = Registration(
            id: id,
            text: PolygoCore.MandarinSpeechText.target(from: text),
            asset: asset,
            audio: audio
        )
        order.append(id)
        return id
    }

    public func unregister(_ id: UUID) {
        let registration = registrations.removeValue(forKey: id)
        order.removeAll { $0 == id }
        if speakingID == id {
            registration?.audio.stopSpeaking()
            speakingID = nil
        }
    }

    public func toggle() {
        guard let registration = currentRegistration else { return }
        if speakingID == registration.id {
            registration.audio.stopSpeaking()
            speakingID = nil
            return
        }

        speakingID = registration.id
        Task { @MainActor [weak self] in
            do {
                try await registration.audio.speak(
                    text: registration.text,
                    localeIdentifier: "zh-CN",
                    rate: .normal,
                    asset: registration.asset
                )
                if self?.speakingID == registration.id {
                    self?.speakingID = nil
                }
            } catch {
                if self?.speakingID == registration.id {
                    self?.speakingID = nil
                }
            }
        }
    }

    public func stop() {
        currentRegistration?.audio.stopSpeaking()
        speakingID = nil
    }

    private var currentRegistration: Registration? {
        for id in order.reversed() {
            if let registration = registrations[id] { return registration }
        }
        return nil
    }
}

/// The learner's “Lent” choice, kept across launches and shared by the
/// dialogue, reading, listening and conversation players. Bundled clips play
/// slower without a pitch change; the local voice uses its slow rate.
public struct SlowAudioToggle: View {
    public static let storageKey = "audio.slowMode"
    @AppStorage(SlowAudioToggle.storageKey) private var isSlow = false

    public init() {}

    public static func rate(slow: Bool) -> SpeechRate {
        slow ? .slow : .normal
    }

    public var body: some View {
        Toggle(isOn: $isSlow) {
            Label("Lent", systemImage: "tortoise")
        }
        .toggleStyle(.button)
        .font(.callout.weight(.semibold))
        .tint(SylluneColor.sky)
        .frame(minHeight: 32)
        .accessibilityIdentifier("audio.slowMode")
        .accessibilityLabel("Lecture lente")
        .accessibilityValue(isSlow ? "Activée" : "Désactivée")
        .accessibilityHint("Ralentit l’audio mandarin sans changer la hauteur de la voix.")
    }
}

public enum SylluneCardStyle {
    case standard
    case quiet
    case interactive
    case hero

    fileprivate var border: Color {
        switch self {
        case .standard: return SylluneColor.border
        case .quiet: return SylluneColor.border.opacity(0.35)
        case .interactive: return SylluneColor.jade.opacity(0.62)
        case .hero: return .clear
        }
    }

    fileprivate var borderWidth: CGFloat {
        switch self {
        case .standard: return 1
        case .quiet: return 0.75
        case .interactive: return 1.25
        case .hero: return 0
        }
    }

    fileprivate var shadowColor: Color {
        switch self {
        case .standard: return .black.opacity(0.08)
        case .quiet: return .black.opacity(0.05)
        case .interactive: return SylluneColor.jade.opacity(0.20)
        case .hero: return SylluneColor.heroEnd.opacity(0.32)
        }
    }

    fileprivate var shadowRadius: CGFloat {
        switch self {
        case .standard: return 6
        case .quiet: return 3
        case .interactive: return 9
        case .hero: return 16
        }
    }

    fileprivate var shadowY: CGFloat {
        switch self {
        case .standard: return 3
        case .quiet: return 2
        case .interactive: return 4
        case .hero: return 6
        }
    }
}

public struct SylluneCard: ViewModifier {
    public let radius: CGFloat
    public let style: SylluneCardStyle

    public init(radius: CGFloat = 18, style: SylluneCardStyle = .standard) {
        self.radius = radius
        self.style = style
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                switch style {
                case .hero:
                    LinearGradient(
                        colors: [SylluneColor.heroStart, SylluneColor.heroEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .quiet:
                    SylluneColor.surfaceRaised
                case .standard:
                    LinearGradient(
                        colors: [SylluneColor.surface, SylluneColor.surfaceRaised.opacity(0.46)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .interactive:
                    LinearGradient(
                        colors: [SylluneColor.surfaceRaised, SylluneColor.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(shape)
            .overlay(shape.stroke(style.border, lineWidth: style.borderWidth))
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.26), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: style.shadowColor, radius: style.shadowRadius, x: 0, y: style.shadowY)
    }
}

public extension View {
    func sylluneCard(radius: CGFloat = 18) -> some View { modifier(SylluneCard(radius: radius)) }
    func sylluneCard(style: SylluneCardStyle, radius: CGFloat = 18) -> some View {
        modifier(SylluneCard(radius: radius, style: style))
    }
}

/// A portable wrapping layout for Chinese tokens. `HStack` keeps every token
/// on one line, which cuts phrases off at large Dynamic Type sizes. This
/// layout measures each child and starts a new row when the available width is
/// exhausted on iPhone, iPad, or a narrow Mac window. A child wider than the
/// available width is proposed that width, so its text wraps inside it.
public struct SylluneFlowLayout: Layout {
    public var horizontalSpacing: CGFloat
    public var verticalSpacing: CGFloat

    public init(horizontalSpacing: CGFloat = 2, verticalSpacing: CGFloat = 6) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = makeRows(subviews: subviews, maximumWidth: proposal.width ?? .greatestFiniteMagnitude)
        let contentWidth = rows.map(\.width).max() ?? 0
        let contentHeight = rows.reduce(0) { $0 + $1.height } + max(0, CGFloat(rows.count - 1)) * verticalSpacing
        return CGSize(width: proposal.width ?? contentWidth, height: contentHeight)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = makeRows(subviews: subviews, maximumWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for (index, size) in zip(row.indices, row.sizes) {
                subviews[index].place(
                    at: CGPoint(x: x + size.width / 2, y: y + row.height / 2),
                    anchor: .center,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func makeRows(subviews: Subviews, maximumWidth: CGFloat) -> [Row] {
        guard !subviews.isEmpty else { return [] }
        let width = max(0, maximumWidth)
        var rows: [Row] = []
        var row = Row()

        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            if size.width > width {
                size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
                size.width = min(size.width, width)
            }
            if !row.indices.isEmpty && row.width + horizontalSpacing + size.width > width {
                rows.append(row)
                row = Row()
            }
            row.width += (row.indices.isEmpty ? 0 : horizontalSpacing) + size.width
            row.indices.append(index)
            row.sizes.append(size)
            row.height = max(row.height, size.height)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

public struct SylluneLogoMark: View {
    public let size: CGFloat
    public init(size: CGFloat = 56) { self.size = size }
    public var body: some View {
        ZStack {
            Circle().fill(SylluneColor.coral)
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(SylluneColor.inkOnDeep)
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Symbole Syllune")
    }
}

public struct ProgressRing: View {
    public let value: Double
    public let tint: Color
    public init(value: Double, tint: Color = SylluneColor.jade) {
        self.value = min(1, max(0, value)); self.tint = tint
    }
    public var body: some View {
        ZStack {
            Circle().stroke(SylluneColor.progressTrack, lineWidth: 7)
            Circle().trim(from: 0, to: value).stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progression")
        .accessibilityValue("\(Int(value * 100)) pour cent")
    }
}

public struct SylluneProgressBar: View {
    public let value: Double
    public let tint: Color

    public init(value: Double, tint: Color = SylluneColor.jade) {
        self.value = min(1, max(0, value))
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SylluneColor.progressTrack)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * value)
            }
        }
        // GeometryReader otherwise expands to all available vertical space,
        // turning the track into a large pill when the bar has no explicit
        // height from its parent.
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progression")
        .accessibilityValue("\(Int(value * 100)) pour cent")
    }
}

public struct Badge: View {
    public let text: String
    public let color: Color
    public init(_ text: String, color: Color = SylluneColor.surfaceRaised) { self.text = text; self.color = color }
    public var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SylluneColor.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color, in: Capsule())
    }
}

/// Chinese content remains selectable for copy/paste and can expose
/// vocabulary words as larger VoiceOver and keyboard targets. Existing callers
/// may keep `ChineseSelectableText("你好")`; callers with lesson content can
/// use the named `hanzi:` initializer and pass `vocabulary` plus
/// `segmentation`.
public struct ChineseSelectableText: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.sylluneShellWordNavigation) private var shellWordNavigation
    public let text: String
    public let font: Font
    public let speechEnabled: Bool
    public let vocabulary: [VocabularyEntry]
    public let segmentation: [TextSegment]
    public let pinyin: String?
    public let translation: String?
    public let phraseAudio: AssetReference?
    /// Optional Mandarin source used only for speech. This lets an exercise
    /// keep its learner-facing blank while reading a completed canonical
    /// sentence aloud.
    public let speechText: String?
    public let wordInteractionEnabled: Bool
    private let onSpeechRequested: (() -> Void)?

    @State private var isSpeaking = false
    @State private var statusMessage: String?
    /// Token whose pinyin and meaning are shown in a popover over it.
    @State private var presentedTokenID: Int?
    @State private var selectedVocabularyID: VocabularyID?
    @State private var commandRegistrationID: UUID?

    public init(
        _ text: String,
        font: Font = .body,
        speechEnabled: Bool = true,
        vocabulary: [VocabularyEntry] = [],
        segmentation: [TextSegment] = [],
        pinyin: String? = nil,
        translation: String? = nil,
        audio: AssetReference? = nil,
        wordInteractionEnabled: Bool? = nil,
        speechText: String? = nil,
        onSpeechRequested: (() -> Void)? = nil
    ) {
        self.text = text
        self.font = font
        self.speechEnabled = speechEnabled
        self.vocabulary = vocabulary
        self.segmentation = segmentation
        self.pinyin = pinyin
        self.translation = translation
        self.phraseAudio = audio
        self.speechText = speechText
        self.wordInteractionEnabled = wordInteractionEnabled ?? speechEnabled
        self.onSpeechRequested = onSpeechRequested
    }

    public init(
        hanzi: String,
        font: Font = .body,
        speechEnabled: Bool = true,
        vocabulary: [VocabularyEntry] = [],
        segmentation: [TextSegment] = [],
        pinyin: String? = nil,
        translation: String? = nil,
        audio: AssetReference? = nil,
        wordInteractionEnabled: Bool? = nil,
        speechText: String? = nil,
        onSpeechRequested: (() -> Void)? = nil
    ) {
        self.init(
            hanzi,
            font: font,
            speechEnabled: speechEnabled,
            vocabulary: vocabulary,
            segmentation: segmentation,
            pinyin: pinyin,
            translation: translation,
            audio: audio,
            wordInteractionEnabled: wordInteractionEnabled,
            speechText: speechText,
            onSpeechRequested: onSpeechRequested
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: pinyin == nil && translation == nil ? 4 : 8) {
            phraseContent

            if speechEnabled && containsChinese {
                HStack(spacing: 10) {
                    Button(action: toggleSpeech) {
                        Label(
                            isSpeaking ? "Arrêter la lecture" : "Écouter",
                            systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2"
                        )
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(isSpeaking ? "Arrêter la lecture en chinois" : "Lire le chinois")
                    .accessibilityHint("Lit l’enregistrement embarqué, ou une voix mandarin locale si elle est installée. Un message indique toute indisponibilité.")
                    .frame(minHeight: 44, alignment: .leading)

                    if pinyin != nil || translation != nil || phraseAudio != nil {
                        Button(action: speakSlowly) {
                            Label("Lentement", systemImage: "tortoise")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Lire lentement en chinois")
                        .accessibilityHint("Lit l’enregistrement embarqué ou la voix locale à vitesse lente.")
                        .frame(minHeight: 44, alignment: .leading)
                    }
                }
            }

            if let pinyin, !pinyin.isEmpty {
                Text(pinyin)
                    .font(.callout)
                    .foregroundStyle(SylluneColor.jadeDeep)
                    .accessibilityLabel("Pinyin : \(pinyin)")
            }
            if let translation, !translation.isEmpty {
                Text(translation)
                    .font(.body)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .accessibilityLabel("Traduction : \(translation)")
            }
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .accessibilityLabel("État de la lecture")
                    .accessibilityValue(statusMessage)
            }
        }
        .onAppear { registerKeyboardPhrase() }
        .onDisappear {
            if let commandRegistrationID {
                SylluneAudioCommandCenter.shared.unregister(commandRegistrationID)
                self.commandRegistrationID = nil
            }
            if isSpeaking {
                model.dependencies.audio.stopSpeaking()
            }
        }
        .navigationDestination(
            isPresented: Binding(
                get: { selectedVocabularyID != nil },
                set: { if !$0 { selectedVocabularyID = nil } }
            )
        ) {
            if let selectedVocabularyID {
                // The token button has already started local Mandarin speech.
                // Avoid a second asset playback when the detail destination
                // appears.
                WordDetailView(vocabularyID: selectedVocabularyID, autoPlayAudio: false)
            }
        }
    }

    @ViewBuilder private var phraseContent: some View {
        if shouldTokenize {
            SylluneFlowLayout(horizontalSpacing: 2, verticalSpacing: 6) {
                ForEach(tokens) { token in
                    tokenView(token)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(text)
                .font(font)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder private func tokenView(_ token: ChineseToken) -> some View {
        if let vocabularyID = token.vocabularyID, wordInteractionEnabled {
            Button {
                if speechEnabled { speakToken(token.surface) }
                presentedTokenID = token.id
            } label: {
                Text(token.surface)
                    .font(font)
                    .foregroundStyle(SylluneColor.jadeDeep)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(token.surface)
            .accessibilityHint(speechEnabled
                ? "Écoute ce mot en mandarin et affiche son pinyin et sa traduction."
                : "Affiche le pinyin et la traduction de ce mot.")
            // No fixed arrow edge: the system opens the bubble on the side
            // with room, so a word near the top keeps its bubble whole.
            .popover(isPresented: Binding(
                get: { presentedTokenID == token.id },
                set: { if !$0 { presentedTokenID = nil } }
            )) {
                ChineseWordPopover(
                    vocabularyID: vocabularyID,
                    surface: token.surface,
                    segmentPinyin: token.pinyin,
                    entry: availableVocabulary.first { $0.id == vocabularyID }
                ) {
                    presentedTokenID = nil
                    openWord(vocabularyID)
                }
                .environmentObject(model)
                // Stays a bubble anchored to the word on iPhone too.
                .presentationCompactAdaptation(.popover)
            }
        } else if speechEnabled && PolygoCore.MandarinSpeechText.containsHanzi(token.surface) {
            Button {
                speakToken(token.surface)
            } label: {
                Text(token.surface)
                    .font(font)
                    .foregroundStyle(SylluneColor.jadeDeep)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(token.surface)
            .accessibilityHint("Écoute ce caractère en mandarin.")
        } else {
            Text(token.surface)
                .font(font)
                .textSelection(.enabled)
        }
    }

    private var containsChinese: Bool {
        PolygoCore.MandarinSpeechText.containsHanzi(text)
    }

    private var speechSource: String {
        speechText ?? text
    }

    private var speechTarget: String {
        PolygoCore.MandarinSpeechText.target(from: speechSource)
    }

    private var shouldTokenize: Bool {
        (speechEnabled || wordInteractionEnabled) && containsChinese
    }

    /// A word's popover and card find it by its ID: `WordDetailView` finds
    /// the entry in every lesson of the course, loaded or not.
    private struct ChineseToken: Identifiable {
        let id: Int
        let surface: String
        let vocabularyID: VocabularyID?
        /// The segment's own pinyin, grouped for this word in context.
        var pinyin: String? = nil
    }

    private var availableVocabulary: [VocabularyEntry] {
        var values: [VocabularyEntry] = []
        var seen: Set<VocabularyID> = []
        for entry in vocabulary + model.loadedLessons.values.flatMap(\.vocabulary) where seen.insert(entry.id).inserted {
            values.append(entry)
        }
        return values
    }

    private var tokens: [ChineseToken] {
        if !segmentation.isEmpty {
            // Latin text between words (names, French punctuation) wraps
            // word by word instead of forming one token wider than the row.
            return segmentation
                .flatMap { segment -> [(surface: String, vocabularyID: VocabularyID?, pinyin: String?)] in
                    guard segment.vocabularyID == nil else { return [(segment.surface, segment.vocabularyID, segment.pinyin)] }
                    return Self.words(in: segment.surface).map { ($0, nil, nil) }
                }
                .enumerated()
                .map { offset, token in
                    ChineseToken(id: offset, surface: token.surface, vocabularyID: token.vocabularyID, pinyin: token.pinyin)
                }
        }

        let dictionary: [(surface: String, entry: VocabularyEntry)] = availableVocabulary
            .flatMap { entry in
                [(entry.hanzi, entry), (entry.traditionalHanzi, entry)].compactMap { pair in
                    guard let surface = pair.0, !surface.isEmpty else { return nil }
                    return (surface: surface, entry: pair.1)
                }
            }
            .sorted { lhs, rhs in
                if lhs.surface.count == rhs.surface.count { return lhs.surface < rhs.surface }
                return lhs.surface.count > rhs.surface.count
            }

        var result: [ChineseToken] = []
        var cursor = text.startIndex
        while cursor < text.endIndex {
            if let match = dictionary.first(where: { text[cursor...].hasPrefix($0.surface) }) {
                result.append(ChineseToken(id: result.count, surface: match.surface, vocabularyID: match.entry.id))
                cursor = text.index(cursor, offsetBy: match.surface.count)
            } else {
                let next = text.index(after: cursor)
                let character = String(text[cursor..<next])
                if PolygoCore.MandarinSpeechText.containsHanzi(character) {
                    result.append(ChineseToken(id: result.count, surface: character, vocabularyID: nil))
                    cursor = next
                } else {
                    // Keep French instructions and punctuation in readable
                    // words, wrapping between them, while preserving one
                    // tappable token per unknown Hanzi character.
                    var end = next
                    while end < text.endIndex {
                        let following = text.index(after: end)
                        let value = String(text[end..<following])
                        if PolygoCore.MandarinSpeechText.containsHanzi(value) { break }
                        end = following
                    }
                    for word in Self.words(in: text[cursor..<end]) {
                        result.append(ChineseToken(id: result.count, surface: word, vocabularyID: nil))
                    }
                    cursor = end
                }
            }
        }
        return result
    }

    /// Splits text into wrapping units. Each word keeps its following spaces,
    /// so only a space opening the text can start a unit; non-breaking spaces
    /// do not split. Closing punctuation (`»`, `?`, `!`) stays with what
    /// precedes it and opening punctuation (`«`) with the next word.
    private static func words<S: StringProtocol>(in text: S) -> [String] {
        func breaks(_ character: Character) -> Bool {
            character.isWhitespace && !["\u{00A0}", "\u{202F}", "\u{2007}"].contains(character)
        }

        var pieces: [String] = []
        var current = ""
        for character in text {
            if let last = current.last, breaks(last), !breaks(character) {
                pieces.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty { pieces.append(current) }

        var words: [String] = []
        var opening = ""
        for piece in pieces {
            let core = piece.filter { !breaks($0) }
            let isPunctuation = !core.isEmpty && core.allSatisfy { !$0.isLetter && !$0.isNumber }
            if isPunctuation && core.allSatisfy({ "«“‘‹„([{¿¡".contains($0) }) {
                opening += piece
            } else if isPunctuation, let last = words.last {
                words[words.count - 1] = last + opening + piece
                opening = ""
            } else {
                words.append(opening + piece)
                opening = ""
            }
        }
        if !opening.isEmpty { words.append(opening) }
        return words
    }

    private func registerKeyboardPhrase() {
        guard commandRegistrationID == nil, speechEnabled else { return }
        guard !speechTarget.isEmpty else { return }
        commandRegistrationID = SylluneAudioCommandCenter.shared.register(text: speechSource, asset: speechAsset, audio: model.dependencies.audio)
    }

    private func toggleSpeech() {
        if isSpeaking {
            model.dependencies.audio.stopSpeaking()
            model.dependencies.audio.stopPlayback()
            isSpeaking = false
            statusMessage = "Lecture arrêtée."
            return
        }

        say(rate: .normal)
    }

    /// A bundled clip records the displayed phrase, names included. A
    /// separate speech source, such as a completed fill-in sentence, is
    /// always read by the local voice.
    private var speechAsset: AssetReference? {
        speechText == nil ? phraseAudio : nil
    }

    private func say(rate: SpeechRate) {
        let target = speechTarget
        guard !target.isEmpty else {
            statusMessage = "Aucun texte mandarin à lire."
            return
        }
        onSpeechRequested?()
        model.dependencies.audio.stopSpeaking()
        model.dependencies.audio.stopPlayback()
        isSpeaking = true
        statusMessage = nil
        Task { @MainActor in
            do {
                try await model.dependencies.audio.speak(text: target, localeIdentifier: "zh-CN", rate: rate, asset: speechAsset)
                isSpeaking = false
                statusMessage = rate == .slow ? "Lecture lente terminée." : "Lecture terminée."
            } catch is CancellationError {
                isSpeaking = false
                statusMessage = "Lecture arrêtée."
            } catch {
                isSpeaking = false
                statusMessage = "Audio indisponible hors ligne."
            }
        }
    }

    private func openWord(_ vocabularyID: VocabularyID) {
        if let shellWordNavigation {
            shellWordNavigation(vocabularyID)
        } else {
            selectedVocabularyID = vocabularyID
        }
    }

    private func speakToken(_ value: String) {
        let target = PolygoCore.MandarinSpeechText.target(from: value)
        guard !target.isEmpty else { return }
        onSpeechRequested?()
        Task { @MainActor in
            try? await model.dependencies.audio.speak(
                text: target,
                localeIdentifier: "zh-CN",
                rate: .normal
            )
        }
    }

    private func speakSlowly() {
        say(rate: .slow)
    }
}

/// A tapped word's Hanzi, pinyin and meaning, shown in a bubble over the
/// text. Its full card opens only from « Voir la fiche ».
private struct ChineseWordPopover: View {
    @EnvironmentObject private var model: AppModel
    let vocabularyID: VocabularyID
    let surface: String
    let segmentPinyin: String?
    let openDetail: () -> Void
    @State private var entry: VocabularyEntry?
    @State private var isPlaying = false
    @State private var audioMessage: String?

    init(
        vocabularyID: VocabularyID,
        surface: String,
        segmentPinyin: String?,
        entry: VocabularyEntry?,
        openDetail: @escaping () -> Void
    ) {
        self.vocabularyID = vocabularyID
        self.surface = surface
        self.segmentPinyin = segmentPinyin
        self.openDetail = openDetail
        _entry = State(initialValue: entry)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(surface)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(SylluneColor.ink)
                Spacer(minLength: 0)
                Button(action: play) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SylluneColor.sky)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isPlaying ? "Arrêter la lecture" : "Écouter ce mot")
                .accessibilityIdentifier("word.popover.play")
            }
            if let pinyin {
                Text(pinyin)
                    .font(.title3)
                    .foregroundStyle(SylluneColor.jadeDeep)
                    .accessibilityLabel("Pinyin : \(pinyin)")
                    .accessibilityIdentifier("word.popover.pinyin")
            }
            if let meaning {
                Text(meaning)
                    .font(.body)
                    .foregroundStyle(SylluneColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Traduction : \(meaning)")
                    .accessibilityIdentifier("word.popover.meaning")
            } else if entry == nil {
                ProgressView()
                    .accessibilityLabel("Chargement du mot")
            }
            if let audioMessage {
                Text(audioMessage)
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
            }
            Button("Voir la fiche", action: openDetail)
                .buttonStyle(.bordered)
                .tint(SylluneColor.skyButton)
                .frame(minHeight: 44)
                .accessibilityHint("Ouvre la fiche complète de ce mot.")
                .accessibilityIdentifier("word.popover.detail")
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("word.popover")
        .task {
            guard entry == nil else { return }
            entry = await model.dictionaryEntries().first { $0.id == vocabularyID }
        }
        .onDisappear {
            if isPlaying {
                model.dependencies.audio.stopSpeaking()
                model.dependencies.audio.stopPlayback()
            }
        }
    }

    private var pinyin: String? {
        let value = segmentPinyin ?? entry?.pinyin
        return value?.isEmpty == false ? value : nil
    }

    private var meaning: String? {
        guard let value = entry?.meaning.resolve(preferred: model.preferredLanguageCodes), !value.isEmpty else { return nil }
        return value
    }

    private func play() {
        let audio = model.dependencies.audio
        audio.stopSpeaking()
        audio.stopPlayback()
        if isPlaying {
            isPlaying = false
            return
        }
        let target = PolygoCore.MandarinSpeechText.target(from: surface)
        guard !target.isEmpty else { return }
        isPlaying = true
        audioMessage = nil
        Task { @MainActor in
            do {
                // The word's clip when bundled, otherwise the local voice.
                try await model.dependencies.audio.speak(text: target, localeIdentifier: "zh-CN", rate: .normal, asset: entry?.audio)
            } catch is CancellationError {
            } catch {
                audioMessage = "Audio indisponible hors ligne."
            }
            isPlaying = false
        }
    }
}
