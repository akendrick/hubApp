import SwiftUI
import PhotosUI

// MARK: - Root

struct DarkroomView: View {
    @ObservedObject var store: DarkroomStore
    @State private var selectedTab: DRTab = .photos

    enum DRTab: String, CaseIterable {
        case photos       = "Photos"
        case supportPaper = "Support Paper"
        case carbonTissue = "Carbon Tissue"
        case negatives    = "Negatives"
        case options      = "Options"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                drTabBar
                Divider()
                Group {
                    switch selectedTab {
                    case .photos:       DRPhotosTab(store: store)
                    case .supportPaper: DRSupportPaperTab(store: store)
                    case .carbonTissue: DRCarbonTissueTab(store: store)
                    case .negatives:    DRNegativesTab(store: store)
                    case .options:      DROptionsTab(store: store)
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
        )) { Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    private var drTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(DRTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                    } label: {
                        Text(tab.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(selectedTab == tab ? Color.primary : Color.clear)
                            .foregroundStyle(selectedTab == tab ? Color(uiColor: .systemBackground) : Color.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - Shared helpers

private struct DREmptyState: View {
    let label: String; let icon: String
    var body: some View {
        ContentUnavailableView("No \(label)", systemImage: icon, description: Text("Tap + to add one."))
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: PHOTOS TAB
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRPhotosTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm  = false
    @State private var editTarget: DRPhoto?
    @State private var detailPhoto: DRPhoto?

    let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        Group {
            if store.photos.isEmpty && !store.isLoading {
                DREmptyState(label: "photos", icon: "photo.stack")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.photos) { photo in
                            DRPhotoCard(photo: photo)
                                .onTapGesture { detailPhoto = photo }
                        }
                    }
                    .padding()
                }
                .refreshable { await store.loadPhotos() }
            }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { editTarget = nil; showForm = true } label: { Image(systemName: "plus") }
        }}
        .sheet(isPresented: $showForm, onDismiss: { editTarget = nil; Task { await store.loadPhotos() } }) {
            DRPhotoForm(store: store, target: editTarget) { showForm = false }
        }
        .sheet(item: $detailPhoto) { photo in
            DRPhotoDetail(store: store, photo: photo) { p in
                editTarget = p; detailPhoto = nil; showForm = true
            }
        }
        .task { await store.loadAllForPhotoForm(); await store.loadPhotos() }
    }
}

// MARK: Photo card

struct DRPhotoCard: View {
    let photo: DRPhoto
    var body: some View {
        VStack(spacing: 0) {
            if let path = photo.imagePath {
                AsyncImage(url: URL(string: path)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(uiColor: .secondarySystemBackground)
                        .overlay(ProgressView())
                }
                .frame(height: 130).clipped()
            } else {
                Color(uiColor: .secondarySystemBackground)
                    .frame(height: 130)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.quaternary))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(photo.title ?? "Untitled #\(photo.id)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                HStack {
                    Text(photo.dateExposed ?? "—").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    if let sz = photo.photoSize { Text(sz).font(.caption2).foregroundStyle(.secondary) }
                }
            }
            .padding(8)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
    }
}

// MARK: Photo detail sheet

struct DRPhotoDetail: View {
    @ObservedObject var store: DarkroomStore
    let photo: DRPhoto
    let onEdit: (DRPhoto) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Image
                    if let path = photo.imagePath {
                        AsyncImage(url: URL(string: path)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: { ProgressView() }
                        .frame(maxHeight: 300)
                    }

                    VStack(spacing: 12) {
                        // Photo basics
                        DRDetailSection(title: "Photo", accent: .primary) {
                            DRDetailRow("Size",       photo.photoSize)
                            DRDetailRow("Sensitized", photo.dateSensitized)
                            DRDetailRow("Exposed",    photo.dateExposed)
                            if let n = photo.notes { DRDetailRow("Notes", n) }
                        }

                        // Layers
                        ForEach(Array(photo.layers.enumerated()), id: \.element.id) { i, layer in
                            VStack(spacing: 6) {
                                Text("Layer \(i + 1)")
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)

                                if layer.supportPaperId != nil {
                                    DRDetailSection(title: "Support Paper", accent: .green) {
                                        DRDetailRow("Mark",  layer.spMark)
                                        DRDetailRow("Paper", layer.spPaperLabel)
                                        if let w = layer.spWeight { DRDetailRow("Weight", String(format: "%.0f gsm", w)) }
                                        DRDetailRow("Hot Press", layer.spHotPress == 1 ? "Yes" : "No")
                                        if let n = layer.spNotes { DRDetailRow("Notes", n) }
                                    }
                                }
                                if layer.carbonTissueId != nil {
                                    DRDetailSection(title: "Carbon Tissue", accent: .blue) {
                                        DRDetailRow("Title", layer.ctTitleId)
                                        DRDetailRow("Size",  layer.ctSize)
                                        DRDetailRow("Poured",layer.ctDate)
                                        DRDetailRow("Amount",layer.ctAmount)
                                        if let n = layer.ctNotes { DRDetailRow("Notes", n) }
                                    }
                                }
                                if layer.negativeId != nil {
                                    DRDetailSection(title: "Negative", accent: .orange) {
                                        DRDetailRow("Title",  layer.negTitleId)
                                        DRDetailRow("Type",   layer.negType)
                                        DRDetailRow("Date",   layer.negDate)
                                        if let n = layer.negNotes { DRDetailRow("Notes", n) }
                                    }
                                }
                            }
                        }

                        // Exposure
                        DRDetailSection(title: "Exposure", accent: .yellow) {
                            DRDetailRow("Test Strip", photo.testStrip == 1 ? "Yes" : "No")
                            if !photo.times.isEmpty {
                                DRDetailRow("Times", photo.times.compactMap { $0.durationMinutes }.map { String(format: "%.0f min", $0) }.joined(separator: " · "))
                            }
                        }

                        // Development
                        DRDetailSection(title: "Development", accent: .purple) {
                            if let t = photo.paperSoakTime {
                                DRDetailRow("Paper Soak", "\(t) min\(photo.paperSoakTemp.map { " / \($0)°C" } ?? "")")
                            }
                            if let t = photo.hotDevelopTime {
                                DRDetailRow("HOT Develop", "\(t) s\(photo.hotDevelopTemp.map { " / \($0)°C" } ?? "")")
                            }
                            if let t = photo.coolDevelopTime {
                                DRDetailRow("COOL Develop", "\(t) s\(photo.coolDevelopTemp.map { " / \($0)°C" } ?? "")")
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(photo.title ?? "Photo #\(photo.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { dismiss(); onEdit(photo) }
                }
            }
        }
    }
}

private struct DRDetailSection<Content: View>: View {
    let title: String; let accent: Color; @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(accent)
                .padding(.horizontal).padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.1))
            content
        }
        .background(accent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

private struct DRDetailRow: View {
    let key: String; let value: String?
    init(_ key: String, _ value: String?) { self.key = key; self.value = value }
    var body: some View {
        if let v = value, !v.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Text(key).font(.caption2).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                Text(v).font(.caption)
                Spacer()
            }
            .padding(.horizontal).padding(.vertical, 4)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: PHOTO FORM (big, sectioned)
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRPhotoForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRPhoto?
    let onDone: () -> Void

    // Photo fields
    @State private var title          = ""
    @State private var photoSize      = ""
    @State private var dateSensitized = Date()
    @State private var dateExposed    = Date()
    @State private var notes          = ""

    // Image picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImageMime = "image/jpeg"

    // Layers
    @State private var layers: [DRPhotoLayer] = [DRPhotoLayer()]

    // Exposure
    @State private var testStrip = false
    @State private var times: [DRPhotoTime] = [DRPhotoTime()]

    // Development
    @State private var soakTime = ""
    @State private var soakTemp = ""
    @State private var hotTime  = ""
    @State private var hotTemp  = ""
    @State private var coolTime = ""
    @State private var coolTemp = ""

    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                // ── PHOTO ──
                Section {
                    TextField("Title", text: $title, prompt: Text("Portrait Study, Landscape…"))
                    TextField("Size", text: $photoSize, prompt: Text("e.g. 8×10, 4×5"))
                    DatePicker("Sensitized", selection: $dateSensitized, displayedComponents: .date)
                    DatePicker("Exposed",    selection: $dateExposed,    displayedComponents: .date)
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(selectedImageData == nil ? "Choose Image…" : "Change Image", systemImage: "photo")
                    }
                    .onChange(of: selectedPhotoItem) { _, item in
                        Task {
                            guard let item else { return }
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                selectedImageData = data
                                selectedImageMime = "image/jpeg"
                            }
                        }
                    }
                    if selectedImageData != nil {
                        Label("Image selected", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.green)
                    }
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4)
                } header: { Text("Photo") }

                // ── LAYERS ──
                Section {
                    ForEach($layers) { $layer in
                        DRLayerEditor(layer: $layer, store: store, onTitleSuggestion: { suggestion in
                            if title.isEmpty { title = suggestion }
                        })
                    }
                    .onDelete { layers.remove(atOffsets: $0) }
                    Button { layers.append(DRPhotoLayer()) }
                    label: { Label("Add Layer", systemImage: "plus.circle") }
                } header: { Text("Layers") }

                // ── EXPOSURE ──
                Section {
                    Toggle("Test Strip", isOn: $testStrip)
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
                    HStack(spacing: 12) {
                        Button { times.append(DRPhotoTime()) }
                        label: { Label("Interval", systemImage: "plus.circle") }
                        if testStrip, let last = times.last?.durationMinutes {
                            Button { times.append(DRPhotoTime(durationMinutes: last)) }
                            label: { Label("Repeat Last", systemImage: "repeat") }
                        }
                    }
                    .font(.caption)
                } header: { Text("Exposure") }

                // ── DEVELOPMENT ──
                Section {
                    DRTwoField(label: "Paper Soak", left: $soakTime, leftHint: "min",
                               right: $soakTemp, rightHint: "°C")
                    DRTwoField(label: "HOT Develop", left: $hotTime, leftHint: "sec",
                               right: $hotTemp, rightHint: "°C")
                    DRTwoField(label: "COOL Develop", left: $coolTime, leftHint: "sec",
                               right: $coolTemp, rightHint: "°C")
                } header: { Text("Development") }

                if let e = error { Section { Text(e).foregroundStyle(.red).font(.caption) } }
            }
            .navigationTitle(target == nil ? "New Photo" : "Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target == nil ? "Add" : "Save") { Task { await save() } }
                        .disabled(saving)
                        .overlay { if saving { ProgressView().scaleEffect(0.75) } }
                }
            }
        }
        .onAppear { populate() }
    }

    private func populate() {
        guard let t = target else { return }
        title          = t.title ?? ""
        photoSize      = t.photoSize ?? ""
        if let ds = t.dateSensitized { dateSensitized = drParseDate(ds) }
        if let de = t.dateExposed    { dateExposed    = drParseDate(de) }
        notes          = t.notes ?? ""
        testStrip      = t.testStrip == 1
        soakTime       = t.paperSoakTime.map  { String($0) } ?? ""
        soakTemp       = t.paperSoakTemp.map  { String($0) } ?? ""
        hotTime        = t.hotDevelopTime.map { String($0) } ?? ""
        hotTemp        = t.hotDevelopTemp.map { String($0) } ?? ""
        coolTime       = t.coolDevelopTime.map{ String($0) } ?? ""
        coolTemp       = t.coolDevelopTemp.map{ String($0) } ?? ""
        layers         = t.layers.isEmpty ? [DRPhotoLayer()] : t.layers
        times          = t.times.isEmpty  ? [DRPhotoTime()]  : t.times
    }

    private func save() async {
        saving = true; error = nil
        let validTimes = times.compactMap { t -> DRTimeRequest? in
            guard let d = t.durationMinutes, d > 0 else { return nil }
            return DRTimeRequest(durationMinutes: d)
        }
        let layerReqs = layers.map {
            DRLayerRequest(supportPaperId: $0.supportPaperId, negativeId: $0.negativeId, carbonTissueId: $0.carbonTissueId)
        }
        let req = DRPhotoRequest(
            title: title.isEmpty ? nil : title,
            paperId: nil,
            photoSize: photoSize.isEmpty ? nil : photoSize,
            dateSensitized: drFormatDate(dateSensitized),
            dateExposed: drFormatDate(dateExposed),
            testStrip: testStrip,
            paperSoakTime: Int(soakTime), paperSoakTemp: Double(soakTemp),
            hotDevelopTime: Int(hotTime),  hotDevelopTemp: Double(hotTemp),
            coolDevelopTime: Int(coolTime), coolDevelopTemp: Double(coolTemp),
            notes: notes.isEmpty ? nil : notes,
            times: validTimes, layers: layerReqs)
        do {
            let photoId: Int
            if let t = target {
                try await store.updatePhoto(id: t.id, req)
                photoId = t.id
            } else {
                photoId = try await store.addPhoto(req)
            }
            // Upload image if selected
            if let imgData = selectedImageData {
                try await store.uploadPhotoImage(photoId: photoId, imageData: imgData, mimeType: selectedImageMime)
            }
            await store.loadPhotos()
            onDone()
        } catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: - Layer editor row (inside the photo form)

struct DRLayerEditor: View {
    @Binding var layer: DRPhotoLayer
    @ObservedObject var store: DarkroomStore
    let onTitleSuggestion: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Support Paper
            VStack(alignment: .leading, spacing: 4) {
                Text("Support Paper").font(.caption2).foregroundStyle(.green)
                Picker("Support Paper", selection: $layer.supportPaperId) {
                    Text("None").tag(Int?.none)
                    ForEach(store.supportPapers) { sp in Text(sp.displayName).tag(sp.id as Int?) }
                }
                if let id = layer.supportPaperId, let sp = store.supportPapers.first(where: { $0.id == id }) {
                    DRInlineInfo {
                        DRInfoChip(label: "Mark", value: sp.mark, color: .green)
                        if let w = sp.weight { DRInfoChip(label: "gsm", value: String(format: "%.0f", w), color: .green) }
                        DRInfoChip(label: "HP", value: sp.hotPress == 1 ? "Yes" : "No", color: .green)
                    }
                }
            }
            .padding(10)
            .background(Color.green.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Carbon Tissue
            VStack(alignment: .leading, spacing: 4) {
                Text("Carbon Tissue").font(.caption2).foregroundStyle(.blue)
                Picker("Carbon Tissue", selection: $layer.carbonTissueId) {
                    Text("None").tag(Int?.none)
                    ForEach(store.carbonTissues) { ct in Text(ct.menuLabel).tag(ct.id as Int?) }
                }
                if let id = layer.carbonTissueId, let ct = store.carbonTissues.first(where: { $0.id == id }) {
                    DRInlineInfo {
                        DRInfoChip(label: "Size",   value: ct.size ?? "—", color: .blue)
                        DRInfoChip(label: "Poured", value: ct.datePoured, color: .blue)
                        if let amt = ct.amountPoured { DRInfoChip(label: "Amt", value: amt, color: .blue) }
                    }
                }
            }
            .padding(10)
            .background(Color.blue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Negative
            VStack(alignment: .leading, spacing: 4) {
                Text("Negative").font(.caption2).foregroundStyle(.orange)
                Picker("Negative", selection: $layer.negativeId) {
                    Text("None").tag(Int?.none)
                    ForEach(store.negatives) { n in Text(n.menuLabel).tag(n.id as Int?) }
                }
                .onChange(of: layer.negativeId) { _, newId in
                    guard let id = newId, let neg = store.negatives.first(where: { $0.id == id }) else { return }
                    if let t = neg.titleId, !t.isEmpty {
                        let ym = drDateToYYMM(neg.dateCreated)
                        onTitleSuggestion("\(t).\(ym)")
                    }
                }
                if let id = layer.negativeId, let neg = store.negatives.first(where: { $0.id == id }) {
                    DRInlineInfo {
                        if let t = neg.titleId { DRInfoChip(label: "Title", value: t, color: .orange) }
                        DRInfoChip(label: "Type", value: neg.typeName ?? "—", color: .orange)
                        DRInfoChip(label: "Date", value: neg.dateCreated, color: .orange)
                    }
                }
            }
            .padding(10)
            .background(Color.orange.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.vertical, 4)
    }
}

private struct DRInlineInfo<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) { content }
        }
    }
}

private struct DRInfoChip: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 7, weight: .semibold)).foregroundStyle(color.opacity(0.7))
            Text(value).font(.system(size: 11)).foregroundStyle(color)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct DRTwoField: View {
    let label: String
    @Binding var left: String; let leftHint: String
    @Binding var right: String; let rightHint: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                TextField(leftHint, text: $left).keyboardType(.numberPad)
                TextField(rightHint, text: $right).keyboardType(.decimalPad)
            }
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: SUPPORT PAPER TAB
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRSupportPaperTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false; @State private var editTarget: DRSupportPaper?
    var body: some View {
        List {
            if store.supportPapers.isEmpty { DREmptyState(label: "support papers", icon: "doc.badge.plus") }
            ForEach(store.supportPapers) { sp in
                HStack(spacing: 12) {
                    Text(sp.mark).font(.headline.weight(.bold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.green).clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sp.paperLabel ?? sp.displayName).font(.subheadline)
                        HStack(spacing: 6) {
                            if let w = sp.weight { Text(String(format: "%.0f gsm", w)).font(.caption).foregroundStyle(.secondary) }
                            if sp.hotPress == 1 { Text("HP").font(.caption2.weight(.semibold)).foregroundStyle(.blue) }
                        }
                    }
                }
                .contentShape(Rectangle()).onTapGesture { editTarget = sp; showForm = true }
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
        .task { await store.loadAllForPhotoForm(); await store.loadSupportPapers() }
        .refreshable { await store.loadSupportPapers() }
    }
}

struct DRSupportPaperForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRSupportPaper?; let onDone: () -> Void
    @State private var paperId: Int? = nil; @State private var mark = ""; @State private var notes = ""
    @State private var saving = false; @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Base Paper") {
                    Picker("Paper", selection: $paperId) {
                        Text("Select…").tag(Int?.none)
                        ForEach(store.papers) { p in Text(p.displayName).tag(p.id as Int?) }
                    }
                }
                Section("Mark") { TextField("e.g. A1, B3", text: $mark).autocorrectionDisabled().textInputAutocapitalization(.characters).onChange(of: mark){ _,v in mark = v.uppercased() } }
                Section("Notes") { TextField("Notes…", text: $notes, axis: .vertical).lineLimit(3...5) }
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
        .onAppear { if let t = target { paperId = t.paperId; mark = t.mark; notes = t.notes ?? "" } }
    }
    private func save() async {
        guard let pid = paperId else { return }
        saving = true; error = nil
        let req = DRSupportPaperRequest(paperId: pid, mark: mark, notes: notes.isEmpty ? nil : notes)
        do { if let t = target { try await store.updateSupportPaper(id: t.id, req) } else { try await store.addSupportPaper(req) }; onDone() }
        catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: CARBON TISSUE TAB
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRCarbonTissueTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false; @State private var editTarget: DRCarbonTissue?
    var body: some View {
        List {
            if store.carbonTissues.isEmpty { DREmptyState(label: "carbon tissue batches", icon: "square.stack") }
            ForEach(store.carbonTissues) { ct in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(ct.menuLabel).font(.headline)
                        Spacer()
                        Text(ct.datePoured).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        if let sz = ct.size { Text(sz).font(.caption).foregroundStyle(.secondary) }
                        if let c = ct.chemType { Text(c).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .contentShape(Rectangle()).onTapGesture { editTarget = ct; showForm = true }
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
        .task { await store.loadAllForPhotoForm(); await store.loadCarbonTissues() }
        .refreshable { await store.loadCarbonTissues() }
    }
}

struct DRCarbonTissueForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRCarbonTissue?; let onDone: () -> Void
    @State private var titleId = ""; @State private var date = Date(); @State private var size = ""
    @State private var chemId: Int? = nil; @State private var amount = ""; @State private var notes = ""
    @State private var saving = false; @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Title / ID", text: $titleId, prompt: Text("Portrait, Landscape…"))
                    DatePicker("Date Poured", selection: $date, displayedComponents: .date)
                }
                Section("Details") {
                    TextField("Size (e.g. 8×10)", text: $size)
                    Picker("Chemistry Used", selection: $chemId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.chemistry) { c in Text("#\(c.id) \(c.typeName ?? "") \(c.dateCreated)").tag(c.id as Int?) }
                    }
                    TextField("Amount Poured (e.g. 45ml)", text: $amount)
                }
                Section("Notes") { TextField("Notes…", text: $notes, axis: .vertical).lineLimit(3...5) }
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
        .onAppear { if let t = target { titleId = t.titleId ?? ""; date = drParseDate(t.datePoured); size = t.size ?? ""; chemId = t.chemistryId; amount = t.amountPoured ?? ""; notes = t.notes ?? "" } }
    }
    private func save() async {
        saving = true; error = nil
        let req = DRCarbonTissueRequest(titleId: titleId.isEmpty ? nil : titleId, size: size.isEmpty ? nil : size, chemistryId: chemId, amountPoured: amount.isEmpty ? nil : amount, datePoured: drFormatDate(date), notes: notes.isEmpty ? nil : notes)
        do { if let t = target { try await store.updateCarbonTissue(id: t.id, req) } else { try await store.addCarbonTissue(req) }; onDone() }
        catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: NEGATIVES TAB
// MARK: ─────────────────────────────────────────────────────────────────────

struct DRNegativesTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false; @State private var editTarget: DRNegative?
    var body: some View {
        List {
            if store.negatives.isEmpty { DREmptyState(label: "negatives", icon: "photo") }
            ForEach(store.negatives) { n in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(n.menuLabel).font(.headline)
                        Spacer()
                        Text(n.dateCreated).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        if let t = n.typeName { Text(t).font(.caption).foregroundStyle(.secondary) }
                    }
                    if let sn = n.settingsNotes { Text(sn).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                }
                .contentShape(Rectangle()).onTapGesture { editTarget = n; showForm = true }
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
    let target: DRNegative?; let onDone: () -> Void
    @State private var titleId = ""; @State private var date = Date()
    @State private var typeId: Int? = nil; @State private var notes = ""
    @State private var saving = false; @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Title / ID", text: $titleId, prompt: Text("Portrait, Landscape…"))
                    DatePicker("Date Created", selection: $date, displayedComponents: .date)
                }
                Section("Type") {
                    Picker("Negative Type", selection: $typeId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.negativeTypes) { t in Text(t.name).tag(t.id as Int?) }
                    }
                }
                Section("Settings & Notes") { TextField("Camera settings, film info…", text: $notes, axis: .vertical).lineLimit(3...8) }
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
        .onAppear { if let t = target { titleId = t.titleId ?? ""; date = drParseDate(t.dateCreated); typeId = t.typeId; notes = t.settingsNotes ?? "" } }
    }
    private func save() async {
        saving = true; error = nil
        let req = DRNegativeRequest(titleId: titleId.isEmpty ? nil : titleId, dateCreated: drFormatDate(date), typeId: typeId, settingsNotes: notes.isEmpty ? nil : notes)
        do { if let t = target { try await store.updateNegative(id: t.id, req) } else { try await store.addNegative(req) }; onDone() }
        catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: OPTIONS TAB
// MARK: ─────────────────────────────────────────────────────────────────────

struct DROptionsTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var newChemType = ""; @State private var newNegType = ""
    @State private var showAllChem = false; @State private var showAllPaper = false

    var body: some View {
        List {
            Section("Chemistry Types") {
                ForEach(store.chemistryTypes) { t in
                    HStack { Text(t.name); Spacer()
                        Button { Task { await deleteType("chemistry_types", id: t.id) } }
                        label: { Image(systemName: "trash").foregroundStyle(.red) }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("New type…", text: $newChemType).submitLabel(.done).onSubmit { Task { await addType("chemistry_types") } }
                    Button("Add") { Task { await addType("chemistry_types") } }
                        .disabled(newChemType.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Negative Types") {
                ForEach(store.negativeTypes) { t in
                    HStack { Text(t.name); Spacer()
                        Button { Task { await deleteType("negative_types", id: t.id) } }
                        label: { Image(systemName: "trash").foregroundStyle(.red) }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("New type…", text: $newNegType).submitLabel(.done).onSubmit { Task { await addType("negative_types") } }
                    Button("Add") { Task { await addType("negative_types") } }
                        .disabled(newNegType.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Recent Chemistry") {
                let slice = showAllChem ? store.chemistry : Array(store.chemistry.prefix(10))
                ForEach(slice) { c in
                    Text("#\(c.id) \(c.typeName ?? "") \(c.dateCreated)\(c.percentSolution.map { " · \($0)%" } ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if store.chemistry.count > 10 {
                    Button(showAllChem ? "Show Less" : "More (\(store.chemistry.count - 10) more)") { showAllChem.toggle() }
                        .font(.caption)
                }
            }

            Section("Recent Paper") {
                let slice = showAllPaper ? store.papers : Array(store.papers.prefix(10))
                ForEach(slice) { p in
                    Text("#\(p.id) \(p.displayName)\(p.weight.map { " · \(Int($0)) gsm" } ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if store.papers.count > 10 {
                    Button(showAllPaper ? "Show Less" : "More (\(store.papers.count - 10) more)") { showAllPaper.toggle() }
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .task { await store.loadTypes() }
    }

    private func addType(_ res: String) async {
        let name = (res == "chemistry_types" ? newChemType : newNegType).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            _ = try await DarkroomAPIClient.create(serverURL: store.serverURL, apiKey: store.apiKey, res: res, body: DRLookupRequest(name: name))
            if res == "chemistry_types" { newChemType = "" } else { newNegType = "" }
            await store.loadTypes()
        } catch { store.errorMessage = error.localizedDescription }
    }

    private func deleteType(_ res: String, id: Int) async {
        do {
            try await DarkroomAPIClient.delete(serverURL: store.serverURL, apiKey: store.apiKey, res: res, id: id)
            await store.loadTypes()
        } catch { store.errorMessage = error.localizedDescription }
    }
}

private struct DRLookupRequest: Encodable { var name: String }
