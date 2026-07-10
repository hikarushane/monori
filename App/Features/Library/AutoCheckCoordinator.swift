import Foundation
import MonoriCore

/// Drives foreground new-chapter checks over the offscreen refresher, one
/// collection at a time. Scheduling decisions live in AutoCheckScheduler
/// (MonoriCore, unit-tested); this class only sequences and reports.
@MainActor
@Observable
final class AutoCheckCoordinator {
    private unowned let env: AppEnvironment
    @ObservationIgnored private var runTask: Task<Void, Never>?

    private(set) var isRunning = false
    private(set) var checkedCount = 0
    private(set) var totalCount = 0
    /// Collections whose last check hit a login wall (session-scoped, not persisted).
    private(set) var needsLoginCollectionIDs: Set<String> = []
    private var blockedKindsThisRound: Set<SourceKind> = []

    init(env: AppEnvironment) {
        self.env = env
    }

    /// Library appear / app foreground: respects the 6 h cooldown.
    func runIfDue() {
        start(force: false)
    }

    /// Pull-to-refresh: ignores the cooldown, awaits round completion.
    func runForced() async {
        start(force: true)
        await runTask?.value
    }

    func cancel() {
        runTask?.cancel()
    }

    private func start(force: Bool) {
        guard !isRunning,
              env.appPrefs.autoCheckEnabled,
              !AppEnvironment.isSmokeMode,
              !AppEnvironment.isAutopilot else { return }
        let due = AutoCheckScheduler.due(from: (try? env.store.collections()) ?? [], force: force)
        guard !due.isEmpty else { return }
        isRunning = true
        checkedCount = 0
        totalCount = due.count
        blockedKindsThisRound = []
        DiagnosticLog.shared.log(category: "refresh", "auto-check round: \(due.count) collections")
        runTask = Task { await run(due) }
    }

    private func run(_ due: [LocalCollectionModel]) async {
        // Clear runTask on every exit path so a later runForced() whose start()
        // is guard-blocked awaits nil (immediate return) rather than a stale,
        // already-finished task that would look like a fresh completed round.
        defer { isRunning = false; runTask = nil }
        for collection in due {
            if Task.isCancelled { break }
            checkedCount += 1
            if blockedKindsThisRound.contains(collection.sourceKind) { continue }
            let outcome = await env.refreshCollection(collection)
            env.store.recordCheck(collection)
            switch outcome {
            case .newChapters, .upToDate:
                needsLoginCollectionIDs.remove(collection.id)
            case .needsLogin:
                needsLoginCollectionIDs.insert(collection.id)
            case .blocked:
                blockedKindsThisRound.insert(collection.sourceKind)
            case .failed, .unsupported:
                break
            }
            // Etiquette pause between collections; also yields the main actor.
            try? await Task.sleep(for: .seconds(3))
        }
        DiagnosticLog.shared.log(category: "refresh", "auto-check round finished")
    }
}
