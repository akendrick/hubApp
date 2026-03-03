import SwiftUI

struct EditItemView: View {
    @ObservedObject var store: TodoStore
    let item: TodoItem?           // nil = new item

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var text      = ""
    @State private var notes     = ""
    @State private var priority  = 3
    @State private var hasDue    = false
    @State private var dueDate   = Date()
    @State private var tagInput  = ""
    @State private var tags: [String] = []
    @State private var done      = false  // Completion state

    @State private var isSaving  = false
    @State private var errorMsg: String?

    private var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            Form {
                // ── Task text ──────────────────────────────────────
                Section("Task") {
                    TextField("What needs doing?", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                }

                // ── Notes ──────────────────────────────────────────
                Section("Notes (optional)") {
                    TextField("Details, links, context…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .foregroundStyle(.secondary)
                }

                // ── Priority ───────────────────────────────────────
                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(1...5, id: \.self) { p in
                            HStack {
                                PriorityDot(priority: p)
                                Text(priorityLabel(p))
                            }
                            .tag(p)
                        }
                    }
                    .pickerStyle(.inline)
                }

                // ── Due date ───────────────────────────────────────
                Section {
                    Toggle("Due date", isOn: $hasDue.animation())
                    if hasDue {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                    }
                }

                // ── Tags ───────────────────────────────────────────
                Section("Tags") {
                    HStack {
                        TextField("Add tag…", text: $tagInput)
                            .submitLabel(.done)
                            .onSubmit(addTag)
                        if !tagInput.isEmpty {
                            Button("Add", action: addTag)
                                .buttonStyle(.borderless)
                        }
                    }
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 3) {
                                        Text(tag)
                                            .font(.caption.weight(.semibold))
                                        Button {
                                            tags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .bold))
                                        }
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.black)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .listRowInsets(.init(top: 4, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                
                // ── Completion ─────────────────────────────────────
                if isEditing {
                    Section {
                        Toggle(isOn: $done) {
                            HStack(spacing: 8) {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(done ? .green : .secondary)
                                    .font(.title3)
                                Text("Mark as completed")
                            }
                        }
                        .tint(.green)
                    }
                }

                // ── Error ──────────────────────────────────────────
                if let err = errorMsg {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        Task { await save() }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .overlay { if isSaving { ProgressView().scaleEffect(0.75) } }
                }
            }
            .onAppear { populate() }
        }
    }

    // MARK: - Helpers

    private func populate() {
        guard let item else { return }
        text     = item.text
        notes    = item.notes ?? ""
        priority = item.priority
        tags     = item.tags
        done     = item.done
        if let due = item.due {
            let iso = ISO8601DateFormatter(); iso.formatOptions = [.withFullDate]
            if let d = iso.date(from: due) { hasDue = true; dueDate = d }
        }
    }

    private func addTag() {
        let t = tagInput.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !tags.contains(t) else { tagInput = ""; return }
        tags.append(t)
        tagInput = ""
    }

    private func dueDateString() -> String? {
        guard hasDue else { return nil }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: dueDate)
    }

    private func priorityLabel(_ p: Int) -> String {
        ["", "Urgent", "High", "Normal", "Low", "Someday"][p]
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errorMsg = nil

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        do {
            if let existing = item {
                // PATCH — send only the mutable fields that changed
                let patch: [String: AnyEncodable] = [
                    "text":     AnyEncodable(trimmed),
                    "priority": AnyEncodable(priority),
                    "notes":    AnyEncodable(notes.isEmpty ? nil : notes),
                    "due":      AnyEncodable(dueDateString()),
                    "tags":     AnyEncodable(tags),
                    "done":     AnyEncodable(done),
                ]
                try await store.update(id: existing.id, patch: patch)
            } else {
                // POST — server assigns id/created/done=false
                let draft = TodoDraft(
                    text:     trimmed,
                    priority: priority,
                    due:      dueDateString(),
                    notes:    notes.isEmpty ? nil : notes,
                    tags:     tags
                )
                try await store.add(draft: draft)
            }
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
