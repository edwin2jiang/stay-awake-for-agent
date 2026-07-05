import Foundation

struct CommandFailure: LocalizedError {
    let command: String
    let output: String

    var errorDescription: String? {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedOutput.isEmpty {
            return "命令执行失败：\(command)"
        }

        return trimmedOutput
    }
}

struct PowerSettingsSnapshot {
    let sleepDisabled: Bool?
    let idleSleepMinutes: Int?
    let capturedAt: Date
}

final class LidCloseController {
    func isSleepDisabled() throws -> Bool {
        let output = try run(executable: "/usr/bin/pmset", arguments: ["-g"])
        return Self.parseIntSetting("SleepDisabled", in: output) == 1
    }

    func readPowerSettingsSnapshot() throws -> PowerSettingsSnapshot {
        let settingsOutput = try run(executable: "/usr/bin/pmset", arguments: ["-g"])
        let sleepDisabledValue = Self.parseIntSetting("SleepDisabled", in: settingsOutput)

        return PowerSettingsSnapshot(
            sleepDisabled: sleepDisabledValue.map { $0 == 1 },
            idleSleepMinutes: Self.parseIntSetting("sleep", in: settingsOutput),
            capturedAt: Date()
        )
    }

    func setSleepDisabled(_ disabled: Bool) throws {
        let value = disabled ? "1" : "0"
        let shellCommand = "/usr/bin/pmset -a disablesleep \(value)"
        let script = "do shell script \"\(shellCommand)\" with administrator privileges"

        _ = try run(executable: "/usr/bin/osascript", arguments: ["-e", script])
    }

    private func run(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let combinedOutput = String(decoding: outputData + errorData, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw CommandFailure(
                command: ([executable] + arguments).joined(separator: " "),
                output: combinedOutput
            )
        }

        return combinedOutput
    }

    private static func parseIntSetting(_ key: String, in output: String) -> Int? {
        for line in output.split(separator: "\n") {
            let parts = String(line)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard parts.count >= 2, parts[0] == key else { continue }
            return Int(parts[1])
        }

        return nil
    }

}
