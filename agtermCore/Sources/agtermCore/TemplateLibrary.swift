import Foundation

/// Session templates
@MainActor
public final class TemplateLibrary: Sendable {
    public struct Template: Identifiable, Codable, Sendable {
        public let id: UUID
        public let name: String
        public let description: String
        public let command: String
        public let workingDir: String?
        public let environment: [String: String]?
        public let isBuiltin: Bool

        public init(name: String, description: String, command: String, workingDir: String? = nil, environment: [String: String]? = nil, isBuiltin: Bool = true) {
            self.id = UUID()
            self.name = name
            self.description = description
            self.command = command
            self.workingDir = workingDir
            self.environment = environment
            self.isBuiltin = isBuiltin
        }
    }

    private var templates: [Template] = []
    private let configPath: String

    public init(configPath: String = NSHomeDirectory() + "/.config/agterm/templates") {
        self.configPath = configPath
        loadBuiltinTemplates()
        loadCustomTemplates()
    }

    /// Load builtin templates
    private func loadBuiltinTemplates() {
        templates = [
            Template(name: "Bash", description: "Default bash shell", command: "/bin/bash", isBuiltin: true),
            Template(name: "Zsh", description: "Zsh shell", command: "/bin/zsh", isBuiltin: true),
            Template(name: "Fish", description: "Fish shell", command: "/opt/homebrew/bin/fish", isBuiltin: true),
            Template(name: "Python REPL", description: "Python interactive shell", command: "python3", isBuiltin: true),
            Template(name: "Node REPL", description: "Node.js interactive shell", command: "node", isBuiltin: true),
        ]
    }

    /// Load custom templates from disk
    private func loadCustomTemplates() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: configPath) else { return }
        do {
            let files = try fm.contentsOfDirectory(atPath: configPath)
            for file in files where file.hasSuffix(".json") {
                let path = (configPath as NSString).appendingPathComponent(file)
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                if let template = try? JSONDecoder().decode(Template.self, from: data) {
                    templates.append(template)
                }
            }
        } catch {
            // Silently ignore load errors
        }
    }

    /// List all templates
    public func all() -> [Template] {
        templates
    }

    /// Get template by ID
    public func template(withID id: UUID) -> Template? {
        templates.first { $0.id == id }
    }

    /// Save a custom template
    public func save(_ template: Template) throws {
        // Remove existing if present
        templates.removeAll { $0.id == template.id }
        templates.append(template)

        // Persist to disk
        let fm = FileManager.default
        try fm.createDirectory(atPath: configPath, withIntermediateDirectories: true)
        let path = (configPath as NSString).appendingPathComponent(template.id.uuidString + ".json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(template)
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// Delete a custom template
    public func delete(_ id: UUID) throws {
        guard let template = template(withID: id), !template.isBuiltin else { return }
        templates.removeAll { $0.id == id }

        let path = (configPath as NSString).appendingPathComponent(id.uuidString + ".json")
        try FileManager.default.removeItem(atPath: path)
    }

    /// Apply a template (returns command + cwd)
    public func apply(_ templateID: UUID) -> (command: String, cwd: String?, environment: [String: String]?)? {
        guard let template = template(withID: templateID) else { return nil }
        return (command: template.command, cwd: template.workingDir, environment: template.environment)
    }
}
