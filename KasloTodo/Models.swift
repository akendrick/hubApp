import Foundation

// MARK: - TodoItem
// Mirrors the server's field structure exactly.
// id, created, done are set by the server on POST; the app never forges them.

struct TodoItem: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var done: Bool
    var priority: Int           // 1 (highest) … 5 (lowest)
    var created: String?        // ISO 8601, server-assigned
    var due: String?            // "YYYY-MM-DD" or nil
    var notes: String?
    var tags: [String]
    var recurWeekday: String?   // "Mon"–"Sun" or nil
    var recurDay: String?       // "1"–"31" or nil

    enum CodingKeys: String, CodingKey {
        case id, text, done, priority, created, due, notes, tags, recurWeekday, recurDay
    }

    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        text        = try c.decode(String.self, forKey: .text)
        done        = (try? c.decode(Bool.self,   forKey: .done))     ?? false
        priority    = (try? c.decode(Int.self,    forKey: .priority)) ?? 3
        created     = try? c.decodeIfPresent(String.self, forKey: .created)
        due         = try? c.decodeIfPresent(String.self, forKey: .due)
        notes       = try? c.decodeIfPresent(String.self, forKey: .notes)
        tags        = (try? c.decode([String].self, forKey: .tags))   ?? []
        recurWeekday = try? c.decodeIfPresent(String.self, forKey: .recurWeekday)
        recurDay    = try? c.decodeIfPresent(String.self, forKey: .recurDay)
    }

    // Convenience for local preview / testing only — id/created assigned locally
    init(localText: String, priority: Int = 3) {
        id          = UUID().uuidString
        text        = localText
        done        = false
        self.priority = priority
        created     = nil
        due         = nil
        notes       = nil
        tags        = []
        recurWeekday = nil
        recurDay    = nil
    }

    /// Formatted due date for display.
    var dueDateFormatted: String? {
        guard let due else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        guard let date = iso.date(from: due) else { return due }
        let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .none
        return fmt.string(from: date)
    }
    
    /// Parsed due date as Date for sorting
    var dueDate: Date? {
        guard let due else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        return iso.date(from: due)
    }

    var isOverdue: Bool {
        guard !done, let due else { return false }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        guard let date = iso.date(from: due) else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }
}
