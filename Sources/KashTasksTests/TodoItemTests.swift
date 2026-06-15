import Foundation
import KashTasksCore

func runTodoItemTests(_ t: TestRunner) {
    // Codable round-trip preserves every field.
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
    let data = try! encoder.encode(item)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try! decoder.decode(TodoItem.self, from: data)

    t.expectEqual(decoded, item, "TodoItem codable round-trip")

    // Priority sort rank: high < medium < low.
    t.expectLessThan(Priority.high.sortRank, Priority.medium.sortRank, "high < medium")
    t.expectLessThan(Priority.medium.sortRank, Priority.low.sortRank, "medium < low")
}
