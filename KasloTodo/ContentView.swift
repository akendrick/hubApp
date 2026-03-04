import SwiftUI

// MARK: - Root content view

struct ContentView: View {
    @ObservedObject var store: TodoStore
    @State private var showAdd      = false
    @State private var editItem: TodoItem?
    @State private var showSettings = false
    @State private var showRecurring = false  // Collapsible recurring section
    @State private var showDone     = false
    @State private var selectedTag: String? = nil  // Tag filter
    @State private var sortOption: SortOption = .priority  // Sort option
    
    enum SortOption: String, CaseIterable {
        case priority = "Priority"
        case dueDate = "Due Date"
        case tag = "Tag"
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.items.isEmpty {
                    ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    todoList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gear")
                                .imageScale(.medium)
                        }
                        
                        // Sort menu
                        Menu {
                            Picker("Sort by", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .imageScale(.medium)
                        }
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Kaslo To Do")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        if store.isLoading { ProgressView().scaleEffect(0.75) }
                        Button { showAdd = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .refreshable { await safeRefresh() }
            .sheet(isPresented: $showAdd) {
                EditItemView(store: store, item: nil)
            }
            .sheet(item: $editItem) { item in
                EditItemView(store: store, item: item)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(store: store)
            }
            .alert("Error", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button("OK") { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
        .task { await safeRefresh() }
    }

    // MARK: List

    private var todoList: some View {
        VStack(spacing: 0) {
            // ── Tag Filter Bar ──────────────────────────────────────
            if !store.allTags.isEmpty {
                tagFilterBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .background(Color(uiColor: .systemGroupedBackground))
            }
            
            List {
                // ── Regular pending items ───────────────────────────────
                if filteredRegularItems.isEmpty && filteredRecurringItems.isEmpty && store.doneItems.isEmpty {
                    emptyState
                }

                ForEach(filteredRegularItems) { item in
                    TodoRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture { editItem = item }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task { try? await store.toggleDone(item) }
                            } label: {
                                Label("Done", systemImage: "checkmark.circle.fill")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { try? await store.delete(id: item.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                
                // ── Repeated items section (collapsible) ────────────
                if !filteredRecurringItems.isEmpty {
                    Section {
                        if showRecurring {
                            ForEach(filteredRecurringItems) { item in
                                TodoRow(item: item)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editItem = item }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            Task { try? await store.toggleDone(item) }
                                        } label: {
                                            Label("Done", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.green)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { try? await store.delete(id: item.id) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    } header: {
                        Button {
                            withAnimation { showRecurring.toggle() }
                        } label: {
                            HStack {
                                Label("Repeating Items (\(filteredRecurringItems.count))", systemImage: "repeat")
                                Spacer()
                                Image(systemName: showRecurring ? "chevron.up" : "chevron.down")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // ── Done section (collapsible) ──────────────────────────
                if !store.doneItems.isEmpty {
                    Section {
                        if showDone {
                            ForEach(store.doneItems) { item in
                                TodoRow(item: item)
                                    .opacity(0.45)
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            Task { try? await store.toggleDone(item) }
                                        } label: {
                                            Label("Undo", systemImage: "arrow.uturn.left.circle")
                                        }
                                        .tint(.orange)
                                    }
                            }
                        }
                    } header: {
                        Button {
                            withAnimation { showDone.toggle() }
                        } label: {
                            HStack {
                                Text("Completed (\(store.doneItems.count))")
                                Spacer()
                                Image(systemName: showDone ? "chevron.up" : "chevron.down")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // ── Sync footer ─────────────────────────────────────────
                if let synced = store.lastSynced {
                    Section {
                        Text("Synced \(synced.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
    
    // MARK: Tag Filter Bar
    
    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" button
                Button {
                    withAnimation { selectedTag = nil }
                } label: {
                    Text("All")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedTag == nil ? Color.black : Color(uiColor: .systemGray5))
                        .foregroundStyle(selectedTag == nil ? .white : .primary)
                        .clipShape(Capsule())
                }
                
                // Tag buttons
                ForEach(store.allTags, id: \.self) { tag in
                    Button {
                        withAnimation {
                            selectedTag = (selectedTag == tag) ? nil : tag
                        }
                    } label: {
                        Text(tag)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTag == tag ? Color.black : Color(uiColor: .systemGray5))
                            .foregroundStyle(selectedTag == tag ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "All clear!",
            systemImage: "checkmark.seal.fill",
            description: Text("Tap + to add a task.")
        )
        .listRowBackground(Color.clear)
    }
    
    // MARK: Filtered Items
    
    private var filteredRegularItems: [TodoItem] {
        let items = store.regularPendingItems
        guard let tag = selectedTag else {
            return applySorting(to: items)
        }
        return applySorting(to: items.filter { $0.tags.contains(tag) })
    }
    
    private var filteredRecurringItems: [TodoItem] {
        let items = store.recurringPendingItems
        guard let tag = selectedTag else {
            return applySorting(to: items)
        }
        return applySorting(to: items.filter { $0.tags.contains(tag) })
    }
    
    private func applySorting(to items: [TodoItem]) -> [TodoItem] {
        switch sortOption {
        case .priority:
            return store.sortedByPriority(items)
        case .dueDate:
            return store.sortedByDueDate(items)
        case .tag:
            return store.sortedByTag(items)
        }
    }

    // MARK: Helpers

    private func safeRefresh() async {
        do { try await store.refresh() }
        catch { store.handleError(error) }
    }
}

// MARK: - Todo row

struct TodoRow: View {
    let item: TodoItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Priority square indicator
            PrioritySquare(priority: item.priority)
                .padding(.top, 3)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(item.text)
                    .font(.body)
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? .secondary : .primary)

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    // Show recurring indicator
                    if item.recurWeekday != nil {
                        Label("Weekly", systemImage: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    } else if item.recurDay != nil {
                        Label("Monthly", systemImage: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    
                    if let due = item.dueDateFormatted {
                        Label(due, systemImage: "calendar")
                            .font(.caption2)
                            .foregroundStyle(item.isOverdue ? .red : .secondary)
                    }
                    ForEach(item.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.black)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Priority square

struct PrioritySquare: View {
    let priority: Int

    var color: Color {
        switch priority {
        case 1: return .red
        case 2: return .orange
        case 3: return .blue
        case 4: return .gray
        default: return .gray.opacity(0.6)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Priority tag (removed - no longer used)

// MARK: - Priority dot (kept for EditItemView)

struct PriorityDot: View {
    let priority: Int

    var color: Color {
        switch priority {
        case 1: return .red
        case 2: return .orange
        case 3: return .primary
        case 4: return .secondary
        default: return .gray.opacity(0.4)
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}
