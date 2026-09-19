import SwiftUI
import UIKit

struct NativeTabBarView: UIViewRepresentable {
    @Binding var selectedTab: AppRootView.AppTab
    let isRegularWidth: Bool
    let contentPadding: CGFloat

    func makeUIView(context: Context) -> NativeTabBarUIView {
        let bar = NativeTabBarUIView()
        bar.onTabTap = { tab in
            selectedTab = tab
        }
        bar.isRegularWidth = isRegularWidth
        bar.contentPadding = contentPadding
        bar.currentTab = selectedTab
        return bar
    }

    func updateUIView(_ uiView: NativeTabBarUIView, context: Context) {
        uiView.isRegularWidth = isRegularWidth
        uiView.contentPadding = contentPadding
        uiView.currentTab = selectedTab
    }
}

final class NativeTabBarUIView: UIView {
    typealias AppTab = AppRootView.AppTab

    var onTabTap: ((AppTab) -> Void)?

    var currentTab: AppTab = .library {
        didSet { if oldValue != currentTab { updateAppearance() } }
    }
    var isRegularWidth = false {
        didSet { if oldValue != isRegularWidth { setNeedsLayout() } }
    }
    var contentPadding: CGFloat = 24 {
        didSet { if oldValue != contentPadding { setNeedsLayout() } }
    }

    private let tabs: [(tab: AppTab, title: String, identifier: String)] = [
        (.browse, "瀏覽", "smoke.browseTab"),
        (.library, "書庫", "smoke.libraryTab"),
        (.settings, "設定", "smoke.settingsTab"),
    ]

    private var buttons: [UIButton] = []
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for (index, item) in tabs.enumerated() {
            let button = UIButton(type: .custom)
            button.tag = index
            button.accessibilityIdentifier = item.identifier
            button.accessibilityLabel = item.title
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            buttons.append(button)
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        updateAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stack.layoutMargins = UIEdgeInsets(
            top: 0, left: contentPadding, bottom: 0, right: contentPadding)
        stack.isLayoutMarginsRelativeArrangement = true
        updateAppearance()
    }

    @objc private func tabTapped(_ sender: UIButton) {
        let tab = tabs[sender.tag].tab
        onTabTap?(tab)
    }

    @MainActor
    private func updateAppearance() {
        let iconSize: CGFloat = isRegularWidth
            ? 39
            : min(max(bounds.height * 0.28, 24), 30)
        let fontSize: CGFloat = isRegularWidth ? 20 : 11

        let selectedIconColor = UIColor(named: "MonoriNavigationGreen") ?? .systemGreen
        let unselectedColor = UIColor(named: "MonoriSecondaryInk") ?? .secondaryLabel
        let selectedTextColor = UIColor(named: "MonoriInk") ?? .label

        let tabIcons: [Image] = [
            MonoriTabIcon.browse,
            MonoriTabIcon.library,
            MonoriTabIcon.settings,
        ]

        for (index, button) in buttons.enumerated() {
            let isSelected = tabs[index].tab == currentTab
            let title = tabs[index].title

            let iconRenderer = ImageRenderer(
                content: tabIcons[index]
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize))
            iconRenderer.scale = UIScreen.main.scale
            let templateImage = (iconRenderer.uiImage ?? UIImage())
                .withRenderingMode(.alwaysTemplate)

            var config = UIButton.Configuration.plain()
            config.image = templateImage
            config.imagePlacement = .top
            config.imagePadding = MonoriSpacing.x1

            var titleAttr = AttributedString(title)
            let manropeDesc = UIFontDescriptor(fontAttributes: [.family: "Manrope"])
                .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight:
                    isSelected ? UIFont.Weight.semibold : UIFont.Weight.medium]])
            titleAttr.font = UIFont(descriptor: manropeDesc, size: fontSize)
            titleAttr.foregroundColor = isSelected ? selectedTextColor : unselectedColor
            titleAttr.kern = MonoriTypography.navigationTracking
            config.attributedTitle = titleAttr

            config.baseForegroundColor = isSelected ? selectedIconColor : unselectedColor

            button.configuration = config
            button.isAccessibilityElement = true
            button.accessibilityTraits = isSelected
                ? [.button, .selected]
                : [.button]
        }
    }
}
