import XCTest
@testable import KashTasksCore

final class TodoItemTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let item = TodoItem(
            title: "Buy milk",
            notes: "2%",
            priority: .high,
            tag: "Errands",
            dueDate: Date(timeIntervalSince1970: 1_000_000),
            isDone: false
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TodoItem.self, from: data)

        XCTAssertEqual(decoded, item)
    }

    func testPrioritySortRankOrder() {
        XCTAssertLessThan(Priority.high.sortRank, Priority.medium.sortRank)
        XCTAssertLessThan(Priority.medium.sortRank, Priority.low.sortRank)
    }
}
