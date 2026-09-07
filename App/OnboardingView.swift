import SwiftUI
import PolygoCore

public struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("syllune.onboarding.step") private var storedStep = 0
    @AppStorage("syllune.onboarding.name") private var storedName = ""
    @AppStorage("syllune.onboarding.level") private var storedLevel = "beginner"
    @AppStorage("syllune.onboarding.minutes") private var storedMinutes = 10
    @AppStorage("syllune.onboarding.days") private var storedDays = "1,2,3,4,5,6,7"
    @State private var step: Int
    @State private var name: String
    @State private var level: String
    @State private var minutes: Int
    @State private var days: Set<Int>
    @State private var showingAbout = false

    public init() {
        let defaults = UserDefaults.standard
        _step = State(initialValue: min(3, max(0, defaults.integer(forKey: "syllune.onboarding.step"))))
        _name = State(initialValue: defaults.string(forKey: "syllune.onboarding.name") ?? "")
        _level = State(initialValue: defaults.string(forKey: "syllune.onboarding.level") ?? "beginner")
        _minutes = State(initialValue: defaults.object(forKey: "syllune.onboarding.minutes") as? Int ?? 10)
        let rawDays = defaults.string(forKey: "syllune.onboarding.days") ?? "1,2,3,4,5,6,7"
        _days = State(initialValue: Set(rawDays.split(separator: ",").compactMap { Int($0) }))
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step > 0 {
                    Button("Retour") { move(to: step - 1) }
                        .buttonStyle(.borderless)
                }
                Spacer()
                Text("\(step + 1) sur 4")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SylluneColor.inkMuted)
                    .accessibilityLabel("Étape \(step + 1) sur 4")
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            ProgressView(value: Double(step + 1), total: 4)
                .tint(SylluneColor.jade)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch step {
                    case 0: welcomeStep
                    case 1: startingPointStep
                    case 2: rhythmStep
                    default: readyStep
                    }
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
        }
        .background(SylluneColor.canvas.ignoresSafeArea())
        .sheet(isPresented: $showingAbout) { AboutOnboardingView() }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            SylluneLogoMark(size: 72)
            VStack(alignment: .leading, spacing: 12) {
                Text("Bienvenue dans Syllune")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(SylluneColor.ink)
                Text("Le mandarin, une syllabe à la fois.")
                    .font(.title3)
                    .foregroundStyle(SylluneColor.jadeDeep)
                Text("Écoute un mot, dis-le, puis trace-le. Tes cours et tes progrès restent sur cet appareil.")
                    .font(.body)
                    .foregroundStyle(SylluneColor.inkMuted)
            }
            Button("Commencer") { move(to: 1) }
                .buttonStyle(SyllunePrimaryButtonStyle())
            Button("En savoir plus") { showingAbout = true }
                .buttonStyle(.borderless)
                .foregroundStyle(SylluneColor.jadeDeep)
        }
    }

    private var startingPointStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Ton point de départ", subtitle: "Tu pourras modifier ce choix dans ton profil.")
            TextField("Comment t’appeler ? (facultatif)", text: $name)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .onChange(of: name) { _, _ in saveDraft() }
            VStack(alignment: .leading, spacing: 10) {
                Text("Je me situe ici")
                    .font(.headline)
                levelButton("Je commence", value: "beginner", detail: "Je découvre le mandarin")
                levelButton("Je connais le pinyin", value: "pinyin", detail: "Je lis les sons et les tons")
                levelButton("Je lis déjà quelques phrases", value: "sentences", detail: "Je veux consolider les bases")
            }
            Button("Continuer") { move(to: 2) }
                .buttonStyle(SyllunePrimaryButtonStyle())
        }
    }

    private var rhythmStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Choisis ton rythme", subtitle: "Une petite session régulière aide à retenir les mots.")
            VStack(alignment: .leading, spacing: 12) {
                Text("Durée quotidienne")
                    .font(.headline)
                Picker("Durée quotidienne", selection: $minutes) {
                    Text("5 min").tag(5)
                    Text("10 min").tag(10)
                    Text("15 min").tag(15)
                }
                .pickerStyle(.segmented)
                .onChange(of: minutes) { _, _ in saveDraft() }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Jours de rappel")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 92), spacing: 8)], spacing: 8) {
                    ForEach(1...7, id: \.self) { day in
                        Button(dayLabel(day)) {
                            if days.contains(day) { days.remove(day) } else { days.insert(day) }
                            saveDraft()
                        }
                        .buttonStyle(DayButtonStyle(selected: days.contains(day)))
                        .accessibilityLabel(dayName(day))
                        .accessibilityValue(days.contains(day) ? "sélectionné" : "non sélectionné")
                        .accessibilityAddTraits(days.contains(day) ? .isSelected : [])
                    }
                }
            }
            Button("Continuer") { move(to: 3) }
                .buttonStyle(SyllunePrimaryButtonStyle())
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Tout est prêt", subtitle: "Voici ton premier parcours, disponible hors ligne.")
            VStack(alignment: .leading, spacing: 12) {
                Label(levelLabel, systemImage: "flag")
                Label("\(minutes) minutes par jour", systemImage: "clock")
                Label("\(days.count) jours de rappel", systemImage: "calendar")
            }
            .foregroundStyle(SylluneColor.inkMuted)
            .padding(18)
            .sylluneCard()
            Button("Ouvrir ma première leçon") {
                Task {
                    guard await model.completeOnboarding(
                        displayName: name,
                        level: level,
                        minutes: minutes,
                        reminderDays: days
                    ) else { return }
                    guard let first = model.nextLessonID ?? model.orderedLessonIDs.first else { return }
                    // Keep the destination as an identified lesson route. The
                    // compact shell can select its tab while the lesson route
                    // is handed to the navigation layer for the initial push.
                    if await model.startLesson(first) {
                        model.persistRoute(.lesson(first))
                    }
                }
            }
            .buttonStyle(SyllunePrimaryButtonStyle())
        }
    }

    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.largeTitle.weight(.semibold)).foregroundStyle(SylluneColor.ink)
            Text(subtitle).font(.body).foregroundStyle(SylluneColor.inkMuted)
        }
    }

    private func levelButton(_ title: String, value: String, detail: String) -> some View {
        Button {
            level = value; saveDraft()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: level == value ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(level == value ? SylluneColor.jade : SylluneColor.inkMuted)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.body.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(SylluneColor.inkMuted)
                }
                Spacer()
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sylluneCard(radius: 12)
        .accessibilityLabel(title)
        .accessibilityValue(level == value ? "sélectionné" : "non sélectionné")
        .accessibilityAddTraits(level == value ? .isSelected : [])
    }

    private var levelLabel: String {
        switch level { case "pinyin": return "Je connais le pinyin"; case "sentences": return "Je lis déjà quelques phrases"; default: return "Je commence" }
    }

    private func dayLabel(_ day: Int) -> String {
        ["L", "M", "M", "J", "V", "S", "D"][day - 1]
    }

    private func dayName(_ day: Int) -> String {
        ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"][day - 1]
    }

    private func move(to newStep: Int) {
        step = min(3, max(0, newStep)); saveDraft()
    }

    private func saveDraft() {
        storedStep = step; storedName = name; storedLevel = level; storedMinutes = minutes
        storedDays = days.sorted().map(String.init).joined(separator: ",")
    }
}

private struct AboutOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Audio et confidentialité").font(.title.bold())
                    Text("Les leçons de l’unité 1 sont embarquées. Les enregistrements et les tracés restent locaux. Le microphone et la transcription ne sont demandés qu’au premier exercice concerné.")
                        .font(.body)
                }
                .padding(24)
            }
            .navigationTitle("À propos")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
        }
    }
}

public struct SyllunePrimaryButtonStyle: ButtonStyle {
    @Environment(\.sylluneReduceMotion) private var reduceMotion

    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(SylluneColor.jadeButton.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
            .transaction { transaction in
                if reduceMotion {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
    }
}

private struct DayButtonStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(minWidth: 40, minHeight: 44)
            .foregroundStyle(selected ? SylluneColor.inkOnSun : SylluneColor.inkMuted)
            .background(selected ? SylluneColor.sun : SylluneColor.surface, in: Circle())
            .overlay(Circle().stroke(SylluneColor.border, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
