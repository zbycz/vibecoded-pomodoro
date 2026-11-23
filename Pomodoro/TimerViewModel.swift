import Foundation
import Combine
import CoreGraphics

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
    @Published private(set) var detectedActivityAt: Date?

    // MARK: - Constants

    static let workDuration: TimeInterval = 25 * 60
    static let maxBreakDuration: TimeInterval = 12 * 60 * 60
    static let activityDetectionDelay: TimeInterval = 10
    static let activityIdleThreshold: TimeInterval = 2
    /// Grace period after the user dismisses a detected activity, so they can
    /// e.g. finish what they were doing or shut down the computer.
    static let activityDismissDelay: TimeInterval = 60

    private static let activityEventTypes: [CGEventType] = [
        .keyDown, .flagsChanged,
        .leftMouseDown, .rightMouseDown, .otherMouseDown,
        .mouseMoved,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .scrollWheel
    ]

    // MARK: - Private

     private var workTimer: Timer?
     private var breakTimer: Timer?
     private var sessionStart: Date?
    private var breakStart: Date?
    /// Activity detection only counts input that occurs after this moment
    /// plus `activityGraceDelay`.
    private var activityDetectionStart: Date?
    private var activityGraceDelay: TimeInterval = TimerViewModel.activityDetectionDelay

    private let logManager = TimeLogManager()

    // MARK: - Computed helpers

    var remainingMinutes: Int { Int(remaining) / 60 }

    var remainingFormatted: String { formatTime(remaining) }
    var breakElapsedFormatted: String { formatTime(breakElapsed) }

    var isBreakRunning: Bool { breakTimer != nil }

    // MARK: - Actions

    func start() {
        start(at: nil)
    }

    func start(at startDate: Date?) {
        guard state == .idle || state == .completed else { return }
        resetBreakTimer()
        let now = Date()
        let earliestAllowed = now.addingTimeInterval(-Self.workDuration)
        let actualStart = max(startDate ?? now, earliestAllowed)
        let elapsed = max(0, now.timeIntervalSince(actualStart))
        remaining = max(0, Self.workDuration - elapsed)
        sessionStart = actualStart
        state = .running
        if remaining <= 0 {
            finishNaturally()
        } else {
            startWorkTimer()
        }
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
        breakStart = nil
        breakElapsed = 0
        detectedActivityAt = nil
        activityDetectionStart = nil
        activityGraceDelay = Self.activityDetectionDelay
    }

    /// Dismiss the detected activity (e.g. non-work use after the session)
    /// and restart detection after a longer grace period.
    func dismissDetectedActivity() {
        guard breakTimer != nil else { return }
        detectedActivityAt = nil
        activityDetectionStart = Date()
        activityGraceDelay = Self.activityDismissDelay
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
        let now = Date()
        breakStart = now
        breakElapsed = 0
        activityDetectionStart = now
        activityGraceDelay = Self.activityDetectionDelay
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateBreakElapsed()
            }
        }
    }

    private func updateBreakElapsed(now: Date = Date()) {
        guard let breakStart else {
            breakElapsed = 0
            return
        }
        let elapsed = now.timeIntervalSince(breakStart)
        guard elapsed <= Self.maxBreakDuration else {
            resetToInitialState()
            return
        }
        breakElapsed = max(0, floor(elapsed))
        detectActivityIfNeeded(now: now)
    }

    private func detectActivityIfNeeded(now: Date) {
        guard detectedActivityAt == nil, let activityDetectionStart else { return }
        let sinceDetectionStart = now.timeIntervalSince(activityDetectionStart)
        guard sinceDetectionStart >= activityGraceDelay else { return }
        let secondsSinceLast = secondsSinceLastUserInput()
        // Require the event to be recent (sustained activity right now)…
        guard secondsSinceLast < Self.activityIdleThreshold else { return }
        // …AND to have occurred after the grace period ended, so that input
        // from during the previous work session, the first 10s of break, or
        // the grace period after a dismissal does not count as "user came back".
        guard secondsSinceLast < sinceDetectionStart - activityGraceDelay else { return }
        detectedActivityAt = now.addingTimeInterval(-secondsSinceLast)
    }

    private func secondsSinceLastUserInput() -> TimeInterval {
        Self.activityEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? .infinity
    }

    private func resetToInitialState() {
        workTimer?.invalidate()
        workTimer = nil
        sessionStart = nil
        state = .idle
        remaining = Self.workDuration
        resetBreakTimer()
    }

    private func saveSession(duration: TimeInterval) {
        let end = Date()
        let start = sessionStart ?? end.addingTimeInterval(-duration)
        logManager.append(start: start, end: end)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
