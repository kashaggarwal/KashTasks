import Foundation
import KashTasksCore

func runTodoItemRecurrenceTests(_ t: TestRunner) {
    t.expectEqual(TodoItem(title: "x").recurrence, Recurrence.none, "default recurrence none")

    let item = TodoItem(title: "standup", priority: .medium, tag: "Work",
                        dueDate: Date(timeIntervalSince1970: 1_000), recurrence: .weekdays)
    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let data = try! enc.encode(item)
    let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
    let decoded = try! dec.decode(TodoItem.self, from: data)
    t.expectEqual(decoded, item, "recurrence survives round-trip")

    let legacy = """
    {"id":"\(UUID().uuidString)","title":"legacy","notes":"","priority":"high","tag":"","isDone":false}
    """.data(using: .utf8)!
    let legacyDecoded = try! dec.decode(TodoItem.self, from: legacy)
    t.expectEqual(legacyDecoded.recurrence, Recurrence.none, "legacy JSON -> recurrence none")
    t.expectEqual(legacyDecoded.title, "legacy", "legacy JSON decodes other fields")
}
