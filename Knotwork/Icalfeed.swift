import Foundation

// MARK: - iCal Event model

struct ICalEvent: Identifiable {
    let id: String          // UID from the feed
    let title: String
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let feedIndex: Int      // which feed it came from (0, 1, 2)
}

// MARK: - Feed definitions (hardcoded per user request)

enum ICalFeeds {
    static let urls: [String] = [
        "https://p162-caldav.icloud.com/published/2/MTI5MzgzNTk0MTI5MzgzNWY9cTYgK0OwIRz4UCfQYKvJY44bQNHC73gDwS5V1U5jUkV9ynvy7uipCHeNIfenut1Eq0LNCaulcS6IDwnCXzpP_iBTsC0Fc21d3SMFtSvB_1CnVBymPyAyPnzFyGkhsg",
        "https://p102-caldav.icloud.com/published/2/MTI5MzgzNTk0MTI5MzgzNWY9cTYgK0OwIRz4UCfQYKvnN6NvIE36DmOUbrBgiLcGN7ezhsYo-YXFxAw38AN_vpaiEFRiXefJROr9Az80VcU",
        "https://p101-caldav.icloud.com/published/2/Mjc4Mjk1ODMxMjc4Mjk1OPiLHZnPp67Ltgtp3v229x8qT-uPdlC-Sg6bv_JZdLUiimpxJVvfu-OL9CBtnZ3CMevVIgwICabIi9WTyZIKqHA",
    ]
}

// MARK: - iCal Fetcher

struct ICalFetcher {

    /// Fetch and parse all three feeds via the server proxy.
    /// Falls back to direct fetch if proxy fails.
    static func fetchAll(serverURL: String) async -> [ICalEvent] {
        await withTaskGroup(of: [ICalEvent].self) { group in
            for (idx, url) in ICalFeeds.urls.enumerated() {
                group.addTask { await fetch(url: url, feedIndex: idx, serverURL: serverURL) }
            }
            var all: [ICalEvent] = []
            for await events in group { all.append(contentsOf: events) }
            return all
        }
    }

    private static func fetch(url: String, feedIndex: Int, serverURL: String) async -> [ICalEvent] {
        // Try via server proxy first (avoids iCloud SSL pinning issues on device)
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let proxyURLStr = "\(base)/ical-proxy.php?url=\(url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url)"

        let proxyData = await fetchData(from: proxyURLStr)
        let data: Data?
        if let proxyData {
            data = proxyData
        } else {
            data = await fetchData(from: url)
        }

        if let data,
           let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
            return parse(ical: text, feedIndex: feedIndex)
        }
        return []
    }

    private static func fetchData(from urlStr: String) async -> Data? {
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("KnotworkApp/1.0", forHTTPHeaderField: "User-Agent")
        return try? await URLSession.shared.data(for: req).0
    }

    // MARK: - iCal parser

    static func parse(ical text: String, feedIndex: Int) -> [ICalEvent] {
        // Unfold continuation lines (RFC 5545 line folding: CRLF + space/tab)
        let unfolded = text
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")

        let lines = unfolded.components(separatedBy: .newlines)

        var events: [ICalEvent] = []
        var inEvent = false
        var uid = ""
        var summary = ""
        var dtstart: String = ""
        var dtend: String = ""

        let now = Date()
        let twoWeeksAhead = Calendar.current.date(byAdding: .day, value: 28, to: now) ?? now
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed == "BEGIN:VEVENT" {
                inEvent = true
                uid = ""; summary = ""; dtstart = ""; dtend = ""
                continue
            }
            if trimmed == "END:VEVENT" {
                inEvent = false
                if !summary.isEmpty, !dtstart.isEmpty {
                    let (startDate, isAllDay) = parseDate(dtstart)
                    let (endDate, _) = dtend.isEmpty ? (nil, false) : parseDate(dtend) as (Date?, Bool)
                    if let start = startDate, start >= yesterday && start <= twoWeeksAhead {
                        let eventId = uid.isEmpty ? "\(feedIndex)-\(dtstart)-\(summary)" : uid
                        events.append(ICalEvent(
                            id: eventId,
                            title: unescapeIcal(summary),
                            startDate: start,
                            endDate: endDate,
                            isAllDay: isAllDay,
                            feedIndex: feedIndex
                        ))
                    }
                }
                continue
            }
            guard inEvent else { continue }

            // Parse property:value — handle parameters like DTSTART;TZID=America/Vancouver:20260328T070000
            if trimmed.hasPrefix("SUMMARY") {
                summary = propertyValue(trimmed)
            } else if trimmed.hasPrefix("UID") {
                uid = propertyValue(trimmed)
            } else if trimmed.hasPrefix("DTSTART") {
                dtstart = trimmed
            } else if trimmed.hasPrefix("DTEND") || trimmed.hasPrefix("DUE") {
                dtend = trimmed
            }
        }
        return events
    }

    // Extract the value after the last colon (handles PARAM=X:VALUE)
    private static func propertyValue(_ line: String) -> String {
        guard let colonIdx = line.lastIndex(of: ":") else { return "" }
        return String(line[line.index(after: colonIdx)...])
    }

    // Parse a DTSTART/DTEND line into a Date
    private static func parseDate(_ line: String) -> (Date?, Bool) {
        let value = propertyValue(line)
        let allDay = !value.contains("T")

        // Try TZID parameter
        var tzIdentifier: String?
        if let tzRange = line.range(of: "TZID=") {
            let afterTZ = line[tzRange.upperBound...]
            let tzStr = afterTZ.prefix(while: { $0 != ":" && $0 != ";" })
            tzIdentifier = String(tzStr)
        }

        let tz = tzIdentifier.flatMap { TimeZone(identifier: $0) } ?? TimeZone(identifier: "UTC")!

        if allDay {
            // DATE format: YYYYMMDD
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd"
            fmt.timeZone = TimeZone(identifier: "UTC")
            return (fmt.date(from: value), true)
        } else {
            // DATE-TIME: YYYYMMDDTHHMMSS or YYYYMMDDTHHMMSSZ
            let cleaned = value.hasSuffix("Z") ? String(value.dropLast()) : value
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd'T'HHmmss"
            fmt.timeZone = value.hasSuffix("Z") ? TimeZone(identifier: "UTC")! : tz
            return (fmt.date(from: cleaned), false)
        }
    }

    private static func unescapeIcal(_ s: String) -> String {
        s.replacingOccurrences(of: "\\n", with: "\n")
         .replacingOccurrences(of: "\\,", with: ",")
         .replacingOccurrences(of: "\\;", with: ";")
         .replacingOccurrences(of: "\\\\", with: "\\")
    }
}

// MARK: - iCal cache

struct ICalCache {
    private static let key = "ical_events_cache"
    private static let ageKey = "ical_events_cache_age"

    struct Cached: Codable {
        let title: String
        let startDate: Date
        let endDate: Date?
        let isAllDay: Bool
        let feedIndex: Int
        let id: String
    }

    static func save(_ events: [ICalEvent]) {
        let items = events.map { Cached(title: $0.title, startDate: $0.startDate, endDate: $0.endDate,
                                         isAllDay: $0.isAllDay, feedIndex: $0.feedIndex, id: $0.id) }
        if let d = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(d, forKey: key)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: ageKey)
        }
    }

    static func load() -> [ICalEvent] {
        guard let d = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([Cached].self, from: d) else { return [] }
        return items.map { ICalEvent(id: $0.id, title: $0.title, startDate: $0.startDate,
                                      endDate: $0.endDate, isAllDay: $0.isAllDay, feedIndex: $0.feedIndex) }
    }

    /// Returns cached events if they are less than `maxAgeMinutes` old
    static func loadIfFresh(maxAgeMinutes: Double = 30) -> [ICalEvent]? {
        let age = UserDefaults.standard.double(forKey: ageKey)
        guard age > 0, Date().timeIntervalSince1970 - age < maxAgeMinutes * 60 else { return nil }
        return load()
    }
}
