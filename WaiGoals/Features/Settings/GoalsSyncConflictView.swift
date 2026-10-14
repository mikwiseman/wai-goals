import SwiftUI
import SwiftData

struct GoalsSyncConflictView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var connection = GoalsConnection.shared
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("The same information changed on this device and on the server. Choose which conflicting changes to keep. Other changes will be combined.")
                }
                if let conflict=connection.syncConflict {
                    ForEach(conflict.entries) { entry in
                        Section(entry.title) {
                            VStack(alignment:.leading,spacing:8) {
                                Text("This device").font(.headline)
                                Text(summary(entry.local,fields:entry.fields)).textSelection(.enabled)
                                Text("Server").font(.headline).padding(.top,8)
                                Text(summary(entry.remote,fields:entry.fields)).textSelection(.enabled)
                            }
                        }
                    }
                    Section {
                        Button("Keep this device’s conflicting changes") { resolve(true) }
                        Button("Keep the server’s conflicting changes") { resolve(false) }
                    }.disabled(connection.busy)
                }
                if let status=connection.status { Section { Text(status).foregroundStyle(.secondary) } }
            }
            .navigationTitle("Review sync changes")
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Decide later") { dismiss() } } }
            .onChange(of:connection.syncConflict == nil) { _, done in if done { dismiss() } }
        }
    }
    private func resolve(_ local: Bool) { Task { await connection.resolveSyncConflict(context:context,preferLocal:local) } }
    private func summary(_ record: GoalsSyncRecord?, fields:[String]) -> String {
        guard let record else { return "Deleted" }
        let selected=fields.contains("record") || fields.contains("goalId") ? ["title","text","smallStep","personalWhy","day","periodKey","isArchived"] : fields
        let labels=["title":"Title","text":"Text","smallStep":"Next step","personalWhy":"Why","day":"Day","periodKey":"Day","isArchived":"Archived","scheduleTypeRaw":"Schedule","weeklyTarget":"Times per week","updatedAt":"Updated"]
        return selected.compactMap { key in record[key].map { (labels[key] ?? key) + ": " + $0.text } }.joined(separator:"\n")
    }
}
