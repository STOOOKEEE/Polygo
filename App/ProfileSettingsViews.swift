import SwiftUI
import PolygoCore

public struct ProfileView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingName = false
    @State private var name = ""
    @State private var entries: [VocabularyEntry] = []

    public init() {}
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        profileIdentity
                        Spacer(minLength: 12)
                        editButton
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        profileIdentity
                        editButton
                    }
                }
                .padding(18).sylluneCard(radius: 20)
                stats
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mon objectif").font(.headline).foregroundStyle(SylluneColor.ink)
                    Text("\(model.snapshot.profile?.dailyMinutes ?? 10) minutes par jour").font(.body).foregroundStyle(SylluneColor.inkMuted)
                }
                .padding(18).sylluneCard()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Données et réglages").font(.headline).foregroundStyle(SylluneColor.ink)
                    NavigationLink(destination: SettingsView()) { Label("Réglages", systemImage: "gearshape") }
                    Text("Progression conservée sur cet appareil").font(.caption).foregroundStyle(SylluneColor.inkMuted)
                }
                .padding(18).sylluneCard()
            }
            .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }
        .background(SylluneColor.canvas)
        .navigationTitle("Profil")
        .sheet(isPresented: $editingName) {
            NavigationStack {
                Form { TextField("Prénom", text: $name) }
                    .navigationTitle("Mon prénom")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Annuler") { editingName = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { Task { if await model.updateProfile(displayName: name) { editingName = false } } } }
                    }
            }
            .presentationDetents([.medium])
        }
        .task { entries = await model.dictionaryEntries() }
    }

    private var initials: String {
        guard let name = model.snapshot.profile?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), let first = name.first else { return "S" }
        return String(first).uppercased()
    }

    private var stats: some View {
        let completed = model.snapshot.lessonProgress.values.filter { $0.completedAt != nil }.count
        let mastered = model.snapshot.reviewStates.values.filter { $0.repetition >= 2 && $0.lapseCount == 0 }.count
        let exercises = model.snapshot.lessonProgress.values.reduce(0) { $0 + $1.attemptCount }
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                stat("Leçons", value: "\(completed)", icon: "checkmark.circle")
                stat("Cartes", value: "\(mastered)", icon: "rectangle.stack")
                stat("Réponses", value: "\(exercises)", icon: "checklist")
                stat("Série", value: "\(model.streakDays) j", icon: "flame")
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                stat("Leçons", value: "\(completed)", icon: "checkmark.circle")
                stat("Cartes", value: "\(mastered)", icon: "rectangle.stack")
                stat("Réponses", value: "\(exercises)", icon: "checklist")
                stat("Série", value: "\(model.streakDays) j", icon: "flame")
            }
        }
    }

    private func stat(_ title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(SylluneColor.jade).accessibilityHidden(true)
            Text(value).font(.headline).foregroundStyle(SylluneColor.ink)
            Text(title)
                .font(.caption2)
                .foregroundStyle(SylluneColor.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .padding(.vertical, 12)
        .background(SylluneColor.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SylluneColor.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) : \(value)")
    }

    private var profileIdentity: some View {
        HStack(spacing: 14) {
            Circle().fill(SylluneColor.coral).frame(width: 58, height: 58)
                .overlay(Text(initials).font(.title2.weight(.semibold)).foregroundStyle(.white))
                .accessibilityLabel("Initiales : \(initials)")
            VStack(alignment: .leading, spacing: 4) {
                Text(model.greeting).font(.title2.weight(.semibold)).foregroundStyle(SylluneColor.ink)
                Text(model.snapshot.profile?.startingLevel == "beginner" ? "Débutant" : "Parcours en cours")
                    .font(.callout).foregroundStyle(SylluneColor.inkMuted)
            }
        }
    }

    private var editButton: some View {
        Button("Modifier") { name = model.snapshot.profile?.displayName ?? ""; editingName = true }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
    }
}

public struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var dailyMinutes = 10
    @State private var showPinyin = true
    @State private var autoPlay = false
    @State private var speed = 1.0
    @State private var appearance: AppearanceMode = .system
    @State private var reduceMotion = false
    @State private var reminderDays: Set<Int> = Set(1...7)
    @State private var savedMessage: String?
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("syllune.appearance") private var storedAppearance = AppearanceMode.system.rawValue
    @AppStorage("syllune.reduceMotion") private var storedReduceMotion = false

    public init() {}
    public var body: some View {
        Form {
            Section("Apprentissage") {
                Picker("Durée quotidienne", selection: $dailyMinutes) { Text("5 min").tag(5); Text("10 min").tag(10); Text("15 min").tag(15) }
                    .onChange(of: dailyMinutes) { _, value in Task { savedMessage = await model.updateDailyMinutes(value) ? "Objectif enregistré." : "Impossible d’enregistrer l’objectif." } }
                Toggle("Afficher le pinyin", isOn: $showPinyin).onChange(of: showPinyin) { _, _ in savePreferences() }
                Toggle("Lecture automatique", isOn: $autoPlay).onChange(of: autoPlay) { _, _ in savePreferences() }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Jours de rappel").font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 84), spacing: 8)], spacing: 8) {
                        ForEach(1...7, id: \.self) { day in
                            Button(dayLabel(day)) {
                                if reminderDays.contains(day) { reminderDays.remove(day) } else { reminderDays.insert(day) }
                                savePreferences()
                            }
                            .buttonStyle(DaySettingButtonStyle(selected: reminderDays.contains(day)))
                            .accessibilityLabel(dayName(day))
                            .accessibilityValue(reminderDays.contains(day) ? "sélectionné" : "non sélectionné")
                            .accessibilityAddTraits(reminderDays.contains(day) ? .isSelected : [])
                        }
                    }
                }
            }
            Section("Audio et oral") {
                Picker("Vitesse", selection: $speed) { Text("0,75×").tag(0.75); Text("1×").tag(1.0) }.onChange(of: speed) { _, _ in savePreferences() }
                Label("Le microphone sera demandé au premier exercice oral.", systemImage: "mic").font(.callout)
                Text("Les enregistrements restent locaux.").font(.caption).foregroundStyle(SylluneColor.inkMuted)
            }
            Section("Apparence") {
                Picker("Thème", selection: $appearance) { Text("Système").tag(AppearanceMode.system); Text("Clair").tag(AppearanceMode.light); Text("Sombre").tag(AppearanceMode.dark) }.onChange(of: appearance) { _, _ in savePreferences() }
                Toggle("Réduire les animations", isOn: $reduceMotion).onChange(of: reduceMotion) { _, _ in savePreferences() }
                if systemReduceMotion {
                    Text("La réduction des animations du système est active.")
                        .font(.caption)
                        .foregroundStyle(SylluneColor.inkMuted)
                }
            }
            Section("Hors ligne") {
                Label("Unité 1 · contenu embarqué", systemImage: "checkmark.circle.fill").foregroundStyle(SylluneColor.success)
                Text("Aucun téléchargement supplémentaire à gérer.").font(.caption).foregroundStyle(SylluneColor.inkMuted)
            }
            Section("Compte et données") {
                Label("Sur cet appareil", systemImage: "iphone").foregroundStyle(SylluneColor.ink)
                Text("La synchronisation iCloud sera proposée quand un service sera configuré.").font(.caption).foregroundStyle(SylluneColor.inkMuted)
            }
            Section("À propos") {
                LabeledContent("Version", value: "0.1")
                Text("Syllune — contenu original Polygo").font(.caption).foregroundStyle(SylluneColor.inkMuted)
            }
            if let savedMessage { Text(savedMessage).font(.caption).foregroundStyle(SylluneColor.success) }
        }
        .navigationTitle("Réglages")
        .scrollContentBackground(.hidden)
        .background(SylluneColor.canvas)
        .task { loadValues() }
    }

    private func loadValues() {
        guard let profile = model.snapshot.profile else { return }
        dailyMinutes = profile.dailyMinutes
        showPinyin = profile.preferences.showPinyin
        autoPlay = profile.preferences.autoPlayAudio
        speed = profile.preferences.audioSpeed
        appearance = profile.preferences.appearance
        reduceMotion = profile.preferences.reduceMotion
        reminderDays = profile.preferences.reminderDays
        storedAppearance = appearance.rawValue
        storedReduceMotion = reduceMotion
    }

    private func savePreferences() {
        storedAppearance = appearance.rawValue
        storedReduceMotion = reduceMotion
        let preferences = LearnerPreferences(interfaceLanguage: "fr", script: .simplified, preferredSpeechLocale: "zh-CN", audioSpeed: speed, showPinyin: showPinyin, autoPlayAudio: autoPlay, reminderDays: reminderDays, appearance: appearance, reduceMotion: reduceMotion)
        Task { savedMessage = await model.updatePreferences(preferences) ? "Préférence enregistrée." : "Impossible d’enregistrer la préférence." }
    }

    private func dayLabel(_ day: Int) -> String { ["L", "M", "M", "J", "V", "S", "D"][day - 1] }
    private func dayName(_ day: Int) -> String { ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"][day - 1] }
}

private struct DaySettingButtonStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(minWidth: 44, minHeight: 44)
            .background(selected ? SylluneColor.sun : SylluneColor.surfaceRaised, in: Circle())
            .foregroundStyle(selected ? SylluneColor.inkOnSun : SylluneColor.ink)
            .overlay(Circle().stroke(SylluneColor.border, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}
