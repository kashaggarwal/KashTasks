import Foundation

public enum Priority: String, Codable, CaseIterable, Sendable {
    case high, medium, low

    public var sortRank: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    public var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

public struct TodoItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var priority: Priority
    public var tag: String
    public var dueDate: Date?
    public var isDone: Bool
    public var recurrence: Recurrence

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        priority: Priority = .medium,
        tag: String = "",
        dueDate: Date? = nil,
        isDone: Bool = false,
        recurrence: Recurrence = .none
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.priority = priority
        self.tag = tag
        self.dueDate = dueDate
        self.isDone = isDone
        self.recurrence = recurrence
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, notes, priority, tag, dueDate, isDone, recurrence
    }

    // Custom decode so legacy tasks.json files (no "recurrence" key) still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        priority = try c.decodeIfPresent(Priority.self, forKey: .priority) ?? .medium
        tag = try c.decodeIfPresent(String.self, forKey: .tag) ?? ""
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        recurrence = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence) ?? .none
    }
}
