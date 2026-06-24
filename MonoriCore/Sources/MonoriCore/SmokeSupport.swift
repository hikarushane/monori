import Foundation

/// Pure helpers for the debug-only smoke autopilot. Kept in MonoriCore so the
/// log-line format and tolerance logic are unit-testable without a simulator.
public enum SmokeCheck {
    public static func approximatelyEqual(_ a: Double, _ b: Double, tolerance: Double) -> Bool {
        abs(a - b) <= tolerance
    }
}

public enum SmokeReport {
    /// Machine-parseable step line: `step=<name> result=pass|fail [reason=<reason>]`.
    /// Reasons never contain spaces so the driver script can parse with a simple regex.
    public static func stepLine(step: String, pass: Bool, reason: String?) -> String {
        var line = "step=\(step) result=\(pass ? "pass" : "fail")"
        if !pass, let reason {
            line += " reason=\(reason.replacingOccurrences(of: " ", with: "_"))"
        }
        return line
    }
}
