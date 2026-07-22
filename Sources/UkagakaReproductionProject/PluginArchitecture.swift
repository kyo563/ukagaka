import Foundation

enum PluginCapability: String, Codable, CaseIterable, Sendable {
    case eventSource
    case command
    case conversationContext
    case notificationAction
    case settings
}

enum PluginPermission: String, Codable, CaseIterable, Sendable {
    case network
    case keychain
    case notifications
    case calendar
    case contacts
    case files
    case automation
}

struct PluginManifest: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let version: String
    let capabilities: Set<PluginCapability>
    let requiredPermissions: Set<PluginPermission>
    let defaultPollingInterval: TimeInterval?

    init(
        id: String,
        name: String,
        version: String,
        capabilities: Set<PluginCapability>,
        requiredPermissions: Set<PluginPermission> = [],
        defaultPollingInterval: TimeInterval? = nil
    ) {
        precondition(id.contains("."), "Plugin ID must use a reverse-DNS style identifier.")
        self.id = id
        self.name = name
        self.version = version
        self.capabilities = capabilities
        self.requiredPermissions = requiredPermissions
        self.defaultPollingInterval = defaultPollingInterval
    }
}

enum CompanionEventKind: String, Codable, CaseIterable, Sendable {
    case mail
    case social
    case video
    case live
    case news
    case calendar
    case system
    case conversation
}

enum CompanionEventPriority: Int, Codable, Comparable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: CompanionEventPriority, rhs: CompanionEventPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum SuggestedSpeaker: String, Codable, Sendable {
    case characterA
    case characterB
    case automatic
}

enum PluginActionKind: String, Codable, Sendable {
    case openURL
    case markRead
    case dismiss
    case remindLater
    case custom
}

struct PluginAction: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let kind: PluginActionKind
    let payload: [String: String]

    init(id: String, title: String, kind: PluginActionKind, payload: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.kind = kind
        self.payload = payload
    }
}

struct CompanionEvent: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let pluginID: String
    let kind: CompanionEventKind
    let title: String
    let body: String
    let sourceName: String
    let sourceURL: URL?
    let occurredAt: Date
    let priority: CompanionEventPriority
    let deduplicationKey: String
    let suggestedSpeaker: SuggestedSpeaker
    let metadata: [String: String]
    let actions: [PluginAction]

    init(
        id: String,
        pluginID: String,
        kind: CompanionEventKind,
        title: String,
        body: String,
        sourceName: String,
        sourceURL: URL? = nil,
        occurredAt: Date = Date(),
        priority: CompanionEventPriority = .normal,
        deduplicationKey: String,
        suggestedSpeaker: SuggestedSpeaker = .automatic,
        metadata: [String: String] = [:],
        actions: [PluginAction] = []
    ) {
        self.id = id
        self.pluginID = pluginID
        self.kind = kind
        self.title = title
        self.body = body
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.occurredAt = occurredAt
        self.priority = priority
        self.deduplicationKey = deduplicationKey
        self.suggestedSpeaker = suggestedSpeaker
        self.metadata = metadata
        self.actions = actions
    }
}

struct PluginFetchContext: Sendable {
    let now: Date
    let lastSuccessfulFetch: Date?
    let locale: Locale
    let timeZone: TimeZone

    init(
        now: Date = Date(),
        lastSuccessfulFetch: Date? = nil,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) {
        self.now = now
        self.lastSuccessfulFetch = lastSuccessfulFetch
        self.locale = locale
        self.timeZone = timeZone
    }
}

struct PluginCommand: Sendable {
    let name: String
    let arguments: [String: String]

    init(name: String, arguments: [String: String] = [:]) {
        self.name = name
        self.arguments = arguments
    }
}

struct PluginCommandResult: Sendable {
    let message: String
    let generatedEvents: [CompanionEvent]

    init(message: String, generatedEvents: [CompanionEvent] = []) {
        self.message = message
        self.generatedEvents = generatedEvents
    }
}

protocol CompanionPlugin: Sendable {
    var manifest: PluginManifest { get }
    func start() async throws
    func stop() async
}

extension CompanionPlugin {
    func start() async throws {}
    func stop() async {}
}

protocol EventSourcePlugin: CompanionPlugin {
    func fetchEvents(context: PluginFetchContext) async throws -> [CompanionEvent]
}

protocol CommandPlugin: CompanionPlugin {
    func canHandle(_ command: PluginCommand) -> Bool
    func execute(_ command: PluginCommand) async throws -> PluginCommandResult
}

protocol ConversationContextPlugin: CompanionPlugin {
    func conversationContext(for userInput: String) async throws -> String?
}

struct AnyEventSourcePlugin: Sendable {
    let manifest: PluginManifest
    private let startHandler: @Sendable () async throws -> Void
    private let stopHandler: @Sendable () async -> Void
    private let fetchHandler: @Sendable (PluginFetchContext) async throws -> [CompanionEvent]

    init<P: EventSourcePlugin>(_ plugin: P) {
        manifest = plugin.manifest
        startHandler = { try await plugin.start() }
        stopHandler = { await plugin.stop() }
        fetchHandler = { context in try await plugin.fetchEvents(context: context) }
    }

    func start() async throws {
        try await startHandler()
    }

    func stop() async {
        await stopHandler()
    }

    func fetchEvents(context: PluginFetchContext) async throws -> [CompanionEvent] {
        try await fetchHandler(context)
    }
}

struct AnyCommandPlugin: Sendable {
    let manifest: PluginManifest
    private let canHandleHandler: @Sendable (PluginCommand) -> Bool
    private let executeHandler: @Sendable (PluginCommand) async throws -> PluginCommandResult

    init<P: CommandPlugin>(_ plugin: P) {
        manifest = plugin.manifest
        canHandleHandler = { command in plugin.canHandle(command) }
        executeHandler = { command in try await plugin.execute(command) }
    }

    func canHandle(_ command: PluginCommand) -> Bool {
        canHandleHandler(command)
    }

    func execute(_ command: PluginCommand) async throws -> PluginCommandResult {
        try await executeHandler(command)
    }
}

actor PluginRegistry {
    enum RegistryError: LocalizedError {
        case duplicatePluginID(String)

        var errorDescription: String? {
            switch self {
            case let .duplicatePluginID(id):
                return "同じプラグインIDが既に登録されています: \(id)"
            }
        }
    }

    private var eventSources: [String: AnyEventSourcePlugin] = [:]
    private var commandPlugins: [String: AnyCommandPlugin] = [:]
    private var enabledPluginIDs: Set<String> = []

    func register<P: EventSourcePlugin>(_ plugin: P, enabled: Bool = true) throws {
        try ensureUniqueCapabilityRegistration(plugin.manifest.id, in: eventSources.keys)
        eventSources[plugin.manifest.id] = AnyEventSourcePlugin(plugin)
        if enabled { enabledPluginIDs.insert(plugin.manifest.id) }
    }

    func register<P: CommandPlugin>(_ plugin: P, enabled: Bool = true) throws {
        try ensureUniqueCapabilityRegistration(plugin.manifest.id, in: commandPlugins.keys)
        commandPlugins[plugin.manifest.id] = AnyCommandPlugin(plugin)
        if enabled { enabledPluginIDs.insert(plugin.manifest.id) }
    }

    func setEnabled(_ enabled: Bool, pluginID: String) {
        if enabled {
            enabledPluginIDs.insert(pluginID)
        } else {
            enabledPluginIDs.remove(pluginID)
        }
    }

    func enabledEventSources() -> [AnyEventSourcePlugin] {
        eventSources.values
            .filter { enabledPluginIDs.contains($0.manifest.id) }
            .sorted { $0.manifest.name.localizedStandardCompare($1.manifest.name) == .orderedAscending }
    }

    func commandHandler(for command: PluginCommand) -> AnyCommandPlugin? {
        commandPlugins.values.first {
            enabledPluginIDs.contains($0.manifest.id) && $0.canHandle(command)
        }
    }

    func manifests() -> [PluginManifest] {
        var manifestsByID: [String: PluginManifest] = [:]
        eventSources.values.forEach { manifestsByID[$0.manifest.id] = $0.manifest }
        commandPlugins.values.forEach { manifestsByID[$0.manifest.id] = $0.manifest }
        return manifestsByID.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func ensureUniqueCapabilityRegistration<S: Sequence>(_ id: String, in ids: S) throws where S.Element == String {
        if ids.contains(id) {
            throw RegistryError.duplicatePluginID(id)
        }
    }
}

struct EventDeliveryPolicy: Sendable {
    let quietHoursStart: Int?
    let quietHoursEnd: Int?
    let minimumImmediatePriority: CompanionEventPriority

    init(
        quietHoursStart: Int? = nil,
        quietHoursEnd: Int? = nil,
        minimumImmediatePriority: CompanionEventPriority = .high
    ) {
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.minimumImmediatePriority = minimumImmediatePriority
    }

    func isQuietHour(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard let start = quietHoursStart, let end = quietHoursEnd else { return false }
        let hour = calendar.component(.hour, from: date)
        if start == end { return true }
        if start < end { return hour >= start && hour < end }
        return hour >= start || hour < end
    }
}

actor EventPipeline {
    enum Decision: Equatable, Sendable {
        case deliverImmediately
        case queueForDigest
        case discardDuplicate
    }

    private var deliveredKeys: Set<String> = []
    private let policy: EventDeliveryPolicy

    init(policy: EventDeliveryPolicy = EventDeliveryPolicy()) {
        self.policy = policy
    }

    func evaluate(_ event: CompanionEvent, now: Date = Date()) -> Decision {
        guard !deliveredKeys.contains(event.deduplicationKey) else {
            return .discardDuplicate
        }
        deliveredKeys.insert(event.deduplicationKey)

        if event.priority == .critical {
            return .deliverImmediately
        }
        if policy.isQuietHour(now) {
            return .queueForDigest
        }
        return event.priority >= policy.minimumImmediatePriority
            ? .deliverImmediately
            : .queueForDigest
    }

    func resetDeduplicationHistory() {
        deliveredKeys.removeAll()
    }
}
