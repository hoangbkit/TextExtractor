import SwiftUI

@main
struct TextExtractorDemoApp: App {
    var body: some Scene {
        WindowGroup {
#if os(macOS)
            ContentView()
                .frame(minWidth: 980, minHeight: 680)
#else
            ContentView()
#endif
        }
    }
}
