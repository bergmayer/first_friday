import SwiftUI
import UIKit

struct SlideshowView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ImageIndex.self) private var index

    @State private var history: [WebDAVImage] = []
    @State private var historyIndex: Int = -1
    @State private var currentUIImage: UIImage?
    @State private var timer: Timer?
    @State private var showFilename = false
    @State private var showSettings = false
    @State private var audio = AudioPlayer()
    @FocusState private var slideshowFocused: Bool

    private let maxHistory = 15

    private var currentImage: WebDAVImage? {
        history.indices.contains(historyIndex) ? history[historyIndex] : nil
    }

    var body: some View {
        ZStack {
            slideshowBase
                .focusable(!showFilename && !showSettings)
                .focused($slideshowFocused)
                .focusEffectDisabled()
                .onMoveCommand { direction in
                    guard !showFilename, !showSettings else { return }
                    switch direction {
                    case .right: Task { await advance() }
                    case .left:  Task { await goBack() }
                    case .up:    if currentImage != nil { showFilename = true }
                    default:     break
                    }
                }
                .onTapGesture {
                    guard !showFilename, !showSettings else { return }
                    if currentImage != nil { showFilename = true }
                }

            if showFilename, let img = currentImage {
                FilenameOverlay(
                    image: img,
                    nowPlaying: audio.nowPlaying,
                    onResume: { showFilename = false },
                    onChangeServer: {
                        showFilename = false
                        showSettings = true
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showFilename)
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(
                onSave: {
                    showSettings = false
                    Task { await rebuildAfterConfigChange() }
                },
                onCancel: { showSettings = false }
            )
        }
        .onChange(of: showFilename) { _, showing in
            if showing {
                timer?.invalidate()
            } else {
                startTimer()
                Task { @MainActor in slideshowFocused = true }
            }
        }
        .onChange(of: showSettings) { _, showing in
            if showing {
                timer?.invalidate()
            } else {
                Task { @MainActor in slideshowFocused = true }
            }
        }
        .onChange(of: settings.imageDuration) { _, _ in
            if !showFilename && !showSettings { startTimer() }
        }
        .task {
            UIApplication.shared.isIdleTimerDisabled = true
            if index.images.isEmpty { await refreshIndex() }
            if currentImage == nil { await advance() }
            startTimer()
            await audio.start(settings: settings)
            slideshowFocused = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            timer?.invalidate()
            Task { await audio.stop() }
        }
    }

    @ViewBuilder
    private var slideshowBase: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let ui = currentUIImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                    .id(currentImage?.url.absoluteString)
                    .transition(.opacity)
            } else if index.isLoading {
                VStack(spacing: 24) {
                    ProgressView().tint(.white)
                    Text("Loading library…").foregroundStyle(.white).font(.title3)
                }
            } else if index.images.isEmpty {
                VStack(spacing: 24) {
                    Text(index.lastError ?? "No images found.")
                        .foregroundStyle(.white)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 200)
                    Button("Change Server") { showSettings = true }
                }
            }
        }
        .animation(.easeInOut(duration: 0.6), value: currentUIImage)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.imageDuration, repeats: true) { _ in
            Task { @MainActor in await advance() }
        }
    }

    private func refreshIndex() async {
        await index.refresh(using: settings)
    }

    private func advance() async {
        if historyIndex < history.count - 1 {
            historyIndex += 1
        } else {
            guard let pick = index.randomImage(excluding: currentImage) else { return }
            history.append(pick)
            if history.count > maxHistory {
                history.removeFirst(history.count - maxHistory)
            }
            historyIndex = history.count - 1
        }
        await loadCurrent()
        startTimer()
    }

    private func goBack() async {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        await loadCurrent()
        startTimer()
    }

    private func loadCurrent() async {
        guard let img = currentImage else { return }
        if let ui = await download(img) {
            currentUIImage = ui
        }
    }

    private func download(_ image: WebDAVImage) async -> UIImage? {
        if image.url.isFileURL {
            return UIImage(contentsOfFile: image.url.path)
        }
        do {
            switch settings.artworkSource {
            case .builtin:
                let (data, _) = try await URLSession.shared.data(from: image.url)
                return UIImage(data: data)
            case .webdav:
                guard let client = settings.makeClient() else { return nil }
                let data = try await client.downloadImage(at: image.url)
                return UIImage(data: data)
            }
        } catch {
            return nil
        }
    }

    private func rebuildAfterConfigChange() async {
        // Refresh the index for the (possibly new) source, but keep the
        // currently displayed image and existing history in place. The next
        // timer tick will pick from the new index.
        await refreshIndex()
        startTimer()
        await audio.start(settings: settings)
    }
}
