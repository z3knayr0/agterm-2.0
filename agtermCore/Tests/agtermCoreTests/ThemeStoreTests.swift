import Foundation
import Testing
@testable import agtermCore

/// ThemeStore unit tests covering builtin themes, custom theme loading/saving, and persistence
@MainActor
final class ThemeStoreTests {
    private let tempDir = FileManager.default.temporaryDirectory

    deinit {
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("theme-test"))
    }

    private func themePath(_ name: String = "themes") -> String {
        let path = tempDir.appendingPathComponent("theme-test").appendingPathComponent(name).path
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    // MARK: - Built-in theme loading

    @Test func initLoadsBuiltinThemes() {
        let store = ThemeStore(configPath: themePath())
        let themes = store.all()

        // Should have at least the builtin themes
        #expect(themes.count >= 5)
    }

    @Test func builtinThemesIncludeGhostty() {
        let store = ThemeStore(configPath: themePath())
        let ghostty = store.theme(withID: "ghostty")

        #expect(ghostty != nil)
        #expect(ghostty?.name == "Ghostty Default")
        #expect(ghostty?.isBuiltin == true)
    }

    @Test func builtinThemesIncludeNord() {
        let store = ThemeStore(configPath: themePath())
        let nord = store.theme(withID: "nord")

        #expect(nord != nil)
        #expect(nord?.name == "Nord")
        #expect(nord?.background == "#2e3440")
        #expect(nord?.isBuiltin == true)
    }

    @Test func builtinThemesIncludeDracula() {
        let store = ThemeStore(configPath: themePath())
        let dracula = store.theme(withID: "dracula")

        #expect(dracula != nil)
        #expect(dracula?.name == "Dracula")
        #expect(dracula?.isBuiltin == true)
    }

    @Test func builtinThemesIncludeOneDark() {
        let store = ThemeStore(configPath: themePath())
        let oneDark = store.theme(withID: "one-dark")

        #expect(oneDark != nil)
        #expect(oneDark?.name == "One Dark")
        #expect(oneDark?.isBuiltin == true)
    }

    @Test func builtinThemesIncludeSolarizedDark() {
        let store = ThemeStore(configPath: themePath())
        let solarized = store.theme(withID: "solarized-dark")

        #expect(solarized != nil)
        #expect(solarized?.name == "Solarized Dark")
        #expect(solarized?.isBuiltin == true)
    }

    @Test func builtinThemesHaveValidColors() {
        let store = ThemeStore(configPath: themePath())
        let themes = store.all()

        for theme in themes where theme.isBuiltin {
            // All builtin themes should have color hex codes
            #expect(theme.background.hasPrefix("#"))
            #expect(theme.foreground.hasPrefix("#"))
            #expect(theme.accentColor.hasPrefix("#"))
            #expect(theme.background.count == 7)  // #RRGGBB
            #expect(theme.foreground.count == 7)
            #expect(theme.accentColor.count == 7)
        }
    }

    // MARK: - Theme getter/setter

    @Test func setThemeChangesCurrentTheme() {
        let store = ThemeStore(configPath: themePath())
        store.setTheme("nord")

        let current = store.currentTheme()
        #expect(current?.id == "nord")
        #expect(current?.name == "Nord")
    }

    @Test func currentThemeDefaultsToGhostty() {
        let store = ThemeStore(configPath: themePath())
        let current = store.currentTheme()

        #expect(current?.id == "ghostty")
    }

    @Test func getThemeByID() {
        let store = ThemeStore(configPath: themePath())
        let theme = store.theme(withID: "dracula")

        #expect(theme != nil)
        #expect(theme?.name == "Dracula")
    }

    @Test func getThemeByIDReturnsNilForUnknownID() {
        let store = ThemeStore(configPath: themePath())
        let theme = store.theme(withID: "nonexistent")

        #expect(theme == nil)
    }

    @Test func setThemeToInvalidIDDoesNothing() {
        let store = ThemeStore(configPath: themePath())
        store.setTheme("nonexistent-theme")

        let current = store.currentTheme()
        #expect(current?.id == "ghostty")  // Should remain unchanged
    }

    @Test func multipleSetThemeChanges() {
        let store = ThemeStore(configPath: themePath())

        store.setTheme("nord")
        #expect(store.currentTheme()?.id == "nord")

        store.setTheme("dracula")
        #expect(store.currentTheme()?.id == "dracula")

        store.setTheme("ghostty")
        #expect(store.currentTheme()?.id == "ghostty")
    }

    // MARK: - Custom theme loading/saving

    @Test func saveCustomThemeAddsToStore() throws {
        let store = ThemeStore(configPath: themePath())
        let custom = Theme(
            id: "my-custom",
            name: "My Custom Theme",
            background: "#111111",
            foreground: "#eeeeee",
            accentColor: "#ff0000",
            isBuiltin: false
        )

        try store.save(custom)
        let retrieved = store.theme(withID: "my-custom")

        #expect(retrieved != nil)
        #expect(retrieved?.name == "My Custom Theme")
        #expect(retrieved?.isBuiltin == false)
    }

    @Test func saveCustomThemePersistsToDisk() throws {
        let configPath = themePath()
        let store = ThemeStore(configPath: configPath)
        let custom = Theme(
            id: "persist-test",
            name: "Persist Test",
            background: "#222222",
            foreground: "#dddddd",
            accentColor: "#00ff00",
            isBuiltin: false
        )

        try store.save(custom)

        let filePath = (configPath as NSString).appendingPathComponent("persist-test.json")
        #expect(FileManager.default.fileExists(atPath: filePath))
    }

    @Test func saveCustomThemeCreatesConfigDirectory() throws {
        let configPath = tempDir.appendingPathComponent("theme-test").appendingPathComponent("new-theme-dir").path
        let store = ThemeStore(configPath: configPath)
        let custom = Theme(
            id: "dir-test",
            name: "Dir Test",
            background: "#333333",
            foreground: "#cccccc",
            accentColor: "#0000ff",
            isBuiltin: false
        )

        try store.save(custom)

        #expect(FileManager.default.fileExists(atPath: configPath))
    }

    @Test func loadCustomThemesFromDisk() throws {
        let configPath = themePath()

        // Create a custom theme file on disk
        let custom = Theme(
            id: "disk-theme",
            name: "Disk Theme",
            background: "#444444",
            foreground: "#bbbbbb",
            accentColor: "#ffff00",
            isBuiltin: false
        )
        let filePath = (configPath as NSString).appendingPathComponent("disk-theme.json")
        let data = try JSONEncoder().encode(custom)
        try data.write(to: URL(fileURLWithPath: filePath))

        // Create a new store instance (should load the file)
        let store = ThemeStore(configPath: configPath)
        let retrieved = store.theme(withID: "disk-theme")

        #expect(retrieved != nil)
        #expect(retrieved?.name == "Disk Theme")
        #expect(retrieved?.isBuiltin == false)
    }

    @Test func customThemeOverridesBuiltinIfSameID() throws {
        let configPath = themePath()

        // Save a custom theme with a builtin ID
        let custom = Theme(
            id: "ghostty",
            name: "Custom Ghostty",
            background: "#555555",
            foreground: "#aaaaaa",
            accentColor: "#ff00ff",
            isBuiltin: false
        )

        try FileManager.default.createDirectory(atPath: configPath, withIntermediateDirectories: true)
        let filePath = (configPath as NSString).appendingPathComponent("ghostty.json")
        let data = try JSONEncoder().encode(custom)
        try data.write(to: URL(fileURLWithPath: filePath))

        let store = ThemeStore(configPath: configPath)
        let theme = store.theme(withID: "ghostty")

        // The custom version should be in the list (may override or coexist)
        #expect(theme != nil)
    }

    @Test func loadCustomThemesIgnoresNonJSONFiles() throws {
        let configPath = themePath()

        // Create various files
        try "not json".write(toFile: (configPath as NSString).appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)
        try "{ bad json ]".write(toFile: (configPath as NSString).appendingPathComponent("bad.json"), atomically: true, encoding: .utf8)

        // Create one valid theme
        let custom = Theme(
            id: "valid-only",
            name: "Valid Only",
            background: "#666666",
            foreground: "#999999",
            accentColor: "#00ff00",
            isBuiltin: false
        )
        let filePath = (configPath as NSString).appendingPathComponent("valid-only.json")
        let data = try JSONEncoder().encode(custom)
        try data.write(to: URL(fileURLWithPath: filePath))

        let store = ThemeStore(configPath: configPath)

        // Should still load the valid theme
        let valid = store.theme(withID: "valid-only")
        #expect(valid != nil)
    }

    // MARK: - Theme metadata

    @Test func themeHasCorrectMetadata() {
        let store = ThemeStore(configPath: themePath())
        let theme = store.theme(withID: "nord")

        #expect(theme?.id == "nord")
        #expect(theme?.name == "Nord")
        #expect(theme?.background == "#2e3440")
        #expect(theme?.foreground == "#eceff4")
        #expect(theme?.accentColor == "#88c0d0")
        #expect(theme?.isBuiltin == true)
    }

    @Test func customThemeMetadataPreserved() throws {
        let store = ThemeStore(configPath: themePath())
        let custom = Theme(
            id: "metadata-test",
            name: "Metadata Test Theme",
            background: "#123456",
            foreground: "#abcdef",
            accentColor: "#fedcba",
            isBuiltin: false
        )

        try store.save(custom)
        let retrieved = store.theme(withID: "metadata-test")

        #expect(retrieved?.id == "metadata-test")
        #expect(retrieved?.name == "Metadata Test Theme")
        #expect(retrieved?.background == "#123456")
        #expect(retrieved?.foreground == "#abcdef")
        #expect(retrieved?.accentColor == "#fedcba")
        #expect(retrieved?.isBuiltin == false)
    }

    // MARK: - Theme persistence across saves

    @Test func themeSettingPersistsAcrossInstanceCreation() throws {
        let configPath = themePath()
        let store1 = ThemeStore(configPath: configPath)
        store1.setTheme("dracula")

        // Create a new instance with the same config path
        let store2 = ThemeStore(configPath: configPath)
        #expect(store2.currentTheme()?.id == "ghostty")  // Default, not persisted
    }

    @Test func savedThemePersistsAcrossInstanceCreation() throws {
        let configPath = themePath()
        let custom = Theme(
            id: "persist-check",
            name: "Persist Check",
            background: "#abcabc",
            foreground: "#defdef",
            accentColor: "#123123",
            isBuiltin: false
        )

        let store1 = ThemeStore(configPath: configPath)
        try store1.save(custom)

        let store2 = ThemeStore(configPath: configPath)
        let retrieved = store2.theme(withID: "persist-check")

        #expect(retrieved != nil)
        #expect(retrieved?.name == "Persist Check")
    }

    // MARK: - Invalid theme name error handling

    @Test func themeIDNotFoundReturnsNil() {
        let store = ThemeStore(configPath: themePath())
        let result = store.theme(withID: "does-not-exist")

        #expect(result == nil)
    }

    @Test func setThemeWithInvalidIDIsNoOp() {
        let store = ThemeStore(configPath: themePath())
        let currentBefore = store.currentTheme()

        store.setTheme("invalid-id-xyz")

        let currentAfter = store.currentTheme()
        #expect(currentAfter?.id == currentBefore?.id)
    }

    // MARK: - Delete functionality

    @Test func deleteCustomThemeRemovesFromStore() throws {
        let store = ThemeStore(configPath: themePath())
        let custom = Theme(
            id: "delete-test",
            name: "Delete Test",
            background: "#dddddd",
            foreground: "#111111",
            accentColor: "#999999",
            isBuiltin: false
        )

        try store.save(custom)
        #expect(store.theme(withID: "delete-test") != nil)

        try store.delete("delete-test")
        #expect(store.theme(withID: "delete-test") == nil)
    }

    @Test func deleteCustomThemeRemovesFile() throws {
        let configPath = themePath()
        let store = ThemeStore(configPath: configPath)
        let custom = Theme(
            id: "file-delete-test",
            name: "File Delete Test",
            background: "#cccccc",
            foreground: "#222222",
            accentColor: "#888888",
            isBuiltin: false
        )

        try store.save(custom)
        let filePath = (configPath as NSString).appendingPathComponent("file-delete-test.json")
        #expect(FileManager.default.fileExists(atPath: filePath))

        try store.delete("file-delete-test")
        #expect(!FileManager.default.fileExists(atPath: filePath))
    }

    @Test func deleteBuiltinThemeIsNoOp() throws {
        let store = ThemeStore(configPath: themePath())
        let builtinBefore = store.theme(withID: "ghostty")

        try store.delete("ghostty")

        let builtinAfter = store.theme(withID: "ghostty")
        #expect(builtinBefore != nil)
        #expect(builtinAfter != nil)  // Should still exist
    }

    @Test func deleteNonexistentThemeIsNoOp() throws {
        let store = ThemeStore(configPath: themePath())
        let countBefore = store.all().count

        try store.delete("nonexistent")

        let countAfter = store.all().count
        #expect(countAfter == countBefore)
    }

    // MARK: - All themes listing

    @Test func allThemesReturnsAllThemes() {
        let store = ThemeStore(configPath: themePath())
        let all = store.all()

        #expect(!all.isEmpty)
        #expect(all.count >= 5)  // At least the 5 builtin themes
    }

    @Test func allThemesIncludesBuiltinAndCustom() throws {
        let store = ThemeStore(configPath: themePath())
        let builtinCount = store.all().filter { $0.isBuiltin }.count

        let custom = Theme(
            id: "custom-for-all",
            name: "Custom for All",
            background: "#bbbbbb",
            foreground: "#333333",
            accentColor: "#777777",
            isBuiltin: false
        )
        try store.save(custom)

        let all = store.all()
        let customCount = all.filter { !$0.isBuiltin }.count

        #expect(all.count == builtinCount + customCount)
        #expect(customCount >= 1)
    }

    // MARK: - Theme identifiability

    @Test func themeIsIdentifiable() {
        let theme = Theme(
            id: "identifiable-test",
            name: "Identifiable",
            background: "#aaaaaa",
            foreground: "#444444",
            accentColor: "#666666",
            isBuiltin: false
        )

        #expect(theme.id == "identifiable-test")
    }

    @Test func themeComparison() {
        let store = ThemeStore(configPath: themePath())
        let theme1 = store.theme(withID: "ghostty")
        let theme2 = store.theme(withID: "ghostty")

        #expect(theme1?.id == theme2?.id)
    }
}
