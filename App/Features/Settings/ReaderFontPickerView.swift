import SwiftUI
import UniformTypeIdentifiers

struct ReaderFontPickerView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false
    @State private var importError: ImportAlertItem?
    @State private var confirmDeleteID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoriSpacing.x5) {
                VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
                    Text("閱讀字體")
                        .font(MonoriTypography.ui(32, relativeTo: .largeTitle, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(MonoriPalette.ink)
                    Text("選擇閱讀器正文使用的字型")
                        .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                        .foregroundStyle(MonoriPalette.secondaryInk)
                }

                VStack(alignment: .leading, spacing: MonoriSpacing.x2) {
                    sectionHeading("預設")
                    settingsGroup {
                        fontRow(
                            name: ReaderFontDescriptor.builtInDefault.displayName,
                            isSelected: env.prefs.selectedFontID == ReaderFontDescriptor.builtInDefault.id,
                            useReaderFont: true
                        ) {
                            env.prefs.selectedFontID = ReaderFontDescriptor.builtInDefault.id
                        }
                    }
                }

                VStack(alignment: .leading, spacing: MonoriSpacing.x2) {
                    sectionHeading("已匯入")
                    if env.readerFontStore.fonts.isEmpty {
                        Text("尚未匯入任何字型")
                            .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                            .foregroundStyle(MonoriPalette.secondaryInk)
                    } else {
                        settingsGroup {
                            ForEach(Array(env.readerFontStore.fonts.enumerated()), id: \.element.id) { index, font in
                                if index > 0 { groupDivider() }
                                fontRow(
                                    name: font.displayName,
                                    isSelected: env.prefs.selectedFontID == font.id,
                                    useReaderFont: false
                                ) {
                                    env.prefs.selectedFontID = font.id
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        if env.prefs.selectedFontID == font.id {
                                            confirmDeleteID = font.id
                                        } else {
                                            env.readerFontStore.deleteFont(id: font.id)
                                        }
                                    } label: {
                                        Label("刪除", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        if env.prefs.selectedFontID == font.id {
                                            confirmDeleteID = font.id
                                        } else {
                                            env.readerFontStore.deleteFont(id: font.id)
                                        }
                                    } label: {
                                        Label("刪除字型", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        showImporter = true
                    } label: {
                        HStack(spacing: MonoriSpacing.x1) {
                            Image(systemName: "plus")
                                .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                            Text("匯入字型")
                                .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                        }
                        .foregroundStyle(MonoriPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(MonoriPalette.surface,
                                    in: RoundedRectangle(cornerRadius: MonoriRadius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: MonoriRadius.control)
                                .stroke(MonoriPalette.divider, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("匯入字型檔案")
                }
            }
            .padding(.horizontal, MonoriSpacing.x3)
            .padding(.top, MonoriSpacing.x3)
            .padding(.bottom, MonoriSpacing.x8)
        }
        .background(MonoriPalette.canvas)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                MonoriBackButton(accessibilityLabel: "返回設定", action: dismiss.callAsFunction)
                Spacer()
            }
            .padding(.horizontal, MonoriSpacing.x2)
            .frame(height: 56)
            .background(MonoriPalette.canvas)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MonoriPalette.divider)
                    .frame(height: 1)
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.font, UTType(filenameExtension: "ttf")!, UTType(filenameExtension: "otf")!],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .alert(item: $importError) { item in
            Alert(title: Text("匯入失敗"),
                  message: Text(item.message),
                  dismissButton: .default(Text("好")))
        }
        .confirmationDialog("刪除使用中的字型？",
                            isPresented: Binding(
                                get: { confirmDeleteID != nil },
                                set: { if !$0 { confirmDeleteID = nil } }),
                            titleVisibility: .visible) {
            Button("刪除並切回預設", role: .destructive) {
                if let id = confirmDeleteID {
                    env.prefs.resetFontToDefault()
                    env.readerFontStore.deleteFont(id: id)
                    confirmDeleteID = nil
                }
            }
        } message: {
            Text("此字型目前正在使用中。刪除後將切回預設字型。")
        }
    }

    private func fontRow(name: String, isSelected: Bool, useReaderFont: Bool,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .font(useReaderFont
                           ? MonoriTypography.reader(16, relativeTo: .body, weight: .regular)
                           : MonoriTypography.ui(16, relativeTo: .body, weight: .regular))
                    .foregroundStyle(MonoriPalette.ink)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(MonoriTypography.ui(16, relativeTo: .body, weight: .semibold))
                        .foregroundStyle(MonoriPalette.ink)
                }
            }
            .padding(.horizontal, MonoriSpacing.x3)
            .padding(.vertical, MonoriSpacing.x2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue(isSelected ? "已選取" : "")
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let descriptor = try env.readerFontStore.importFont(from: url)
                env.prefs.selectedFontID = descriptor.id
            } catch let error as ReaderFontStore.ImportError {
                switch error {
                case .fileTooBig:
                    importError = ImportAlertItem(message: "檔案超過 25 MB 上限。")
                case .invalidFont:
                    importError = ImportAlertItem(message: "無法辨識此字型檔案。請確認為有效的 .ttf 或 .otf 檔案。")
                case .alreadyImported(let name):
                    importError = ImportAlertItem(message: "「\(name)」已匯入。")
                case .copyFailed:
                    importError = ImportAlertItem(message: "無法儲存字型檔案。")
                }
            } catch {
                importError = ImportAlertItem(message: "匯入時發生錯誤。")
            }
        case .failure:
            break
        }
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
}

private struct ImportAlertItem: Identifiable {
    let id = UUID()
    let message: String
}
