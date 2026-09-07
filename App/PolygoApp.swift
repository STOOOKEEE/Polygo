import SwiftUI
import Foundation
import PolygoCore

@main
public struct PolygoApp: App {
    @StateObject private var model: AppModel

    public init() {
        _model = StateObject(wrappedValue: AppModel(dependencies: AppDependencies.live()))
    }

    public var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(SylluneColor.jade)
        }
        #if os(macOS)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Réglages") { model.persistRoute(.settings) }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Syllune") {
                Button("Rechercher dans le dictionnaire") {
                    model.persistRoute(.dictionary(""))
                    // The route is installed first; the next run-loop turn
                    // lets DictionaryView receive the focus request.
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .sylluneFocusDictionarySearch, object: nil)
                    }
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Lire ou mettre en pause l’audio") {
                    SylluneAudioCommandCenter.shared.toggle()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Arrêter l’audio ou fermer") {
                    SylluneAudioCommandCenter.shared.stop()
                    model.dependencies.audio.stopPlayback()
                    NotificationCenter.default.post(name: .sylluneEscape, object: nil)
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        #endif
    }
}
