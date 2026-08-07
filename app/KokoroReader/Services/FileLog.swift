import Foundation

/// Append-only debug log at ~/Library/Logs/KokoroReader/app.log so failures
/// are inspectable after the fact (`log show` is unreliable for this).
enum FileLog {
    private static let queue = DispatchQueue(label: "com.kokoro.reader.filelog", qos: .utility)
    private static let maxSize = 2 * 1024 * 1024  // truncate past 2MB

    private static let logURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/KokoroReader", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("app.log")
    }()

    private static let timestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func log(_ message: String) {
        queue.async {
            let line = "\(timestamp.string(from: Date())) \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

            if let size = try? FileManager.default.attributesOfItem(atPath: logURL.path)[.size] as? Int,
               size > maxSize {
                try? FileManager.default.removeItem(at: logURL)
            }

            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}
