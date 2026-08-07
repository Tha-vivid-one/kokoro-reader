import AppKit
import SwiftUI

final class FloatingWindowController {
    private var panel: NSPanel?
    private(set) var isVisible = false

    private let player: AudioPlayerService
    private let settings: SettingsService

    init(player: AudioPlayerService, settings: SettingsService) {
        self.player = player
        self.settings = settings
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil {
            createPanel()
        }
        panel?.orderFront(nil)
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    private func createPanel() {
        let toolbarView = FloatingToolbarView(
            player: player,
            settings: settings,
            onClose: { [weak self] in self?.hide() }
        )

        let hostingView = NSHostingView(rootView: toolbarView)
        let size = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden

        // Position at bottom center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.minY + 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.panel = panel
    }
}
