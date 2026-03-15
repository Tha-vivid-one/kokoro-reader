import SwiftUI

struct MenuBarView: View {
    let player: AudioPlayerService
    let settings: SettingsService
    let onReadSelection: () -> Void
    let onReadClipboard: () -> Void
    let onToggleToolbar: () -> Void
    let isToolbarVisible: Bool

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            if showSettings {
                HStack {
                    Button { showSettings = false } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("Settings")
                        .font(.headline)
                    Spacer()
                }

                SettingsView(settings: settings)
            } else {
                // Player
                PlayerView(player: player)

                Divider()

                // Quick actions
                VStack(spacing: 4) {
                    ActionButton(title: "Read Selection", shortcut: "⌘⇧R", icon: "text.cursor") {
                        onReadSelection()
                    }

                    ActionButton(title: "Read Clipboard", shortcut: "", icon: "doc.on.clipboard") {
                        onReadClipboard()
                    }
                }

                Divider()

                // Quick selectors
                HStack {
                    Picker("", selection: Binding(
                        get: { settings.voice },
                        set: { settings.voice = $0 }
                    )) {
                        Text(settings.voice).tag(settings.voice)
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption)
                        Text("\(settings.speed, specifier: "%.1f")x")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)
                }

                Divider()

                // Footer
                HStack {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        onToggleToolbar()
                    } label: {
                        Label(
                            isToolbarVisible ? "Hide Toolbar" : "Show Toolbar",
                            systemImage: isToolbarVisible ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}

private struct ActionButton: View {
    let title: String
    let shortcut: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
                if !shortcut.isEmpty {
                    Text(shortcut)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
