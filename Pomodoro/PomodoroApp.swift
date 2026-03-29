import SwiftUI

@main
struct PomodoroApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window — the app lives entirely in the menu bar (LSUIElement = YES).
        Settings { EmptyView() }
    }
}
