import SwiftUI
import SwiftData

struct GoalsConnectionView: View {
    @Environment(\.modelContext) private var context
    @State private var connection = GoalsConnection.shared
    @State private var email = ""
    @State private var name = ""
    @State private var creatingAccount = false
    @State private var password = ""
    var body: some View {
        Form {
            Section {
                Text("Your goals. Your space.")
                    .font(.title3.weight(.semibold))
                Text(connection.isConnected
                     ? "Your goals and journal sync to your personal account."
                     : "Create an account or sign in here. You do not need to install WaiMoney.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if connection.isConnected {
                Section {
                    Label("Account connected", systemImage: "checkmark.circle")
                    if connection.aiAvailable == true {
                        LabeledContent("Assistant", value: "Connected")
                        Text("ChatGPT powers the conversation. ElevenLabs handles voice.").font(.footnote).foregroundStyle(.secondary)
                    } else if connection.aiAvailable == false {
                        Text("AI and voice are not connected for this account. Goals, journal editing and sync are available.").font(.footnote).foregroundStyle(.secondary)
                    }
                    if let date = connection.lastSyncedAt {
                        LabeledContent("Last synced", value: date.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        Text("Waiting for the first sync").foregroundStyle(.secondary)
                    }
                    Button("Sync now") { Task { await connection.sync(goals: context.allGoals(), journal: context.allJournalEntries()) } }
                    Button("Sign out", role: .destructive) { Task { await connection.disconnect() } }
                        .disabled(connection.busy)
                } footer: {
                    Text("Signing out removes this device’s synced copy from the server. Your goals stay on this device and remain linked to this account.")
                }
            } else {
                Section {
                    Picker("Account", selection: $creatingAccount) {
                        Text("Sign in").tag(false)
                        Text("Create account").tag(true)
                    }.pickerStyle(.segmented)
                    if creatingAccount {
                        TextField("Name", text: $name).textContentType(.name).textInputAutocapitalization(.words)
                    }
                    TextField("Email", text: $email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password).textContentType(creatingAccount ? .newPassword : .password)
                    Button {
                        Task {
                            await connection.connect(email: email, password: password, name: creatingAccount ? name : nil, goals: context.allGoals(), journal: context.allJournalEntries())
                            if connection.isConnected { password = "" }
                        }
                    } label: {
                        if connection.busy { ProgressView() } else { Text(creatingAccount ? "Create account" : "Sign in") }
                    }
                    .disabled(connection.busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || (creatingAccount && (password.count < 8 || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)))
                } header: { Text(creatingAccount ? "Create your account" : "Your account") } footer: {
                    Text("Money and Goals share this account. Use at least 8 characters for a new password. Your goals also work offline; your password is never saved.")
                }
            }
            if let status = connection.status {
                Section { Text(status).foregroundStyle(.secondary).accessibilityIdentifier("goals.connection.status") }
            }
        }
        .task { await connection.refreshStatus() }
        .navigationTitle("WaiGoals")
        .navigationBarTitleDisplayMode(.inline)
    }
}
