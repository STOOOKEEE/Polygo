import SwiftUI
import PolygoCore

public struct ReviewCardsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var due: [ReviewState] = []
    @State private var selected: ReviewState?
    @State private var revealed = false
    @State private var message: String?

    public init() {}
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Cartes").font(.largeTitle.weight(.semibold)).foregroundStyle(SylluneColor.ink)
                        Text("\(due.count) carte\(due.count == 1 ? "" : "s") due\(due.count == 1 ? "" : "s")")
                            .font(.body).foregroundStyle(SylluneColor.inkMuted)
                    }
                    Spacer()
                    if !due.isEmpty { ProgressRing(value: selected == nil ? 0 : 1 / Double(max(1, due.count))).frame(width: 48, height: 48) }
                }
                if let message { Text(message).font(.callout).foregroundStyle(SylluneColor.inkMuted).padding(12).sylluneCard(radius: 12) }
                if let selected {
                    reviewCard(selected)
                } else if due.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Rien à revoir pour le moment", systemImage: "checkmark.circle.fill").font(.title3.weight(.semibold)).foregroundStyle(SylluneColor.success)
                        Text("Les cartes ajoutées pendant tes leçons apparaîtront ici à leur échéance.").font(.body).foregroundStyle(SylluneColor.inkMuted)
                        NavigationLink(destination: LearningPathView()) { Text("Retour au parcours") }.buttonStyle(SyllunePrimaryButtonStyle())
                    }
                    .padding(20).sylluneCard(radius: 24)
                } else {
                    Button("Commencer") { selected = due.first; revealed = false }
                        .buttonStyle(SyllunePrimaryButtonStyle())
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(SylluneColor.canvas)
        .navigationTitle("Cartes")
        .task {
            for lessonID in model.orderedLessonIDs { _ = await model.loadLesson(lessonID) }
            refresh()
        }
    }

    @ViewBuilder private func reviewCard(_ state: ReviewState) -> some View {
        if let card = model.reviewCard(for: state.cardID) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Carte \(due.firstIndex(where: { $0.cardID == state.cardID }).map { $0 + 1 } ?? 1) / \(due.count)")
                        .font(.caption.weight(.semibold)).foregroundStyle(SylluneColor.inkMuted)
                    Spacer()
                    Menu {
                        Button("Suspendre cette carte") { Task { if await model.suspendCard(state.cardID, suspended: true) { refresh() } } }
                    } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                    .accessibilityLabel("Actions de la carte")
                }
                VStack(spacing: 12) {
                    ChineseSelectableText(display(card.front), font: .system(size: 52, weight: .semibold, design: .rounded)).foregroundStyle(SylluneColor.ink).frame(maxWidth: .infinity, minHeight: 150)
                    if revealed {
                        Divider()
                        ChineseSelectableText(display(card.back), font: .title3).foregroundStyle(SylluneColor.jadeDeep).frame(maxWidth: .infinity, alignment: .leading)
                        if let text = card.back.text?.resolve(preferred: ["fr", "en"]) { Text(text).font(.body).foregroundStyle(SylluneColor.inkMuted).frame(maxWidth: .infinity, alignment: .leading) }
                    } else {
                        Button("Révéler") { revealed = true }.buttonStyle(.borderedProminent).tint(SylluneColor.jade)
                    }
                }
                .padding(20).sylluneCard(radius: 18)
                if revealed {
                    Text("Comment était cette carte ?").font(.headline).foregroundStyle(SylluneColor.ink)
                    HStack(spacing: 8) {
                        reviewButton("À refaire", .again, SylluneColor.error)
                        reviewButton("Difficile", .hard, SylluneColor.coral)
                        reviewButton("Bien", .good, SylluneColor.success)
                        reviewButton("Facile", .easy, SylluneColor.jade)
                    }
                }
            }
        } else {
            Text("Le contenu de cette carte n’est plus disponible.").font(.body).foregroundStyle(SylluneColor.inkMuted)
        }
    }

    private func reviewButton(_ title: String, _ rating: ReviewRating, _ tint: Color) -> some View {
        Button(title) {
            guard let current = selected else { return }
            Task {
                if await model.reviewCard(current.cardID, rating: rating) {
                    due.removeAll { $0.cardID == current.cardID }
                    selected = due.first
                    revealed = false
                    message = "Réponse enregistrée. Prochaine échéance : \(dateText(model.snapshot.reviewStates[current.cardID]?.dueAt))"
                } else {
                    message = "La réponse n’a pas été enregistrée. Réessaie."
                }
            }
        }
        .buttonStyle(.borderedProminent).tint(tint)
        .accessibilityLabel("\(title), planifier la prochaine révision")
    }

    private func refresh() {
        due = model.snapshot.dueCards(at: model.dependencies.clock.now())
        if let selected, !due.contains(where: { $0.cardID == selected.cardID }) { self.selected = due.first; revealed = false }
    }

    private func display(_ side: CardSide) -> String {
        side.hanzi ?? side.pinyin ?? side.text?.resolve(preferred: ["fr", "en"]) ?? "—"
    }

    private func dateText(_ date: Date?) -> String {
        guard let date else { return "bientôt" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
