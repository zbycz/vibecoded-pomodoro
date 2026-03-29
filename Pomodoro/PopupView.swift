import SwiftUI

struct PopupView: View {

    @ObservedObject var vm: TimerViewModel

    var body: some View {
        VStack(spacing: 0) {
            switch vm.state {
            case .idle:
                IdleView(vm: vm)
            case .running, .paused:
                RunningView(vm: vm)
            case .completed:
                CompletedView(vm: vm)
            }

            Button(action: { TimeLogManager().openLogFile() }) {
                Label("Show Time Log", systemImage: "doc.text")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.top, 12)
        }
        .frame(width: 260)
        .padding(20)
    }
}

// MARK: - Idle

private struct IdleView: View {
    @ObservedObject var vm: TimerViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Pomodoro")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button(action: vm.start) {
                Label("Start  25:00", systemImage: "play.fill")
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - Running / Paused

private struct RunningView: View {
    @ObservedObject var vm: TimerViewModel

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                Text(vm.remainingFormatted)
                    .font(.system(size: 52, weight: .thin, design: .monospaced))
                    .monospacedDigit()

                VStack(spacing: 10) {
                    // Pause / Resume
                    Button(action: togglePause) {
                        Image(systemName: vm.state == .running ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .help(vm.state == .running ? "Pause" : "Resume")

                    // Finish early and save
                    Button(action: vm.completeEarly) {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .help("Finish & save now")
                }
            }

            if vm.state == .paused {
                Text("Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func togglePause() {
        if vm.state == .running { vm.pause() } else { vm.resume() }
    }
}

// MARK: - Completed

private struct CompletedView: View {
    @ObservedObject var vm: TimerViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Finished label + work time
            VStack(spacing: 4) {
                Text("Done!")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("0:00")
                    .font(.system(size: 52, weight: .thin, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            // Break timer row
            HStack(alignment: .center, spacing: 6) {
                Text("Break")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(vm.breakElapsedFormatted)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button(action: vm.resetBreakTimer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset break timer")
            }

            // Start next
            Button(action: vm.start) {
                Label("Start  25:00", systemImage: "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Preview

#Preview {
    PopupView(vm: TimerViewModel())
}
