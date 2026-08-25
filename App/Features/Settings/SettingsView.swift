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
    @State private var showExportFailedAlert = false
    @State private var confirmRestore = false
    @State private var showForceBackupConfirm = false
    @State private var forceBackupMessage = ""
    @State private var showResultAlert = false
    @State private var resultAlertTitle = ""
    @State private var resultAlertMessage = ""

    var body: some View {
        @Bindable var prefs = env.prefs

        ScrollView {
            VStack(alignment: .leading, spacing: MonoriSpacing.x5) {

                VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
                    Text("設定")
                        .font(MonoriTypography.ui(32, relativeTo: .largeTitle, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(MonoriPalette.ink)
                    Text("個人化您的閱讀體驗與應用程式偏好")
                        .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                        .foregroundStyle(MonoriPalette.secondaryInk)
                }

                VStack(alignment: .leading, spacing: MonoriSpacing.x2) {
                    sectionHeading("閱讀設定")
                    settingsGroup {
                        HStack(spacing: MonoriSpacing.x2) {
                            VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
                                Text("自動檢查新章節")
                                    .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                                    .foregroundStyle(MonoriPalette.ink)
                                Text("有更新時會發出通知")
                                    .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                                    .foregroundStyle(MonoriPalette.secondaryInk)
                            }
                            Spacer()
                            Button {
                                env.appPrefs.autoCheckEnabled.toggle()
                            } label: {
                                MonoriSwitchControl(
                                    isOn: env.appPrefs.autoCheckEnabled,
                                    onTrackColor: MonoriPalette.ink,
                                    offTrackColor: MonoriPalette.canvas,
                                    borderColor: MonoriPalette.divider,
                                    onThumbColor: MonoriPalette.canvas,
                                    offThumbColor: MonoriPalette.secondaryInk
                                ) { _ in EmptyView() }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("自動檢查新章節")
                            .accessibilityValue(env.appPrefs.autoCheckEnabled ? "開啟" : "關閉")
                            .accessibilityIdentifier("smoke.autoCheckToggle")
                        }
                        .padding(.horizontal, MonoriSpacing.x3)
                        .padding(.vertical, MonoriSpacing.x2)

                        groupDivider()

                        HStack(spacing: MonoriSpacing.x2) {
                            VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
                                Text("字體大小")
                                    .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                                    .foregroundStyle(MonoriPalette.ink)
                                Text("\(prefs.fontSize) pt")
                                    .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                                    .foregroundStyle(MonoriPalette.secondaryInk)
                            }
                            Spacer()
                            HStack(spacing: MonoriSpacing.x1) {
                                valueButton(symbol: "−", accessibilityLabel: "字體大小減少",
                                            identifier: "Decrement",
                                            disabled: prefs.fontSize <= 14) {
                                    prefs.fontSize -= 1
                                }
                                valueButton(symbol: "+", accessibilityLabel: "字體大小增加",
                                            identifier: "Increment",
                                            disabled: prefs.fontSize >= 32) {
                                    prefs.fontSize += 1
                                }
                            }
                        }
                        .padding(.horizontal, MonoriSpacing.x3)
                        .padding(.vertical, MonoriSpacing.x2)
                    }
                    sectionFootnote("開啟書庫時自動為「追更中」的收藏檢查新章節。僅在 app 使用中執行，不會在背景連線。")
                }

                VStack(alignment: .leading, spacing: MonoriSpacing.x2) {
                    sectionHeading("外觀")
                    settingsGroup {
                        HStack(spacing: MonoriSpacing.x2) {
                            Text("主題")
                                .font(MonoriTypography.ui(16, relativeTo: .body,
                                                          weight: .semibold))
                                .tracking(MonoriTypography.uiTracking)
                                .foregroundStyle(MonoriPalette.ink)
                            Spacer()
                            ThemeToggle()
                        }
                        .frame(minHeight: 56)
                        .padding(.horizontal, MonoriSpacing.x3)
                        .padding(.vertical, MonoriSpacing.x2)

                        groupDivider()

                        HStack {
                            VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
                                HStack(spacing: MonoriSpacing.x1) {
                                    Text("閱讀字體")
                                        .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                                        .foregroundStyle(MonoriPalette.ink)
                                    Text("（施工中）")
                                        .font(MonoriTypography.ui(11, relativeTo: .caption, weight: .light))
                                        .foregroundStyle(MonoriPalette.secondaryInk)
                                }
                                Text("Source Serif 4 (預設)")
                                    .font(MonoriTypography.reader(14, relativeTo: .subheadline))
                                    .italic()
                                    .foregroundStyle(MonoriPalette.secondaryInk)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, MonoriSpacing.x3)
                        .padding(.vertical, MonoriSpacing.x2)
                    }
                }

                VStack(alignment: .leading, spacing: MonoriSpacing.x2) {
                    sectionHeading("資料")
                    settingsGroup {
                        settingsAction("清除書庫資料", destructive: true) {
                            confirmClearLibrary = true
                        }
                        .padding(.horizontal, MonoriSpacing.x3)
                        .padding(.vertical, MonoriSpacing.x2)

                        groupDivider()

                        settingsAction("清除瀏覽器資料", destructive: true) {
                            confirmLogout = true
                        }
                        .padding(.horizontal, MonoriSpacing.x3)
                        .padding(.vertical, MonoriSpacing.x2)
                    }
                    sectionFootnote("「清除書庫資料」會刪除裝置上儲存的收藏、章節、書籤與閱歷。「清除瀏覽器資料」會清除內建瀏覽器的所有 cookie 與登入狀態，等同登出所有來源。兩者互相獨立。iCloud 備份不受影響。")
                }

                VStack(alignment: .leading, spacing: MonoriSpacing.x2) {
                    sectionHeading("iCloud 備份")
                    settingsGroup {
                        backupSectionContent()
                    }
                    sectionFootnote("僅備份書庫、書籤、閱讀進度與閱歷。不含文章內容、登入資料或個人帳號資訊。")
                }

                VStack(alignment: .leading, spacing: MonoriSpacing.x2) {
                    sectionHeading("診斷")
                    settingsGroup {
                        settingsAction("匯出診斷記錄") {
                            exportDiagnosticLog()
                        }
                        .padding(.horizontal, MonoriSpacing.x3)
                        .padding(.vertical, MonoriSpacing.x2)
                    }
                    sectionFootnote("記錄操作事件與錯誤，不含文章內容、密碼或登入資訊。")
                }

                VStack(alignment: .leading, spacing: MonoriSpacing.x2) {
                    sectionHeading("關於")
                    settingsGroup {
                        HStack {
                            Text("版本")
                                .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                                .foregroundStyle(MonoriPalette.ink)
                            Spacer()
                            Text(MonoriCore.version)
                                .font(.system(size: 13, design: .monospaced).weight(.medium))
                                .foregroundStyle(MonoriPalette.secondaryInk)
                                .padding(.horizontal, MonoriSpacing.x1)
                                .padding(.vertical, 4)
                                .background(MonoriPalette.canvas,
                                            in: RoundedRectangle(cornerRadius: 4))
                        }
                        .padding(.horizontal, MonoriSpacing.x3)
                        .padding(.vertical, MonoriSpacing.x2)

                        groupDivider()

                        Link(destination: URL(string: "https://github.com/hikarushane/monori/blob/main/COMPLIANCE.md")!) {
                            HStack {
                                Text("隱私權政策與法律合規")
                                    .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                                    .foregroundStyle(MonoriPalette.ink)
                                Spacer()
                                ExternalLinkIcon()
                                    .stroke(MonoriPalette.secondaryInk.opacity(0.5),
                                            style: StrokeStyle(lineWidth: 1.5,
                                                               lineCap: .round,
                                                               lineJoin: .round))
                                    .frame(width: 14, height: 14)
                            }
                            .padding(.horizontal, MonoriSpacing.x3)
                            .padding(.vertical, MonoriSpacing.x2)
                        }

                        groupDivider()

                        Text("把散落在 Patreon、Google Docs、AO3、方格子、AsianFanfics 的同人作品收進同一個書庫。匯入章節、離線書籤、沉浸閱讀，不用在五個網站之間切換。\n\n僅在裝置上儲存章節標題、連結、書籤與閱歷，不儲存文章內容。備份至 iCloud 時同樣不含文章內容。所有文章存取由各平台控制。")
                            .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                            .foregroundStyle(MonoriPalette.secondaryInk)
                            .lineSpacing(6)
                            .padding(.horizontal, MonoriSpacing.x3)
                            .padding(.vertical, MonoriSpacing.x2)
                    }
                }
            }
            .padding(.horizontal, MonoriSpacing.x3)
            .padding(.top, MonoriSpacing.x3)
            .padding(.bottom, MonoriSpacing.x8)
        }
        .background(MonoriPalette.canvas)
        .tint(MonoriPalette.ink)
        .confirmationDialog("刪除此裝置上的書庫資料？",
                            isPresented: $confirmClearLibrary, titleVisibility: .visible) {
            Button("清除書庫資料", role: .destructive) { env.clearLibraryData() }
        } message: {
            Text("會刪除此裝置上的書庫、章節、書籤、閱讀進度與閱歷。網站登入資料與 iCloud 備份不受影響。")
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
        .alert("匯出失敗", isPresented: $showExportFailedAlert) {
            Button("好", role: .cancel) {}
        }
        .confirmationDialog("從 iCloud 還原備份？",
                            isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("還原", role: .destructive) {
                Task { await performRestore() }
            }
        } message: {
            Text("還原將以 iCloud 備份覆蓋此裝置上的書庫、書籤、閱讀進度與閱歷。此操作無法復原。")
        }
        .confirmationDialog("iCloud 上已有更新的備份",
                            isPresented: $showForceBackupConfirm, titleVisibility: .visible) {
            Button("覆蓋備份", role: .destructive) {
                Task { await performForceBackup() }
            }
        } message: {
            Text(forceBackupMessage)
        }
        .alert(resultAlertTitle, isPresented: $showResultAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(resultAlertMessage)
        }
        .task {
            await env.backupService.checkAvailability()
        }
    }


    private static let backupDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    @ViewBuilder
    private func backupSectionContent() -> some View {
        let bs = env.backupService
        if bs.state == .checking {
            HStack(spacing: MonoriSpacing.x2) {
                ProgressView()
                    .controlSize(.small)
                Text("檢查 iCloud 狀態…")
                    .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(MonoriPalette.secondaryInk)
            }
            .padding(.horizontal, MonoriSpacing.x3)
            .padding(.vertical, MonoriSpacing.x2)
        } else if bs.state == .noAccount || bs.state == .restricted || bs.state == .unavailable {
            VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
                Text("iCloud 無法使用")
                    .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                    .foregroundStyle(MonoriPalette.ink)
                Text(bs.state == .noAccount
                     ? "請在系統設定中登入 iCloud"
                     : "iCloud 目前無法使用，請稍後再試")
                    .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(MonoriPalette.secondaryInk)
            }
            .padding(.horizontal, MonoriSpacing.x3)
            .padding(.vertical, MonoriSpacing.x2)
        } else {
            if let meta = bs.lastBackupMetadata {
                VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
                    Text("上次備份")
                        .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                        .foregroundStyle(MonoriPalette.ink)
                    Text(Self.backupDateFormatter.string(from: meta.createdAt))
                        .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                        .foregroundStyle(MonoriPalette.secondaryInk)
                    Text("\(meta.collectionCount) 收藏 · \(meta.chapterCount) 章節 · \(meta.historyCount) 閱歷")
                        .font(MonoriTypography.ui(13, relativeTo: .footnote))
                        .foregroundStyle(MonoriPalette.secondaryInk)
                }
                .padding(.horizontal, MonoriSpacing.x3)
                .padding(.vertical, MonoriSpacing.x2)
            } else {
                Text("尚無 iCloud 備份")
                    .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(MonoriPalette.secondaryInk)
                    .padding(.horizontal, MonoriSpacing.x3)
                    .padding(.vertical, MonoriSpacing.x2)
            }

            groupDivider()

            Button {
                Task { await performBackup() }
            } label: {
                HStack {
                    Text("立即備份")
                        .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                        .foregroundStyle(MonoriPalette.ink)
                    Spacer()
                    if bs.state == .backingUp {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(bs.state != .available)
            .opacity(bs.state == .backingUp ? 0.6 : 1)
            .accessibilityIdentifier("smoke.backupNowButton")
            .padding(.horizontal, MonoriSpacing.x3)
            .padding(.vertical, MonoriSpacing.x2)

            groupDivider()

            Button {
                confirmRestore = true
            } label: {
                HStack {
                    Text("從 iCloud 還原")
                        .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                        .foregroundStyle(.red)
                    Spacer()
                    if bs.state == .restoring {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(bs.state != .available || bs.lastBackupMetadata == nil)
            .opacity(bs.state == .restoring ? 0.6 : 1)
            .accessibilityIdentifier("smoke.restoreFromCloudButton")
            .padding(.horizontal, MonoriSpacing.x3)
            .padding(.vertical, MonoriSpacing.x2)
        }
    }

    private func performBackup() async {
        let result = await env.backupService.backup()
        switch result {
        case .success:
            resultAlertTitle = "備份完成"
            resultAlertMessage = "已成功備份至 iCloud。"
            showResultAlert = true
        case .newerBackupExists(let date):
            forceBackupMessage = "iCloud 備份時間為 \(Self.backupDateFormatter.string(from: date))，比此裝置的資料更新。確定要覆蓋？"
            showForceBackupConfirm = true
        case .failed(let error):
            resultAlertTitle = "備份失敗"
            resultAlertMessage = error.localizedMessage
            showResultAlert = true
        }
    }

    private func performForceBackup() async {
        let result = await env.backupService.forceBackup()
        switch result {
        case .success:
            resultAlertTitle = "備份完成"
            resultAlertMessage = "已成功備份至 iCloud。"
        case .newerBackupExists:
            resultAlertTitle = "備份失敗"
            resultAlertMessage = "備份失敗"
        case .failed(let error):
            resultAlertTitle = "備份失敗"
            resultAlertMessage = error.localizedMessage
        }
        showResultAlert = true
    }

    private func performRestore() async {
        let result = await env.backupService.restore()
        switch result {
        case .success:
            resultAlertTitle = "還原完成"
            resultAlertMessage = "已從 iCloud 還原書庫。"
        case .noBackup:
            resultAlertTitle = "無備份資料"
            resultAlertMessage = "iCloud 上沒有備份可供還原。"
        case .failed(let error):
            resultAlertTitle = "還原失敗"
            resultAlertMessage = error.localizedMessage
        }
        showResultAlert = true
    }

    private func valueButton(symbol: String, accessibilityLabel: String, identifier: String,
                             disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(MonoriTypography.ui(22, relativeTo: .title3, weight: .medium))
                .foregroundStyle(MonoriPalette.ink)
                .frame(width: 44, height: 44)
                .background(MonoriPalette.canvas,
                            in: RoundedRectangle(cornerRadius: MonoriRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: MonoriRadius.control)
                        .stroke(MonoriPalette.divider, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonoriPalette.surface,
                        in: RoundedRectangle(cornerRadius: MonoriRadius.container))
            .overlay {
                RoundedRectangle(cornerRadius: MonoriRadius.container)
                    .stroke(MonoriPalette.divider, lineWidth: 1)
            }
    }

    private func groupDivider() -> some View {
        Rectangle()
            .fill(MonoriPalette.divider)
            .frame(height: 1)
            .padding(.horizontal, MonoriSpacing.x3)
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(MonoriTypography.ui(13, relativeTo: .footnote, weight: .semibold))
            .tracking(MonoriTypography.navigationTracking)
            .foregroundStyle(MonoriPalette.ink.opacity(0.8))
    }

    private func sectionFootnote(_ text: String) -> some View {
        Text(text)
            .font(MonoriTypography.ui(13, relativeTo: .footnote))
            .foregroundStyle(MonoriPalette.secondaryInk)
            .lineSpacing(5)
    }

    private func settingsAction(_ title: String, destructive: Bool = false,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                .foregroundStyle(destructive ? Color.red : MonoriPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(destructive
                                 ? (title == "清除書庫資料" ? "smoke.clearDataButton" : "smoke.logoutButton")
                                 : "smoke.exportLogsButton")
    }

    private func exportDiagnosticLog() {
        guard let text = DiagnosticLog.shared.exportText() else {
            showNoLogsAlert = true
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("monori-diagnostic-log.txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            logExport = LogExport(url: url)
        } catch {
            showExportFailedAlert = true
        }
    }
}

#if DEBUG
#Preview("設定") {
    let env = PreviewSupport.emptyEnvironment()
    SettingsView()
        .environment(env)
        .modelContainer(env.store.container)
}

#Preview("設定・大字體", traits: .fixedLayout(width: 430, height: 932)) {
    let env = PreviewSupport.emptyEnvironment()
    SettingsView()
        .environment(env)
        .modelContainer(env.store.container)
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif

private struct ExternalLinkIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let cr = 5 * s
        var p = Path()
        p.move(to: CGPoint(x: 21*s, y: 9*s))
        p.addLine(to: CGPoint(x: 21*s, y: 3*s))
        p.addLine(to: CGPoint(x: 15*s, y: 3*s))
        p.move(to: CGPoint(x: 21*s, y: 3*s))
        p.addLine(to: CGPoint(x: 12*s, y: 12*s))
        p.move(to: CGPoint(x: 10*s, y: 3*s))
        p.addArc(tangent1End: CGPoint(x: 3*s, y: 3*s),
                 tangent2End: CGPoint(x: 3*s, y: 12*s), radius: cr)
        p.addArc(tangent1End: CGPoint(x: 3*s, y: 21*s),
                 tangent2End: CGPoint(x: 12*s, y: 21*s), radius: cr)
        p.addArc(tangent1End: CGPoint(x: 21*s, y: 21*s),
                 tangent2End: CGPoint(x: 21*s, y: 12*s), radius: cr)
        p.addLine(to: CGPoint(x: 21*s, y: 14*s))
        return p
    }
}

