import SwiftUI

/// Curated SF Symbols suitable for goals/habits.
enum GoalSymbols {
    static let all: [String] = [
        "target", "flag.fill", "star.fill", "heart.fill", "bolt.fill", "flame.fill",
        "drop.fill", "leaf.fill", "moon.stars.fill", "sun.max.fill", "bed.double.fill",
        "alarm.fill", "timer", "calendar", "checkmark.seal.fill", "hand.thumbsup.fill",
        "figure.run", "figure.walk", "figure.strengthtraining.traditional",
        "figure.mind.and.body", "figure.yoga", "dumbbell.fill", "sportscourt.fill", "bicycle",
        "book.fill", "pencil", "graduationcap.fill", "brain.head.profile",
        "text.book.closed.fill", "newspaper.fill",
        "paperplane.fill", "bubble.left.fill", "envelope.fill", "phone.fill", "message.fill",
        "laptopcomputer", "keyboard", "chart.bar.fill", "briefcase.fill",
        "paintbrush.fill", "camera.fill", "music.note", "guitars.fill", "theatermasks.fill",
        "fork.knife", "cup.and.saucer.fill", "carrot.fill", "waterbottle.fill",
        "pills.fill", "cross.case.fill",
        "dollarsign.circle.fill", "cart.fill", "creditcard.fill", "house.fill",
        "airplane", "car.fill", "globe.americas.fill", "mountain.2.fill", "tent.fill",
        "pawprint.fill", "hands.sparkles.fill", "sparkles", "trophy.fill", "iphone.slash"
    ]
}

struct SymbolPicker: View {
    @Binding var selection: String
    var tint: Color = .accentColor

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 60), spacing: 12)]

    private var filtered: [String] {
        query.isEmpty ? GoalSymbols.all
            : GoalSymbols.all.filter { $0.contains(query.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(tint: tint)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
                        ForEach(filtered, id: \.self) { name in
                            SymbolCell(name: name, isSelected: selection == name, tint: tint) {
                                selection = name
                                dismiss()
                            }
                        }
                    }
                    .padding(Theme.Spacing.l)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Choose an Icon")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search icons")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct SymbolCell: View {
    let name: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.title2)
                .foregroundStyle(isSelected ? tint : Color.primary)
                .frame(width: 60, height: 60)
                .background(background)
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? AnyShapeStyle(tint.opacity(0.18)) : AnyShapeStyle(.thinMaterial))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? tint.opacity(0.55) : .white.opacity(0.45), lineWidth: 0.75)
            }
    }
}
