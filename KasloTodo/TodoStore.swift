import Foundation

@MainActor
class TodoStore: ObservableObject {

    @Published var items: [TodoItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastSynced: Date?
    
    // Track configuration state to trigger UI updates
    @Published private(set) var isConfigured = false

    // MARK: Config — stored in UserDefaults (no session cookies needed)

    var serverURL: String {
        get { UserDefaults.standard.string(forKey: "serverURL") ?? "" }
        set { 
            UserDefaults.standard.set(newValue, forKey: "serverURL")
            updateConfigurationState()
        }
    }

    /// Raw API key is stored in the Keychain.
    var apiKey: String {
        get { KeychainHelper.read(key: "apiKey") ?? "" }
        set { 
            KeychainHelper.save(key: "apiKey", value: newValue)
            updateConfigurationState()
        }
    }
    
    // Initialize configuration state and load cached data
    init() {
        updateConfigurationState()
        loadCachedItems()
    }
    
    // MARK: - Caching
    
    private func loadCachedItems() {
        if let data = UserDefaults.standard.data(forKey: "cachedTodoItems"),
           let cached = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = cached
        }
    }
    
    private func cacheItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "cachedTodoItems")
        }
    }
    
    private func updateConfigurationState() {
        isConfigured = !serverURL.isEmpty && !apiKey.isEmpty
    }

    // MARK: Onboarding — called once with URL + key from onboarding screen

    func configure(serverURL url: String, apiKey key: String) async throws {
        // Validate immediately by attempting a fetch
        let fetched = try await APIClient.fetchTodos(serverURL: url, apiKey: key)
        
        // Update published properties on main actor
        serverURL = url
        apiKey    = key
        items     = fetched
        lastSynced = Date()
        cacheItems()
    }

    // MARK: Read

    func refresh() async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        items = try await APIClient.fetchTodos(serverURL: serverURL, apiKey: apiKey)
        lastSynced = Date()
        cacheItems()
    }

    // MARK: Write — one item at a time (server is source of truth)

    /// Add a new item. Server assigns id, created, done=false.
    func add(draft: TodoDraft) async throws {
        let created = try await APIClient.addTodo(serverURL: serverURL, apiKey: apiKey, draft: draft)
        items.insert(created, at: 0)
        lastSynced = Date()
        cacheItems()
    }

    /// Update mutable fields of an existing item via PATCH.
    func update(id: String, patch: [String: AnyEncodable]) async throws {
        let updated = try await APIClient.patchTodo(serverURL: serverURL, apiKey: apiKey, id: id, patch: patch)
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx] = updated
        }
        lastSynced = Date()
        cacheItems()
    }

    /// Toggle done state.
    func toggleDone(_ item: TodoItem) async throws {
        try await update(id: item.id, patch: ["done": AnyEncodable(!item.done)])
    }

    /// Delete permanently.
    func delete(id: String) async throws {
        try await APIClient.deleteTodo(serverURL: serverURL, apiKey: apiKey, id: id)
        items.removeAll { $0.id == id }
        lastSynced = Date()
        cacheItems()
    }

    func delete(at offsets: IndexSet, in source: [TodoItem]) async throws {
        for idx in offsets {
            try await delete(id: source[idx].id)
        }
    }

    // MARK: Computed views

    var pendingItems: [TodoItem] {
        items.filter { !$0.done }
             .sorted {
                 $0.priority != $1.priority
                     ? $0.priority < $1.priority
                     : $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending
             }
    }
    
    /// Non-recurring pending tasks (primary focus)
    var regularPendingItems: [TodoItem] {
        let regular = pendingItems.filter { $0.recurWeekday == nil && $0.recurDay == nil }
        print("📋 Regular items: \(regular.count)")
        for item in regular {
            print("   ✓ \(item.text)")
        }
        return regular
    }
    
    /// Recurring pending tasks (weekly or monthly)
    var recurringPendingItems: [TodoItem] {
        let recurring = pendingItems.filter { $0.recurWeekday != nil || $0.recurDay != nil }
        print("🔁 Recurring items: \(recurring.count)")
        for item in recurring {
            print("   ↻ \(item.text) - weekday: '\(item.recurWeekday ?? "nil")', day: '\(item.recurDay ?? "nil")'")
        }
        return recurring
    }

    var doneItems: [TodoItem] {
        items.filter { $0.done }
    }
    
    /// All unique tags across all items
    var allTags: [String] {
        let tags = items.flatMap { $0.tags }
        return Array(Set(tags)).sorted()
    }
    
    // MARK: Sorting Methods
    
    /// Sort items by tag (items with tags first, then by tag alphabetically)
    func sortedByTag(_ items: [TodoItem]) -> [TodoItem] {
        items.sorted { item1, item2 in
            let tag1 = item1.tags.first ?? ""
            let tag2 = item2.tags.first ?? ""
            
            // Items with no tags go to the end
            if item1.tags.isEmpty && !item2.tags.isEmpty { return false }
            if !item1.tags.isEmpty && item2.tags.isEmpty { return true }
            
            // Both have tags, sort alphabetically by first tag
            if tag1 != tag2 { return tag1 < tag2 }
            
            // Same tag or both empty, sort by text
            return item1.text.localizedCaseInsensitiveCompare(item2.text) == .orderedAscending
        }
    }
    
    /// Sort items by priority (already the default sorting in pendingItems)
    func sortedByPriority(_ items: [TodoItem]) -> [TodoItem] {
        items.sorted {
            $0.priority != $1.priority
                ? $0.priority < $1.priority
                : $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending
        }
    }
    
    /// Sort items by due date (items with due dates first, then by date)
    func sortedByDueDate(_ items: [TodoItem]) -> [TodoItem] {
        items.sorted { item1, item2 in
            let date1 = item1.dueDate
            let date2 = item2.dueDate
            
            // Items with no due date go to the end
            if date1 == nil && date2 != nil { return false }
            if date1 != nil && date2 == nil { return true }
            
            // Both have due dates, sort by date
            if let d1 = date1, let d2 = date2 {
                if d1 != d2 { return d1 < d2 }
            }
            
            // Same date or both nil, sort by text
            return item1.text.localizedCaseInsensitiveCompare(item2.text) == .orderedAscending
        }
    }

    // MARK: Error handling

    func handleError(_ error: Error) {
        if case APIError.unauthorized = error {
            // Key was revoked — clear so onboarding shows
            apiKey = ""
        }
        errorMessage = error.localizedDescription
    }

    func logout() {
        serverURL = ""
        apiKey    = ""
        items     = []
        
        // Explicitly clear storage
        KeychainHelper.delete(key: "apiKey")
        UserDefaults.standard.removeObject(forKey: "serverURL")
        
        updateConfigurationState()
    }
}

// MARK: - Keychain helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
