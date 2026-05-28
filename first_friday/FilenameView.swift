import SwiftUI

struct FilenameOverlay: View {
    let image: WebDAVImage
    let nowPlaying: String?
    let onResume: () -> Void
    let onChangeServer: () -> Void

    @FocusState private var focused: Bool
    @State private var contentOpacity: Double = 1
    @State private var dismissTask: Task<Void, Never>?

    private let holdDuration: TimeInterval = 5
    private let fadeDuration: TimeInterval = 1.5

    var body: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()

            VStack(spacing: 50) {
                Text(image.displayPath)
                    .font(.system(size: 80, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.4)
                    .shadow(color: .black.opacity(0.6), radius: 12, y: 4)

                if let nowPlaying, !nowPlaying.isEmpty {
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

                Text("click for settings")
                    .font(.system(size: 26, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
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
        .opacity(contentOpacity)
        .focusable(true)
        .focused($focused)
        .focusEffectDisabled()
        .onTapGesture {
            dismissTask?.cancel()
            onChangeServer()
        }
        .onMoveCommand { _ in
            dismissTask?.cancel()
            onResume()
        }
        .onExitCommand {
            dismissTask?.cancel()
            onResume()
        }
        .onAppear {
            Task { @MainActor in focused = true }
            scheduleAutoDismiss()
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }

    private func scheduleAutoDismiss() {
        dismissTask?.cancel()
        contentOpacity = 1
        withAnimation(.linear(duration: fadeDuration).delay(holdDuration)) {
            contentOpacity = 0
        }
        let total = holdDuration + fadeDuration
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(total))
            guard !Task.isCancelled else { return }
            onResume()
        }
    }
}
