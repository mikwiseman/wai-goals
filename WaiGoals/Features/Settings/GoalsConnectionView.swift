import SwiftUI
import SwiftData

struct GoalsConnectionView: View {
    @Environment(\.modelContext) private var context
    @State private var connection = GoalsConnection.shared
    @State private var email = ""
    @State private var password = ""
    var body: some View {
        Form {
            Section {
                Text("Your goals. Your space.")
                    .font(.title3.weight(.semibold))
                Text("Sign in with your personal WaiMoney account. Your goals, time and money stay connected. Access is reserved for the owner.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if connection.isConnected {
                Section {
                    Label("Connected to WaiMoney", systemImage: "checkmark.circle")
                    if let date = connection.lastSyncedAt {
                        LabeledContent("Last synced", value: date.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        Text("Waiting for the first sync").foregroundStyle(.secondary)
                    }
                    Button("Sync now") { Task { await connection.sync(goals: context.allGoals()) } }
                    Button("Sign out", role: .destructive) { Task { await connection.disconnect() } }
                        .disabled(connection.busy)
                } footer: {
                    Text("Dots also needs access to your WaiMoney connection. This screen confirms data sync, not whether Dots has been connected. Disconnect removes this device’s snapshot from WaiMoney.")
                }
            } else {
                Section {
                    TextField("Email", text: $email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password).textContentType(.password)
                    Button {
                        Task {
                            await connection.connect(email: email, password: password, goals: context.allGoals())
                            if connection.isConnected { password = "" }
                        }
                    } label: {
                        if connection.busy { ProgressView() } else { Text("Sign in") }
                    }
                    .disabled(connection.busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                } header: { Text("Sign in to WaiMoney") } footer: {
                    Text("After signing in, your goals also work offline. Your password is never saved.")
                }
            }
            if let status = connection.status {
                Section { Text(status).foregroundStyle(.secondary).accessibilityIdentifier("goals.connection.status") }
            }
        }
        .navigationTitle("WaiGoals")
        .navigationBarTitleDisplayMode(.inline)
    }
}
