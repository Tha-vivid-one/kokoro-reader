import SwiftUI

@main
struct KokoroReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let player = AudioPlayerService.shared
    private let settings = SettingsService.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                player: player,
                settings: settings,
                onReadSelection: { appDelegate.readSelection() },
                onReadClipboard: { appDelegate.readClipboard() },
                onToggleToolbar: { appDelegate.toggleToolbar() },
                isToolbarVisible: appDelegate.isToolbarVisible
            )
        } label: {
            Image(systemName: player.state == .playing ? "speaker.wave.2.fill" : "speaker.fill")
        }
    }
}
