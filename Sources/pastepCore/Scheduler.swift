import Foundation

/// 遅延実行の抽象。テストでは手動で進める実装に差し替える。
public protocol Scheduler {
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void)
}

public struct MainQueueScheduler: Scheduler {
    public init() {}

    public func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

func logError(_ message: String) {
    FileHandle.standardError.write(Data("[pastep] \(message)\n".utf8))
}
