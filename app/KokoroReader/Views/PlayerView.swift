import SwiftUI

struct PlayerView: View {
    let player: AudioPlayerService

    var body: some View {
        VStack(spacing: 8) {
            if !player.textPreview.isEmpty {
                Text(player.textPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.tint)
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
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()

            // Transport controls
            HStack(spacing: 16) {
                Button { player.skipBackward() } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(player.state == .idle)

                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(player.state == .idle)

                Button { player.skipForward() } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(player.state == .idle)

                Spacer()

                Button { player.stop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(player.state == .idle)
            }
        }
        .padding(.horizontal, 4)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
