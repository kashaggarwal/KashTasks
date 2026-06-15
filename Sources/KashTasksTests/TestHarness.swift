import Foundation

/// Minimal test harness so tests run under Command Line Tools (no XCTest needed).
/// Each test group is a free function `runXxxTests(_ t: TestRunner)` that records
/// checks on the runner. `main.swift` calls every group and then `summarize()`.
final class TestRunner {
    private(set) var failures: [String] = []
    private var checks = 0

    func check(_ condition: Bool, _ message: @autoclosure () -> String) {
        checks += 1
        if !condition { failures.append(message()) }
    }

    func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ context: String = "") {
        checks += 1
        if actual != expected {
            failures.append("expectEqual failed [\(context)]: \(actual) != \(expected)")
        }
    }

    func expectTrue(_ value: Bool, _ context: String = "") {
        check(value, "expectTrue failed [\(context)]")
    }

    func expectFalse(_ value: Bool, _ context: String = "") {
        check(!value, "expectFalse failed [\(context)]")
    }

    func expectLessThan<T: Comparable>(_ a: T, _ b: T, _ context: String = "") {
        check(a < b, "expectLessThan failed [\(context)]: \(a) is not < \(b)")
    }

    func summarize() -> Never {
        if failures.isEmpty {
            print("✅ All checks passed (\(checks) checks)")
            exit(0)
        } else {
            print("❌ \(failures.count) failure(s) out of \(checks) checks:")
            for failure in failures { print("  - \(failure)") }
            exit(1)
        }
    }
}
