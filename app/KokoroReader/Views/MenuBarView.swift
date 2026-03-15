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
        VStack(spacing: 0) {
            if showSettings {
                // Settings header
                HStack {
                    Button { showSettings = false } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(KokoroTheme.accent)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KokoroTheme.textPrimary)
                    Spacer()
                    // Balance spacer
                    Text("Back")
                        .font(.system(size: 12))
                        .hidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(KokoroTheme.bgSurface)

                Divider().overlay(KokoroTheme.border)

                SettingsView(settings: settings)
            } else {
                // Brand header
                HStack {
                    Text("KOKORO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(KokoroTheme.accent)
                        .tracking(0.8)
                    Spacer()
                    Text("READER")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(KokoroTheme.textMuted)
                        .tracking(0.5)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(KokoroTheme.bgSurface)

                Divider().overlay(KokoroTheme.border)

                VStack(spacing: 10) {
                    // Player
                    PlayerView(player: player)

                    Divider().overlay(KokoroTheme.border)

                    // Quick actions
                    VStack(spacing: 2) {
                        ActionButton(title: "Read Selection", shortcut: "⌘⇧R", icon: "text.cursor") {
                            onReadSelection()
                        }
                        ActionButton(title: "Read Clipboard", shortcut: "", icon: "doc.on.clipboard") {
                            onReadClipboard()
                        }
                    }

                    Divider().overlay(KokoroTheme.border)

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
                                .font(.system(size: 10))
                            Text("\(settings.speed, specifier: "%.1f")x")
                                .font(.system(size: 11, design: .monospaced))
                        }
                        .foregroundStyle(KokoroTheme.textSecondary)
                    }

                    Divider().overlay(KokoroTheme.border)

                    // Footer
                    HStack {
                        Button { showSettings = true } label: {
                            Image(systemName: "gear")
                                .font(.system(size: 13))
                                .foregroundStyle(KokoroTheme.textSecondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            onToggleToolbar()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isToolbarVisible ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle")
                                    .font(.system(size: 10))
                                Text(isToolbarVisible ? "Hide Toolbar" : "Show Toolbar")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(KokoroTheme.accent)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button("Quit") {
                            NSApplication.shared.terminate(nil)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(KokoroTheme.textMuted)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 280)
        .background(KokoroTheme.bgBase)
    }
}

private struct ActionButton: View {
    let title: String
    let shortcut: String
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(KokoroTheme.accent)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(KokoroTheme.textPrimary)
                Spacer()
                if !shortcut.isEmpty {
                    Text(shortcut)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(KokoroTheme.textMuted)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? KokoroTheme.accent.opacity(0.08) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
