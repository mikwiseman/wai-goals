import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage(AppStorageKey.appearance) private var appearanceRaw = Appearance.system.rawValue
    @Environment(\.modelContext) private var context
    @State private var scheduler = NotificationScheduler()
    @State private var coordinator = NotificationCoordinator()
    @State private var didBootstrap = false
    @State private var selection: AppTab = AppLaunch.initialTab

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "target", value: AppTab.today) {
                TodayView()
            }
            Tab("Goals", systemImage: "flag.fill", value: AppTab.goals) {
                GoalsListView()
            }
            Tab("Stats", systemImage: "chart.bar.fill", value: AppTab.stats) {
                StatsView()
            }
        }
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
            await scheduler.refreshAuthorizationStatus()
            scheduler.reschedule(for: context.allGoals())
        }
    }
}
