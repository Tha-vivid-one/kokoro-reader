import SwiftUI

struct PlayerView: View {
    let player: AudioPlayerService

    var body: some View {
        VStack(spacing: 8) {
            if !player.textPreview.isEmpty {
                Text(player.textPreview)
                    .font(.system(size: 12))
                    .foregroundStyle(KokoroTheme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            player.seek(to: fraction)
                        }
                )
            }
            .frame(height: 4)

            // Time display
            HStack {
                Text(formatTime(player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(KokoroTheme.textMuted)

            // Transport controls
            HStack(spacing: 12) {
                transportButton("backward.fill", size: 13) { player.skipBackward() }
                    .disabled(player.state == .idle)

                transportButton(
                    player.state == .playing ? "pause.fill" : "play.fill",
                    size: 16,
                    isPrimary: true
                ) { player.togglePlayPause() }
                .disabled(player.state == .idle)

                transportButton("forward.fill", size: 13) { player.skipForward() }
                    .disabled(player.state == .idle)

                Spacer()

                transportButton("stop.fill", size: 13) { player.stop() }
                    .disabled(player.state == .idle)
            }
        }
        .padding(.horizontal, 4)
    }

    private func transportButton(
        _ symbol: String,
        size: CGFloat,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(KokoroTheme.textPrimary)
                .frame(width: isPrimary ? 32 : 26, height: isPrimary ? 32 : 26)
                .background(
                    isPrimary
                        ? AnyShapeStyle(KokoroTheme.accent.opacity(0.15))
                        : AnyShapeStyle(.clear)
                )
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
