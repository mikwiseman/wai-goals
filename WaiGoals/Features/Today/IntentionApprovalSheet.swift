import SwiftUI

struct IntentionApprovalSheet: View {
    let goal: Goal
    let day: Date
    let calendar: Calendar

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var selectedCue: IntentionCue

    init(goal: Goal, date: Date = .now, calendar: Calendar = .current) {
        self.goal = goal
        self.calendar = calendar
        self.day = calendar.startOfDay(for: date)
        self._selectedCue = State(
            initialValue: goal.intention(on: date, calendar: calendar)?.cue ?? .defaultCue
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                cueGrid
                planPreview
                approveButton
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppBackground(tint: goal.accent.color))
            .navigationTitle("Intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.m) {
            GoalIcon(symbol: goal.symbol, tint: goal.accent.color, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var cueGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Cue")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: Theme.Spacing.s)],
                      spacing: Theme.Spacing.s) {
                ForEach(IntentionCue.allCases) { cue in
                    CueChoiceButton(cue: cue, isSelected: selectedCue == cue, tint: goal.accent.color) {
                        selectedCue = cue
                    }
                }
            }
        }
    }

    private var planPreview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(selectedCue.planLine(for: goal.title))
                .font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(cornerRadius: Theme.Radius.button)
    }

    private var approveButton: some View {
        Button {
            goal.approveIntention(on: day, cue: selectedCue, context: context, calendar: calendar)
            Haptics.success()
            dismiss()
        } label: {
            Label(goal.hasIntention(on: day, calendar: calendar) ? "Update intention" : "Approve intention",
                  systemImage: "checkmark.seal.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(goal.accent.color)
        .controlSize(.large)
    }
}

private struct CueChoiceButton: View {
    let cue: IntentionCue
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: cue.symbol)
                    .frame(width: 18)
                Text(cue.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Color.primary))
            .padding(.horizontal, Theme.Spacing.m)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.14) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(isSelected ? tint : Color.secondary.opacity(0.16), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
