import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public enum TaviPose: Sendable {
    case welcome
    case encouragement
    case celebration
}

public struct TaviMascot: View {
    private let pose: TaviPose

    public init(pose: TaviPose) {
        self.pose = pose
    }

    public var body: some View {
        artwork
            .resizable()
            .aspectRatio(contentMode: .fit)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private var artwork: Image {
        switch pose {
        case .welcome: SylluneDesignArtwork.taviWelcome
        case .encouragement: SylluneDesignArtwork.taviEncouragement
        case .celebration: SylluneDesignArtwork.taviCelebration
        }
    }
}

public struct SylluneCoinIcon: View {
    public init() {}

    public var body: some View {
        SylluneDesignArtwork.coin
            .resizable()
            .aspectRatio(contentMode: .fit)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

public struct SylluneCoinBadge: View {
    private let balance: Int?

    public init(balance: Int?) {
        self.balance = balance
    }

    public var body: some View {
        HStack(spacing: 7) {
            SylluneCoinIcon()
                .frame(width: 22, height: 22)
            Text(balance.map { String($0) } ?? "Indisponible")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(balance == nil ? SylluneColor.inkMuted : SylluneColor.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(SylluneColor.surface, in: Capsule())
        .overlay(Capsule().stroke(SylluneColor.border, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(balance == nil ? "Solde de pièces indisponible" : "Solde de pièces")
        .accessibilityValue(balance.map { String($0) } ?? "Historique indisponible")
    }
}

private enum SylluneDesignArtwork {
    static let taviWelcome = load(named: "tavi-welcome")
    static let taviEncouragement = load(named: "tavi-encouragement")
    static let taviCelebration = load(named: "tavi-celebration")
    static let coin = load(named: "polygo-coin")

    private static func load(named name: String) -> Image {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Design") else {
            preconditionFailure("Required image resource Design/\(name).png is missing.")
        }

#if os(iOS)
        guard let image = UIImage(contentsOfFile: url.path) else {
            preconditionFailure("Unable to load required image resource Design/\(name).png.")
        }
        return Image(uiImage: image)
#elseif os(macOS)
        guard let image = NSImage(contentsOf: url) else {
            preconditionFailure("Unable to load required image resource Design/\(name).png.")
        }
        return Image(nsImage: image)
#endif
    }
}
