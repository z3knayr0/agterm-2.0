import Foundation
import Testing
@testable import agtermCore

@MainActor
struct TemplateLibraryTests {
    // MARK: - Initialization
    @Test func initLoadsBuiltinTemplates() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_templates")

        let library = TemplateLibrary(configPath: testConfigPath)

        let templates = library.all()

        #expect(templates.count >= 5)
    }

    @Test func initIncludesBashTemplate() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_bash")

        let library = TemplateLibrary(configPath: testConfigPath)

        let templates = library.all()
        let bashTemplate = templates.first { $0.name == "Bash" }

        #expect(bashTemplate != nil)
        #expect(bashTemplate?.command == "/bin/bash")
    }

    @Test func initIncludesZshTemplate() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_zsh")

        let library = TemplateLibrary(configPath: testConfigPath)

        let templates = library.all()
        let zshTemplate = templates.first { $0.name == "Zsh" }

        #expect(zshTemplate != nil)
        #expect(zshTemplate?.command == "/bin/zsh")
    }

    @Test func initIncludesInterpreterTemplates() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_interp")

        let library = TemplateLibrary(configPath: testConfigPath)

        let templates = library.all()
        let pythonTemplate = templates.first { $0.name == "Python REPL" }
        let nodeTemplate = templates.first { $0.name == "Node REPL" }

        #expect(pythonTemplate != nil)
        #expect(nodeTemplate != nil)
    }

    // MARK: - Builtin Templates
    @Test func builtinTemplatesMarkedAsBuiltin() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_builtin")

        let library = TemplateLibrary(configPath: testConfigPath)

        let templates = library.all()

        for template in templates where template.name == "Bash" || template.name == "Zsh" {
            #expect(template.isBuiltin == true)
        }
    }

    // MARK: - Template Retrieval
    @Test func templateWithIDReturnsBashTemplate() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_retrieve")

        let library = TemplateLibrary(configPath: testConfigPath)

        let templates = library.all()
        let bash = templates.first { $0.name == "Bash" }!
        let retrieved = library.template(withID: bash.id)

        #expect(retrieved != nil)
        #expect(retrieved?.name == "Bash")
    }

    @Test func templateWithIDReturnsNilForNonExistent() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_nonexist")

        let library = TemplateLibrary(configPath: testConfigPath)

        let fakeID = UUID()
        let retrieved = library.template(withID: fakeID)

        #expect(retrieved == nil)
    }

    @Test func allReturnsAllTemplates() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_all")

        let library = TemplateLibrary(configPath: testConfigPath)

        let templates = library.all()

        #expect(templates.count >= 5)
        #expect(templates.contains { $0.name == "Bash" })
        #expect(templates.contains { $0.name == "Zsh" })
    }

    // MARK: - Template Application
    @Test func applyReturnsCommandForTemplate() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_apply")

        let library = TemplateLibrary(configPath: testConfigPath)

        let templates = library.all()
        let bash = templates.first { $0.name == "Bash" }!

        let applied = library.apply(bash.id)

        #expect(applied != nil)
        #expect(applied?.command == "/bin/bash")
    }

    @Test func applyReturnsWorkingDirectory() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_apply_cwd")

        let library = TemplateLibrary(configPath: testConfigPath)

        let templates = library.all()
        let bash = templates.first { $0.name == "Bash" }!

        let applied = library.apply(bash.id)

        #expect(applied?.cwd == nil) // Builtin has no cwd
    }

    @Test func applyReturnsNilForNonExistent() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_apply_nil")

        let library = TemplateLibrary(configPath: testConfigPath)

        let fakeID = UUID()
        let applied = library.apply(fakeID)

        #expect(applied == nil)
    }

    @Test func applyReturnsEnvironment() {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_apply_env")

        let library = TemplateLibrary(configPath: testConfigPath)

        let templates = library.all()
        let bash = templates.first { $0.name == "Bash" }!

        let applied = library.apply(bash.id)

        #expect(applied?.environment == nil) // Builtin has no env
    }

    // MARK: - Custom Template Save
    @Test func saveCustomTemplate() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_save_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        let customTemplate = TemplateLibrary.Template(
            name: "Custom Shell",
            description: "My custom shell",
            command: "/usr/local/bin/custom",
            workingDir: "/home/user",
            environment: ["SHELL": "custom"],
            isBuiltin: false
        )

        try library.save(customTemplate)

        let saved = library.template(withID: customTemplate.id)

        #expect(saved != nil)
        #expect(saved?.name == "Custom Shell")

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }

    @Test func saveTemplateWritesToDisk() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_disk_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        let customTemplate = TemplateLibrary.Template(
            name: "Disk Test",
            description: "Test disk write",
            command: "test",
            isBuiltin: false
        )

        try library.save(customTemplate)

        let fileName = customTemplate.id.uuidString + ".json"
        let filePath = (testConfigPath as NSString).appendingPathComponent(fileName)

        #expect(FileManager.default.fileExists(atPath: filePath))

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }

    @Test func saveTemplateCanBeRetrieved() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_retrieve_saved_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        let customTemplate = TemplateLibrary.Template(
            name: "Retrievable",
            description: "Can retrieve",
            command: "test",
            isBuiltin: false
        )

        try library.save(customTemplate)

        let retrieved = library.template(withID: customTemplate.id)

        #expect(retrieved?.name == "Retrievable")
        #expect(retrieved?.description == "Can retrieve")

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }

    @Test func saveSetsWorkingDirectoryCorrectly() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_cwd_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        let customTemplate = TemplateLibrary.Template(
            name: "With CWD",
            description: "Has working dir",
            command: "test",
            workingDir: "/tmp/test",
            isBuiltin: false
        )

        try library.save(customTemplate)

        let retrieved = library.template(withID: customTemplate.id)

        #expect(retrieved?.workingDir == "/tmp/test")

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }

    @Test func saveSetsEnvironmentCorrectly() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_env_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        let env = ["VAR1": "value1", "VAR2": "value2"]
        let customTemplate = TemplateLibrary.Template(
            name: "With Env",
            description: "Has environment",
            command: "test",
            environment: env,
            isBuiltin: false
        )

        try library.save(customTemplate)

        let retrieved = library.template(withID: customTemplate.id)

        #expect(retrieved?.environment == env)

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }

    // MARK: - Custom Template Delete
    @Test func deleteRemovesCustomTemplate() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_delete_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        let customTemplate = TemplateLibrary.Template(
            name: "To Delete",
            description: "Will be deleted",
            command: "test",
            isBuiltin: false
        )

        try library.save(customTemplate)
        try library.delete(customTemplate.id)

        let deleted = library.template(withID: customTemplate.id)

        #expect(deleted == nil)

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }

    @Test func deleteRemovesFileFromDisk() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_delete_disk_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        let customTemplate = TemplateLibrary.Template(
            name: "File Delete",
            description: "File will be deleted",
            command: "test",
            isBuiltin: false
        )

        try library.save(customTemplate)
        let fileName = customTemplate.id.uuidString + ".json"
        let filePath = (testConfigPath as NSString).appendingPathComponent(fileName)

        #expect(FileManager.default.fileExists(atPath: filePath))

        try library.delete(customTemplate.id)

        #expect(!FileManager.default.fileExists(atPath: filePath))

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }

    @Test func deleteCannotRemoveBuiltinTemplate() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_delete_builtin_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        let templates = library.all()
        let bash = templates.first { $0.name == "Bash" }!

        try library.delete(bash.id)

        let stillThere = library.template(withID: bash.id)

        #expect(stillThere != nil)

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }

    @Test func deleteNonExistentTemplateSafe() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_delete_nonexist_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        let fakeID = UUID()

        try library.delete(fakeID)

        #expect(true)

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }

    // MARK: - Template Structure
    @Test func templateIsIdentifiable() {
        let template1 = TemplateLibrary.Template(
            name: "Test1",
            description: "Desc1",
            command: "cmd1"
        )
        let template2 = TemplateLibrary.Template(
            name: "Test2",
            description: "Desc2",
            command: "cmd2"
        )

        #expect(template1.id != template2.id)
    }

    @Test func templateIsCodable() throws {
        let template = TemplateLibrary.Template(
            name: "Codable",
            description: "Can encode/decode",
            command: "test",
            workingDir: "/tmp",
            environment: ["VAR": "value"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(template)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TemplateLibrary.Template.self, from: data)

        #expect(decoded.name == "Codable")
        #expect(decoded.description == "Can encode/decode")
    }

    @Test func templateStoresMetadata() {
        let template = TemplateLibrary.Template(
            name: "Metadata Test",
            description: "Test description",
            command: "/bin/test",
            workingDir: "/work",
            environment: ["K": "V"],
            isBuiltin: false
        )

        #expect(template.name == "Metadata Test")
        #expect(template.description == "Test description")
        #expect(template.command == "/bin/test")
        #expect(template.workingDir == "/work")
        #expect(template.environment == ["K": "V"])
        #expect(template.isBuiltin == false)
    }

    // MARK: - Edge Cases
    @Test func saveAndLoadLargeEnvironment() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_large_env_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        var largeEnv: [String: String] = [:]
        for i in 0..<50 {
            largeEnv["VAR\(i)"] = "value\(i)"
        }

        let template = TemplateLibrary.Template(
            name: "Large Env",
            description: "Many env vars",
            command: "test",
            environment: largeEnv,
            isBuiltin: false
        )

        try library.save(template)
        let retrieved = library.template(withID: template.id)

        #expect(retrieved?.environment?.count == 50)

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }

    @Test func multipleCustomTemplatesCoexist() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_multiple_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        for i in 0..<5 {
            let template = TemplateLibrary.Template(
                name: "Custom \(i)",
                description: "Custom template \(i)",
                command: "cmd\(i)",
                isBuiltin: false
            )
            try library.save(template)
        }

        let allTemplates = library.all()
        let customCount = allTemplates.filter { !$0.isBuiltin }.count

        #expect(customCount == 5)

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }

    @Test func templateWithEmptyDescription() throws {
        let tempDir = NSTemporaryDirectory()
        let testConfigPath = (tempDir as NSString).appendingPathComponent("agterm_test_empty_desc_\(UUID())")

        let library = TemplateLibrary(configPath: testConfigPath)

        let template = TemplateLibrary.Template(
            name: "No Description",
            description: "",
            command: "test",
            isBuiltin: false
        )

        try library.save(template)
        let retrieved = library.template(withID: template.id)

        #expect(retrieved?.description == "")

        try? FileManager.default.removeItem(atPath: testConfigPath)
    }
}
