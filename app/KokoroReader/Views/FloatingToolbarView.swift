import SwiftUI

struct FloatingToolbarView: View {
    let player: AudioPlayerService
    let settings: SettingsService
    let onClose: () -> Void

    @State private var showSettings = false
    @State private var showSpeed = false
    @State private var availableVoices: [String] = []

    var body: some View {
        HStack(spacing: 0) {
            // Transport controls
            HStack(spacing: 4) {
                toolbarButton("backward.fill") { player.skipBackward() }
                    .disabled(player.state == .idle)

                toolbarButton(player.state == .playing ? "pause.fill" : "play.fill", size: 14, isPrimary: true) {
                    player.togglePlayPause()
                }
                .disabled(player.state == .idle)

                toolbarButton("forward.fill") { player.skipForward() }
                    .disabled(player.state == .idle)

                toolbarButton("stop.fill") { player.stop() }
                    .disabled(player.state == .idle)
            }
            .padding(.horizontal, 8)

            divider

            // Time + progress
            HStack(spacing: 6) {
                Text(formatTime(player.currentTime))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(KokoroTheme.textMuted)
                    .frame(width: 30, alignment: .trailing)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(KokoroTheme.bgElevated)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(KokoroTheme.progressGradient)
                            .frame(width: geo.size.width * player.progress)
                    }
                    .frame(height: 4)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = max(0, min(1, value.location.x / geo.size.width))
                                player.seek(to: fraction)
                            }
                    )
                }
                .frame(width: 80, height: 20)

                Text(formatTime(player.duration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(KokoroTheme.textMuted)
                    .frame(width: 30, alignment: .leading)
            }
            .padding(.horizontal, 8)

            divider

            // Voice picker
            Picker("", selection: Binding(
                get: { settings.voice },
                set: { settings.voice = $0 }
            )) {
                if availableVoices.isEmpty {
                    Text(settings.voice).tag(settings.voice)
                } else {
                    ForEach(availableVoices, id: \.self) { voice in
                        Text(voice).tag(voice)
                    }
                }
            }
            .labelsHidden()
            .frame(width: 90)
            .scaleEffect(0.85)

            // Speed — dropdown with a slider, applies to live playback
            Button { showSpeed.toggle() } label: {
                HStack(spacing: 3) {
                    Text("\(settings.speed, specifier: "%.1f")x")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(KokoroTheme.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(KokoroTheme.textMuted)
                }
                .frame(width: 40)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            .popover(isPresented: $showSpeed, arrowEdge: .top) {
                VStack(spacing: 8) {
                    Text("\(settings.speed, specifier: "%.1f")x")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(KokoroTheme.textPrimary)

                    Slider(
                        value: Binding(
                            get: { settings.speed },
                            set: {
                                settings.speed = ($0 * 10).rounded() / 10
                                player.refreshRate()
                            }
                        ),
                        in: 0.5...2.0
                    )
                    .frame(width: 150)

                    HStack {
                        Text("0.5x")
                        Spacer()
                        Text("2.0x")
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(KokoroTheme.textMuted)
                    .frame(width: 150)
                }
                .padding(12)
            }

            divider

            // Settings gear
            Button { showSettings.toggle() } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12))
                    .foregroundStyle(KokoroTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .popover(isPresented: $showSettings, arrowEdge: .top) {
                SettingsView(settings: settings)
                    .frame(width: 300)
                    .padding(8)
            }

            // Close
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(KokoroTheme.textMuted)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
        }
        .frame(height: 44)
        .background(KokoroTheme.bgBase)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(KokoroTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 16, y: 4)
        .task {
            do {
                let voices = try await TTSService.shared.fetchVoices()
                availableVoices = voices
            } catch {}
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(KokoroTheme.border)
            .frame(width: 1, height: 28)
    }

    private func toolbarButton(_ symbol: String, size: CGFloat = 12, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(KokoroTheme.textPrimary)
                .frame(width: isPrimary ? 28 : 24, height: isPrimary ? 28 : 24)
                .background(isPrimary ? KokoroTheme.accent.opacity(0.15) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
