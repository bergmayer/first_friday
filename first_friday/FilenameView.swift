import SwiftUI

struct FilenameOverlay: View {
    let image: WebDAVImage
    let metadataText: String?
    let nowPlaying: String?
    let isAudioAvailable: Bool
    let isAudioPlaying: Bool
    let onToggleAudio: () -> Void
    let onResume: () -> Void
    let onChangeServer: () -> Void

    private enum OverlayAction: Hashable { case music, settings, resume }

    @FocusState private var focusedAction: OverlayAction?
    var body: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()

            VStack(spacing: 50) {
                Text(metadataText ?? image.displayPath)
                    .font(.system(size: 80, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(8)
                    .minimumScaleFactor(0.4)
                    .shadow(color: .black.opacity(0.6), radius: 12, y: 4)

                if isAudioPlaying, let nowPlaying, !nowPlaying.isEmpty {
                    HStack(spacing: 18) {
                        Image(systemName: "music.note")
                        Text(nowPlaying)
                    }
                    .font(.system(size: 42, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.6), radius: 10, y: 3)
                }

                HStack(spacing: 30) {
                    Button("Resume Slideshow", action: onResume)
                        .focused($focusedAction, equals: .resume)

                    if isAudioAvailable {
                        Button(isAudioPlaying ? "Pause Music" : "Play Music") {
                            onToggleAudio()
                        }
                        .focused($focusedAction, equals: .music)
                    }

                    Button("Settings") {
                        onChangeServer()
                    }
                    .focused($focusedAction, equals: .settings)
                }
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            }
            .padding(.vertical, 80)
            .padding(.horizontal, 120)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 60, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 60, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 40, y: 20)
            .padding(.horizontal, 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onExitCommand(perform: onResume)
        .onAppear {
            focusedAction = .settings
        }
    }
}
