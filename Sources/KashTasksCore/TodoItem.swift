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

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        priority: Priority = .medium,
        tag: String = "",
        dueDate: Date? = nil,
        isDone: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.priority = priority
        self.tag = tag
        self.dueDate = dueDate
        self.isDone = isDone
    }
}
