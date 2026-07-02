import Foundation

/// ChatOps integration
@MainActor
public final class ChatIntegration: Sendable {
    public struct Message: Identifiable, Codable, Sendable {
        public let id: UUID
        public let timestamp: Date
        public let sender: String
        public let content: String
        public let isCommand: Bool

        public init(sender: String, content: String, isCommand: Bool = false) {
            self.id = UUID()
            self.timestamp = Date()
            self.sender = sender
            self.content = content
            self.isCommand = isCommand
        }
    }

    public struct CommandResult: Codable, Sendable {
        public let command: String
        public let exitCode: Int32
        public let stdout: String
        public let stderr: String
    }

    private var messages: [Message] = []
    private var isConnected = false
    private let maxMessages = 1000

    /// Connect to chat service
    public func connect() -> Bool {
        isConnected = true
        return true
    }

    /// Disconnect from chat service
    public func disconnect() {
        isConnected = false
    }

    /// Check connection status
    public var connected: Bool { isConnected }

    /// Send message to chat
    public func sendMessage(_ content: String) -> UUID {
        let message = Message(sender: "agterm", content: content, isCommand: false)
        messages.append(message)

        if messages.count > maxMessages {
            messages.removeFirst()
        }

        return message.id
    }

    /// Execute a command and report result
    /// Reads pipes in background to prevent deadlock on large output
    public func executeCommand(_ command: String) -> CommandResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()

            // Read pipes in background to prevent deadlock when buffers fill
            var outData = Data()
            var errData = Data()

            DispatchQueue.global().async {
                outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            }
            DispatchQueue.global().async {
                errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            }

            task.waitUntilExit()

            // Give background reads a small time to complete
            let deadline = Date().addingTimeInterval(1.0)
            while Date() < deadline && (outData.isEmpty || errData.isEmpty) {
                Thread.sleep(forTimeInterval: 0.01)
            }

            let stdout = String(data: outData, encoding: .utf8) ?? ""
            let stderr = String(data: errData, encoding: .utf8) ?? ""

            return CommandResult(command: command, exitCode: task.terminationStatus, stdout: stdout, stderr: stderr)
        } catch {
            return CommandResult(command: command, exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }
    }

    /// Get all messages
    public func allMessages() -> [Message] {
        messages
    }

    /// Clear messages
    public func clearMessages() {
        messages.removeAll()
    }
}
