import Foundation
import Combine

// MARK: - Timer State

enum PomodoroState: Equatable {
    case idle
    case running
    case paused
    case completed
}

// MARK: - ViewModel

@MainActor
final class TimerViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var state: PomodoroState = .idle
    @Published private(set) var remaining: TimeInterval = 25 * 60
    @Published private(set) var breakElapsed: TimeInterval = 0

    // MARK: - Constants

    static let workDuration: TimeInterval = 25 * 60

    // MARK: - Private

    private var workTimer: Timer?
    private var breakTimer: Timer?
    private var sessionStart: Date?

    private let logManager = TimeLogManager()

    // MARK: - Computed helpers

    var remainingMinutes: Int { Int(remaining) / 60 }

    var remainingFormatted: String { formatTime(remaining) }
    var breakElapsedFormatted: String { formatTime(breakElapsed) }

    var isBreakRunning: Bool { breakTimer != nil }

    // MARK: - Actions

    func start() {
        guard state == .idle || state == .completed else { return }
        remaining = Self.workDuration
        sessionStart = Date()
        state = .running
        startWorkTimer()
    }

    func pause() {
        guard state == .running else { return }
        workTimer?.invalidate()
        workTimer = nil
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        startWorkTimer()
    }

    /// Finish the current interval early and save it to the log.
    func completeEarly() {
        guard state == .running || state == .paused else { return }
        let elapsed = Self.workDuration - remaining
        saveSession(duration: elapsed)
        finishWork()
    }

    /// Reset the break timer that runs after a completed session.
    func resetBreakTimer() {
        breakTimer?.invalidate()
        breakTimer = nil
        breakElapsed = 0
    }

    // MARK: - Private helpers

    private func startWorkTimer() {
        workTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard remaining > 0 else {
            finishNaturally()
            return
        }
        remaining -= 1
        if remaining <= 0 {
            finishNaturally()
        }
    }

    private func finishNaturally() {
        saveSession(duration: Self.workDuration)
        finishWork()
    }

    private func finishWork() {
        workTimer?.invalidate()
        workTimer = nil
        remaining = 0
        state = .completed
        startBreakTimer()
    }

    private func startBreakTimer() {
        breakElapsed = 0
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.breakElapsed += 1
            }
        }
    }

    private func saveSession(duration: TimeInterval) {
        let start = sessionStart ?? Date().addingTimeInterval(-duration)
        let end = start.addingTimeInterval(duration)
        logManager.append(start: start, end: end)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
