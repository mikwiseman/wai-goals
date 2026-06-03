import SwiftUI
import SwiftData

@main
struct WaiGoalsApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Goal.self, Completion.self)
        } catch {
            // Persistence is foundational; surface the failure loudly rather
            // than silently degrading to a broken state.
            fatalError("Failed to create the SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
