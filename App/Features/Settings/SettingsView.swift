import SwiftUI
import MonoriCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var confirmClearLibrary = false
    @State private var confirmLogout = false

    var body: some View {
        @Bindable var prefs = env.prefs
        NavigationStack {
            Form {
                Section("Reading") {
                    Stepper("Font size: \(prefs.fontSize)", value: $prefs.fontSize, in: 14...32)
                }

                Section {
                    Button("Clear Library Data", role: .destructive) { confirmClearLibrary = true }
                        .accessibilityIdentifier("smoke.clearDataButton")
                    Button("Logout from Patreon", role: .destructive) { confirmLogout = true }
                        .accessibilityIdentifier("smoke.logoutButton")
                } header: {
                    Text("Data")
                } footer: {
                    Text("Clear Library Data deletes collections, chapters, and bookmarks stored on this device. Logout from Patreon ends the website session in the built-in browser. The two are independent.")
                }

                Section("About") {
                    LabeledContent("Version", value: MonoriCore.version)
                    Text("Chapterly is a local-only reading shell for your own Patreon session. It stores chapter titles, links, and bookmarks on this device — never post content. Patreon controls all access to posts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all collections, chapters, and bookmarks?",
                                isPresented: $confirmClearLibrary, titleVisibility: .visible) {
                Button("Clear Library Data", role: .destructive) { env.clearLibraryData() }
            }
            .confirmationDialog("End your Patreon session in the built-in browser?",
                                isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Logout from Patreon", role: .destructive) {
                    Task { await env.logoutFromPatreon() }
                }
            }
        }
    }
}
