import Foundation
import AppKit

struct TimeLogManager {

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("pomodoro-log.md")
    }()

    // MARK: - Public

    /// Append a completed session to the log file.
    func append(start: Date, end: Date) {
        let minutes = max(1, Int(ceil(end.timeIntervalSince(start) / 60)))
        let line = "- \(timeString(start)) – \(timeString(end)) (\(minutes) min)\n"
        let heading = "## \(dateString(start))\n"

        var content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""

        if content.contains(heading) {
            content += line
        } else {
            if !content.isEmpty && !content.hasSuffix("\n\n") {
                content += content.hasSuffix("\n") ? "\n" : "\n\n"
            }
            content += heading + "\n" + line
        }

        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Open the log file in TextEdit.
    func openLogFile() {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        NSWorkspace.shared.open([fileURL], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Formatters

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd EEE"
        return f.string(from: date)
    }
}
