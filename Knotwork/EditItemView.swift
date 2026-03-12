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
    @State private var tagToDelete: String?
    @State private var showDeleteTagDialog = false
    @State private var errorMsg: String?

    private var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            Form {
                // ── Existing tags ───────────────────────────────────
                if !store.allTags.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(store.allTags, id: \.self) { tag in
                                    let isSelected = tags.contains(tag)
                                    Text(tag)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.black : Color(uiColor: .systemGray5))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .clipShape(Capsule())
                                        .contentShape(Capsule())
                                        .onTapGesture {
                                            toggleTag(tag)
                                        }
                                        .onLongPressGesture(minimumDuration: 0.45) {
                                            tagToDelete = tag
                                            showDeleteTagDialog = true
                                        }
                                }
                            }
                        }
                        .listRowInsets(.init(top: 4, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }

                // ── Task text ──────────────────────────────────────
                Section("Task") {
                    TextField("What needs doing?", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                }


                // ── Priority ───────────────────────────────────────
                Section {
                    HStack(spacing: 18) {
                        ForEach(1...5, id: \.self) { p in
                            Button {
                                priority = p
                            } label: {
                                VStack(spacing: 5) {
                                    Circle()
                                        .fill(priorityColor(p))
                                        .frame(width: 20, height: 20)
                                        .overlay {
                                            Circle()
                                                .stroke(priority == p ? Color.primary : .clear, lineWidth: 2)
                                                .padding(-4)
                                        }
                                    Text(priorityText(p))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(height: 12)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .listRowBackground(Color.clear)
                }

                // ── Due date ───────────────────────────────────────
                Section {
                    Toggle("Due date", isOn: $hasDue.animation())
                    if hasDue {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                    }
                }

                // ── Notes ──────────────────────────────────────────
                Section("Notes (optional)") {
                    TextField("Details, links, context…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .foregroundStyle(.secondary)
                }

                // ── Tags ───────────────────────────────────────────
                Section(" Create New Tag") {
                    HStack {
                        TextField("Add tag…", text: $tagInput)
                            .submitLabel(.done)
                            .onSubmit(addTag)
                        if !tagInput.isEmpty {
                            Button("Add", action: addTag)
                                .buttonStyle(.borderless)
                        }
                    }
                    .listRowBackground(Color.clear)
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
                        .listRowBackground(Color.clear)
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
            .confirmationDialog(
                "Remove tag from this item?",
                isPresented: $showDeleteTagDialog,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    deleteSelectedTag()
                }
                Button("Cancel", role: .cancel) {
                    tagToDelete = nil
                }
            } message: {
                if let tag = tagToDelete {
                    Text("\"\(tag)\" will be removed only from this item.")
                }
            }
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

    private func toggleTag(_ tag: String) {
        if tags.contains(tag) {
            tags.removeAll { $0 == tag }
        } else {
            tags.append(tag)
        }
    }

    private func deleteSelectedTag() {
        guard let tag = tagToDelete else { return }
        tags.removeAll { $0 == tag }
        tagToDelete = nil
    }

    private func dueDateString() -> String? {
        guard hasDue else { return nil }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: dueDate)
    }

    private func priorityText(_ p: Int) -> String {
        switch p {
        case 1: return "URGENT"
        case 3: return "NORMAL"
        case 4: return "LOW"
        case 5: return "EVENTUALLY"
        default: return ""
        }
    }

    private func priorityColor(_ p: Int) -> Color {
        switch p {
        case 1: return .red
        case 2: return .orange
        case 3: return .primary
        case 4: return .secondary
        default: return .gray.opacity(0.4)
        }
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
