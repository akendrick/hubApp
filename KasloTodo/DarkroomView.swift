import SwiftUI

// MARK: - Shared date helpers

private func drToday() -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
}
private func drParseDate(_ s: String) -> Date {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.date(from: s) ?? Date()
}
private func drFormatDate(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
}

// MARK: - Root

struct DarkroomView: View {
    @ObservedObject var store: DarkroomStore
    @State private var selectedTab: DRTab = .photos

    enum DRTab: String, CaseIterable {
        case photos       = "Photos"
        case negatives    = "Negatives"
        case more         = "More"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                drTabBar
                Divider()
                Group {
                    switch selectedTab {
                    case .photos:       DRPhotosTab(store: store)
                    case .negatives:    DRNegativesTab(store: store)
                    case .more:         DRMoreTab(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Darkroom")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await store.loadTypes() }
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var drTabBar: some View {
        HStack(spacing: 10) {
            ForEach(DRTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.primary : Color.clear)
                        .foregroundStyle(selectedTab == tab
                            ? Color(uiColor: .systemBackground)
                            : Color.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private enum DRMoreSection: String, CaseIterable, Hashable, Identifiable {
    case carbonTissue = "Carbon Tissue"
    case chemistry = "Chemistry"
    case exposures = "Exposures"
    case paper = "Paper"
    case supportPaper = "Support Paper"

    var id: String { rawValue }
}

struct DRMoreTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var sectionOrder: [DRMoreSection] = DRMoreSection.allCases
    @State private var expandedSections: Set<DRMoreSection> = []
    @State private var visibleCounts: [DRMoreSection: Int] = [:]

    @State private var showChemistryForm = false
    @State private var chemistryEditTarget: DRChemistry?
    @State private var showPaperForm = false
    @State private var paperEditTarget: DRPaper?
    @State private var showSupportPaperForm = false
    @State private var supportPaperEditTarget: DRSupportPaper?
    @State private var showCarbonTissueForm = false
    @State private var carbonTissueEditTarget: DRCarbonTissue?
    @State private var showExposureForm = false
    @State private var exposureEditTarget: DRExposure?

    var body: some View {
        List {
            ForEach(sectionOrder, id: \.self) { section in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            toggle(section)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(section.rawValue)
                                    .font(.headline.weight(.bold))
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            presentCreate(for: section)
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption.weight(.bold))
                                .frame(width: 22, height: 22)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    if expandedSections.contains(section) {
                        sectionContent(section)
                            .padding(.leading, 18)
                    }
                }
                .padding(.vertical, 4)
            }
            .onMove(perform: moveSections)
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showChemistryForm, onDismiss: { chemistryEditTarget = nil }) {
            DRChemistryForm(store: store, target: chemistryEditTarget) { showChemistryForm = false }
        }
        .sheet(isPresented: $showPaperForm, onDismiss: { paperEditTarget = nil }) {
            DRPaperForm(store: store, target: paperEditTarget) { showPaperForm = false }
        }
        .sheet(isPresented: $showSupportPaperForm, onDismiss: { supportPaperEditTarget = nil }) {
            DRSupportPaperForm(store: store, target: supportPaperEditTarget) { showSupportPaperForm = false }
        }
        .sheet(isPresented: $showCarbonTissueForm, onDismiss: { carbonTissueEditTarget = nil }) {
            DRCarbonTissueForm(store: store, target: carbonTissueEditTarget) { showCarbonTissueForm = false }
        }
        .sheet(isPresented: $showExposureForm, onDismiss: { exposureEditTarget = nil }) {
            DRExposureForm(store: store, target: exposureEditTarget) { showExposureForm = false }
        }
        .task { await loadAllMoreData() }
        .refreshable { await loadAllMoreData() }
    }

    @ViewBuilder
    private func sectionContent(_ section: DRMoreSection) -> some View {
        switch section {
        case .carbonTissue:
            if store.carbonTissues.isEmpty {
                Text("No carbon tissue batches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let sortedItems = store.carbonTissues.sorted {
                    drParseDate($0.datePoured) > drParseDate($1.datePoured)
                }
                let total = sortedItems.count
                let visible = visibleCount(for: .carbonTissue, total: total)
                ForEach(Array(sortedItems.prefix(visible))) { ct in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("#\(ct.id)")
                                .font(.subheadline.weight(.semibold))
                            if let sz = ct.size {
                                Text(sz)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(ct.datePoured)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let n = ct.notes, !n.isEmpty {
                            Text(n)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        carbonTissueEditTarget = ct
                        showCarbonTissueForm = true
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { Task { await store.deleteCarbonTissue(id: ct.id) } }
                        label: { Label("Delete", systemImage: "trash") }
                    }
                }
                if visible < total {
                    showMoreButton(for: .carbonTissue, total: total)
                }
            }

        case .chemistry:
            if store.chemistry.isEmpty {
                Text("No chemistry batches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let sortedItems = store.chemistry.sorted {
                    drParseDate($0.dateCreated) > drParseDate($1.dateCreated)
                }
                let total = sortedItems.count
                let visible = visibleCount(for: .chemistry, total: total)
                ForEach(Array(sortedItems.prefix(visible))) { c in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(c.typeName ?? "Chemistry")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(c.dateCreated)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let pct = c.percentSolution {
                            Text(String(format: "%.1f%% solution", pct))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        chemistryEditTarget = c
                        showChemistryForm = true
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { Task { await store.deleteChemistry(id: c.id) } }
                        label: { Label("Delete", systemImage: "trash") }
                    }
                }
                if visible < total {
                    showMoreButton(for: .chemistry, total: total)
                }
            }

        case .exposures:
            if store.exposures.isEmpty {
                Text("No exposures")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let sortedItems = store.exposures.sorted {
                    drParseDate($0.dateExposed) > drParseDate($1.dateExposed)
                }
                let total = sortedItems.count
                let visible = visibleCount(for: .exposures, total: total)
                ForEach(Array(sortedItems.prefix(visible))) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            if e.testStrip == 1 {
                                Text("Test Strip")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Text(e.dateExposed)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if !e.times.isEmpty {
                            Text(e.times.compactMap { $0.durationMinutes }.map { String(format: "%.0f′", $0) }.joined(separator: " · "))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        exposureEditTarget = e
                        showExposureForm = true
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { Task { await store.deleteExposure(id: e.id) } }
                        label: { Label("Delete", systemImage: "trash") }
                    }
                }
                if visible < total {
                    showMoreButton(for: .exposures, total: total)
                }
            }

        case .paper:
            if store.papers.isEmpty {
                Text("No paper stocks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let sortedItems = store.papers.sorted { $0.id > $1.id }
                let total = sortedItems.count
                let visible = visibleCount(for: .paper, total: total)
                ForEach(Array(sortedItems.prefix(visible))) { p in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(p.displayName.isEmpty ? "Paper #\(p.id)" : p.displayName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if p.hotPress == 1 {
                                Text("HP")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        if let w = p.weight {
                            Text(String(format: "%.0f gsm", w))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        paperEditTarget = p
                        showPaperForm = true
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { Task { await store.deletePaper(id: p.id) } }
                        label: { Label("Delete", systemImage: "trash") }
                    }
                }
                if visible < total {
                    showMoreButton(for: .paper, total: total)
                }
            }

        case .supportPaper:
            if store.supportPapers.isEmpty {
                Text("No support papers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let sortedItems = store.supportPapers.sorted { $0.id > $1.id }
                let total = sortedItems.count
                let visible = visibleCount(for: .supportPaper, total: total)
                ForEach(Array(sortedItems.prefix(visible))) { sp in
                    HStack(spacing: 8) {
                        Text(sp.mark)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        Text(sp.paperLabel ?? sp.displayName)
                            .font(.subheadline)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        supportPaperEditTarget = sp
                        showSupportPaperForm = true
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { Task { await store.deleteSupportPaper(id: sp.id) } }
                        label: { Label("Delete", systemImage: "trash") }
                    }
                }
                if visible < total {
                    showMoreButton(for: .supportPaper, total: total)
                }
            }
        }
    }

    private func toggle(_ section: DRMoreSection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    private func presentCreate(for section: DRMoreSection) {
        switch section {
        case .carbonTissue:
            carbonTissueEditTarget = nil
            showCarbonTissueForm = true
        case .chemistry:
            chemistryEditTarget = nil
            showChemistryForm = true
        case .exposures:
            exposureEditTarget = nil
            showExposureForm = true
        case .paper:
            paperEditTarget = nil
            showPaperForm = true
        case .supportPaper:
            supportPaperEditTarget = nil
            showSupportPaperForm = true
        }
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        sectionOrder.move(fromOffsets: source, toOffset: destination)
    }

    private func loadAllMoreData() async {
        await store.loadChemistry()
        await store.loadPapers()
        await store.loadSupportPapers()
        await store.loadCarbonTissues()
        await store.loadNegatives()
        await store.loadExposures()
    }

    private func visibleCount(for section: DRMoreSection, total: Int) -> Int {
        min(visibleCounts[section] ?? 10, total)
    }

    @ViewBuilder
    private func showMoreButton(for section: DRMoreSection, total: Int) -> some View {
        Button {
            let current = visibleCounts[section] ?? 10
            visibleCounts[section] = min(current + 10, total)
        } label: {
            Text("Show more")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}

// MARK: - Shared empty state

private struct DREmptyState: View {
    let label: String
    let icon: String
    var body: some View {
        ContentUnavailableView(
            "No \(label)",
            systemImage: icon,
            description: Text("Tap + to add one.")
        )
        .listRowBackground(Color.clear)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: CHEMISTRY
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRChemistryTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false
    @State private var editTarget: DRChemistry?

    var body: some View {
        List {
            if store.chemistry.isEmpty {
                DREmptyState(label: "chemistry batches", icon: "flask")
            }
            ForEach(store.chemistry) { c in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(c.typeName ?? "Chemistry").font(.headline)
                        Spacer()
                        Text(c.dateCreated).font(.caption).foregroundStyle(.secondary)
                    }
                    if let pct = c.percentSolution {
                        Text(String(format: "%.1f%% solution", pct))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let n = c.notes { Text(n).font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture { editTarget = c; showForm = true }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { Task { await store.deleteChemistry(id: c.id) } }
                    label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { editTarget = nil; showForm = true } label: { Image(systemName: "plus") }
        }}
        .sheet(isPresented: $showForm, onDismiss: { editTarget = nil }) {
            DRChemistryForm(store: store, target: editTarget) { showForm = false }
        }
        .task { await store.loadChemistry() }
        .refreshable { await store.loadChemistry() }
    }
}

struct DRChemistryForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRChemistry?
    let onDone: () -> Void

    @State private var date    = Date()
    @State private var typeId: Int?   = nil
    @State private var percent = ""
    @State private var fromId: Int?   = nil
    @State private var notes   = ""
    @State private var saving  = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    DatePicker("Date Created", selection: $date, displayedComponents: .date)
                }
                Section("Type") {
                    Picker("Chemistry Type", selection: $typeId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.chemistryTypes) { t in Text(t.name).tag(t.id as Int?) }
                    }
                }
                Section("Details") {
                    TextField("% Solution (e.g. 5.0)", text: $percent).keyboardType(.decimalPad)
                    Picker("Created From", selection: $fromId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.chemistry.filter { $0.id != target?.id }) { c in
                            Text("#\(c.id) \(c.typeName ?? "") \(c.dateCreated)").tag(c.id as Int?)
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes…", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if let e = error { Section { Text(e).foregroundStyle(.red).font(.caption) } }
            }
            .navigationTitle(target == nil ? "New Chemistry" : "Edit Chemistry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target == nil ? "Add" : "Save") { Task { await save() } }.disabled(saving)
                }
            }
        }
        .onAppear {
            if let t = target {
                date = drParseDate(t.dateCreated); typeId = t.typeId
                percent = t.percentSolution.map { String($0) } ?? ""; notes = t.notes ?? ""
            }
        }
    }

    private func save() async {
        saving = true; error = nil
        let req = DRChemistryRequest(
            dateCreated: drFormatDate(date), typeId: typeId,
            percentSolution: Double(percent), createdFromId: fromId,
            notes: notes.isEmpty ? nil : notes)
        do {
            if let t = target { try await store.updateChemistry(id: t.id, req) }
            else { try await store.addChemistry(req) }
            onDone()
        } catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: PAPER
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRPaperTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false
    @State private var editTarget: DRPaper?

    var body: some View {
        List {
            if store.papers.isEmpty { DREmptyState(label: "paper stocks", icon: "doc") }
            ForEach(store.papers) { p in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(p.displayName.isEmpty ? "Paper #\(p.id)" : p.displayName).font(.headline)
                        Spacer()
                        if p.hotPress == 1 {
                            Text("HP").font(.caption2.weight(.bold))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15)).foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 8) {
                        if let w = p.weight { Text(String(format: "%.0f gsm", w)).font(.caption).foregroundStyle(.secondary) }
                        if let tl = p.treatmentLabel, !tl.isEmpty { Text(tl).font(.caption).foregroundStyle(.secondary) }
                    }
                    if let n = p.notes { Text(n).font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture { editTarget = p; showForm = true }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { Task { await store.deletePaper(id: p.id) } }
                    label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { editTarget = nil; showForm = true } label: { Image(systemName: "plus") }
        }}
        .sheet(isPresented: $showForm, onDismiss: { editTarget = nil }) {
            DRPaperForm(store: store, target: editTarget) { showForm = false }
        }
        .task { await store.loadPapers() }
        .refreshable { await store.loadPapers() }
    }
}

struct DRPaperForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRPaper?
    let onDone: () -> Void

    @State private var manufacturer = ""
    @State private var label        = ""
    @State private var weight       = ""
    @State private var hotPress     = false
    @State private var chemId: Int? = nil
    @State private var notes        = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Paper") {
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Label / Name", text: $label)
                    TextField("Weight (gsm)", text: $weight).keyboardType(.decimalPad)
                    Toggle("Hot Press", isOn: $hotPress)
                }
                Section("Treatment Chemistry") {
                    Picker("Chemistry", selection: $chemId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.chemistry) { c in
                            Text("#\(c.id) \(c.typeName ?? "") \(c.dateCreated)").tag(c.id as Int?)
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes…", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if let e = error { Section { Text(e).foregroundStyle(.red).font(.caption) } }
            }
            .navigationTitle(target == nil ? "New Paper" : "Edit Paper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target == nil ? "Add" : "Save") { Task { await save() } }.disabled(saving)
                }
            }
        }
        .onAppear {
            if let t = target {
                manufacturer = t.manufacturer ?? ""; label = t.label ?? ""
                weight = t.weight.map { String(Int($0)) } ?? ""
                hotPress = t.hotPress == 1; chemId = t.treatmentChemistryId; notes = t.notes ?? ""
            }
        }
    }

    private func save() async {
        saving = true; error = nil
        let req = DRPaperRequest(
            manufacturer: manufacturer.isEmpty ? nil : manufacturer,
            label: label.isEmpty ? nil : label,
            weight: Double(weight), hotPress: hotPress,
            treatmentChemistryId: chemId,
            notes: notes.isEmpty ? nil : notes)
        do {
            if let t = target { try await store.updatePaper(id: t.id, req) }
            else { try await store.addPaper(req) }
            onDone()
        } catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: SUPPORT PAPER
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRSupportPaperTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false
    @State private var editTarget: DRSupportPaper?

    var body: some View {
        List {
            if store.supportPapers.isEmpty { DREmptyState(label: "support papers", icon: "doc.badge.plus") }
            ForEach(store.supportPapers) { sp in
                HStack(spacing: 12) {
                    Text(sp.mark)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sp.paperLabel ?? sp.displayName).font(.subheadline)
                        HStack(spacing: 6) {
                            if let w = sp.weight { Text(String(format: "%.0f gsm", w)).font(.caption).foregroundStyle(.secondary) }
                            if sp.hotPress == 1 { Text("HP").font(.caption2.weight(.semibold)).foregroundStyle(.blue) }
                        }
                        if let n = sp.notes { Text(n).font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
                    }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture { editTarget = sp; showForm = true }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { Task { await store.deleteSupportPaper(id: sp.id) } }
                    label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { editTarget = nil; showForm = true } label: { Image(systemName: "plus") }
        }}
        .sheet(isPresented: $showForm, onDismiss: { editTarget = nil }) {
            DRSupportPaperForm(store: store, target: editTarget) { showForm = false }
        }
        .task { await store.loadPapers(); await store.loadSupportPapers() }
        .refreshable { await store.loadSupportPapers() }
    }
}

struct DRSupportPaperForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRSupportPaper?
    let onDone: () -> Void

    @State private var paperId: Int? = nil
    @State private var mark   = ""
    @State private var notes  = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Base Paper") {
                    Picker("Paper", selection: $paperId) {
                        Text("Select paper…").tag(Int?.none)
                        ForEach(store.papers) { p in Text(p.displayName).tag(p.id as Int?) }
                    }
                }
                Section("ID / Mark") {
                    TextField("e.g. A1, B3", text: $mark)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .onChange(of: mark) { _, v in mark = v.uppercased() }
                }
                Section("Notes") {
                    TextField("Notes…", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if let e = error { Section { Text(e).foregroundStyle(.red).font(.caption) } }
            }
            .navigationTitle(target == nil ? "New Support Paper" : "Edit Support Paper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target == nil ? "Add" : "Save") { Task { await save() } }
                        .disabled(saving || paperId == nil || mark.isEmpty)
                }
            }
        }
        .onAppear {
            if let t = target { paperId = t.paperId; mark = t.mark; notes = t.notes ?? "" }
        }
    }

    private func save() async {
        guard let pid = paperId else { return }
        saving = true; error = nil
        let req = DRSupportPaperRequest(paperId: pid, mark: mark, notes: notes.isEmpty ? nil : notes)
        do {
            if let t = target { try await store.updateSupportPaper(id: t.id, req) }
            else { try await store.addSupportPaper(req) }
            onDone()
        } catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: CARBON TISSUE
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRCarbonTissueTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false
    @State private var editTarget: DRCarbonTissue?

    var body: some View {
        List {
            if store.carbonTissues.isEmpty { DREmptyState(label: "carbon tissue batches", icon: "square.stack") }
            ForEach(store.carbonTissues) { ct in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("#\(ct.id)").font(.headline)
                        if let sz = ct.size { Text(sz).font(.subheadline).foregroundStyle(.secondary) }
                        Spacer()
                        Text(ct.datePoured).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        if let chem = ct.chemType { Text(chem).font(.caption).foregroundStyle(.secondary) }
                        if let amt = ct.amountPoured { Text(amt).font(.caption).foregroundStyle(.secondary) }
                    }
                    if let n = ct.notes { Text(n).font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture { editTarget = ct; showForm = true }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { Task { await store.deleteCarbonTissue(id: ct.id) } }
                    label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { editTarget = nil; showForm = true } label: { Image(systemName: "plus") }
        }}
        .sheet(isPresented: $showForm, onDismiss: { editTarget = nil }) {
            DRCarbonTissueForm(store: store, target: editTarget) { showForm = false }
        }
        .task { await store.loadChemistry(); await store.loadCarbonTissues() }
        .refreshable { await store.loadCarbonTissues() }
    }
}

struct DRCarbonTissueForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRCarbonTissue?
    let onDone: () -> Void

    @State private var date   = Date()
    @State private var size   = ""
    @State private var chemId: Int? = nil
    @State private var amount = ""
    @State private var notes  = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Poured") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Details") {
                    TextField("Size (e.g. 8×10)", text: $size)
                    Picker("Chemistry Used", selection: $chemId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.chemistry) { c in
                            Text("#\(c.id) \(c.typeName ?? "") \(c.dateCreated)").tag(c.id as Int?)
                        }
                    }
                    TextField("Amount Poured (e.g. 45ml)", text: $amount)
                }
                Section("Notes") {
                    TextField("Notes…", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if let e = error { Section { Text(e).foregroundStyle(.red).font(.caption) } }
            }
            .navigationTitle(target == nil ? "New Carbon Tissue" : "Edit Carbon Tissue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target == nil ? "Add" : "Save") { Task { await save() } }.disabled(saving)
                }
            }
        }
        .onAppear {
            if let t = target {
                date = drParseDate(t.datePoured); size = t.size ?? ""
                chemId = t.chemistryId; amount = t.amountPoured ?? ""; notes = t.notes ?? ""
            }
        }
    }

    private func save() async {
        saving = true; error = nil
        let req = DRCarbonTissueRequest(
            size: size.isEmpty ? nil : size, chemistryId: chemId,
            amountPoured: amount.isEmpty ? nil : amount,
            datePoured: drFormatDate(date), notes: notes.isEmpty ? nil : notes)
        do {
            if let t = target { try await store.updateCarbonTissue(id: t.id, req) }
            else { try await store.addCarbonTissue(req) }
            onDone()
        } catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: NEGATIVES
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRNegativesTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false
    @State private var editTarget: DRNegative?

    var body: some View {
        List {
            if store.negatives.isEmpty { DREmptyState(label: "negatives", icon: "photo") }
            ForEach(store.negatives) { n in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("#\(n.id) \(n.typeName ?? "Negative")").font(.headline)
                        Spacer()
                        Text(n.dateCreated).font(.caption).foregroundStyle(.secondary)
                    }
                    if let sn = n.settingsNotes { Text(sn).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture { editTarget = n; showForm = true }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { Task { await store.deleteNegative(id: n.id) } }
                    label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { editTarget = nil; showForm = true } label: { Image(systemName: "plus") }
        }}
        .sheet(isPresented: $showForm, onDismiss: { editTarget = nil }) {
            DRNegativeForm(store: store, target: editTarget) { showForm = false }
        }
        .task { await store.loadNegatives() }
        .refreshable { await store.loadNegatives() }
    }
}

struct DRNegativeForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRNegative?
    let onDone: () -> Void

    @State private var date   = Date()
    @State private var typeId: Int? = nil
    @State private var notes  = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Created") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Type") {
                    Picker("Negative Type", selection: $typeId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.negativeTypes) { t in Text(t.name).tag(t.id as Int?) }
                    }
                }
                Section("Settings & Notes") {
                    TextField("Camera settings, film info…", text: $notes, axis: .vertical).lineLimit(3...8)
                }
                if let e = error { Section { Text(e).foregroundStyle(.red).font(.caption) } }
            }
            .navigationTitle(target == nil ? "New Negative" : "Edit Negative")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target == nil ? "Add" : "Save") { Task { await save() } }.disabled(saving)
                }
            }
        }
        .onAppear {
            if let t = target { date = drParseDate(t.dateCreated); typeId = t.typeId; notes = t.settingsNotes ?? "" }
        }
    }

    private func save() async {
        saving = true; error = nil
        let req = DRNegativeRequest(dateCreated: drFormatDate(date), typeId: typeId, settingsNotes: notes.isEmpty ? nil : notes)
        do {
            if let t = target { try await store.updateNegative(id: t.id, req) }
            else { try await store.addNegative(req) }
            onDone()
        } catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: EXPOSURES
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRExposuresTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false
    @State private var editTarget: DRExposure?

    var body: some View {
        List {
            if store.exposures.isEmpty { DREmptyState(label: "exposures", icon: "camera") }
            ForEach(store.exposures) { e in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        if e.testStrip == 1 {
                            Text("Test Strip")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2)).foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Text(e.dateExposed).font(.caption).foregroundStyle(.secondary)
                    }
                    if let neg = e.negType { Text("Neg: \(neg)").font(.caption).foregroundStyle(.secondary) }
                    if !e.times.isEmpty {
                        let timeStr = e.times.compactMap { $0.durationMinutes }.map { String(format: "%.0f′", $0) }.joined(separator: " · ")
                        Text(timeStr).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    if let n = e.notes { Text(n).font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture { editTarget = e; showForm = true }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { Task { await store.deleteExposure(id: e.id) } }
                    label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { editTarget = nil; showForm = true } label: { Image(systemName: "plus") }
        }}
        .sheet(isPresented: $showForm, onDismiss: { editTarget = nil }) {
            DRExposureForm(store: store, target: editTarget) { showForm = false }
        }
        .task { await store.loadExposureFormDeps() }
        .refreshable { await store.loadExposures() }
    }
}

struct DRExposureForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRExposure?
    let onDone: () -> Void

    @State private var date         = Date()
    @State private var testStrip    = false
    @State private var negId: Int?  = nil
    @State private var soakTime     = ""
    @State private var soakTemp     = ""
    @State private var hotTime      = ""
    @State private var hotTemp      = ""
    @State private var coolTime     = ""
    @State private var coolTemp     = ""
    @State private var times: [DRExposureTime] = [DRExposureTime()]
    @State private var notes        = ""
    @State private var saving       = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Date & Type") {
                    DatePicker("Date Exposed", selection: $date, displayedComponents: .date)
                    Toggle("Test Strip", isOn: $testStrip)
                    Picker("Negative", selection: $negId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.negatives) { n in Text(n.displayName).tag(n.id as Int?) }
                    }
                }

                Section("Paper Soak") {
                    HStack {
                        TextField("Time (min)", text: $soakTime).keyboardType(.numberPad)
                        Divider()
                        TextField("Temp (°C)", text: $soakTemp).keyboardType(.decimalPad)
                    }
                }

                Section("Hot Development") {
                    HStack {
                        TextField("Time (sec)", text: $hotTime).keyboardType(.numberPad)
                        Divider()
                        TextField("Temp (°C)", text: $hotTemp).keyboardType(.decimalPad)
                    }
                }

                Section("Cool Development") {
                    HStack {
                        TextField("Time (sec)", text: $coolTime).keyboardType(.numberPad)
                        Divider()
                        TextField("Temp (°C)", text: $coolTemp).keyboardType(.decimalPad)
                    }
                }

                Section {
                    ForEach($times) { $t in
                        HStack {
                            Image(systemName: "clock").foregroundStyle(.secondary)
                            TextField("Duration (min)", value: $t.durationMinutes, format: .number)
                                .keyboardType(.decimalPad)
                            if times.count > 1 {
                                Button { times.removeAll { $0.id == t.id } }
                                label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button {
                        if testStrip, let last = times.last {
                            times.append(DRExposureTime(durationMinutes: last.durationMinutes))
                        } else {
                            times.append(DRExposureTime())
                        }
                    } label: {
                        Label(testStrip && !times.isEmpty ? "Repeat Last" : "Add Time", systemImage: "plus.circle")
                    }
                } header: { Text("Exposure Times") }

                Section("Notes") {
                    TextField("Notes…", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if let e = error { Section { Text(e).foregroundStyle(.red).font(.caption) } }
            }
            .navigationTitle(target == nil ? "New Exposure" : "Edit Exposure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target == nil ? "Add" : "Save") { Task { await save() } }.disabled(saving)
                }
            }
        }
        .onAppear { populate() }
    }

    private func populate() {
        guard let t = target else { return }
        date = drParseDate(t.dateExposed); testStrip = t.testStrip == 1; negId = t.negativeId
        soakTime = t.paperSoakTime.map { String($0) } ?? ""
        soakTemp = t.paperSoakTemp.map { String($0) } ?? ""
        hotTime  = t.hotDevelopTime.map  { String($0) } ?? ""
        hotTemp  = t.hotDevelopTemp.map  { String($0) } ?? ""
        coolTime = t.coolDevelopTime.map { String($0) } ?? ""
        coolTemp = t.coolDevelopTemp.map { String($0) } ?? ""
        times    = t.times.isEmpty ? [DRExposureTime()] : t.times
        notes    = t.notes ?? ""
    }

    private func save() async {
        saving = true; error = nil
        let validTimes = times.compactMap { t -> DRTimeRequest? in
            guard let d = t.durationMinutes, d > 0 else { return nil }
            return DRTimeRequest(durationMinutes: d)
        }
        let req = DRExposureRequest(
            dateExposed: drFormatDate(date), testStrip: testStrip, negativeId: negId,
            paperSoakTime: Int(soakTime), paperSoakTemp: Double(soakTemp),
            hotDevelopTime: Int(hotTime), hotDevelopTemp: Double(hotTemp),
            coolDevelopTime: Int(coolTime), coolDevelopTemp: Double(coolTemp),
            notes: notes.isEmpty ? nil : notes, times: validTimes)
        do {
            if let t = target { try await store.updateExposure(id: t.id, req) }
            else { try await store.addExposure(req) }
            onDone()
        } catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: PHOTOS
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRPhotosTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false
    @State private var editTarget: DRPhoto?

    var body: some View {
        List {
            if store.photos.isEmpty { DREmptyState(label: "photos", icon: "photo.stack") }
            ForEach(store.photos) { p in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("#\(p.id)").font(.headline)
                        if let sz = p.photoSize { Text(sz).font(.subheadline).foregroundStyle(.secondary) }
                        Spacer()
                        if let d = p.dateExposed { Text(d).font(.caption).foregroundStyle(.secondary) }
                    }
                    if let pl = p.paperLabel { Text(pl).font(.caption).foregroundStyle(.secondary) }
                    // Layer badges
                    if !p.layers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(p.layers) { layer in
                                    HStack(spacing: 4) {
                                        if let m = layer.spMark {
                                            DRBadge(text: "SP:\(m)", color: .green)
                                        }
                                        if let neg = layer.negType ?? layer.negDate {
                                            DRBadge(text: "Neg:\(neg)", color: .orange)
                                        }
                                        if let ct = layer.ctSize ?? layer.ctDate {
                                            DRBadge(text: "CT:\(ct)", color: .blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if let n = p.notes { Text(n).font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture { editTarget = p; showForm = true }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { Task { await store.deletePhoto(id: p.id) } }
                    label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { editTarget = nil; showForm = true } label: { Image(systemName: "plus") }
        }}
        .sheet(isPresented: $showForm, onDismiss: { editTarget = nil }) {
            DRPhotoForm(store: store, target: editTarget) { showForm = false }
        }
        .task { await store.loadPhotoFormDeps() }
        .refreshable { await store.loadPhotos() }
    }
}

private struct DRBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct DRPhotoForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRPhoto?
    let onDone: () -> Void

    @State private var dateSensitized = Date()
    @State private var dateExposed    = Date()
    @State private var paperId: Int?  = nil
    @State private var photoSize      = ""
    @State private var gelatinId: Int? = nil
    @State private var amountUsed     = ""
    @State private var exposureId: Int? = nil
    @State private var layers: [DRPhotoLayer] = [DRPhotoLayer()]
    @State private var notes          = ""
    @State private var saving         = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Dates") {
                    DatePicker("Sensitized", selection: $dateSensitized, displayedComponents: .date)
                    DatePicker("Exposed",    selection: $dateExposed,    displayedComponents: .date)
                }

                Section("Paper & Size") {
                    Picker("Paper", selection: $paperId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.papers) { p in Text(p.displayName).tag(p.id as Int?) }
                    }
                    TextField("Photo Size (e.g. 8×10)", text: $photoSize)
                }

                Section("Gelatin") {
                    Picker("Gelatin Chemistry", selection: $gelatinId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.chemistry) { c in
                            Text("#\(c.id) \(c.typeName ?? "") \(c.dateCreated)").tag(c.id as Int?)
                        }
                    }
                    TextField("Amount Used (e.g. 20ml)", text: $amountUsed)
                }

                Section("Exposure") {
                    Picker("Exposure Record", selection: $exposureId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.exposures) { e in
                            Text("#\(e.id) \(e.dateExposed)").tag(e.id as Int?)
                        }
                    }
                }

                Section {
                    ForEach($layers) { $layer in
                        VStack(spacing: 8) {
                            Picker("Support Paper", selection: $layer.supportPaperId) {
                                Text("None").tag(Int?.none)
                                ForEach(store.supportPapers) { sp in
                                    Text(sp.displayName).tag(sp.id as Int?)
                                }
                            }
                            Picker("Negative", selection: $layer.negativeId) {
                                Text("None").tag(Int?.none)
                                ForEach(store.negatives) { n in
                                    Text(n.displayName).tag(n.id as Int?)
                                }
                            }
                            Picker("Carbon Tissue", selection: $layer.carbonTissueId) {
                                Text("None").tag(Int?.none)
                                ForEach(store.carbonTissues) { ct in
                                    Text(ct.displayName).tag(ct.id as Int?)
                                }
                            }
                            if layers.count > 1 {
                                Button(role: .destructive) { layers.removeAll { $0.id == layer.id } }
                                label: { Label("Remove Layer", systemImage: "minus.circle") }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Button { layers.append(DRPhotoLayer()) }
                    label: { Label("Add Layer", systemImage: "plus.circle") }
                } header: { Text("Layers") }
                  footer: { Text("Each layer combines support paper, a negative, and carbon tissue.") }

                Section("Notes") {
                    TextField("Notes…", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if let e = error { Section { Text(e).foregroundStyle(.red).font(.caption) } }
            }
            .navigationTitle(target == nil ? "New Photo" : "Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target == nil ? "Add" : "Save") { Task { await save() } }.disabled(saving)
                }
            }
        }
        .onAppear { populate() }
    }

    private func populate() {
        guard let t = target else { return }
        if let ds = t.dateSensitized { dateSensitized = drParseDate(ds) }
        if let de = t.dateExposed    { dateExposed    = drParseDate(de) }
        paperId    = t.paperId
        photoSize  = t.photoSize ?? ""
        gelatinId  = t.gelatinChemistryId
        amountUsed = t.amountUsed ?? ""
        exposureId = t.exposureId
        layers     = t.layers.isEmpty ? [DRPhotoLayer()] : t.layers
        notes      = t.notes ?? ""
    }

    private func save() async {
        saving = true; error = nil
        let layerReqs = layers.map { DRLayerRequest(supportPaperId: $0.supportPaperId, negativeId: $0.negativeId, carbonTissueId: $0.carbonTissueId) }
        let req = DRPhotoRequest(
            dateSensitized: drFormatDate(dateSensitized),
            dateExposed: drFormatDate(dateExposed),
            paperId: paperId, photoSize: photoSize.isEmpty ? nil : photoSize,
            gelatinChemistryId: gelatinId, amountUsed: amountUsed.isEmpty ? nil : amountUsed,
            exposureId: exposureId, notes: notes.isEmpty ? nil : notes,
            layers: layerReqs)
        do {
            if let t = target { try await store.updatePhoto(id: t.id, req) }
            else { try await store.addPhoto(req) }
            onDone()
        } catch { self.error = error.localizedDescription }
        saving = false
    }
}
