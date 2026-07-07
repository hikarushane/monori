import SwiftUI
import MonoriCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var confirmClearLibrary = false
    @State private var confirmLogout = false

    private struct LogExport: Identifiable {
        let id = UUID()
        let url: URL
    }
    @State private var logExport: LogExport?
    @State private var showNoLogsAlert = false

    var body: some View {
        @Bindable var prefs = env.prefs
        NavigationStack {
            Form {
                Section("外觀") {
                    Picker("主題", selection: Binding(
                        get: { env.appPrefs.appearance },
                        set: { env.appPrefs.appearance = $0 }
                    )) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("閱讀") {
                    Stepper("字體大小：\(prefs.fontSize)", value: $prefs.fontSize, in: 14...32)
                }

                Section {
                    Button("清除書庫資料", role: .destructive) { confirmClearLibrary = true }
                        .accessibilityIdentifier("smoke.clearDataButton")
                    Button("清除瀏覽器資料", role: .destructive) { confirmLogout = true }
                        .accessibilityIdentifier("smoke.logoutButton")
                } header: {
                    Text("資料")
                } footer: {
                    Text("「清除書庫資料」會刪除裝置上儲存的收藏、章節與書籤。「清除瀏覽器資料」會清除內建瀏覽器的所有 cookie 與登入狀態，等同登出所有來源。兩者互相獨立。")
                }

                Section {
                    Button("匯出診斷記錄") {
                        if let text = DiagnosticLog.shared.exportText() {
                            let url = FileManager.default.temporaryDirectory
                                .appendingPathComponent("monori-diagnostic-log.txt")
                            try? text.write(to: url, atomically: true, encoding: .utf8)
                            logExport = LogExport(url: url)
                        } else {
                            showNoLogsAlert = true
                        }
                    }
                    .accessibilityIdentifier("smoke.exportLogsButton")
                } header: {
                    Text("診斷")
                } footer: {
                    Text("記錄操作事件與錯誤，不含文章內容、密碼或登入資訊。")
                }

                Section("關於") {
                    LabeledContent("版本", value: MonoriCore.version)
                    Text("把散落在 Patreon、Google Docs、AO3、方格子、AsianFanfics 的同人作品收進同一個書庫。匯入章節、離線書籤、沉浸閱讀，不用在五個網站之間切換。\n\n僅在裝置上儲存章節標題、連結與書籤，不儲存文章內容。所有文章存取由各平台控制。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .confirmationDialog("刪除所有收藏、章節與書籤？",
                                isPresented: $confirmClearLibrary, titleVisibility: .visible) {
                Button("清除書庫資料", role: .destructive) { env.clearLibraryData() }
            }
            .confirmationDialog("清除內建瀏覽器的所有 cookie 與登入狀態？",
                                isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("清除瀏覽器資料", role: .destructive) {
                    Task { await env.clearBrowserData() }
                }
            }
            .sheet(item: $logExport) { export in
                ActivityView(items: [export.url])
            }
            .alert("尚無診斷記錄", isPresented: $showNoLogsAlert) {
                Button("好", role: .cancel) {}
            }
        }
    }
}
