import AppKit

@MainActor
protocol MenuViewDelegate: AnyObject {
    func menuViewDidRequestAccessibilitySettings(_ menuView: MenuView)
    func menuView(_ menuView: MenuView, didSelectAddressOptionAt index: Int)
    func menuViewDidRequestCopyLink(_ menuView: MenuView)
    func menuView(_ menuView: MenuView, didToggleKeepAwake isOn: Bool)
    func menuViewDidRequestNewToken(_ menuView: MenuView)
    func menuViewDidRequestQuit(_ menuView: MenuView)
}

/// Contenu du menu de la barre des menus.
/// Ne connaît aucun objet du modèle : il affiche des valeurs et signale les actions à son délégué.
final class MenuView: NSView {

    enum Status {
        case pending
        case ready
        case warning
        case failure
    }

    struct Content {
        var status: Status
        var statusText: String
        var showsAccessibilityWarning: Bool
        var showsPairing: Bool
        var qrCode: NSImage?
        var pairingMessage: String?
        var addressOptions: [String]
        var selectedAddressOption: Int
        var connectedPhones: String
        var targetApp: String
        var shortcutProfile: String
        var keepsMacAwake: Bool
    }

    static let qrDimension: CGFloat = 168

    weak var delegate: MenuViewDelegate?

    private static let width: CGFloat = 300
    private static let padding: CGFloat = 16

    private let statusDot = NSView()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let accessibilityCard = NSView()
    private let pairingStack = NSStackView()
    private let qrGroup = NSStackView()
    private let qrImageView = NSImageView()
    private let pairingMessageLabel = NSTextField(labelWithString: "")
    private let addressControl = NSSegmentedControl()
    private let copyButton = NSButton()
    private let phonesValue = NSTextField(labelWithString: "")
    private let appValue = NSTextField(labelWithString: "")
    private let profileValue = NSTextField(labelWithString: "")
    private let keepAwakeCheckbox = NSButton(checkboxWithTitle: "Garder le Mac éveillé", target: nil, action: nil)

    init() {
        super.init(frame: .zero)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) n'est pas utilisé")
    }

    func configure(with content: Content) {
        statusDot.layer?.backgroundColor = color(for: content.status).cgColor
        statusLabel.stringValue = content.statusText
        accessibilityCard.isHidden = !content.showsAccessibilityWarning

        pairingStack.isHidden = !content.showsPairing
        qrImageView.image = content.qrCode
        qrGroup.isHidden = content.qrCode == nil
        copyButton.isHidden = content.qrCode == nil
        pairingMessageLabel.stringValue = content.pairingMessage ?? ""
        pairingMessageLabel.isHidden = content.pairingMessage == nil

        if addressControl.segmentCount != content.addressOptions.count {
            addressControl.segmentCount = content.addressOptions.count
        }
        for (index, label) in content.addressOptions.enumerated() {
            addressControl.setLabel(label, forSegment: index)
        }
        addressControl.selectedSegment = content.selectedAddressOption

        phonesValue.stringValue = content.connectedPhones
        appValue.stringValue = content.targetApp
        profileValue.stringValue = content.shortcutProfile
        keepAwakeCheckbox.state = content.keepsMacAwake ? .on : .off
    }

    @objc private func openAccessibilitySettings() {
        delegate?.menuViewDidRequestAccessibilitySettings(self)
    }

    @objc private func addressOptionChanged() {
        delegate?.menuView(self, didSelectAddressOptionAt: addressControl.selectedSegment)
    }

    @objc private func copyLink() {
        delegate?.menuViewDidRequestCopyLink(self)
    }

    @objc private func keepAwakeToggled() {
        delegate?.menuView(self, didToggleKeepAwake: keepAwakeCheckbox.state == .on)
    }

    @objc private func newToken() {
        delegate?.menuViewDidRequestNewToken(self)
    }

    @objc private func quit() {
        delegate?.menuViewDidRequestQuit(self)
    }

    private func buildLayout() {
        keepAwakeCheckbox.target = self
        keepAwakeCheckbox.action = #selector(keepAwakeToggled)

        let stack = NSStackView(views: [
            makeHeader(),
            makeAccessibilityCard(),
            makePairingSection(),
            makeSeparator(),
            makeInfoSection(),
            keepAwakeCheckbox,
            makeSeparator(),
            makeFooter(),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        embed(stack, in: self)
        widthAnchor.constraint(equalToConstant: Self.width).isActive = true

        for view in stack.arrangedSubviews where view !== keepAwakeCheckbox {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -2 * Self.padding).isActive = true
        }
    }

    private func makeHeader() -> NSView {
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),
        ])

        let title = NSTextField(labelWithString: "Mac Remote Control")
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let titleGroup = NSStackView(views: [statusDot, title])
        titleGroup.spacing = 8

        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right
        statusLabel.maximumNumberOfLines = 2
        statusLabel.preferredMaxLayoutWidth = 170

        let row = NSStackView(views: [titleGroup, statusLabel])
        row.distribution = .equalSpacing
        row.alignment = .centerY
        return row
    }

    private func makeAccessibilityCard() -> NSView {
        let icon = NSImageView(image: NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .systemOrange
        let title = NSTextField(labelWithString: "Autorisation requise")
        title.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        title.textColor = .systemOrange
        let titleRow = NSStackView(views: [icon, title])
        titleRow.spacing = 6

        let body = NSTextField(wrappingLabelWithString:
            "Mac Remote Control doit pouvoir simuler le clavier et la souris. Active-le dans Réglages › Confidentialité et sécurité › Accessibilité.")
        body.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        body.textColor = .secondaryLabelColor
        body.preferredMaxLayoutWidth = Self.width - 2 * Self.padding - 20

        let button = NSButton(title: "Ouvrir les réglages", target: self, action: #selector(openAccessibilitySettings))
        button.controlSize = .small

        let stack = NSStackView(views: [titleRow, body, button])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        accessibilityCard.wantsLayer = true
        accessibilityCard.layer?.cornerRadius = 8
        accessibilityCard.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.1).cgColor
        embed(stack, in: accessibilityCard)
        return accessibilityCard
    }

    private func makePairingSection() -> NSView {
        qrImageView.imageScaling = .scaleProportionallyUpOrDown
        let qrContainer = NSView()
        qrContainer.wantsLayer = true
        qrContainer.layer?.backgroundColor = NSColor.white.cgColor
        qrContainer.layer?.cornerRadius = 10
        embed(qrImageView, in: qrContainer, inset: 10)
        NSLayoutConstraint.activate([
            qrImageView.widthAnchor.constraint(equalToConstant: Self.qrDimension),
            qrImageView.heightAnchor.constraint(equalToConstant: Self.qrDimension),
        ])

        let caption = NSTextField(labelWithString: "Scanne avec l'appareil photo du téléphone")
        caption.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        caption.textColor = .secondaryLabelColor

        qrGroup.setViews([qrContainer, caption], in: .center)
        qrGroup.orientation = .vertical
        qrGroup.spacing = 10

        pairingMessageLabel.textColor = .secondaryLabelColor

        addressControl.trackingMode = .selectOne
        addressControl.segmentDistribution = .fillEqually
        addressControl.target = self
        addressControl.action = #selector(addressOptionChanged)
        addressControl.toolTip = "Si le téléphone ne trouve pas le Mac avec le nom .local (fréquent sur Android), passe en IP"

        copyButton.title = "Copier le lien"
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyButton.imagePosition = .imageLeading
        copyButton.bezelStyle = .push
        copyButton.controlSize = .small
        copyButton.target = self
        copyButton.action = #selector(copyLink)

        pairingStack.setViews([qrGroup, pairingMessageLabel, addressControl, copyButton], in: .center)
        pairingStack.orientation = .vertical
        pairingStack.alignment = .centerX
        pairingStack.spacing = 10
        addressControl.widthAnchor.constraint(equalTo: pairingStack.widthAnchor).isActive = true
        return pairingStack
    }

    private func makeInfoSection() -> NSView {
        let rows = [
            makeRow(title: "Téléphones connectés", value: phonesValue),
            makeRow(title: "App ciblée", value: appValue),
            makeRow(title: "Raccourcis", value: profileValue),
        ]
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        for row in rows {
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func makeRow(title: String, value: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        value.textColor = .secondaryLabelColor
        value.alignment = .right
        value.lineBreakMode = .byTruncatingTail
        value.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [label, value])
        row.distribution = .equalSpacing
        return row
    }

    private func makeFooter() -> NSView {
        let newTokenButton = NSButton(title: "Nouveau jeton", target: self, action: #selector(newToken))
        newTokenButton.toolTip = "Déconnecte les téléphones : il faudra rescanner le QR code"
        let quitButton = NSButton(title: "Quitter", target: self, action: #selector(quit))
        quitButton.keyEquivalent = "q"
        quitButton.keyEquivalentModifierMask = .command
        let row = NSStackView(views: [newTokenButton, quitButton])
        row.distribution = .equalSpacing
        return row
    }

    private func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    private func embed(_ child: NSView, in parent: NSView, inset: CGFloat = 0) {
        child.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(child)
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
        ])
    }

    private func color(for status: Status) -> NSColor {
        switch status {
        case .pending: .systemYellow
        case .ready: .systemGreen
        case .warning: .systemOrange
        case .failure: .systemRed
        }
    }
}
