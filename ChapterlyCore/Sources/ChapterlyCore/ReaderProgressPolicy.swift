import Foundation

public enum ReaderProgressPolicy {
    public static let minimumRestorableProgress = 0.02
    public static let maximumRestorableProgress = 0.90

    public static func shouldStore(_ progress: Double) -> Bool {
        progress >= 0 && progress <= maximumRestorableProgress
    }

    public static func shouldRestore(_ progress: Double) -> Bool {
        progress > minimumRestorableProgress && progress <= maximumRestorableProgress
    }
}
