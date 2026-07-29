import SwiftUI

struct IntentionApprovalSheet: View {
    let goal: Goal
    let day: Date
    let calendar: Calendar

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    init(goal: Goal, date: Date = .now, calendar: Calendar = .current) {
        self.goal = goal
        self.calendar = calendar
        self.day = calendar.startOfDay(for: date)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                header
                pledgeCard
                approveButton
            }
            .padding(Theme.Spacing.xl)
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
            GoalIcon(symbol: goal.symbol, accent: goal.accent, size: 52)
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

    private var pledgeCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Today’s deliberate step")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(Intention.pledgeText)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(cornerRadius: Theme.Radius.button)
    }

    private var approveButton: some View {
        Button {
            goal.approveIntention(on: day, context: context, calendar: calendar)
            Haptics.success()
            dismiss()
        } label: {
            Label("Approve", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .waiGlassButton(prominent: true)
        .tint(goal.accent.color)
        .controlSize(.large)
    }
}
