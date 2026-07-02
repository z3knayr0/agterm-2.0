import Foundation

/// Plugin system
@MainActor
public final class PluginRegistry: Sendable {
    public struct PluginManifest: Codable, Sendable {
        public let id: String
        public let name: String
        public let version: String
        public let description: String
        public let mainScript: String
        public let settings: [String: String]?

        public init(id: String, name: String, version: String, description: String, mainScript: String, settings: [String: String]? = nil) {
            self.id = id
            self.name = name
            self.version = version
            self.description = description
            self.mainScript = mainScript
            self.settings = settings
        }
    }

    private var plugins: [PluginManifest] = []
    private var loadedPlugins: Set<String> = []
    private let pluginsPath: String

    public init(pluginsPath: String = NSHomeDirectory() + "/.config/agterm/plugins") {
        self.pluginsPath = pluginsPath
        loadPlugins()
    }

    /// Validate script path contains no directory traversal attempts
    private func isValidScriptPath(_ path: String) -> Bool {
        !path.contains("/") && !path.contains("..") && !path.isEmpty
    }

    /// Load all plugins from disk
    private func loadPlugins() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: pluginsPath) else { return }

        do {
            let dirs = try fm.contentsOfDirectory(atPath: pluginsPath)
            for dir in dirs {
                let pluginPath = (pluginsPath as NSString).appendingPathComponent(dir)
                let manifestPath = (pluginPath as NSString).appendingPathComponent("plugin.json")

                guard fm.fileExists(atPath: manifestPath) else { continue }

                let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
                if var manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) {
                    // Validate mainScript path to prevent directory traversal
                    guard isValidScriptPath(manifest.mainScript) else { continue }
                    plugins.append(manifest)
                }
            }
        } catch {
            // Silently ignore load errors
        }
    }

    /// List all plugins
    public func all() -> [PluginManifest] {
        plugins
    }

    /// Get plugin by ID
    public func plugin(withID id: String) -> PluginManifest? {
        plugins.first { $0.id == id }
    }

    /// Load a plugin
    public func load(_ pluginID: String) -> Bool {
        guard plugin(withID: pluginID) != nil else { return false }
        loadedPlugins.insert(pluginID)
        return true
    }

    /// Unload a plugin
    public func unload(_ pluginID: String) {
        loadedPlugins.remove(pluginID)
    }

    /// Check if plugin is loaded
    public func isLoaded(_ pluginID: String) -> Bool {
        loadedPlugins.contains(pluginID)
    }

    /// Execute a plugin command
    public func execute(_ pluginID: String, command: String) -> (exitCode: Int32, output: String) {
        guard isLoaded(pluginID), let plugin = plugin(withID: pluginID) else {
            return (exitCode: 1, output: "Plugin not loaded or not found")
        }

        // Defense-in-depth: validate script path again at execution time
        guard isValidScriptPath(plugin.mainScript) else {
            return (exitCode: 1, output: "Invalid plugin script path")
        }

        let pluginPath = (pluginsPath as NSString).appendingPathComponent(pluginID)
        let scriptPath = (pluginPath as NSString).appendingPathComponent(plugin.mainScript)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: scriptPath)
        task.arguments = [command]

        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = outPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outData, encoding: .utf8) ?? ""

            return (exitCode: task.terminationStatus, output: output)
        } catch {
            return (exitCode: 1, output: error.localizedDescription)
        }
    }

    /// Install a plugin from a zip file
    public func install(from zipPath: String) throws -> String {
        // Placeholder: would unzip and validate plugin.json
        return UUID().uuidString
    }

    /// Uninstall a plugin
    public func uninstall(_ pluginID: String) throws {
        guard let plugin = plugin(withID: pluginID) else { throw NSError(domain: "PluginRegistry", code: 1) }
        plugins.removeAll { $0.id == pluginID }
        loadedPlugins.remove(pluginID)

        let pluginPath = (pluginsPath as NSString).appendingPathComponent(pluginID)
        try FileManager.default.removeItem(atPath: pluginPath)
    }
}
