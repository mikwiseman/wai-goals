import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(NotificationScheduler.self) private var scheduler
    @AppStorage(AppStorageKey.appearance) private var appearanceRaw = Appearance.system.rawValue

    @State private var showingEraseConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceRaw) {
                        ForEach(Appearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notifications") {
                    notificationsRow
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("About")
                } footer: {
                    Text("WaiGoals keeps everything on your device. No account, no cloud, no tracking — just your goals.")
                }

                #if DEBUG
                Section("Developer") {
                    Button { loadSampleData() } label: {
                        Label("Load sample data", systemImage: "wand.and.stars")
                    }
                    Button(role: .destructive) { showingEraseConfirm = true } label: {
                        Label("Erase all data", systemImage: "trash")
                    }
                }
                #endif
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await scheduler.refreshAuthorizationStatus() }
            .confirmationDialog("Erase all goals and history?", isPresented: $showingEraseConfirm, titleVisibility: .visible) {
                Button("Erase Everything", role: .destructive) { eraseAll() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var notificationsRow: some View {
        switch scheduler.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            LabeledContent("Reminders") {
                Label("On", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            }
        case .denied:
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Reminders are turned off for WaiGoals.")
                    .font(.subheadline)
                Button("Open Settings") { openSystemSettings() }
            }
        default:
            Button {
                Task { await scheduler.requestAuthorizationIfNeeded() }
            } label: {
                Label("Enable reminders", systemImage: "bell.badge")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func loadSampleData() {
        SampleData.reseed(context)
        scheduler.reschedule(for: context.allGoals())
    }

    private func eraseAll() {
        SampleData.wipe(context)
        scheduler.reschedule(for: [])
    }
}
