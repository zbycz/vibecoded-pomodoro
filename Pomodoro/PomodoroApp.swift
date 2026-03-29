import SwiftUI

@main
struct PomodoroApp: App {

    @StateObject private var vm = TimerViewModel()

    var body: some Scene {
        MenuBarExtra(content: {
            PopupView(vm: vm)
        }, label: {
            MenuBarLabel(vm: vm)
        })
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Dynamic menu bar label

private struct MenuBarLabel: View {
    @ObservedObject var vm: TimerViewModel

    var body: some View {
        switch vm.state {
        case .idle, .completed:
            Image(systemName: "stopwatch")
        case .running, .paused:
            Text("\(vm.remainingMinutes) min")
                .monospacedDigit()
        }
    }
}
