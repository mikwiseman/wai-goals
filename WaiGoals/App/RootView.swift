import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage(AppStorageKey.appearance) private var appearanceRaw = Appearance.system.rawValue
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var preferredDynamicTypeSize
    @State private var scheduler = NotificationScheduler()
    @State private var coordinator = NotificationCoordinator()
    @State private var didBootstrap = false
    @State private var selection: AppTab = AppLaunch.initialTab

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "target", value: AppTab.today) {
                TodayView()
                    .environment(\.dynamicTypeSize, preferredDynamicTypeSize)
            }
            Tab("Goals", systemImage: "flag.fill", value: AppTab.goals) {
                GoalsListView()
                    .environment(\.dynamicTypeSize, preferredDynamicTypeSize)
            }
            Tab("Stats", systemImage: "chart.bar.fill", value: AppTab.stats) {
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
        }
    }
}
