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
    @State private var workspaceShown = false
    @State private var selection: AppTab = AppLaunch.initialTab

    var body: some View {
        Group {
            if connection.isConnected { conversation }
            else { NavigationStack { GoalsConnectionView() } }
        }
        .preferredColorScheme(Appearance(rawValue: appearanceRaw)?.colorScheme)
        .task(id: connection.isConnected) {
            await connection.refreshStatus()
            await connection.sync(goals: context.allGoals(), journal: context.allJournalEntries())
        }
    }

    private var conversation: some View {
        GoalsConversationView(onOpenWorkspace: { workspaceShown = true })
            .environment(\.dynamicTypeSize, preferredDynamicTypeSize)
            .sheet(isPresented: $workspaceShown) {
                workspace.safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Text("Цели").font(.headline)
                        Spacer()
                        Button("К чату") { workspaceShown = false }.frame(minHeight: 44)
                    }.padding(.horizontal, 20).background(Color(uiColor: .systemBackground))
                }.presentationDetents([.large])
            }
            .environment(scheduler)
            .environment(coordinator)
            .onChange(of: coordinator.routeGoalID) { _, id in
                if id != nil { selection = .today; workspaceShown = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: .goalsDidSave)) { _ in synchronize() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { synchronize() } }
            .task {
                guard !didBootstrap else { return }
                didBootstrap = true
                coordinator.register()
                if AppLaunch.seedSampleData { SampleData.seedIfNeeded(context) }
                AchievementUnlockStore.reconcile(goals: context.allGoals(), context: context)
                await scheduler.refreshAuthorizationStatus()
                scheduler.reschedule(for: context.allGoals())
                synchronize()
            }
    }

    private var workspace: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "checklist", value: AppTab.today) {
                TodayView().environment(\.dynamicTypeSize, preferredDynamicTypeSize)
            }
            Tab("Goals", systemImage: "square.stack.3d.up.fill", value: AppTab.goals) {
                GoalsListView().environment(\.dynamicTypeSize, preferredDynamicTypeSize)
            }
            Tab("Stats", systemImage: "chart.bar.xaxis", value: AppTab.stats) {
                StatsView().environment(\.dynamicTypeSize, preferredDynamicTypeSize)
            }
        }
        .dynamicTypeSize(.small ... .large)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.accentColor)
        .environment(scheduler)
        .environment(coordinator)
        .preferredColorScheme(Appearance(rawValue: appearanceRaw)?.colorScheme)
        .onAppear { if selection == .journal { selection = .today } }
    }

    private func synchronize() {
        Task { await connection.sync(goals: context.allGoals(), journal: context.allJournalEntries()) }
    }
}
