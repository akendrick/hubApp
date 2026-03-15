import Foundation

// MARK: - Lookup tables

struct DRLookup: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
}

private extension KeyedDecodingContainer {
    func decodeLossyStringIfPresent(forKey key: K) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        return nil
    }

    func decodeLossyIntIfPresent(forKey key: K) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Int(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        return nil
    }

    func decodeLossyDoubleIfPresent(forKey key: K) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }
}

// MARK: - Photo Type
// Controls which form sections are shown.
// hasLayers:  true  → show Layers section
// devMode:    "carbon"  → paper soak + hot develop + cool develop
//             "simple"  → single time / temp / notes field

struct DRPhotoType: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
    var hasLayers: Int      // 0/1 from server
    var devMode: String     // "carbon" | "simple"

    var showLayers: Bool  { hasLayers != 0 }
    var isCarbon: Bool    { devMode == "carbon" }
    var isCarbonDev: Bool { isCarbon }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = c.decodeLossyStringIfPresent(forKey: .name) ?? ""
        hasLayers = c.decodeLossyIntIfPresent(forKey: .hasLayers) ?? 0
        devMode = c.decodeLossyStringIfPresent(forKey: .devMode) ?? "simple"
    }
}

// MARK: - Chemistry

struct DRChemistry: Identifiable, Codable {
    var id: Int
    var dateCreated: String
    var typeId: Int?
    var typeName: String?
    var percentSolution: Double?
    var createdFromIds: String?
    var notes: String?

    var menuLabel: String {
        let type = typeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let percentText: String
        if let percentSolution {
            percentText = String(format: "%.0f%%", percentSolution)
        } else {
            percentText = "Unknown %"
        }

        let base = [type, percentText]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return base.isEmpty ? "#\(id)" : "\(base) (\(drDateToYYMM(dateCreated)))"
    }

    init(id: Int, dateCreated: String, typeId: Int?, typeName: String?, percentSolution: Double?, createdFromIds: String?, notes: String?) {
        self.id = id
        self.dateCreated = dateCreated
        self.typeId = typeId
        self.typeName = typeName
        self.percentSolution = percentSolution
        self.createdFromIds = createdFromIds
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        dateCreated = (try? container.decode(String.self, forKey: .dateCreated)) ?? drToday()
        typeId = container.decodeLossyIntIfPresent(forKey: .typeId)
        typeName = container.decodeLossyStringIfPresent(forKey: .typeName)
        notes = container.decodeLossyStringIfPresent(forKey: .notes)
        percentSolution = container.decodeLossyDoubleIfPresent(forKey: .percentSolution)

        if let value = try? container.decodeIfPresent(String.self, forKey: .createdFromIds) {
            createdFromIds = value
        } else if let value = try? container.decodeIfPresent(Int.self, forKey: .createdFromIds) {
            createdFromIds = String(value)
        } else if let values = try? container.decodeIfPresent([Int].self, forKey: .createdFromIds) {
            createdFromIds = values.map(String.init).joined(separator: ",")
        } else if let values = try? container.decodeIfPresent([String].self, forKey: .createdFromIds) {
            createdFromIds = values.joined(separator: ",")
        } else {
            createdFromIds = nil
        }
    }
}

// MARK: - Paper

struct DRPaper: Identifiable, Codable {
    var id: Int
    var manufacturer: String?
    var label: String?
    var weight: Double?
    var hotPress: Int?
    var notes: String?

    var displayName: String {
        [manufacturer, label].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        manufacturer = c.decodeLossyStringIfPresent(forKey: .manufacturer)
        label = c.decodeLossyStringIfPresent(forKey: .label)
        weight = c.decodeLossyDoubleIfPresent(forKey: .weight)
        hotPress = c.decodeLossyIntIfPresent(forKey: .hotPress)
        notes = c.decodeLossyStringIfPresent(forKey: .notes)
    }
}

// MARK: - Support Paper

struct DRSupportPaper: Identifiable, Codable {
    var id: Int
    var paperId: Int
    var mark: String
    var paperLabel: String?
    var manufacturer: String?
    var label: String?
    var weight: Double?
    var hotPress: Int?
    var treatmentChemistryId: Int?
    var treatmentLabel: String?
    var notes: String?

    var displayName: String {
        let base = paperLabel ?? [manufacturer, label].compactMap { $0 }.joined(separator: " ")
        return mark + (base.isEmpty ? "" : " (\(base))")
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        paperId = c.decodeLossyIntIfPresent(forKey: .paperId) ?? 0
        mark = c.decodeLossyStringIfPresent(forKey: .mark) ?? ""
        paperLabel = c.decodeLossyStringIfPresent(forKey: .paperLabel)
        manufacturer = c.decodeLossyStringIfPresent(forKey: .manufacturer)
        label = c.decodeLossyStringIfPresent(forKey: .label)
        weight = c.decodeLossyDoubleIfPresent(forKey: .weight)
        hotPress = c.decodeLossyIntIfPresent(forKey: .hotPress)
        treatmentChemistryId = c.decodeLossyIntIfPresent(forKey: .treatmentChemistryId)
        treatmentLabel = c.decodeLossyStringIfPresent(forKey: .treatmentLabel)
        notes = c.decodeLossyStringIfPresent(forKey: .notes)
    }
}

// MARK: - Carbon Tissue

struct DRCarbonTissue: Identifiable, Codable {
    var id: Int
    var titleId: String?
    var size: String?
    var chemistryId: Int?
    var chemType: String?
    var amountPoured: String?
    var datePoured: String
    var notes: String?

    var menuLabel: String {
        let ym = drDateToYYMM(datePoured)
        if let t = titleId, !t.isEmpty { return "\(t).\(ym)" }
        return "#\(id) \(ym)"
    }

    init(id: Int, titleId: String?, size: String?, chemistryId: Int?, chemType: String?, amountPoured: String?, datePoured: String, notes: String?) {
        self.id = id
        self.titleId = titleId
        self.size = size
        self.chemistryId = chemistryId
        self.chemType = chemType
        self.amountPoured = amountPoured
        self.datePoured = datePoured
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        titleId = c.decodeLossyStringIfPresent(forKey: .titleId)
        size = c.decodeLossyStringIfPresent(forKey: .size)
        chemistryId = c.decodeLossyIntIfPresent(forKey: .chemistryId)
        chemType = c.decodeLossyStringIfPresent(forKey: .chemType)
        amountPoured = c.decodeLossyStringIfPresent(forKey: .amountPoured)
        datePoured = c.decodeLossyStringIfPresent(forKey: .datePoured) ?? drToday()
        notes = c.decodeLossyStringIfPresent(forKey: .notes)
    }
}

// MARK: - Negative

struct DRNegative: Identifiable, Codable {
    var id: Int
    var titleId: String?
    var dateCreated: String
    var typeId: Int?
    var typeName: String?
    var settingsNotes: String?

    var menuLabel: String {
        let ym = drDateToYYMM(dateCreated)
        if let t = titleId, !t.isEmpty { return "\(t).\(ym)" }
        return "#\(id) \(ym)"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        titleId = c.decodeLossyStringIfPresent(forKey: .titleId)
        dateCreated = c.decodeLossyStringIfPresent(forKey: .dateCreated) ?? drToday()
        typeId = c.decodeLossyIntIfPresent(forKey: .typeId)
        typeName = c.decodeLossyStringIfPresent(forKey: .typeName)
        settingsNotes = c.decodeLossyStringIfPresent(forKey: .settingsNotes)
    }
}

// MARK: - Photo

struct DRPhoto: Identifiable, Codable {
    var id: Int
    var title: String?
    // Type
    var photoTypeId: Int?
    var typeName: String?
    var typeHasLayers: Int?
    var typeDevMode: String?
    // Paper
    var paperId: Int?
    var paperLabel: String?
    var photoSize: String?
    var dateSensitized: String?
    var dateExposed: String?
    // Exposure
    var testStrip: Int?
    var exposureDuration: Double?
    var times: [DRPhotoTime]
    // Development — carbon mode
    var paperSoakTime: Int?
    var paperSoakTemp: Double?
    var hotDevelopTime: Int?
    var hotDevelopTemp: Double?
    var coolDevelopTime: Int?
    var coolDevelopTemp: Double?
    // Development — simple mode
    var developTime: Int?
    var developTemp: Double?
    var developNotes: String?
    // Image
    var imagePath: String?
    var notes: String?
    // Children
    var layers: [DRPhotoLayer]
    var finishing: [DRFinishingStep]

    var showLayers: Bool  { (typeHasLayers ?? 0) != 0 }
    var isCarbon: Bool    { typeDevMode == "carbon" }
    var isCarbonDev: Bool { isCarbon }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = c.decodeLossyStringIfPresent(forKey: .title)
        photoTypeId = c.decodeLossyIntIfPresent(forKey: .photoTypeId)
        typeName = c.decodeLossyStringIfPresent(forKey: .typeName)
        typeHasLayers = c.decodeLossyIntIfPresent(forKey: .typeHasLayers)
        typeDevMode = c.decodeLossyStringIfPresent(forKey: .typeDevMode)
        paperId = c.decodeLossyIntIfPresent(forKey: .paperId)
        paperLabel = c.decodeLossyStringIfPresent(forKey: .paperLabel)
        photoSize = c.decodeLossyStringIfPresent(forKey: .photoSize)
        dateSensitized = c.decodeLossyStringIfPresent(forKey: .dateSensitized)
        dateExposed = c.decodeLossyStringIfPresent(forKey: .dateExposed)
        testStrip = c.decodeLossyIntIfPresent(forKey: .testStrip)
        exposureDuration = c.decodeLossyDoubleIfPresent(forKey: .exposureDuration)
        times = (try? c.decodeIfPresent([DRPhotoTime].self, forKey: .times)) ?? []
        paperSoakTime = c.decodeLossyIntIfPresent(forKey: .paperSoakTime)
        paperSoakTemp = c.decodeLossyDoubleIfPresent(forKey: .paperSoakTemp)
        hotDevelopTime = c.decodeLossyIntIfPresent(forKey: .hotDevelopTime)
        hotDevelopTemp = c.decodeLossyDoubleIfPresent(forKey: .hotDevelopTemp)
        coolDevelopTime = c.decodeLossyIntIfPresent(forKey: .coolDevelopTime)
        coolDevelopTemp = c.decodeLossyDoubleIfPresent(forKey: .coolDevelopTemp)
        developTime = c.decodeLossyIntIfPresent(forKey: .developTime)
        developTemp = c.decodeLossyDoubleIfPresent(forKey: .developTemp)
        developNotes = c.decodeLossyStringIfPresent(forKey: .developNotes)
        imagePath = c.decodeLossyStringIfPresent(forKey: .imagePath)
        notes = c.decodeLossyStringIfPresent(forKey: .notes)
        layers = (try? c.decodeIfPresent([DRPhotoLayer].self, forKey: .layers)) ?? []
        finishing = (try? c.decodeIfPresent([DRFinishingStep].self, forKey: .finishing)) ?? []
    }
}

// MARK: - Photo Times (exposure intervals for test strips)

struct DRPhotoTime: Codable, Identifiable {
    var id: UUID = UUID()
    var durationMinutes: Double?

    init(durationMinutes: Double? = nil) { self.durationMinutes = durationMinutes }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        durationMinutes = c.decodeLossyDoubleIfPresent(forKey: .durationMinutes)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
    }
    enum CodingKeys: String, CodingKey { case durationMinutes }
}

// MARK: - Photo Layer (with full denormalized detail)

struct DRPhotoLayer: Codable, Identifiable {
    var id: UUID = UUID()
    var supportPaperId: Int?
    var negativeId: Int?
    var carbonTissueId: Int?
    // Support Paper detail
    var spMark: String?
    var spPaperLabel: String?
    var spWeight: Double?
    var spHotPress: Int?
    var spNotes: String?
    // Negative detail
    var negTitleId: String?
    var negType: String?
    var negDate: String?
    var negNotes: String?
    // Carbon Tissue detail
    var ctTitleId: String?
    var ctSize: String?
    var ctDate: String?
    var ctAmount: String?
    var ctNotes: String?

    init(supportPaperId: Int? = nil, negativeId: Int? = nil, carbonTissueId: Int? = nil) {
        self.supportPaperId = supportPaperId
        self.negativeId = negativeId
        self.carbonTissueId = carbonTissueId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        supportPaperId = c.decodeLossyIntIfPresent(forKey: .supportPaperId)
        negativeId     = c.decodeLossyIntIfPresent(forKey: .negativeId)
        carbonTissueId = c.decodeLossyIntIfPresent(forKey: .carbonTissueId)
        spMark         = c.decodeLossyStringIfPresent(forKey: .spMark)
        spPaperLabel   = c.decodeLossyStringIfPresent(forKey: .spPaperLabel)
        spWeight       = c.decodeLossyDoubleIfPresent(forKey: .spWeight)
        spHotPress     = c.decodeLossyIntIfPresent(forKey: .spHotPress)
        spNotes        = c.decodeLossyStringIfPresent(forKey: .spNotes)
        negTitleId     = c.decodeLossyStringIfPresent(forKey: .negTitleId)
        negType        = c.decodeLossyStringIfPresent(forKey: .negType)
        negDate        = c.decodeLossyStringIfPresent(forKey: .negDate)
        negNotes       = c.decodeLossyStringIfPresent(forKey: .negNotes)
        ctTitleId      = c.decodeLossyStringIfPresent(forKey: .ctTitleId)
        ctSize         = c.decodeLossyStringIfPresent(forKey: .ctSize)
        ctDate         = c.decodeLossyStringIfPresent(forKey: .ctDate)
        ctAmount       = c.decodeLossyStringIfPresent(forKey: .ctAmount)
        ctNotes        = c.decodeLossyStringIfPresent(forKey: .ctNotes)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(supportPaperId, forKey: .supportPaperId)
        try c.encodeIfPresent(negativeId,     forKey: .negativeId)
        try c.encodeIfPresent(carbonTissueId, forKey: .carbonTissueId)
    }

    enum CodingKeys: String, CodingKey {
        case supportPaperId, negativeId, carbonTissueId
        case spMark, spPaperLabel, spWeight, spHotPress, spNotes
        case negTitleId, negType, negDate, negNotes
        case ctTitleId, ctSize, ctDate, ctAmount, ctNotes
    }
}

// MARK: - Finishing Step

struct DRFinishingStep: Codable, Identifiable {
    var id: UUID = UUID()
    var label: String           // e.g. "Clearing Bath", "Toner", "Fixer"
    var chemistryId: Int?
    var chemTypeName: String?
    var stepTime: Int?          // seconds
    var stepTemp: Double?       // celsius
    var notes: String?

    init(label: String = "", chemistryId: Int? = nil, stepTime: Int? = nil, stepTemp: Double? = nil, notes: String? = nil) {
        self.label = label
        self.chemistryId = chemistryId
        self.stepTime = stepTime
        self.stepTemp = stepTemp
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        label        = c.decodeLossyStringIfPresent(forKey: .label) ?? ""
        chemistryId  = c.decodeLossyIntIfPresent(forKey: .chemistryId)
        chemTypeName = c.decodeLossyStringIfPresent(forKey: .chemTypeName)
        stepTime     = c.decodeLossyIntIfPresent(forKey: .stepTime)
        stepTemp     = c.decodeLossyDoubleIfPresent(forKey: .stepTemp)
        notes        = c.decodeLossyStringIfPresent(forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(label,              forKey: .label)
        try c.encodeIfPresent(chemistryId, forKey: .chemistryId)
        try c.encodeIfPresent(stepTime,    forKey: .stepTime)
        try c.encodeIfPresent(stepTemp,    forKey: .stepTemp)
        try c.encodeIfPresent(notes,       forKey: .notes)
    }

    enum CodingKeys: String, CodingKey {
        case label, chemistryId, chemTypeName, stepTime, stepTemp, notes
    }
}

// MARK: - Request bodies

struct DRPhotoTypeRequest: Encodable {
    var name: String
    var hasLayers: Bool
    var devMode: String
}

struct DRChemistryRequest: Encodable {
    var dateCreated: String
    var typeId: Int?
    var percentSolution: Double?
    var createdFromId: Int?
    var notes: String?
}

struct DRPaperRequest: Encodable {
    var manufacturer: String?
    var label: String?
    var weight: Double?
    var hotPress: Bool
    var notes: String?
}

struct DRSupportPaperRequest: Encodable {
    var paperId: Int
    var mark: String
    var treatmentChemistryId: Int?
    var notes: String?
}

struct DRCarbonTissueRequest: Encodable {
    var titleId: String?
    var size: String?
    var chemistryId: Int?
    var amountPoured: String?
    var datePoured: String
    var notes: String?
}

struct DRNegativeRequest: Encodable {
    var titleId: String?
    var dateCreated: String
    var typeId: Int?
    var settingsNotes: String?
}

struct DRLookupRequest: Encodable {
    var name: String
}

struct DRPhotoRequest: Encodable {
    var title: String?
    var photoTypeId: Int?
    var paperId: Int?
    var photoSize: String?
    var dateSensitized: String?
    var dateExposed: String?
    // Exposure
    var testStrip: Bool
    var exposureDuration: Double?
    var times: [DRTimeRequest]
    // Development — carbon
    var paperSoakTime: Int?
    var paperSoakTemp: Double?
    var hotDevelopTime: Int?
    var hotDevelopTemp: Double?
    var coolDevelopTime: Int?
    var coolDevelopTemp: Double?
    // Development — simple
    var developTime: Int?
    var developTemp: Double?
    var developNotes: String?
    var notes: String?
    var layers: [DRLayerRequest]
    var finishing: [DRFinishingRequest]
}

struct DRTimeRequest: Encodable {
    var durationMinutes: Double
}

struct DRLayerRequest: Encodable {
    var supportPaperId: Int?
    var negativeId: Int?
    var carbonTissueId: Int?
}

struct DRFinishingRequest: Encodable {
    var label: String
    var chemistryId: Int?
    var stepTime: Int?
    var stepTemp: Double?
    var notes: String?
}

// MARK: - Utility

func drDateToYYMM(_ dateStr: String) -> String {
    let parts = dateStr.split(separator: "-")
    guard parts.count >= 3 else { return dateStr }
    return String(parts[1]) + "." + String(parts[2])
}
func drFirstCreatedFromId(_ ids: String?) -> Int? {
    guard let ids else { return nil }
    let first = ids
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first
    guard let first else { return nil }
    return Int(first)
}
func drParseDate(_ s: String) -> Date {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
    return f.date(from: s) ?? Date()
}
func drFormatDate(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
}
func drToday() -> String { drFormatDate(Date()) }
