import Foundation

/// Theme definition and management
public struct Theme: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let background: String
    public let foreground: String
    public let accentColor: String
    public let isBuiltin: Bool

    public init(id: String, name: String, background: String, foreground: String, accentColor: String, isBuiltin: Bool = true) {
        self.id = id
        self.name = name
        self.background = background
        self.foreground = foreground
        self.accentColor = accentColor
        self.isBuiltin = isBuiltin
    }
}

/// Theme store: load, save, and manage themes
@MainActor
public final class ThemeStore: Sendable {
    private var themes: [Theme] = []
    private var currentThemeID: String = "ghostty"
    private let configPath: String

    public init(configPath: String = NSHomeDirectory() + "/.config/agterm/themes") {
        self.configPath = configPath
        loadBuiltinThemes()
        loadCustomThemes()
    }

    /// Load builtin themes
    private func loadBuiltinThemes() {
        themes = [
            Theme(id: "ghostty", name: "Ghostty Default", background: "#000000", foreground: "#ffffff", accentColor: "#0080ff"),
            Theme(id: "nord", name: "Nord", background: "#2e3440", foreground: "#eceff4", accentColor: "#88c0d0"),
            Theme(id: "dracula", name: "Dracula", background: "#282a36", foreground: "#f8f8f2", accentColor: "#ff79c6"),
            Theme(id: "one-dark", name: "One Dark", background: "#282c34", foreground: "#abb2bf", accentColor: "#61afef"),
            Theme(id: "solarized-dark", name: "Solarized Dark", background: "#002b36", foreground: "#839496", accentColor: "#268bd2"),
        ]
    }

    /// Load custom themes from disk
    private func loadCustomThemes() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: configPath) else { return }
        do {
            let files = try fm.contentsOfDirectory(atPath: configPath)
            for file in files where file.hasSuffix(".json") {
                let path = (configPath as NSString).appendingPathComponent(file)
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                if let theme = try? JSONDecoder().decode(Theme.self, from: data) {
                    themes.append(theme)
                }
            }
        } catch {
            // Silently ignore load errors
        }
    }

    /// Get all themes
    public func all() -> [Theme] {
        themes
    }

    /// Get theme by ID
    public func theme(withID id: String) -> Theme? {
        themes.first { $0.id == id }
    }

    /// Set current theme
    public func setTheme(_ id: String) {
        guard themes.contains(where: { $0.id == id }) else { return }
        currentThemeID = id
    }

    /// Get current theme
    public func currentTheme() -> Theme? {
        theme(withID: currentThemeID)
    }

    /// Save a custom theme
    public func save(_ theme: Theme) throws {
        // Remove existing if present
        themes.removeAll { $0.id == theme.id }
        themes.append(theme)

        // Persist to disk
        let fm = FileManager.default
        try fm.createDirectory(atPath: configPath, withIntermediateDirectories: true)
        let path = (configPath as NSString).appendingPathComponent(theme.id + ".json")
        let data = try JSONEncoder().encode(theme)
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// Delete a custom theme
    public func delete(_ id: String) throws {
        guard let theme = theme(withID: id), !theme.isBuiltin else { return }
        themes.removeAll { $0.id == id }

        let path = (configPath as NSString).appendingPathComponent(id + ".json")
        try FileManager.default.removeItem(atPath: path)
    }
}
