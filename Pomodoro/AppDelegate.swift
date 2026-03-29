import AppKit
import SwiftUI
import Combine
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let vm = TimerViewModel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Popover hosts the SwiftUI popup
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopupView(vm: vm).fixedSize()
        )

        if let button = statusItem.button {
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateStatusItem()

        // Keep status item in sync with timer state
        Publishers.CombineLatest(vm.$state, vm.$remaining)
            .receive(on: RunLoop.main)
            .sink { [weak self] state, _ in
                self?.updateStatusItem()
                if state == .completed { self?.openPopover() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Click handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard statusItem.button != nil else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Context menu

    private func showContextMenu() {
        let menu = NSMenu()

        let loginTitle = "Start on Login"
        let loginItem = NSMenuItem(title: loginTitle, action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLoginItemEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Pomodoro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        // Temporarily assign menu so it can pop up from the status item
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Remove after display so left-clicks still trigger our action
        DispatchQueue.main.async { self.statusItem.menu = nil }
    }

    @objc private func toggleLoginItem() {
        do {
            if isLoginItemEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change login item"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - Status item appearance

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        switch vm.state {
        case .idle, .completed:
            button.image = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "Pomodoro")
            button.title = ""
            button.imagePosition = .imageOnly
        case .running, .paused:
            button.image = nil
            button.title = "\(vm.remainingMinutes) min"
            button.imagePosition = .noImage
        }
    }
}
