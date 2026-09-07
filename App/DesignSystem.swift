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
    // Light values keep normal text at or above a readable contrast ratio;
    // dark values are selected independently rather than simply inverted.
    public static let canvas = Color.sylluneAdaptive(light: SylluneRGB(0.969, 0.973, 0.957), dark: SylluneRGB(0.055, 0.075, 0.075))
    public static let surface = Color.sylluneAdaptive(light: SylluneRGB(1, 1, 1), dark: SylluneRGB(0.09, 0.12, 0.12))
    public static let surfaceRaised = Color.sylluneAdaptive(light: SylluneRGB(0.91, 0.94, 0.92), dark: SylluneRGB(0.13, 0.18, 0.17))
    public static let ink = Color.sylluneAdaptive(light: SylluneRGB(0.086, 0.137, 0.173), dark: SylluneRGB(0.94, 0.96, 0.94))
    public static let inkMuted = Color.sylluneAdaptive(light: SylluneRGB(0.235, 0.302, 0.310), dark: SylluneRGB(0.70, 0.76, 0.75))
    public static let border = Color.sylluneAdaptive(light: SylluneRGB(0.45, 0.52, 0.47), dark: SylluneRGB(0.45, 0.55, 0.50))
    public static let jade = Color.sylluneAdaptive(light: SylluneRGB(0.055, 0.33, 0.285), dark: SylluneRGB(0.12, 0.46, 0.36))
    public static let jadeDeep = Color.sylluneAdaptive(light: SylluneRGB(0.03, 0.24, 0.21), dark: SylluneRGB(0.40, 0.87, 0.74))
    public static let jadeButton = Color.sylluneAdaptive(light: SylluneRGB(0.055, 0.33, 0.285), dark: SylluneRGB(0.12, 0.46, 0.36))
    // Coral is dark enough for the white mark and remains distinguishable as
    // an icon in both appearances.
    public static let coral = Color.sylluneAdaptive(light: SylluneRGB(0.65, 0.16, 0.13), dark: SylluneRGB(0.78, 0.24, 0.18))
    public static let sun = Color.sylluneAdaptive(light: SylluneRGB(0.94, 0.75, 0.22), dark: SylluneRGB(0.42, 0.30, 0.06))
    // `sky` is used for text and therefore stays light enough on dark canvas.
    // Buttons use `skyButton`, whose darker value keeps white button labels
    // readable as well.
    public static let sky = Color.sylluneAdaptive(light: SylluneRGB(0.12, 0.34, 0.56), dark: SylluneRGB(0.35, 0.60, 0.78))
    public static let skyButton = Color.sylluneAdaptive(light: SylluneRGB(0.12, 0.34, 0.56), dark: SylluneRGB(0.17, 0.40, 0.61))
    public static let success = Color.sylluneAdaptive(light: SylluneRGB(0.06, 0.36, 0.24), dark: SylluneRGB(0.36, 0.80, 0.61))
    public static let error = Color.sylluneAdaptive(light: SylluneRGB(0.62, 0.10, 0.15), dark: SylluneRGB(0.95, 0.37, 0.43))

    /// Text placed on the selected-day accent. The accent is intentionally
    /// dark in dark mode, so its foreground must change with the appearance.
    public static let inkOnSun = Color.sylluneAdaptive(light: SylluneRGB(0.086, 0.137, 0.173), dark: SylluneRGB(0.94, 0.96, 0.94))
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
        let audio: any AudioService
    }

    private var registrations: [UUID: Registration] = [:]
    private var order: [UUID] = []
    private var speakingID: UUID?

    private init() {}

    @discardableResult
    public func register(text: String, audio: any AudioService) -> UUID {
        let id = UUID()
        registrations[id] = Registration(id: id, text: text, audio: audio)
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
                    rate: .normal
                )
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

public struct SylluneCard: ViewModifier {
    public let radius: CGFloat
    public init(radius: CGFloat = 18) { self.radius = radius }
    public func body(content: Content) -> some View {
        content
            .background(SylluneColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(SylluneColor.border, lineWidth: 1))
    }
}

public extension View {
    func sylluneCard(radius: CGFloat = 18) -> some View { modifier(SylluneCard(radius: radius)) }
}

/// A portable wrapping layout for Chinese tokens. `HStack` keeps every token
/// on one line, which cuts phrases off at large Dynamic Type sizes. This
/// layout measures each child and starts a new row when the available width is
/// exhausted on iPhone, iPad, or a narrow Mac window.
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
        var index = 0

        for row in rows {
            var x = bounds.minX
            for _ in row.indices {
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                subview.place(
                    at: CGPoint(x: x + size.width / 2, y: y + row.height / 2),
                    anchor: .center,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
                index += 1
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int]
        var width: CGFloat
        var height: CGFloat
    }

    private func makeRows(subviews: Subviews, maximumWidth: CGFloat) -> [Row] {
        guard !subviews.isEmpty else { return [] }
        let width = max(0, maximumWidth)
        var rows: [Row] = []
        var row = Row(indices: [], width: 0, height: 0)

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let spacing = row.indices.isEmpty ? 0 : horizontalSpacing
            if !row.indices.isEmpty && row.width + spacing + size.width > width {
                rows.append(row)
                row = Row(indices: [], width: 0, height: 0)
            }
            let nextSpacing = row.indices.isEmpty ? 0 : horizontalSpacing
            row.indices.append(index)
            row.width += nextSpacing + size.width
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
                .foregroundStyle(.white)
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
            Circle().stroke(SylluneColor.border, lineWidth: 7)
            Circle().trim(from: 0, to: value).stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
        }
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
    public let text: String
    public let font: Font
    public let speechEnabled: Bool
    public let vocabulary: [VocabularyEntry]
    public let segmentation: [TextSegment]
    public let pinyin: String?
    public let translation: String?
    public let phraseAudio: AssetReference?
    public let wordInteractionEnabled: Bool

    @State private var isSpeaking = false
    @State private var statusMessage: String?
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
        wordInteractionEnabled: Bool? = nil
    ) {
        self.text = text
        self.font = font
        self.speechEnabled = speechEnabled
        self.vocabulary = vocabulary
        self.segmentation = segmentation
        self.pinyin = pinyin
        self.translation = translation
        self.phraseAudio = audio
        self.wordInteractionEnabled = wordInteractionEnabled ?? speechEnabled
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
        wordInteractionEnabled: Bool? = nil
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
            wordInteractionEnabled: wordInteractionEnabled
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
                    .accessibilityHint("Utilise une voix mandarin locale si elle est installée. Un message indique toute indisponibilité.")
                    .frame(minHeight: 44, alignment: .leading)

                    if pinyin != nil || translation != nil || phraseAudio != nil {
                        Button(action: speakSlowly) {
                            Label("Lentement", systemImage: "tortoise")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Lire lentement en chinois")
                        .accessibilityHint("Utilise la synthèse vocale locale à vitesse lente.")
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
                WordDetailView(vocabularyID: selectedVocabularyID, autoPlayAudio: true)
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
        if let entry = token.entry, wordInteractionEnabled {
            Button {
                openWord(entry)
            } label: {
                Text(token.surface)
                    .font(font)
                    .foregroundStyle(SylluneColor.jadeDeep)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(token.surface)
            .accessibilityHint("Ouvre la fiche de ce mot et lance son audio local.")
        } else {
            Text(token.surface)
                .font(font)
                .textSelection(.enabled)
        }
    }

    private var containsChinese: Bool {
        text.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    private var shouldTokenize: Bool {
        wordInteractionEnabled && (!segmentation.isEmpty || tokens.contains { $0.entry != nil })
    }

    private struct ChineseToken: Identifiable {
        let id: Int
        let surface: String
        let entry: VocabularyEntry?
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
            return segmentation.enumerated().map { offset, segment in
                ChineseToken(id: offset, surface: segment.surface, entry: vocabularyEntry(for: segment.vocabularyID))
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

        guard !dictionary.isEmpty else { return [] }
        var result: [ChineseToken] = []
        var cursor = text.startIndex
        while cursor < text.endIndex {
            if let match = dictionary.first(where: { text[cursor...].hasPrefix($0.surface) }) {
                result.append(ChineseToken(id: result.count, surface: match.surface, entry: match.entry))
                cursor = text.index(cursor, offsetBy: match.surface.count)
            } else {
                let next = text.index(after: cursor)
                result.append(ChineseToken(id: result.count, surface: String(text[cursor..<next]), entry: nil))
                cursor = next
            }
        }
        return result
    }

    private func vocabularyEntry(for id: VocabularyID?) -> VocabularyEntry? {
        guard let id else { return nil }
        return availableVocabulary.first { $0.id == id }
    }

    private func registerKeyboardPhrase() {
        guard commandRegistrationID == nil, speechEnabled, containsChinese else { return }
        commandRegistrationID = SylluneAudioCommandCenter.shared.register(text: text, audio: model.dependencies.audio)
    }

    private func toggleSpeech() {
        if isSpeaking {
            model.dependencies.audio.stopSpeaking()
            model.dependencies.audio.stopPlayback()
            isSpeaking = false
            statusMessage = "Lecture arrêtée."
            return
        }

        isSpeaking = true
        statusMessage = nil
        Task { @MainActor in
            do {
                if let phraseAudio {
                    do {
                        try await model.dependencies.audio.play(asset: phraseAudio)
                    } catch {
                        try await model.dependencies.audio.speak(text: text, localeIdentifier: "zh-CN", rate: .normal)
                    }
                } else {
                    try await model.dependencies.audio.speak(text: text, localeIdentifier: "zh-CN", rate: .normal)
                }
                statusMessage = "Lecture en cours."
            } catch {
                isSpeaking = false
                statusMessage = "Audio indisponible hors ligne."
            }
        }
    }

    private func openWord(_ entry: VocabularyEntry) {
        selectedVocabularyID = entry.id
    }

    private func speakSlowly() {
        model.dependencies.audio.stopSpeaking()
        model.dependencies.audio.stopPlayback()
        isSpeaking = true
        statusMessage = nil
        Task { @MainActor in
            do {
                // A supplied asset has no rate control in AudioService. Slow
                // playback therefore uses the local synthesizer explicitly.
                try await model.dependencies.audio.speak(text: text, localeIdentifier: "zh-CN", rate: .slow)
                statusMessage = "Lecture lente en cours."
            } catch {
                isSpeaking = false
                statusMessage = "Audio indisponible hors ligne."
            }
        }
    }
}
