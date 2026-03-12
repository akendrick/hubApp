import SwiftUI
import PhotosUI

// MARK: - Root

struct DarkroomView: View {
    @ObservedObject var store: DarkroomStore
    @State private var selectedTab: DRTab = .photos

    enum DRTab: String, CaseIterable {
        case photos = "Photos"
        case layers = "Layers"
        case more   = "More"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                drTabBar
                Divider()
                Group {
                    switch selectedTab {
                    case .photos: DRPhotosTab(store: store)
                    case .layers: DRLayersTab(store: store)
                    case .more:   DRMoreTab(store: store)
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

private struct DREmptyState: View {
    let label: String; let icon: String
    var body: some View {
        ContentUnavailableView("No \(label)", systemImage: icon, description: Text("Tap + to add one."))
    }
}


// MARK: - Photos Tab

struct DRPhotosTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false
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
                            DRPhotoCard(photo: photo).onTapGesture { detailPhoto = photo }
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
            DRPhotoDetail(store: store, photo: photo) { p in editTarget = p; detailPhoto = nil; showForm = true }
        }
        .task { await store.loadAllForPhotoForm(); await store.loadPhotos() }
    }
}

struct DRPhotoCard: View {
    let photo: DRPhoto
    var body: some View {
        VStack(spacing: 0) {
            if let path = photo.imagePath {
                AsyncImage(url: URL(string: path)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(uiColor: .secondarySystemBackground).overlay(ProgressView())
                }
                .frame(height: 130).clipped()
            } else {
                Color(uiColor: .secondarySystemBackground).frame(height: 130)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.quaternary))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(photo.title ?? "Untitled #\(photo.id)").font(.caption.weight(.semibold)).lineLimit(1)
                HStack {
                    if let type = photo.typeName {
                        Text(type).font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12)).clipShape(Capsule())
                    }
                    Spacer()
                    if let sz = photo.photoSize { Text(sz).font(.caption2).foregroundStyle(.secondary) }
                }
                Text(photo.dateExposed ?? "—").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
    }
}


// MARK: - Photo Detail

struct DRPhotoDetail: View {
    @ObservedObject var store: DarkroomStore
    let photo: DRPhoto
    let onEdit: (DRPhoto) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let path = photo.imagePath {
                        AsyncImage(url: URL(string: path)) { img in img.resizable().scaledToFit() }
                            placeholder: { ProgressView() }
                            .frame(maxHeight: 300)
                    }
                    VStack(spacing: 12) {
                        // Basics
                        DRDetailSection(title: "Photo", accent: .primary) {
                            if let t = photo.typeName { DRDetailRow("Type", t) }
                            DRDetailRow("Size",       photo.photoSize)
                            DRDetailRow("Sensitized", photo.dateSensitized)
                            DRDetailRow("Exposed",    photo.dateExposed)
                            if let n = photo.notes { DRDetailRow("Notes", n) }
                        }
                        // Layers
                        if photo.showLayers {
                            ForEach(Array(photo.layers.enumerated()), id: \.element.id) { i, layer in
                                VStack(spacing: 6) {
                                    Text("Layer \(i+1)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                                    if layer.supportPaperId != nil {
                                        DRDetailSection(title: "Support Paper", accent: .green) {
                                            DRDetailRow("Mark", layer.spMark); DRDetailRow("Paper", layer.spPaperLabel)
                                            if let w = layer.spWeight { DRDetailRow("Weight", String(format: "%.0f gsm", w)) }
                                            if let n = layer.spNotes { DRDetailRow("Notes", n) }
                                        }
                                    }
                                    if layer.carbonTissueId != nil {
                                        DRDetailSection(title: "Carbon Tissue", accent: .blue) {
                                            DRDetailRow("Title", layer.ctTitleId); DRDetailRow("Size", layer.ctSize)
                                            DRDetailRow("Poured", layer.ctDate); DRDetailRow("Amount", layer.ctAmount)
                                            if let n = layer.ctNotes { DRDetailRow("Notes", n) }
                                        }
                                    }
                                    if layer.negativeId != nil {
                                        DRDetailSection(title: "Negative", accent: .orange) {
                                            DRDetailRow("Title", layer.negTitleId); DRDetailRow("Type", layer.negType)
                                            DRDetailRow("Date", layer.negDate)
                                            if let n = layer.negNotes { DRDetailRow("Notes", n) }
                                        }
                                    }
                                }
                            }
                        }
                        // Exposure
                        DRDetailSection(title: "Exposure", accent: .yellow) {
                            DRDetailRow("Test Strip", photo.testStrip == 1 ? "Yes" : "No")
                            if let d = photo.exposureDuration { DRDetailRow("Duration", String(format: "%.1f min", d)) }
                            if !photo.times.isEmpty {
                                DRDetailRow("Intervals",
                                    photo.times.compactMap { $0.durationMinutes }
                                        .map { String(format: "%.0f min", $0) }.joined(separator: " → "))
                            }
                        }
                        // Development - carbon
                        if photo.isCarbonDev {
                            DRDetailSection(title: "Development", accent: .purple) {
                                if let t = photo.paperSoakTime { DRDetailRow("Paper Soak", "\(t) min\(photo.paperSoakTemp.map{" / \($0)°C"} ?? "")") }
                                if let t = photo.hotDevelopTime { DRDetailRow("HOT Develop", "\(t) s\(photo.hotDevelopTemp.map{" / \($0)°C"} ?? "")") }
                                if let t = photo.coolDevelopTime { DRDetailRow("COOL Develop", "\(t) s\(photo.coolDevelopTemp.map{" / \($0)°C"} ?? "")") }
                            }
                        } else if photo.developTime != nil || photo.developTemp != nil || photo.developNotes != nil {
                            DRDetailSection(title: "Development", accent: .purple) {
                                if let t = photo.developTime { DRDetailRow("Time / Temp", "\(t) s\(photo.developTemp.map{" / \($0)°C"} ?? "")") }
                                if let n = photo.developNotes { DRDetailRow("Notes", n) }
                            }
                        }
                        // Finishing
                        if !photo.finishing.isEmpty {
                            DRDetailSection(title: "Finishing", accent: .teal) {
                                ForEach(photo.finishing) { step in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(step.label.isEmpty ? "Step" : step.label).font(.caption.weight(.semibold))
                                        HStack(spacing: 12) {
                                            if let t = step.stepTime { Text("\(t) s").font(.caption2).foregroundStyle(.secondary) }
                                            if let t = step.stepTemp { Text(String(format: "%.1f°C", t)).font(.caption2).foregroundStyle(.secondary) }
                                            if let c = step.chemTypeName { Text(c).font(.caption2).foregroundStyle(.teal) }
                                        }
                                        if let n = step.notes { Text(n).font(.caption2).foregroundStyle(.secondary) }
                                    }
                                    .padding(.horizontal).padding(.vertical, 4)
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(photo.title ?? "Photo #\(photo.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Edit") { dismiss(); onEdit(photo) } }
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
                .frame(maxWidth: .infinity, alignment: .leading).background(accent.opacity(0.1))
            content
        }
        .background(accent.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 8)).padding(.horizontal)
    }
}

private struct DRDetailRow: View {
    let key: String; let value: String?
    init(_ key: String, _ value: String?) { self.key = key; self.value = value }
    var body: some View {
        if let v = value, !v.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Text(key).font(.caption2).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                Text(v).font(.caption); Spacer()
            }
            .padding(.horizontal).padding(.vertical, 4)
        }
    }
}


// MARK: - Photo Form

struct DRPhotoForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRPhoto?
    let onDone: () -> Void

    @State private var title           = ""
    @State private var photoTypeId: Int? = nil
    @State private var photoSize       = ""
    @State private var dateSensitized  = Date()
    @State private var dateExposed     = Date()
    @State private var notes           = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImageMime = "image/jpeg"
    @State private var layers: [DRPhotoLayer] = [DRPhotoLayer()]
    @State private var testStrip        = false
    @State private var exposureDuration = ""
    @State private var times: [DRPhotoTime] = []
    @State private var soakTime = ""; @State private var soakTemp = ""
    @State private var hotTime  = ""; @State private var hotTemp  = ""
    @State private var coolTime = ""; @State private var coolTemp = ""
    @State private var developTime  = ""; @State private var developTemp = ""; @State private var developNotes = ""
    @State private var finishingSteps: [DRFinishingStep] = []
    @State private var saving = false
    @State private var error: String?

    private var currentType: DRPhotoType? {
        guard let tid = photoTypeId else { return nil }
        return store.photoTypes.first { $0.id == tid }
    }
    private var finishingPresets: [String] {
        let labels = store.finishingTypes
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return labels.isEmpty ? ["Clearing Bath", "Fixative", "Toner", "Bleach", "Stop Bath", "Wash", "Hypo Clear", "Selenium"] : labels
    }
    private var showLayers:  Bool { currentType?.showLayers  ?? false }
    private var isCarbonDev: Bool { currentType?.isCarbonDev ?? false }

    var body: some View {
        NavigationStack {
            Form {
                // Photo
                Section("Photo") {
                    Picker("Process Type", selection: $photoTypeId) {
                        Text("Select Type…").tag(Int?.none)
                        ForEach(store.photoTypes) { pt in Text(pt.name).tag(pt.id as Int?) }
                    }
                    TextField("Title", text: $title, prompt: Text("Portrait Study, Landscape…"))
                    TextField("Size", text: $photoSize, prompt: Text("e.g. 8×10, 4×5"))
                    DatePicker("Sensitized", selection: $dateSensitized, displayedComponents: .date)
                    DatePicker("Exposed",    selection: $dateExposed,    displayedComponents: .date)
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(selectedImageData == nil ? "Choose Image…" : "Change Image", systemImage: "photo")
                    }
                    .onChange(of: selectedPhotoItem) { _, item in
                        Task { guard let item else { return }
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                selectedImageData = data; selectedImageMime = "image/jpeg" } }
                    }
                    if selectedImageData != nil {
                        Label("Image selected", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                    }
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4)
                }

                // Layers (carbon transfer etc.)
                if showLayers {
                    Section("Layers") {
                        ForEach($layers) { $layer in
                            DRLayerEditor(layer: $layer, store: store) { sug in if title.isEmpty { title = sug } }
                        }
                        .onDelete { layers.remove(atOffsets: $0) }
                        Button { layers.append(DRPhotoLayer()) } label: { Label("Add Layer", systemImage: "plus.circle") }
                    }
                }

                // Exposure
                Section("Exposure") {
                    Toggle("Test Strip", isOn: $testStrip)
                        .onChange(of: testStrip) { _, on in if on && times.isEmpty { times.append(DRPhotoTime()) } }
                    HStack {
                        Image(systemName: "timer").foregroundStyle(.yellow)
                        TextField("Duration (min)", text: $exposureDuration).keyboardType(.decimalPad)
                        Text("min").font(.caption).foregroundStyle(.secondary)
                    }
                    if testStrip {
                        ForEach($times) { $t in
                            HStack {
                                Image(systemName: "arrow.right.circle").foregroundStyle(.secondary)
                                TextField("Interval (min)", value: $t.durationMinutes, format: .number).keyboardType(.decimalPad)
                                Text("min").font(.caption).foregroundStyle(.secondary)
                                if times.count > 1 {
                                    Button { times.removeAll { $0.id == t.id } }
                                    label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }.buttonStyle(.plain)
                                }
                            }
                        }
                        HStack(spacing: 12) {
                            Button { times.append(DRPhotoTime()) } label: { Label("Add Interval", systemImage: "plus.circle") }
                            if let last = times.last?.durationMinutes {
                                Button { times.append(DRPhotoTime(durationMinutes: last)) }
                                label: { Label("Repeat Last", systemImage: "repeat") }
                            }
                        }
                        .font(.caption)
                    }
                }

                // Development — carbon
                if isCarbonDev {
                    Section("Development") {
                        DRTwoField(label: "Paper Soak",   left: $soakTime, leftHint: "min",  right: $soakTemp, rightHint: "°C")
                        DRTwoField(label: "HOT Develop",  left: $hotTime,  leftHint: "sec",  right: $hotTemp,  rightHint: "°C")
                        DRTwoField(label: "COOL Develop", left: $coolTime, leftHint: "sec",  right: $coolTemp, rightHint: "°C")
                    }
                }

                // Development — simple
                if !isCarbonDev && photoTypeId != nil {
                    Section("Development") {
                        DRTwoField(label: "Develop", left: $developTime, leftHint: "sec", right: $developTemp, rightHint: "°C")
                        TextField("Notes", text: $developNotes, axis: .vertical).lineLimit(2...4)
                        HStack(spacing: 10) {
                            Text("Quick add:").font(.caption2).foregroundStyle(.secondary)
                            ForEach(Array(finishingPresets.prefix(4)), id: \.self) { label in
                                Button {
                                    finishingSteps.append(DRFinishingStep(label: label))
                                } label: {
                                    Text(label)
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.12))
                                        .foregroundStyle(Color.purple)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                // Finishing
                Section("Finishing") {
                    if finishingSteps.isEmpty {
                        Text("No finishing steps yet.").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach($finishingSteps) { $step in
                        DRFinishingEditor(step: $step, store: store, presets: finishingPresets)
                    }
                    .onDelete { finishingSteps.remove(atOffsets: $0) }
                    Button { finishingSteps.append(DRFinishingStep()) }
                    label: { Label("Add Step", systemImage: "plus.circle") }
                }

                if let e = error { Section { Text(e).foregroundStyle(.red).font(.caption) } }
            }
            .navigationTitle(target == nil ? "New Photo" : "Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target == nil ? "Add" : "Save") { Task { await save() } }
                        .disabled(saving).overlay { if saving { ProgressView().scaleEffect(0.75) } }
                }
            }
        }
        .onAppear { populate() }
        .onChange(of: store.photoTypes) { _, _ in
            guard target == nil, photoTypeId == nil else { return }
            populate()
        }
        .task {
            await store.loadFinishingTypes()
        }
    }

    private func populate() {
        guard let t = target else {
            if photoTypeId == nil,
               let carbonTransfer = store.photoTypes.first(where: { $0.name.compare("Carbon Transfer", options: .caseInsensitive) == .orderedSame }) {
                photoTypeId = carbonTransfer.id
            }
            return
        }
        title           = t.title ?? "";          photoTypeId = t.photoTypeId
        photoSize       = t.photoSize ?? ""
        if let ds = t.dateSensitized { dateSensitized = drParseDate(ds) }
        if let de = t.dateExposed    { dateExposed    = drParseDate(de) }
        notes           = t.notes ?? "";           testStrip = t.testStrip == 1
        exposureDuration = t.exposureDuration.map { String($0) } ?? ""
        soakTime = t.paperSoakTime.map  { String($0) } ?? ""; soakTemp = t.paperSoakTemp.map  { String($0) } ?? ""
        hotTime  = t.hotDevelopTime.map { String($0) } ?? ""; hotTemp  = t.hotDevelopTemp.map { String($0) } ?? ""
        coolTime = t.coolDevelopTime.map{ String($0) } ?? ""; coolTemp = t.coolDevelopTemp.map{ String($0) } ?? ""
        developTime  = t.developTime.map  { String($0) } ?? ""; developTemp  = t.developTemp.map  { String($0) } ?? ""
        developNotes = t.developNotes ?? ""
        layers = t.layers.isEmpty ? [DRPhotoLayer()] : t.layers
        times  = t.times;  finishingSteps = t.finishing
    }

    private func save() async {
        saving = true; error = nil
        let validTimes  = times.compactMap { t -> DRTimeRequest? in
            guard let d = t.durationMinutes, d > 0 else { return nil }; return DRTimeRequest(durationMinutes: d) }
        let layerReqs   = showLayers ? layers.map {
            DRLayerRequest(supportPaperId: $0.supportPaperId, negativeId: $0.negativeId, carbonTissueId: $0.carbonTissueId) } : []
        let finishReqs  = finishingSteps.map {
            DRFinishingRequest(label: $0.label, chemistryId: $0.chemistryId,
                               stepTime: $0.stepTime, stepTemp: $0.stepTemp, notes: $0.notes) }
        let req = DRPhotoRequest(
            title: title.isEmpty ? nil : title,
            photoTypeId: photoTypeId, paperId: nil,
            photoSize: photoSize.isEmpty ? nil : photoSize,
            dateSensitized: drFormatDate(dateSensitized), dateExposed: drFormatDate(dateExposed),
            testStrip: testStrip, exposureDuration: Double(exposureDuration),
            times: validTimes,
            paperSoakTime:  isCarbonDev ? Int(soakTime)    : nil,
            paperSoakTemp:  isCarbonDev ? Double(soakTemp) : nil,
            hotDevelopTime: isCarbonDev ? Int(hotTime)     : nil,
            hotDevelopTemp: isCarbonDev ? Double(hotTemp)  : nil,
            coolDevelopTime:isCarbonDev ? Int(coolTime)    : nil,
            coolDevelopTemp:isCarbonDev ? Double(coolTemp) : nil,
            developTime:  !isCarbonDev ? Int(developTime)    : nil,
            developTemp:  !isCarbonDev ? Double(developTemp) : nil,
            developNotes: !isCarbonDev && !developNotes.isEmpty ? developNotes : nil,
            notes: notes.isEmpty ? nil : notes,
            layers: layerReqs, finishing: finishReqs)
        do {
            let photoId: Int
            if let t = target { try await store.updatePhoto(id: t.id, req); photoId = t.id }
            else               { photoId = try await store.addPhoto(req) }
            if let imgData = selectedImageData {
                try await store.uploadPhotoImage(photoId: photoId, imageData: imgData, mimeType: selectedImageMime) }
            await store.loadPhotos(); onDone()
        } catch { self.error = error.localizedDescription }
        saving = false
    }
}


// MARK: - Layer Editor

struct DRLayerEditor: View {
    @Binding var layer: DRPhotoLayer
    @ObservedObject var store: DarkroomStore
    let onTitleSuggestion: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
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
            .padding(10).background(Color.green.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text("Carbon Tissue").font(.caption2).foregroundStyle(.blue)
                Picker("Carbon Tissue", selection: $layer.carbonTissueId) {
                    Text("None").tag(Int?.none)
                    ForEach(store.carbonTissues) { ct in Text(ct.menuLabel).tag(ct.id as Int?) }
                }
                if let id = layer.carbonTissueId, let ct = store.carbonTissues.first(where: { $0.id == id }) {
                    DRInlineInfo {
                        DRInfoChip(label: "Size", value: ct.size ?? "—", color: .blue)
                        DRInfoChip(label: "Poured", value: ct.datePoured, color: .blue)
                        if let a = ct.amountPoured { DRInfoChip(label: "Amt", value: a, color: .blue) }
                    }
                }
            }
            .padding(10).background(Color.blue.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text("Negative").font(.caption2).foregroundStyle(.orange)
                Picker("Negative", selection: $layer.negativeId) {
                    Text("None").tag(Int?.none)
                    ForEach(store.negatives) { n in Text(n.menuLabel).tag(n.id as Int?) }
                }
                .onChange(of: layer.negativeId) { _, newId in
                    guard let id = newId, let neg = store.negatives.first(where: { $0.id == id }) else { return }
                    if let t = neg.titleId, !t.isEmpty { onTitleSuggestion("\(t).\(drDateToYYMM(neg.dateCreated))") }
                }
                if let id = layer.negativeId, let neg = store.negatives.first(where: { $0.id == id }) {
                    DRInlineInfo {
                        if let t = neg.titleId { DRInfoChip(label: "Title", value: t, color: .orange) }
                        DRInfoChip(label: "Type", value: neg.typeName ?? "—", color: .orange)
                        DRInfoChip(label: "Date", value: neg.dateCreated, color: .orange)
                    }
                }
            }
            .padding(10).background(Color.orange.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Finishing Step Editor

struct DRFinishingEditor: View {
    @Binding var step: DRFinishingStep
    @ObservedObject var store: DarkroomStore
    let presets: [String]
    @State private var timeStr = ""; @State private var tempStr = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preset chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            step.label = preset
                        } label: {
                            Text(preset)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(step.label == preset ? Color.teal : Color.teal.opacity(0.1))
                                .foregroundStyle(step.label == preset ? Color.white : Color.teal)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            TextField("Label (e.g. Clearing Bath, Fixative, Toner…)", text: $step.label).font(.subheadline)
            Picker("Chemistry (optional)", selection: $step.chemistryId) {
                Text("None").tag(Int?.none)
                ForEach(store.chemistry) { c in Text(c.menuLabel).tag(c.id as Int?) }
            }
            .font(.caption)
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    TextField("sec", text: $timeStr).keyboardType(.numberPad).frame(width: 56)
                        .onChange(of: timeStr) { _, v in step.stepTime = Int(v) }
                    Text("sec").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    TextField("°C", text: $tempStr).keyboardType(.decimalPad).frame(width: 56)
                        .onChange(of: tempStr) { _, v in step.stepTemp = Double(v) }
                    Text("°C").font(.caption2).foregroundStyle(.secondary)
                }
            }
            TextField("Notes", text: Binding(
                get: { step.notes ?? "" },
                set: { step.notes = $0.isEmpty ? nil : $0 }
            ), axis: .vertical).font(.caption).lineLimit(2...3)
        }
        .padding(.vertical, 4)
        .onAppear {
            timeStr = step.stepTime.map { String($0) } ?? ""
            tempStr = step.stepTemp.map { String($0) } ?? ""
        }
    }
}

// MARK: - Shared form components

private struct DRInlineInfo<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) { content } } }
}

private struct DRInfoChip: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 7, weight: .semibold)).foregroundStyle(color.opacity(0.7))
            Text(value).font(.system(size: 11)).foregroundStyle(color)
        }
        .padding(.horizontal, 7).padding(.vertical, 4).background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct DRTwoField: View {
    let label: String
    @Binding var left: String;  let leftHint: String
    @Binding var right: String; let rightHint: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                TextField(leftHint,  text: $left).keyboardType(.numberPad)
                TextField(rightHint, text: $right).keyboardType(.decimalPad)
            }
        }
    }
}


// MARK: - Support Paper Tab

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
    @State private var treatmentChemId: Int? = nil
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
                Section("Mark") {
                    TextField("e.g. A1, B3", text: $mark).autocorrectionDisabled()
                        .textInputAutocapitalization(.characters).onChange(of: mark) { _, v in mark = v.uppercased() }
                }
                Section("Treatment Chemistry") {
                    Picker("Sizing / Coating Used", selection: $treatmentChemId) {
                        Text("None").tag(Int?.none)
                        ForEach(store.chemistry.filter {
                            ["Sizing","Coating","Gelatin"].contains($0.typeName ?? "")
                        }) { c in Text(c.menuLabel).tag(c.id as Int?) }
                        if !store.chemistry.filter({ ["Sizing","Coating","Gelatin"].contains($0.typeName ?? "") }).isEmpty {
                            Divider()
                        }
                        ForEach(store.chemistry.filter {
                            !["Sizing","Coating","Gelatin"].contains($0.typeName ?? "")
                        }) { c in Text(c.menuLabel).tag(c.id as Int?) }
                    }
                    if let cid = treatmentChemId, let chem = store.chemistry.first(where: { $0.id == cid }) {
                        HStack(spacing: 6) {
                            if let t = chem.typeName { DRInfoChip(label: "Type", value: t, color: .teal) }
                            if let p = chem.percentSolution { DRInfoChip(label: "%", value: String(format: "%.1f", p), color: .teal) }
                            DRInfoChip(label: "Made", value: drDateToYYMM(chem.dateCreated), color: .teal)
                        }
                        .padding(.top, 2)
                    }
                }
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
        .onAppear { if let t = target { paperId = t.paperId; mark = t.mark; treatmentChemId = t.treatmentChemistryId; notes = t.notes ?? "" } }
        .task {
            if store.papers.isEmpty { await store.loadPapers() }
            if store.chemistry.isEmpty { await store.loadChemistry() }
        }
    }
    private func save() async {
        guard let pid = paperId else { return }
        saving = true; error = nil
        let req = DRSupportPaperRequest(paperId: pid, mark: mark, treatmentChemistryId: treatmentChemId, notes: notes.isEmpty ? nil : notes)
        do { if let t = target { try await store.updateSupportPaper(id: t.id, req) } else { try await store.addSupportPaper(req) }; onDone() }
        catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: - Carbon Tissue Tab

struct DRCarbonTissueTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false; @State private var editTarget: DRCarbonTissue?
    var body: some View {
        List {
            if store.carbonTissues.isEmpty { DREmptyState(label: "carbon tissue batches", icon: "square.stack") }
            ForEach(store.carbonTissues) { ct in
                VStack(alignment: .leading, spacing: 3) {
                    HStack { Text(ct.menuLabel).font(.headline); Spacer()
                        Text(ct.datePoured).font(.caption).foregroundStyle(.secondary) }
                    HStack(spacing: 8) {
                        if let sz = ct.size  { Text(sz).font(.caption).foregroundStyle(.secondary) }
                        if let c  = ct.chemType { Text(c).font(.caption).foregroundStyle(.secondary) }
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
                        ForEach(store.chemistry) { c in Text(c.menuLabel).tag(c.id as Int?) }
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
        .task {
            if store.chemistry.isEmpty { await store.loadChemistry() }
        }
    }
    private func save() async {
        saving = true; error = nil
        let req = DRCarbonTissueRequest(titleId: titleId.isEmpty ? nil : titleId, size: size.isEmpty ? nil : size,
            chemistryId: chemId, amountPoured: amount.isEmpty ? nil : amount,
            datePoured: drFormatDate(date), notes: notes.isEmpty ? nil : notes)
        do { if let t = target { try await store.updateCarbonTissue(id: t.id, req) } else { try await store.addCarbonTissue(req) }; onDone() }
        catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: - Negatives Tab

struct DRNegativesTab: View {
    @ObservedObject var store: DarkroomStore
    @State private var showForm = false; @State private var editTarget: DRNegative?
    var body: some View {
        List {
            if store.negatives.isEmpty { DREmptyState(label: "negatives", icon: "photo") }
            ForEach(store.negatives) { n in
                VStack(alignment: .leading, spacing: 3) {
                    HStack { Text(n.menuLabel).font(.headline); Spacer()
                        Text(n.dateCreated).font(.caption).foregroundStyle(.secondary) }
                    if let t = n.typeName { Text(t).font(.caption).foregroundStyle(.secondary) }
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
        .task { await store.loadNegatives() }.refreshable { await store.loadNegatives() }
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
        let req = DRNegativeRequest(titleId: titleId.isEmpty ? nil : titleId, dateCreated: drFormatDate(date),
            typeId: typeId, settingsNotes: notes.isEmpty ? nil : notes)
        do { if let t = target { try await store.updateNegative(id: t.id, req) } else { try await store.addNegative(req) }; onDone() }
        catch { self.error = error.localizedDescription }
        saving = false
    }
}

// MARK: - Options Forms

struct DRPhotoTypeForm: View {
    @ObservedObject var store: DarkroomStore
    let target: DRPhotoType?
    let onDone: () -> Void

    @State private var name = ""
    @State private var hasLayers = false
    @State private var devMode = "simple"
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $name)
                }
                Section("Behavior") {
                    Toggle("Show Layers", isOn: $hasLayers)
                    Picker("Development Mode", selection: $devMode) {
                        Text("Simple").tag("simple")
                        Text("Carbon").tag("carbon")
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle(target == nil ? "New Process Type" : "Edit Process Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target == nil ? "Add" : "Save") { Task { await save() } }
                        .disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            guard let target else { return }
            name = target.name
            hasLayers = target.showLayers
            devMode = target.devMode
        }
    }

    private func save() async {
        saving = true
        error = nil
        let req = DRPhotoTypeRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            hasLayers: hasLayers,
            devMode: devMode
        )
        do {
            if let target {
                try await store.updatePhotoType(id: target.id, req)
            } else {
                try await store.addPhotoType(req)
            }
            onDone()
        } catch {
            self.error = error.localizedDescription
        }
        saving = false
    }
}

struct DRLookupTypeForm: View {
    @ObservedObject var store: DarkroomStore
    let title: String
    let target: DRLookup?
    let onSave: (String) async throws -> Void
    let onDone: () -> Void

    @State private var name = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(title) {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle(target == nil ? "Create New" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target == nil ? "Add" : "Save") { Task { await save() } }
                        .disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { name = target?.name ?? "" }
    }

    private func save() async {
        saving = true
        error = nil
        do {
            try await onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
            onDone()
        } catch {
            self.error = error.localizedDescription
        }
        saving = false
    }
}

private struct DRFinishingTypeRow: View {
    let label: String

    var body: some View {
        Text(label)
    }
}

private struct DROptionsHeader: View {
    let title: String
    let count: Int
    let emptyLabel: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(count == 0 ? emptyLabel : "\(count) item\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DROptionsSectionHeader: View {
    let title: String
    let count: Int
    let emptyLabel: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let onCreate: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                HStack {
                    DROptionsHeader(title: title, count: count, emptyLabel: emptyLabel)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            if isExpanded {
                Button(action: onCreate) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Layers Tab

struct DRLayersTab: View {
    @ObservedObject var store: DarkroomStore

    @State private var supportPapersExpanded = false
    @State private var carbonTissuesExpanded = false
    @State private var negativesExpanded = false

    @State private var showSupportPaperForm = false
    @State private var showCarbonTissueForm = false
    @State private var showNegativeForm = false

    @State private var selectedSupportPaper: DRSupportPaper?
    @State private var selectedCarbonTissue: DRCarbonTissue?
    @State private var selectedNegative: DRNegative?

    var body: some View {
        List {
            Section(
                header: DROptionsSectionHeader(
                    title: "Support Paper",
                    count: store.supportPapers.count,
                    emptyLabel: "No support papers",
                    isExpanded: supportPapersExpanded,
                    onToggle: { supportPapersExpanded.toggle() },
                    onCreate: {
                        selectedSupportPaper = nil
                        showSupportPaperForm = true
                    }
                )
            ) {
                if supportPapersExpanded {
                    if store.supportPapers.isEmpty {
                        Text("No support papers yet.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.supportPapers) { paper in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(paper.displayName)
                                    HStack(spacing: 8) {
                                        Text(paper.mark)
                                        if let weight = paper.weight { Text(String(format: "%.0f gsm", weight)) }
                                        if paper.hotPress == 1 { Text("HP") }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Edit") {
                                    selectedSupportPaper = paper
                                    showSupportPaperForm = true
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    Task { await store.deleteSupportPaper(id: paper.id) }
                                }
                            }
                        }
                    }
                }
            }

            Section(
                header: DROptionsSectionHeader(
                    title: "Carbon Tissue",
                    count: store.carbonTissues.count,
                    emptyLabel: "No carbon tissues",
                    isExpanded: carbonTissuesExpanded,
                    onToggle: { carbonTissuesExpanded.toggle() },
                    onCreate: {
                        selectedCarbonTissue = nil
                        showCarbonTissueForm = true
                    }
                )
            ) {
                if carbonTissuesExpanded {
                    if store.carbonTissues.isEmpty {
                        Text("No carbon tissues yet.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.carbonTissues) { tissue in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tissue.menuLabel)
                                    HStack(spacing: 8) {
                                        Text(tissue.datePoured)
                                        if let size = tissue.size { Text(size) }
                                        if let chemType = tissue.chemType { Text(chemType) }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Edit") {
                                    selectedCarbonTissue = tissue
                                    showCarbonTissueForm = true
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    Task { await store.deleteCarbonTissue(id: tissue.id) }
                                }
                            }
                        }
                    }
                }
            }

            Section(
                header: DROptionsSectionHeader(
                    title: "Negatives",
                    count: store.negatives.count,
                    emptyLabel: "No negatives",
                    isExpanded: negativesExpanded,
                    onToggle: { negativesExpanded.toggle() },
                    onCreate: {
                        selectedNegative = nil
                        showNegativeForm = true
                    }
                )
            ) {
                if negativesExpanded {
                    if store.negatives.isEmpty {
                        Text("No negatives yet.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.negatives) { negative in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(negative.menuLabel)
                                    HStack(spacing: 8) {
                                        Text(negative.dateCreated)
                                        if let typeName = negative.typeName { Text(typeName) }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Edit") {
                                    selectedNegative = negative
                                    showNegativeForm = true
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    Task { await store.deleteNegative(id: negative.id) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showSupportPaperForm, onDismiss: { selectedSupportPaper = nil }) {
            DRSupportPaperForm(store: store, target: selectedSupportPaper) { showSupportPaperForm = false }
        }
        .sheet(isPresented: $showCarbonTissueForm, onDismiss: { selectedCarbonTissue = nil }) {
            DRCarbonTissueForm(store: store, target: selectedCarbonTissue) { showCarbonTissueForm = false }
        }
        .sheet(isPresented: $showNegativeForm, onDismiss: { selectedNegative = nil }) {
            DRNegativeForm(store: store, target: selectedNegative) { showNegativeForm = false }
        }
        .task { await loadLayersData() }
        .refreshable { await loadLayersData() }
    }

    private func loadLayersData() async {
        await store.loadSupportPapers()
        await store.loadCarbonTissues()
        await store.loadNegatives()
    }
}

// MARK: - More Tab

struct DRMoreTab: View {
    @ObservedObject var store: DarkroomStore

    @State private var processTypesExpanded = false
    @State private var chemistryTypesExpanded = false
    @State private var negativeTypesExpanded = false
    @State private var finishingTypesExpanded = false

    @State private var showPhotoTypeForm = false
    @State private var showChemistryTypeForm = false
    @State private var showNegativeTypeForm = false
    @State private var showFinishingTypeForm = false

    @State private var selectedPhotoType: DRPhotoType?
    @State private var selectedChemistryType: DRLookup?
    @State private var selectedNegativeType: DRLookup?
    @State private var selectedFinishingType: DRLookup?

    var body: some View {
        List {
            Section(
                header: DROptionsSectionHeader(
                    title: "Process Types",
                    count: store.photoTypes.count,
                    emptyLabel: "No process types",
                    isExpanded: processTypesExpanded,
                    onToggle: { processTypesExpanded.toggle() },
                    onCreate: {
                        selectedPhotoType = nil
                        showPhotoTypeForm = true
                    }
                )
            ) {
                if processTypesExpanded {
                    if store.photoTypes.isEmpty {
                        Text("No process types yet.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.photoTypes) { type in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.name)
                                    HStack(spacing: 8) {
                                        Text(type.isCarbonDev ? "Carbon dev" : "Simple dev")
                                        if type.showLayers { Text("Layers") }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Edit") {
                                    selectedPhotoType = type
                                    showPhotoTypeForm = true
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    Task { await store.deletePhotoType(id: type.id) }
                                }
                            }
                        }
                    }
                }
            }

            Section(
                header: DROptionsSectionHeader(
                    title: "Chemistry Types",
                    count: store.chemistryTypes.count,
                    emptyLabel: "No chemistry types",
                    isExpanded: chemistryTypesExpanded,
                    onToggle: { chemistryTypesExpanded.toggle() },
                    onCreate: {
                        selectedChemistryType = nil
                        showChemistryTypeForm = true
                    }
                )
            ) {
                if chemistryTypesExpanded {
                    if store.chemistryTypes.isEmpty {
                        Text("No chemistry types yet.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.chemistryTypes) { type in
                            HStack {
                                Text(type.name)
                                Spacer()
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Edit") {
                                    selectedChemistryType = type
                                    showChemistryTypeForm = true
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    Task { await deleteLookupType("chemistry_types", id: type.id) }
                                }
                            }
                        }
                    }
                }
            }

            Section(
                header: DROptionsSectionHeader(
                    title: "Negative Types",
                    count: store.negativeTypes.count,
                    emptyLabel: "No negative types",
                    isExpanded: negativeTypesExpanded,
                    onToggle: { negativeTypesExpanded.toggle() },
                    onCreate: {
                        selectedNegativeType = nil
                        showNegativeTypeForm = true
                    }
                )
            ) {
                if negativeTypesExpanded {
                    if store.negativeTypes.isEmpty {
                        Text("No negative types yet.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.negativeTypes) { type in
                            HStack {
                                Text(type.name)
                                Spacer()
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Edit") {
                                    selectedNegativeType = type
                                    showNegativeTypeForm = true
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    Task { await deleteLookupType("negative_types", id: type.id) }
                                }
                            }
                        }
                    }
                }
            }

            Section(
                header: DROptionsSectionHeader(
                    title: "Finishing",
                    count: store.finishingTypes.count,
                    emptyLabel: "No finishing presets",
                    isExpanded: finishingTypesExpanded,
                    onToggle: { finishingTypesExpanded.toggle() },
                    onCreate: {
                        selectedFinishingType = nil
                        showFinishingTypeForm = true
                    }
                )
            ) {
                if finishingTypesExpanded {
                    if store.finishingTypes.isEmpty {
                        Text("No finishing presets yet.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.finishingTypes) { type in
                            HStack {
                                DRFinishingTypeRow(label: type.name)
                                Spacer()
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Edit") {
                                    selectedFinishingType = type
                                    showFinishingTypeForm = true
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    Task { await deleteLookupType("finishing_types", id: type.id, reloadFinishing: true) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showPhotoTypeForm, onDismiss: { selectedPhotoType = nil }) {
            DRPhotoTypeForm(store: store, target: selectedPhotoType) { showPhotoTypeForm = false }
        }
        .sheet(isPresented: $showChemistryTypeForm, onDismiss: { selectedChemistryType = nil }) {
            DRLookupTypeForm(
                store: store,
                title: "Chemistry Type",
                target: selectedChemistryType,
                onSave: { name in try await saveLookupType("chemistry_types", id: selectedChemistryType?.id, name: name) },
                onDone: { showChemistryTypeForm = false }
            )
        }
        .sheet(isPresented: $showNegativeTypeForm, onDismiss: { selectedNegativeType = nil }) {
            DRLookupTypeForm(
                store: store,
                title: "Negative Type",
                target: selectedNegativeType,
                onSave: { name in try await saveLookupType("negative_types", id: selectedNegativeType?.id, name: name) },
                onDone: { showNegativeTypeForm = false }
            )
        }
        .sheet(isPresented: $showFinishingTypeForm, onDismiss: { selectedFinishingType = nil }) {
            DRLookupTypeForm(
                store: store,
                title: "Finishing Preset",
                target: selectedFinishingType,
                onSave: { name in try await saveLookupType("finishing_types", id: selectedFinishingType?.id, name: name, reloadFinishing: true) },
                onDone: { showFinishingTypeForm = false }
            )
        }
        .task { await loadMoreData() }
        .refreshable { await loadMoreData() }
    }

    private func saveLookupType(_ res: String, id: Int?, name: String, reloadFinishing: Bool = false) async throws {
        let req = DRLookupRequest(name: name)
        if let id {
            try await DarkroomAPIClient.update(serverURL: store.serverURL, apiKey: store.apiKey, res: res, id: id, body: req)
        } else {
            _ = try await DarkroomAPIClient.create(serverURL: store.serverURL, apiKey: store.apiKey, res: res, body: req)
        }
        if reloadFinishing {
            await store.loadFinishingTypes()
        } else {
            await store.loadTypes()
        }
    }

    private func deleteLookupType(_ res: String, id: Int, reloadFinishing: Bool = false) async {
        do {
            try await DarkroomAPIClient.delete(serverURL: store.serverURL, apiKey: store.apiKey, res: res, id: id)
            if reloadFinishing {
                await store.loadFinishingTypes()
            } else {
                await store.loadTypes()
            }
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func loadMoreData() async {
        await store.loadTypes()
        await store.loadFinishingTypes()
    }
}
