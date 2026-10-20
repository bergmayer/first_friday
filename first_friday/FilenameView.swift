import SwiftUI

struct FilenameOverlay: View {
    @Environment(AppSettings.self) private var settings
    let image: WebDAVImage
    let metadataText: String?
    let nowPlaying: String?
    let isAudioAvailable: Bool
    let isAudioPlaying: Bool
    let onToggleAudio: () -> Void
    let onResume: () -> Void
    let onChangeServer: () -> Void

    private enum OverlayAction: Hashable { case music, settings, resume, info }

    @FocusState private var focusedAction: OverlayAction?
    var body: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()

            VStack(spacing: 28) {
                Text(metadataText ?? image.displayPath)
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
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

                Button {
                    settings.alwaysShowInfo.toggle()
                } label: {
                    Label("Always Show Info: \(settings.alwaysShowInfo ? "On" : "Off")",
                          systemImage: settings.alwaysShowInfo ? "checkmark.circle.fill" : "circle")
                }
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .focused($focusedAction, equals: .info)

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
                VStack(spacing: 8) {
                    Text("Slidehow Controls")
                        .fontWeight(.semibold)
                    Text("← / → Artwork · ↑ \(settings.alwaysShowInfo ? "Move info" : "Controls") · ↓ Show/hide info")
                    Text("Select or Back: Controls · Play/Pause: Music")
                }
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 44)
            .padding(.horizontal, 64)
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

/// White text over a dark translucent fill keeps contrast even on white artwork.
struct PersistentInfoOverlay: View {
    let artwork: String
    let nowPlaying: String?
    let corner: InfoOverlayCorner

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(artwork)
                .font(.system(size: 18, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let nowPlaying, !nowPlaying.isEmpty {
                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(height: 1)
                Label(nowPlaying, systemImage: "music.note")
                    .font(.system(size: 16, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.leading)
        .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
        .padding(12)
        .frame(width: 340, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.54))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner.alignment)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

enum InfoOverlayCorner: CaseIterable {
    case upperRight, upperLeft, bottomLeft, bottomRight

    var next: Self {
        switch self {
        case .upperRight: .upperLeft
        case .upperLeft: .bottomLeft
        case .bottomLeft: .bottomRight
        case .bottomRight: .upperRight
        }
    }

    var alignment: Alignment {
        switch self {
        case .upperRight: .topTrailing
        case .upperLeft: .topLeading
        case .bottomLeft: .bottomLeading
        case .bottomRight: .bottomTrailing
        }
    }
}
