import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Group {
            if settings.isConfigured {
                SlideshowView()
            } else {
                SettingsView(onSave: {}, onCancel: nil)
            }
        }
    }
}
