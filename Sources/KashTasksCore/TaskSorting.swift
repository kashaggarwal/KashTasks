import Foundation

public enum TaskSorting {
    public struct Group: Equatable {
        public let tag: String
        public let items: [TodoItem]
    }

    public static func grouped(_ items: [TodoItem]) -> [Group] {
        let buckets = Dictionary(grouping: items) { item in
            item.tag.isEmpty ? "Inbox" : item.tag
        }
        return buckets.keys.sorted().map { key in
            Group(tag: key, items: sortedWithin(buckets[key] ?? []))
        }
    }

    public static func sortedWithin(_ items: [TodoItem]) -> [TodoItem] {
        items.sorted { lhs, rhs in
            if lhs.priority.sortRank != rhs.priority.sortRank {
                return lhs.priority.sortRank < rhs.priority.sortRank
            }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?): return l < r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return false
            }
        }
    }
}
