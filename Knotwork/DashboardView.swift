import SwiftUI

// MARK: - Dashboard View

struct DashboardView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var darkroomStore: DarkroomStore
    @State private var refreshing = false
    @State private var editItem: TodoItem?
    @State private var calEvents: [ICalEvent] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if !overdueItems.isEmpty { overdueSection }
                    calendarSection
                    recentDarkroomSection
                }
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("KNOTWORK")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .tracking(3)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if refreshing { ProgressView().scaleEffect(0.8) }
                }
            }
            .refreshable { await doRefresh() }
            .sheet(item: $editItem) { EditItemView(store: store, item: $0) }
            .task {
                // Load iCal cache immediately, then refresh everything
                calEvents = ICalCache.load()
                await doRefresh()
            }
        }
    }

    // MARK: - Refresh

    private func doRefresh() async {
        refreshing = true
        defer { refreshing = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { try? await self.store.refresh() }
            group.addTask { await self.darkroomStore.loadRecentForDashboard() }
            group.addTask {
                // Only re-fetch if cache is stale (> 30 min)
                if let fresh = ICalCache.loadIfFresh(maxAgeMinutes: 30) {
                    await MainActor.run { self.calEvents = fresh }
                    return
                }
                let events = await ICalFetcher.fetchAll(serverURL: self.store.serverURL)
                ICalCache.save(events)
                await MainActor.run { self.calEvents = events }
            }
        }
    }

    // MARK: - Overdue

    private var overdueSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("OVERDUE")
                    .font(.system(size: 10, design: .monospaced).weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.red)

            ForEach(overdueItems) { item in
                Button { editItem = item } label: {
                    CalendarItemBar(text: item.text, isRecurring: false, overdue: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - 28-Day Calendar

    private var calendarSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(calendarDays.enumerated()), id: \.element) { idx, day in
                let cal = Calendar.current
                let prevDay = idx > 0 ? calendarDays[idx - 1] : nil
                let monthChanged = prevDay.map {
                    cal.component(.month, from: $0) != cal.component(.month, from: day)
                } ?? false

                if monthChanged {
                    MonthHeader(date: day)
                }

                DayRow(
                    day: day,
                    items: todosFor(day: day),
                    events: eventsFor(day: day),
                    isFirstDay: idx == 0,
                    zebraStripe: idx % 2 == 1,
                    onTap: { editItem = $0 }
                )
            }
        }
    }

    // MARK: - Recent Darkroom

    private var recentDarkroomSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !darkroomStore.photos.isEmpty {
                DashSectionHeader(title: "RECENT PHOTOS")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(darkroomStore.photos.prefix(6)) { photo in
                            DashPhotoThumb(photo: photo, serverURL: store.serverURL)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            if !darkroomStore.chemistry.isEmpty {
                DashSectionHeader(title: "RECENT CHEMISTRY")
                VStack(spacing: 0) {
                    ForEach(Array(darkroomStore.chemistry.prefix(5).enumerated()), id: \.element.id) { idx, c in
                        DashChemRow(chemistry: c)
                            .background(idx % 2 == 1
                                ? Color(uiColor: .secondarySystemBackground)
                                : Color(uiColor: .systemBackground))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(uiColor: .separator), lineWidth: 0.5))
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Data helpers

    private var calendarDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<28).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    private func todosFor(day: Date) -> [TodoItem] {
        let cal = Calendar.current
        let dayStr = isoDate(day)
        return store.items.filter { item in
            guard !item.done else { return false }
            if let due = item.due { return due == dayStr }
            if let wd = item.recurWeekday {
                let names = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                return names[cal.component(.weekday, from: day) - 1] == wd
            }
            if let rd = item.recurDay, let n = Int(rd) {
                return cal.component(.day, from: day) == n
            }
            return false
        }
        .sorted { $0.priority < $1.priority }
    }

    private func eventsFor(day: Date) -> [ICalEvent] {
        let cal = Calendar.current
        return calEvents.filter { event in
            cal.isDate(event.startDate, inSameDayAs: day)
        }
        .sorted { $0.startDate < $1.startDate }
    }

    private var overdueItems: [TodoItem] {
        let today = isoDate(Calendar.current.startOfDay(for: Date()))
        return store.items
            .filter { !$0.done && ($0.due ?? "") < today && $0.due != nil }
            .sorted { ($0.due ?? "") < ($1.due ?? "") }
    }

    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
}

// MARK: - Day Row

struct DayRow: View {
    let day: Date
    let items: [TodoItem]
    let events: [ICalEvent]
    let isFirstDay: Bool
    let zebraStripe: Bool
    let onTap: (TodoItem) -> Void

    private static let cal = Calendar.current

    private var isToday: Bool   { Self.cal.isDateInToday(day) }
    private var isWeekend: Bool {
        let wd = Self.cal.component(.weekday, from: day)
        return wd == 1 || wd == 7
    }
    private var isFirstOfMonth: Bool { Self.cal.component(.day, from: day) == 1 }
    private var showMonthInChip: Bool { isFirstDay || isFirstOfMonth }

    private var dayName: String {
        isToday ? "TODAY" : day.formatted(.dateTime.weekday(.abbreviated)).uppercased()
    }
    private var dayNum: String { day.formatted(.dateTime.day()) }
    private var monthName: String { day.formatted(.dateTime.month(.abbreviated)).uppercased() }

    // Split items
    private var regularItems: [TodoItem] {
        items.filter { $0.recurWeekday == nil && $0.recurDay == nil }
    }
    private var recurringItems: [TodoItem] {
        items.filter { $0.recurWeekday != nil || $0.recurDay != nil }
    }

    // ── Colour palette ────────────────────────────────────────────
    // Chip = date number box (left).  Row = content area (right).

    // Today weekday:  chip = dark orange,        row = warm yellow
    // Today weekend:  chip = reddish-purple,      row = light reddish-purple
    // Weekend:        chip = dark navy,            row = light steel-blue
    // Weekday:        chip = system bg (plain),   row = zebra

    private var isTodayWeekend: Bool { isToday && isWeekend }

    private var chipBg: Color {
        if isTodayWeekend { return Color(red: 0.50, green: 0.12, blue: 0.35) }  // reddish-purple
        if isToday        { return Color(red: 0.75, green: 0.32, blue: 0.00) }  // dark orange
        if isWeekend      { return Color(red: 0.08, green: 0.15, blue: 0.38) }  // dark navy
        return Color(uiColor: .systemBackground)
    }
    private var chipFg: Color {
        (isToday || isWeekend) ? .white : Color(uiColor: .label)
    }
    private var rowBg: Color {
        if isTodayWeekend { return Color(red: 0.50, green: 0.12, blue: 0.35).opacity(0.10) }
        if isToday        { return Color(red: 1.00, green: 0.96, blue: 0.80) }  // light yellow
        if isWeekend      { return Color(red: 0.82, green: 0.88, blue: 0.97) }  // light steel-blue
        return zebraStripe
            ? Color(uiColor: .secondarySystemBackground).opacity(0.55)
            : Color(uiColor: .systemBackground)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Day chip — month appears above day name when it's the first shown or 1st of month
            VStack(spacing: 0) {
                if showMonthInChip {
                    Text(monthName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(chipFg.opacity(0.7))
                        .padding(.bottom, 1)
                }
                Text(dayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(chipFg.opacity(0.85))
                    .padding(.bottom, 2)
                Text(dayNum)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(chipFg)
            }
            .frame(width: 68)
            .frame(minHeight: 52)
            .padding(.vertical, 8)
            .background(chipBg)

            // Separator — tinted to match chip on special days
            Rectangle()
                .fill((isToday || isWeekend) ? chipBg.opacity(0.5) : Color(uiColor: .separator))
                .frame(width: 0.5)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                let isEmpty = regularItems.isEmpty && events.isEmpty && recurringItems.isEmpty
                if isEmpty {
                    Text("–")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .padding(.leading, 14)
                } else {
                    // iCal events (time + title rows)
                    ForEach(events) { event in
                        CalendarEventRow(event: event)
                    }
                    // Regular (non-recurring) todo bars
                    ForEach(regularItems) { item in
                        Button { onTap(item) } label: {
                            CalendarItemBar(text: item.text, isRecurring: false, overdue: false)
                        }
                        .buttonStyle(.plain)
                    }
                    // Recurring items — single bottom strip of coloured pills
                    if !recurringItems.isEmpty {
                        RecurringStrip(items: recurringItems, onTap: onTap)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 52, alignment: .center)
        }
        .background(rowBg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.4))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Calendar Item Bar (dark filled pill, screenshot style)

struct CalendarItemBar: View {
    let text: String
    let isRecurring: Bool
    let overdue: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(uiColor: .systemBackground).opacity(0.75))
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .lineLimit(1)
            Spacer(minLength: 2)
            if isRecurring {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(uiColor: .systemBackground).opacity(0.55))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(overdue ? Color.red : Color(uiColor: .label))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Recurring Strip (shared bottom bar, one coloured pill per recurring item)

private let recurringPalette: [Color] = [
    Color(red: 0.10, green: 0.25, blue: 0.60),  // deep blue
    Color(red: 0.08, green: 0.40, blue: 0.25),  // deep green
    Color(red: 0.40, green: 0.12, blue: 0.50),  // deep purple
    Color(red: 0.55, green: 0.22, blue: 0.05),  // deep orange
    Color(red: 0.05, green: 0.35, blue: 0.42),  // deep teal
    Color(red: 0.45, green: 0.08, blue: 0.15),  // deep red
]

struct RecurringStrip: View {
    let items: [TodoItem]
    let onTap: (TodoItem) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                let color = recurringPalette[idx % recurringPalette.count]
                Button { onTap(item) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8, weight: .bold))
                        Text(item.text)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}



struct CalendarEventRow: View {
    let event: ICalEvent

    // Subtle left-border colour per feed
    private var feedColor: Color {
        switch event.feedIndex {
        case 0: return Color.blue.opacity(0.7)
        case 1: return Color.purple.opacity(0.7)
        default: return Color.teal.opacity(0.7)
        }
    }

    private var timeStr: String? {
        guard !event.isAllDay else { return nil }
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "am"; f.pmSymbol = "pm"
        return f.string(from: event.startDate)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Coloured left accent bar
            Rectangle()
                .fill(feedColor)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))

            VStack(alignment: .leading, spacing: 1) {
                if let t = timeStr {
                    Text(t)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(uiColor: .label))
                    .lineLimit(1)
            }
            .padding(.leading, 8)
            Spacer()
        }
        .padding(.vertical, 3)
    }
}



struct DashPhotoThumb: View {
    let photo: DRPhoto
    let serverURL: String

    private var thumbURL: URL? {
        let path = photo.thumbPath ?? photo.imagePath
        guard let p = path, !p.isEmpty else { return nil }
        if p.hasPrefix("http") { return URL(string: p) }
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return URL(string: "\(base)/\(p)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let url = thumbURL {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image { img.resizable().scaledToFill() }
                        else { Color(uiColor: .secondarySystemFill).overlay(ProgressView().scaleEffect(0.6)) }
                    }
                } else {
                    Color(uiColor: .secondarySystemFill)
                        .overlay(Image(systemName: "photo").foregroundStyle(.quaternary))
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(photo.title ?? "#\(photo.id)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary).lineLimit(1)
                .frame(width: 90, alignment: .leading)

            if let type = photo.typeName {
                Text(type).font(.system(size: 9)).foregroundStyle(.tertiary)
                    .lineLimit(1).frame(width: 90, alignment: .leading)
            }
        }
    }
}

// MARK: - Dashboard Chemistry Row

struct DashChemRow: View {
    let chemistry: DRChemistry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(chemistry.menuLabel).font(.subheadline)
                if let pct = chemistry.percentSolution {
                    Text(String(format: "%.1f%%", pct)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(chemistry.dateCreated)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Section Header

struct DashSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(.caption2, design: .monospaced).weight(.semibold))
            .tracking(2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }
}

// MARK: - Month separator (between month boundaries in the list)

struct MonthHeader: View {
    let date: Date
    var body: some View {
        HStack {
            Text(date.formatted(.dateTime.month(.wide).year()))
                .font(.system(.footnote, design: .default).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Color(uiColor: .label))
                .padding(.leading, 16)
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(uiColor: .separator)).frame(height: 0.5)
        }
    }
}

// MARK: - DateFormatter helper

extension DateFormatter {
    func then(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        configure(self); return self
    }
}
