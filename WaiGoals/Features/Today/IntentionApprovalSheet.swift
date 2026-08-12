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
    /// One-shot ripple ring expanding from the seal's point of impact.
    @State private var sealRippled = false

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
        // The pledge takes the hit: a barely-there dip sells the stamp's weight.
        .scaleEffect(approved && !reduceMotion ? 0.985 : 1)
        .overlay(alignment: .bottomTrailing) {
            if approved {
                seal
            }
        }
    }

    /// The seal lands like a real stamp: it arrives from above the surface
    /// (scale 1.8 → 1) with a firm spring, settling slightly tilted, while a
    /// tinted ring ripples out from the point of impact.
    private var seal: some View {
        ZStack {
            Circle()
                .stroke(goal.accent.color.opacity(sealRippled ? 0 : 0.5), lineWidth: 2)
                .frame(width: 54, height: 54)
                .scaleEffect(sealRippled ? 1.9 : 0.9)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(goal.accent.color.gradient)
                .shadow(color: goal.accent.color.opacity(0.5), radius: 10, y: 4)
                .rotationEffect(.degrees(reduceMotion ? 0 : -8))
        }
        .padding(Theme.Spacing.m)
        .transition(
            reduceMotion
                ? .opacity
                : .scale(scale: 1.8).combined(with: .opacity)
        )
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.5).delay(0.08)) {
                sealRippled = true
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
                withAnimation(WaiMotion.stamp) { approved = true }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(760))
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
