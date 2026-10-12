import Foundation

/// ペーストに必要な OS 操作。macOS 実装は pastepMac の `MacPasteSystem`。
public protocol PasteSystem: AnyObject {
    /// 自動ペースト（⌘V の送信）が許可されているか（アクセシビリティ権限）
    var canPostKeystrokes: Bool { get }
    var ownPID: Int32 { get }
    func frontmostPID() -> Int32?
    func write(_ entry: ClipboardEntry)
    func activate(pid: Int32)
    func postPasteKeystroke()
}

/// 選択された履歴をペーストボードにセットし、元のアプリへ ⌘V を送る。
public final class PasteCoordinator {
    public enum Outcome: Equatable {
        /// ペーストボードへのコピーのみ（権限がないため ⌘V は送らない）
        case copiedOnly
        /// ⌘V の送信を予約した
        case pasteScheduled
    }

    private let system: PasteSystem
    private let scheduler: Scheduler
    let pasteDelay: TimeInterval
    let activationDelay: TimeInterval

    public init(
        system: PasteSystem,
        scheduler: Scheduler = MainQueueScheduler(),
        pasteDelay: TimeInterval = 0.05,
        activationDelay: TimeInterval = 0.15
    ) {
        self.system = system
        self.scheduler = scheduler
        self.pasteDelay = pasteDelay
        self.activationDelay = activationDelay
    }

    /// - Parameter target: メニューを開いた時点で最前面だったアプリの PID
    @discardableResult
    public func paste(_ entry: ClipboardEntry, into target: Int32?) -> Outcome {
        system.write(entry)
        guard system.canPostKeystrokes else { return .copiedOnly }

        var delay = pasteDelay
        if let target, target != system.ownPID, system.frontmostPID() != target {
            system.activate(pid: target)
            delay = activationDelay
        }
        scheduler.schedule(after: delay) { [system] in
            system.postPasteKeystroke()
        }
        return .pasteScheduled
    }
}
