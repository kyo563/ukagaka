import XCTest
@testable import UkagakaReproductionProject

final class PluginArchitectureTests: XCTestCase {
    func testRegistryReturnsEnabledEventSource() async throws {
        let registry = PluginRegistry()
        let plugin = MockEventPlugin()

        try await registry.register(plugin)
        let sources = await registry.enabledEventSources()

        XCTAssertEqual(sources.map(\.manifest.id), [plugin.manifest.id])
    }

    func testDisabledPluginIsNotReturned() async throws {
        let registry = PluginRegistry()
        let plugin = MockEventPlugin()

        try await registry.register(plugin)
        await registry.setEnabled(false, pluginID: plugin.manifest.id)

        XCTAssertTrue(await registry.enabledEventSources().isEmpty)
    }

    func testPipelineDiscardsDuplicateEvent() async {
        let pipeline = EventPipeline()
        let event = MockEventPlugin.makeEvent(priority: .high)

        let first = await pipeline.evaluate(event)
        let second = await pipeline.evaluate(event)

        XCTAssertEqual(first, .deliverImmediately)
        XCTAssertEqual(second, .discardDuplicate)
    }

    func testCriticalEventBypassesQuietHours() async {
        let policy = EventDeliveryPolicy(
            quietHoursStart: 0,
            quietHoursEnd: 0,
            minimumImmediatePriority: .high
        )
        let pipeline = EventPipeline(policy: policy)
        let event = MockEventPlugin.makeEvent(priority: .critical)

        XCTAssertEqual(await pipeline.evaluate(event), .deliverImmediately)
    }

    func testNormalEventIsQueuedForDigest() async {
        let pipeline = EventPipeline()
        let event = MockEventPlugin.makeEvent(priority: .normal)

        XCTAssertEqual(await pipeline.evaluate(event), .queueForDigest)
    }
}

private struct MockEventPlugin: EventSourcePlugin {
    let manifest = PluginManifest(
        id: "jp.kyo563.ukagaka.mock-events",
        name: "Mock Events",
        version: "1.0.0",
        capabilities: [.eventSource],
        defaultPollingInterval: 300
    )

    func fetchEvents(context: PluginFetchContext) async throws -> [CompanionEvent] {
        [Self.makeEvent(priority: .normal)]
    }

    static func makeEvent(priority: CompanionEventPriority) -> CompanionEvent {
        CompanionEvent(
            id: "event-1",
            pluginID: "jp.kyo563.ukagaka.mock-events",
            kind: .system,
            title: "テスト通知",
            body: "プラグイン基盤のテスト通知です。",
            sourceName: "Mock Events",
            priority: priority,
            deduplicationKey: "mock:event-1"
        )
    }
}
