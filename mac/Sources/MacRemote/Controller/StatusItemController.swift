import AppKit

/// Icône dans la barre des menus : ouvre et ferme le menu (un popover).
@MainActor
final class StatusItemController: NSObject {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()

    init(contentViewController: NSViewController) {
        super.init()
        popover.contentViewController = contentViewController
        popover.behavior = .transient

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "playpause.circle.fill", accessibilityDescription: "Mac Remote Control")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}
