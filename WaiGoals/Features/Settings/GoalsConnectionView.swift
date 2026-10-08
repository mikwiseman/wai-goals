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
                Text("Let your goals meet your time and money.")
                    .font(.title3.weight(.semibold))
                Text("Connect your WaiMoney account to make your goals available to your personal agent, including Dots. Your phone sends an updated snapshot when you open WaiGoals or change a goal.")
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
                    Button("Disconnect", role: .destructive) { Task { await connection.disconnect() } }
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
                        if connection.busy { ProgressView() } else { Text("Connect my goals") }
                    }
                    .disabled(connection.busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                } header: { Text("Sign in to WaiMoney") } footer: {
                    Text("Optional. Shares goal names, your reasons, small steps, schedules and the last 90 days of intentions and completions with your WaiMoney account. Your password is never saved. Goals still work offline.")
                }
            }
            if let status = connection.status {
                Section { Text(status).foregroundStyle(.secondary).accessibilityIdentifier("goals.connection.status") }
            }
        }
        .navigationTitle("Connect your goals")
        .navigationBarTitleDisplayMode(.inline)
    }
}
