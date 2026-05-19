import SwiftUI

@main
struct first_fridayApp: App {
    @State private var settings = AppSettings()
    @State private var index = ImageIndex()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(index)
        }
    }
}
