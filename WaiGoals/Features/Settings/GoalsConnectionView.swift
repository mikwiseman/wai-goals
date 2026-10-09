import SwiftUI
import SwiftData
import UIKit

struct GoalsConnectionView: View {
    @Environment(\.modelContext) private var context
    @State private var connection = GoalsConnection.shared
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @State private var code = ""
    @State private var mode = Mode.email
    @State private var migrating = false
    @State private var confirmingDelete = false
    private enum Mode { case email, code, password, create }
    var body: some View {
        Form {
            Section {
                Text("Your goals. Your space.").font(.title3.weight(.semibold))
                Text(connection.isConnected && !migrating
                     ? "Your goals and journal sync to your personal account."
                     : "Sign in or create your Goals account. It is separate from Money and Time.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if connection.isConnected && !migrating {
                Section {
                    Label("Account connected", systemImage:"checkmark.circle")
                    if connection.aiAvailable == true {
                        LabeledContent("Assistant",value:"Connected")
                    } else if connection.aiAvailable == false {
                        Text("AI and voice are not connected for this account. Goals, journal editing and sync are available.").font(.footnote).foregroundStyle(.secondary)
                    }
                    if let date=connection.lastSyncedAt {
                        LabeledContent("Last synced",value:date.formatted(date:.abbreviated,time:.shortened))
                    }
                    Button("Sync now") { Task { await connection.sync(goals:context.allGoals(),journal:context.allJournalEntries()) } }
                    Button("Sign out",role:.destructive) { Task { await connection.disconnect() } }.disabled(connection.busy)
                } footer: {
                    Text("Signing out removes this device’s synced copy from the server. Your goals stay on this device and remain linked to this account.")
                }
                if connection.isLegacyConnection {
                    Section {
                        Button("Move to a Goals account") { migrating=true;mode = .email }
                    } footer: {
                        Text("Your existing connection still works. You can move this device’s goals to an independent Goals account. AI and voice will need to be connected separately.")
                    }
                } else {
                    Section {
                        Text(connection.mcpURL).font(.caption).textSelection(.enabled)
                        Button("Copy server address") { UIPasteboard.general.string=connection.mcpURL }
                        Button("Create access key") { Task { await connection.createMCPAccess() } }.disabled(connection.busy)
                        if let token=connection.mcpToken {
                            Button("Copy new key") { UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic:token]],options:[.localOnly:true,.expirationDate:Date.now.addingTimeInterval(120)]) }
                            Text("The key is shown only during this visit. Copy it into your MCP client.").font(.footnote).foregroundStyle(.secondary)
                        }
                        ForEach(connection.mcpAccess) { access in
                            HStack {
                                Text(access.name)
                                Spacer()
                                Button("Revoke",role:.destructive) { Task { await connection.revokeMCPAccess(id:access.id) } }.disabled(connection.busy)
                            }
                        }
                    } header: { Text("MCP") } footer: { Text("An access key lets Dots read your synced goals and journal. Revoke it here at any time.") }
                    Section {
                        SecureField("Password, if you use one",text:$password).textContentType(.password)
                        Button("Delete Goals account",role:.destructive) { confirmingDelete=true }.disabled(connection.busy)
                    } footer: { Text("Account deletion removes server data and access keys. Your local goals remain. With email-code sign-in, sign in again before deleting.") }
                }
            } else {
                Section {
                    if mode == .create {
                        TextField("Name",text:$name).textContentType(.name).textInputAutocapitalization(.words)
                    }
                    TextField("Email",text:$email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().disabled(mode == .code)
                    if mode == .password || mode == .create {
                        SecureField("Password",text:$password).textContentType(mode == .create ? .newPassword : .password)
                    }
                    if mode == .code {
                        TextField("6-digit code",text:$code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                    }
                    Button {
                        Task {
                            if mode == .email {
                                if await connection.sendCode(email:email) { code="";mode = .code }
                            } else {
                                await connection.connect(email:email,password:password,name:mode == .create ? name : nil,code:mode == .code ? code : nil,goals:context.allGoals(),journal:context.allJournalEntries())
                                if connection.isConnected && !connection.isLegacyConnection { password="";code="";migrating=false;await connection.loadMCPAccess() }
                            }
                        }
                    } label: {
                        if connection.busy { ProgressView() } else { Text(mode == .email ? "Send code" : mode == .create ? "Create account" : "Sign in") }
                    }.disabled(connection.busy || !canSubmit)
                    if mode == .email {
                        Button("Use password instead") { mode = .password;connection.status=nil }
                    } else if mode == .code {
                        Button("Resend code") { Task { _ = await connection.sendCode(email:email) } }.disabled(connection.busy)
                        Button("Change email") { mode = .email;code="" }
                    } else {
                        Button("Use email code instead") { mode = .email;connection.status=nil }
                        Button(mode == .password ? "Create account" : "I already have an account") { mode = mode == .password ? .create : .password;connection.status=nil }
                    }
                    if migrating { Button("Keep existing connection") { migrating=false } }
                } header: { Text(mode == .create ? "Create your account" : "Your account") } footer: {
                    Text(mode == .code ? "Enter the code sent to your email. It expires in 10 minutes." : "Use a code sent to your email, or a password with at least 8 characters. Your Goals password is never saved on this device.")
                }
            }
            if let status=connection.status {
                Section { Text(status).foregroundStyle(.secondary).accessibilityIdentifier("goals.connection.status") }
            }
        }
        .task { await connection.refreshStatus();await connection.loadMCPAccess() }
        .onDisappear { connection.mcpToken=nil;password="";code="" }
        .confirmationDialog("Delete your Goals account and all server data?",isPresented:$confirmingDelete,titleVisibility:.visible) {
            Button("Delete account",role:.destructive) { Task { await connection.deleteAccount(password:password);password="" } }
            Button("Cancel",role:.cancel) {}
        }
        .navigationTitle("WaiGoals")
        .navigationBarTitleDisplayMode(.inline)
    }
    private var canSubmit:Bool {
        guard email.contains("@") else { return false }
        switch mode {
        case .email: return true
        case .code: return code.count == 6 && code.allSatisfy(\.isNumber)
        case .password: return !password.isEmpty
        case .create: return password.count >= 8 && !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
        }
    }
}
