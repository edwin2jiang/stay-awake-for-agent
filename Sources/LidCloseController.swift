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

final class LidCloseController {
    func isSleepDisabled() throws -> Bool {
        let output = try run(executable: "/usr/bin/pmset", arguments: ["-g"])
        return output
            .split(separator: "\n")
            .contains { line in
                let normalized = line.replacingOccurrences(of: "\t", with: " ")
                return normalized.contains("SleepDisabled") && normalized.contains("1")
            }
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
}
