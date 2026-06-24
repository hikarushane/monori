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
                Section("閱讀") {
                    Stepper("字體大小：\(prefs.fontSize)", value: $prefs.fontSize, in: 14...32)
                }

                Section {
                    Button("清除書庫資料", role: .destructive) { confirmClearLibrary = true }
                        .accessibilityIdentifier("smoke.clearDataButton")
                    Button("登出 Patreon", role: .destructive) { confirmLogout = true }
                        .accessibilityIdentifier("smoke.logoutButton")
                } header: {
                    Text("資料")
                } footer: {
                    Text("「清除書庫資料」會刪除裝置上儲存的收藏、章節與書籤。「登出 Patreon」會結束內建瀏覽器中的 Patreon 連線。兩者互相獨立。")
                }

                Section("關於") {
                    LabeledContent("版本", value: MonoriCore.version)
                    Text("Monori 是一個純本機的閱讀介面，使用你自己的 Patreon 連線。僅在裝置上儲存章節標題、連結與書籤，不儲存文章內容。所有文章存取由 Patreon 控制。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .confirmationDialog("刪除所有收藏、章節與書籤？",
                                isPresented: $confirmClearLibrary, titleVisibility: .visible) {
                Button("清除書庫資料", role: .destructive) { env.clearLibraryData() }
            }
            .confirmationDialog("結束內建瀏覽器中的 Patreon 連線？",
                                isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("登出 Patreon", role: .destructive) {
                    Task { await env.logoutFromPatreon() }
                }
            }
        }
    }
}
