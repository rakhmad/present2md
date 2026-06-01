import SwiftUI
import present2mdCore

@main
struct present2mdApp: App {
    @StateObject private var coordinator = ConversionCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .frame(minWidth: 480, minHeight: 320)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
