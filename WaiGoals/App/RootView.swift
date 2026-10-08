import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage(AppStorageKey.appearance) private var appearanceRaw = Appearance.system.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var preferredDynamicTypeSize
    @State private var scheduler = NotificationScheduler()
    @State private var coordinator = NotificationCoordinator()
    @State private var connection = GoalsConnection.shared
    @State private var didBootstrap = false
    @State private var selection: AppTab = AppLaunch.initialTab

    var body: some View {
        Group {
            if connection.isConnected {
                mainTabs
            } else {
                NavigationStack { GoalsConnectionView() }
            }
        }
        .preferredColorScheme(Appearance(rawValue: appearanceRaw)?.colorScheme)
        .task { await connection.sync(goals: context.allGoals(), journal: context.allJournalEntries()) }
    }

    private var mainTabs: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "checklist", value: AppTab.today) {
                TodayView()
                    .environment(\.dynamicTypeSize, preferredDynamicTypeSize)
            }
            Tab("Разговор", systemImage: "bubble.left.and.text.bubble.right", value: AppTab.journal) {
                GoalsConversationView().environment(\.dynamicTypeSize, preferredDynamicTypeSize)
            }
            Tab("Goals", systemImage: "square.stack.3d.up.fill", value: AppTab.goals) {
                GoalsListView()
                    .environment(\.dynamicTypeSize, preferredDynamicTypeSize)
            }
            Tab("Stats", systemImage: "chart.bar.xaxis", value: AppTab.stats) {
                StatsView()
                    .environment(\.dynamicTypeSize, preferredDynamicTypeSize)
            }
        }
        // Keep the native tab bar usable at accessibility sizes while each
        // destination still receives the user's full Dynamic Type preference.
        .dynamicTypeSize(.small ... .large)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.accentColor)
        .environment(scheduler)
        .environment(coordinator)
        .preferredColorScheme(Appearance(rawValue: appearanceRaw)?.colorScheme)
        .onChange(of: coordinator.routeGoalID) { _, id in
            if id != nil { selection = .today }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goalsDidSave)) { _ in
            Task { await GoalsConnection.shared.sync(goals: context.allGoals(), journal: context.allJournalEntries()) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await GoalsConnection.shared.sync(goals: context.allGoals(), journal: context.allJournalEntries()) } }
        }
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            coordinator.register()
            if AppLaunch.seedSampleData {
                SampleData.seedIfNeeded(context)
            }
            AchievementUnlockStore.reconcile(goals: context.allGoals(), context: context)
            await scheduler.refreshAuthorizationStatus()
            scheduler.reschedule(for: context.allGoals())
            await GoalsConnection.shared.sync(goals: context.allGoals(), journal: context.allJournalEntries())
        }
    }
}
