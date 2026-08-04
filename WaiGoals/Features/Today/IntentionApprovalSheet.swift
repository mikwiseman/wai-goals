import SwiftUI

struct IntentionApprovalSheet: View {
    let goal: Goal
    let day: Date
    let calendar: Calendar

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drives the seal "stamp" that lands on the pledge right after approval,
    /// just before the sheet dismisses itself.
    @State private var approved = false

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
        .overlay(alignment: .bottomTrailing) {
            if approved {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(goal.accent.color.gradient)
                    .shadow(color: goal.accent.color.opacity(0.5), radius: 10, y: 4)
                    .padding(Theme.Spacing.m)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
    }

    private var approveButton: some View {
        Button {
            guard !approved else { return }
            goal.approveIntention(on: day, context: context, calendar: calendar)
            Haptics.success()
            if reduceMotion {
                dismiss()
            } else {
                withAnimation(WaiMotion.pop) { approved = true }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(640))
                    dismiss()
                }
            }
        } label: {
            Label("Approve", systemImage: approved ? "checkmark.seal.fill" : "checkmark.seal")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .symbolEffect(.bounce, options: .nonRepeating, value: approved)
        }
        .waiGlassButton(prominent: true)
        .tint(goal.accent.color)
        .controlSize(.large)
        .disabled(approved)
    }
}
