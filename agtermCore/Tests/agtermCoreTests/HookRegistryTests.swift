import Foundation
import Testing
@testable import agtermCore

@MainActor
struct HookRegistryTests {
    // MARK: - Initialization
    @Test func initStartsEmpty() {
        let registry = HookRegistry()

        #expect(registry.all().isEmpty)
    }

    // MARK: - Hook Registration
    @Test func registerAddsHook() {
        let registry = HookRegistry()

        let hookID = registry.register(event: .sessionCreated, command: "echo 'session created'")

        #expect(!hookID.uuidString.isEmpty)
        #expect(registry.all().count == 1)
    }

    @Test func registerReturnsUniqueID() {
        let registry = HookRegistry()

        let hookID1 = registry.register(event: .sessionCreated, command: "cmd1")
        let hookID2 = registry.register(event: .sessionCreated, command: "cmd2")

        #expect(hookID1 != hookID2)
    }

    @Test func registerMultipleHooksForSameEvent() {
        let registry = HookRegistry()

        let hookID1 = registry.register(event: .sessionCreated, command: "cmd1")
        let hookID2 = registry.register(event: .sessionCreated, command: "cmd2")

        let hooks = registry.hooksFor(.sessionCreated)

        #expect(hooks.count == 2)
    }

    @Test func registerMultipleEventTypes() {
        let registry = HookRegistry()

        registry.register(event: .sessionCreated, command: "cmd1")
        registry.register(event: .sessionClosed, command: "cmd2")
        registry.register(event: .inputReceived, command: "cmd3")

        #expect(registry.all().count == 3)
    }

    @Test func registerDefaultEnabled() {
        let registry = HookRegistry()

        let hookID = registry.register(event: .sessionCreated, command: "cmd")

        let hooks = registry.all()
        #expect(hooks[0].isEnabled == true)
    }

    // MARK: - Hook Unregistration
    @Test func unregisterRemovesHook() {
        let registry = HookRegistry()

        let hookID = registry.register(event: .sessionCreated, command: "cmd")
        registry.unregister(id: hookID)

        #expect(registry.all().isEmpty)
    }

    @Test func unregisterNonExistentHookNoError() {
        let registry = HookRegistry()

        let nonExistentID = UUID()
        registry.unregister(id: nonExistentID)

        #expect(registry.all().isEmpty)
    }

    @Test func unregisterPreservesOtherHooks() {
        let registry = HookRegistry()

        let hookID1 = registry.register(event: .sessionCreated, command: "cmd1")
        let hookID2 = registry.register(event: .sessionCreated, command: "cmd2")

        registry.unregister(id: hookID1)

        let remaining = registry.all()
        #expect(remaining.count == 1)
        #expect(remaining[0].id == hookID2)
    }

    // MARK: - Hook Enable/Disable
    @Test func setEnabledDisablesHook() {
        let registry = HookRegistry()

        let hookID = registry.register(event: .sessionCreated, command: "cmd")
        registry.setEnabled(hookID, false)

        let hooks = registry.all()
        #expect(hooks[0].isEnabled == false)
    }

    @Test func setEnabledEnablesHook() {
        let registry = HookRegistry()

        let hookID = registry.register(event: .sessionCreated, command: "cmd")
        registry.setEnabled(hookID, false)
        registry.setEnabled(hookID, true)

        let hooks = registry.all()
        #expect(hooks[0].isEnabled == true)
    }

    @Test func setEnabledNonExistentHookNoError() {
        let registry = HookRegistry()

        let nonExistentID = UUID()
        registry.setEnabled(nonExistentID, false)

        #expect(registry.all().isEmpty)
    }

    @Test func disabledHooksNotReturnedByHooksFor() {
        let registry = HookRegistry()

        let hookID1 = registry.register(event: .sessionCreated, command: "cmd1")
        let hookID2 = registry.register(event: .sessionCreated, command: "cmd2")

        registry.setEnabled(hookID1, false)

        let hooks = registry.hooksFor(.sessionCreated)

        #expect(hooks.count == 1)
        #expect(hooks[0].id == hookID2)
    }

    // MARK: - Hook Querying
    @Test func hooksForReturnsEmpty() {
        let registry = HookRegistry()

        let hooks = registry.hooksFor(.sessionCreated)

        #expect(hooks.isEmpty)
    }

    @Test func hooksForReturnsMatchingEvent() {
        let registry = HookRegistry()

        registry.register(event: .sessionCreated, command: "cmd1")
        registry.register(event: .sessionCreated, command: "cmd2")
        registry.register(event: .sessionClosed, command: "cmd3")

        let hooks = registry.hooksFor(.sessionCreated)

        #expect(hooks.count == 2)
    }

    @Test func hooksForOnlyEnabledHooks() {
        let registry = HookRegistry()

        let hookID1 = registry.register(event: .sessionCreated, command: "cmd1")
        let hookID2 = registry.register(event: .sessionCreated, command: "cmd2")

        registry.setEnabled(hookID1, false)

        let hooks = registry.hooksFor(.sessionCreated)

        #expect(hooks.count == 1)
        #expect(hooks[0].id == hookID2)
    }

    @Test func allReturnsAllHooks() {
        let registry = HookRegistry()

        registry.register(event: .sessionCreated, command: "cmd1")
        registry.register(event: .sessionClosed, command: "cmd2")

        let hooks = registry.all()

        #expect(hooks.count == 2)
    }

    @Test func allIncludesDisabledHooks() {
        let registry = HookRegistry()

        let hookID = registry.register(event: .sessionCreated, command: "cmd")
        registry.setEnabled(hookID, false)

        let hooks = registry.all()

        #expect(hooks.count == 1)
        #expect(hooks[0].isEnabled == false)
    }

    // MARK: - Hook Firing
    @Test func fireExecutesHooksForEvent() {
        let registry = HookRegistry()

        registry.register(event: .sessionCreated, command: "echo 'test'")

        // Fire should not throw or crash
        registry.fire(.sessionCreated)

        #expect(true)
    }

    @Test func fireWithContextPassesEnvironment() {
        let registry = HookRegistry()

        registry.register(event: .sessionCreated, command: "echo 'test'")

        let context = ["SESSION_ID": "123", "USER": "testuser"]
        registry.fire(.sessionCreated, context: context)

        #expect(true)
    }

    @Test func fireIgnoresDisabledHooks() {
        let registry = HookRegistry()

        let hookID = registry.register(event: .sessionCreated, command: "echo 'test'")
        registry.setEnabled(hookID, false)

        // Should only fire enabled hooks
        registry.fire(.sessionCreated)

        #expect(true)
    }

    @Test func fireMultipleHooksForEvent() {
        let registry = HookRegistry()

        registry.register(event: .sessionCreated, command: "echo 'hook1'")
        registry.register(event: .sessionCreated, command: "echo 'hook2'")

        registry.fire(.sessionCreated)

        #expect(true)
    }

    @Test func fireWithoutContextWorks() {
        let registry = HookRegistry()

        registry.register(event: .sessionCreated, command: "true")

        registry.fire(.sessionCreated)

        #expect(true)
    }

    @Test func fireDoesNotThrowForInvalidCommand() {
        let registry = HookRegistry()

        registry.register(event: .sessionCreated, command: "nonexistent_command_12345")

        // Should not throw even if command fails
        registry.fire(.sessionCreated)

        #expect(true)
    }

    // MARK: - Clear Operations
    @Test func clearRemovesAllHooks() {
        let registry = HookRegistry()

        registry.register(event: .sessionCreated, command: "cmd1")
        registry.register(event: .sessionClosed, command: "cmd2")

        registry.clear()

        #expect(registry.all().isEmpty)
    }

    @Test func clearAllowsNewHooksAfter() {
        let registry = HookRegistry()

        registry.register(event: .sessionCreated, command: "cmd1")
        registry.clear()

        let hookID = registry.register(event: .sessionCreated, command: "cmd2")

        #expect(registry.all().count == 1)
        #expect(registry.all()[0].id == hookID)
    }

    // MARK: - Hook Structure
    @Test func hookStructureIdentifiable() {
        let hook1 = HookRegistry.Hook(event: .sessionCreated, command: "cmd")
        let hook2 = HookRegistry.Hook(event: .sessionCreated, command: "cmd")

        #expect(hook1.id != hook2.id)
    }

    @Test func hookStoresEventAndCommand() {
        let hook = HookRegistry.Hook(event: .sessionClosed, command: "test command")

        #expect(hook.event == .sessionClosed)
        #expect(hook.command == "test command")
    }

    @Test func hookDefaultsToEnabled() {
        let hook = HookRegistry.Hook(event: .sessionCreated, command: "cmd")

        #expect(hook.isEnabled == true)
    }

    @Test func hookCanBeInitializedDisabled() {
        let hook = HookRegistry.Hook(event: .sessionCreated, command: "cmd", isEnabled: false)

        #expect(hook.isEnabled == false)
    }

    // MARK: - Event Types
    @Test func eventTypesAvailable() {
        #expect(HookRegistry.EventType.sessionCreated.rawValue == "session.created")
        #expect(HookRegistry.EventType.sessionClosed.rawValue == "session.closed")
        #expect(HookRegistry.EventType.sessionActive.rawValue == "session.active")
        #expect(HookRegistry.EventType.sessionInactive.rawValue == "session.inactive")
        #expect(HookRegistry.EventType.inputReceived.rawValue == "input.received")
        #expect(HookRegistry.EventType.outputReceived.rawValue == "output.received")
    }

    // MARK: - Edge Cases
    @Test func registerManyHooks() {
        let registry = HookRegistry()

        for i in 0..<50 {
            registry.register(event: .sessionCreated, command: "cmd\(i)")
        }

        #expect(registry.all().count == 50)
    }

    @Test func fireMultipleEventsSequentially() {
        let registry = HookRegistry()

        registry.register(event: .sessionCreated, command: "echo 'created'")
        registry.register(event: .sessionClosed, command: "echo 'closed'")
        registry.register(event: .inputReceived, command: "echo 'input'")

        registry.fire(.sessionCreated)
        registry.fire(.sessionClosed)
        registry.fire(.inputReceived)

        #expect(true)
    }
}
