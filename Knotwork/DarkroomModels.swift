import Foundation

// MARK: - Lookup tables

struct DRLookup: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
}

// MARK: - Photo Type
// Controls which form sections are shown.
// hasLayers:  true  → show Layers section
// devMode:    "carbon"  → paper soak + hot develop + cool develop
//             "simple"  → single time / temp / notes field

struct DRPhotoType: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
    var hasLayers: Int   // 0/1
    var devMode: String  // "carbon" | "simple"

    var showLayers: Bool  { hasLayers != 0 }
    var isCarbon: Bool    { devMode == "carbon" }
    var isCarbonDev: Bool { devMode == "carbon" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decodeFlexInt(forKey: .id)
        name      = (try? c.decode(String.self, forKey: .name)) ?? ""
        hasLayers = c.decodeFlexOptInt(forKey: .hasLayers) ?? 0
        devMode   = (try? c.decode(String.self, forKey: .devMode)) ?? "simple"
    }
}

// MARK: - Chemistry

struct DRChemistry: Identifiable, Codable {
    var id: Int
    var label: String?
    var dateCreated: String
    var typeId: Int?
    var typeName: String?
    var percentSolution: Double?
    var createdFromIds: String?
    var notes: String?

    var menuLabel: String {
        let type = typeName ?? "Chemistry"
        if let l = label, !l.isEmpty { return "\(l) (\(type))" }
        let parts = dateCreated.split(separator: "-")
        if parts.count == 3,
           let month = Int(parts[1]),
           let day   = Int(parts[2]) {
            let monthName = DateFormatter().shortMonthSymbols[month - 1]
            return "\(type) \(monthName) \(day)"
        }
        return "\(type) #\(id)"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decodeFlexInt(forKey: .id)
        label           = try? c.decode(String.self, forKey: .label)
        dateCreated     = (try? c.decode(String.self, forKey: .dateCreated)) ?? ""
        typeId          = c.decodeFlexOptInt(forKey: .typeId)
        typeName        = try? c.decode(String.self, forKey: .typeName)
        percentSolution = c.decodeFlexDouble(forKey: .percentSolution)
        createdFromIds  = try? c.decode(String.self, forKey: .createdFromIds)
        notes           = try? c.decode(String.self, forKey: .notes)
    }
}

// MARK: - Lookup request (for chemistry_types, negative_types, finishing_types)
struct DRLookupRequest: Encodable {
    var name: String
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
        id           = try c.decodeFlexInt(forKey: .id)
        manufacturer = try? c.decode(String.self, forKey: .manufacturer)
        label        = try? c.decode(String.self, forKey: .label)
        weight       = c.decodeFlexDouble(forKey: .weight)
        hotPress     = c.decodeFlexOptInt(forKey: .hotPress)
        notes        = try? c.decode(String.self, forKey: .notes)
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
        let base = paperLabel ?? [manufacturer, label].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        return mark + (base.isEmpty ? "" : " (\(base))")
    }

    // Custom decoder: MySQL PDO may return any numeric column as a String.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decodeFlexInt(forKey: .id)
        paperId             = try c.decodeFlexInt(forKey: .paperId)
        mark                = (try? c.decode(String.self, forKey: .mark)) ?? ""
        paperLabel          = try? c.decode(String.self, forKey: .paperLabel)
        manufacturer        = try? c.decode(String.self, forKey: .manufacturer)
        label               = try? c.decode(String.self, forKey: .label)
        weight              = c.decodeFlexDouble(forKey: .weight)
        hotPress            = c.decodeFlexOptInt(forKey: .hotPress)
        treatmentChemistryId = c.decodeFlexOptInt(forKey: .treatmentChemistryId)
        treatmentLabel      = try? c.decode(String.self, forKey: .treatmentLabel)
        notes               = try? c.decode(String.self, forKey: .notes)
    }
}

/// Helpers for decoding MySQL PDO responses where numeric columns may arrive as strings.
extension KeyedDecodingContainer {
    func decodeFlexInt(forKey key: Key) throws -> Int {
        if let i = try? decode(Int.self, forKey: key)    { return i }
        if let s = try? decode(String.self, forKey: key), let i = Int(s) { return i }
        throw DecodingError.typeMismatch(Int.self, .init(codingPath: [key], debugDescription: "Expected Int or String-encoded Int"))
    }
    func decodeFlexOptInt(forKey key: Key) -> Int? {
        if let i = try? decode(Int.self, forKey: key)    { return i }
        if let s = try? decode(String.self, forKey: key), let i = Int(s) { return i }
        return nil
    }
    func decodeFlexDouble(forKey key: Key) -> Double? {
        if let d = try? decode(Double.self, forKey: key) { return d }
        if let s = try? decode(String.self, forKey: key), let d = Double(s) { return d }
        return nil
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decodeFlexInt(forKey: .id)
        titleId      = try? c.decode(String.self, forKey: .titleId)
        size         = try? c.decode(String.self, forKey: .size)
        chemistryId  = c.decodeFlexOptInt(forKey: .chemistryId)
        chemType     = try? c.decode(String.self, forKey: .chemType)
        amountPoured = try? c.decode(String.self, forKey: .amountPoured)
        datePoured   = (try? c.decode(String.self, forKey: .datePoured)) ?? ""
        notes        = try? c.decode(String.self, forKey: .notes)
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
        id            = try c.decodeFlexInt(forKey: .id)
        titleId       = try? c.decode(String.self, forKey: .titleId)
        dateCreated   = (try? c.decode(String.self, forKey: .dateCreated)) ?? ""
        typeId        = c.decodeFlexOptInt(forKey: .typeId)
        typeName      = try? c.decode(String.self, forKey: .typeName)
        settingsNotes = try? c.decode(String.self, forKey: .settingsNotes)
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
    var thumbPath: String?
    var notes: String?
    // Children
    var layers: [DRPhotoLayer]
    var finishing: [DRFinishingStep]

    var showLayers: Bool  { (typeHasLayers ?? 0) != 0 }
    var isCarbon: Bool    { typeDevMode == "carbon" }
    var isCarbonDev: Bool { typeDevMode == "carbon" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decodeFlexInt(forKey: .id)
        title           = try? c.decode(String.self, forKey: .title)
        photoTypeId     = c.decodeFlexOptInt(forKey: .photoTypeId)
        typeName        = try? c.decode(String.self, forKey: .typeName)
        typeHasLayers   = c.decodeFlexOptInt(forKey: .typeHasLayers)
        typeDevMode     = try? c.decode(String.self, forKey: .typeDevMode)
        paperId         = c.decodeFlexOptInt(forKey: .paperId)
        paperLabel      = try? c.decode(String.self, forKey: .paperLabel)
        photoSize       = try? c.decode(String.self, forKey: .photoSize)
        dateSensitized  = try? c.decode(String.self, forKey: .dateSensitized)
        dateExposed     = try? c.decode(String.self, forKey: .dateExposed)
        testStrip       = c.decodeFlexOptInt(forKey: .testStrip)
        exposureDuration = c.decodeFlexDouble(forKey: .exposureDuration)
        times           = (try? c.decode([DRPhotoTime].self, forKey: .times)) ?? []
        paperSoakTime   = c.decodeFlexOptInt(forKey: .paperSoakTime)
        paperSoakTemp   = c.decodeFlexDouble(forKey: .paperSoakTemp)
        hotDevelopTime  = c.decodeFlexOptInt(forKey: .hotDevelopTime)
        hotDevelopTemp  = c.decodeFlexDouble(forKey: .hotDevelopTemp)
        coolDevelopTime = c.decodeFlexOptInt(forKey: .coolDevelopTime)
        coolDevelopTemp = c.decodeFlexDouble(forKey: .coolDevelopTemp)
        developTime     = c.decodeFlexOptInt(forKey: .developTime)
        developTemp     = c.decodeFlexDouble(forKey: .developTemp)
        developNotes    = try? c.decode(String.self, forKey: .developNotes)
        imagePath       = try? c.decode(String.self, forKey: .imagePath)
        thumbPath       = try? c.decode(String.self, forKey: .thumbPath)
        notes           = try? c.decode(String.self, forKey: .notes)
        layers          = (try? c.decode([DRPhotoLayer].self, forKey: .layers)) ?? []
        finishing       = (try? c.decode([DRFinishingStep].self, forKey: .finishing)) ?? []
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
        durationMinutes = try? c.decodeIfPresent(Double.self, forKey: .durationMinutes)
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
        supportPaperId = try? c.decodeIfPresent(Int.self,    forKey: .supportPaperId)
        negativeId     = try? c.decodeIfPresent(Int.self,    forKey: .negativeId)
        carbonTissueId = try? c.decodeIfPresent(Int.self,    forKey: .carbonTissueId)
        spMark         = try? c.decodeIfPresent(String.self, forKey: .spMark)
        spPaperLabel   = try? c.decodeIfPresent(String.self, forKey: .spPaperLabel)
        spWeight       = try? c.decodeIfPresent(Double.self, forKey: .spWeight)
        spHotPress     = try? c.decodeIfPresent(Int.self,    forKey: .spHotPress)
        spNotes        = try? c.decodeIfPresent(String.self, forKey: .spNotes)
        negTitleId     = try? c.decodeIfPresent(String.self, forKey: .negTitleId)
        negType        = try? c.decodeIfPresent(String.self, forKey: .negType)
        negDate        = try? c.decodeIfPresent(String.self, forKey: .negDate)
        negNotes       = try? c.decodeIfPresent(String.self, forKey: .negNotes)
        ctTitleId      = try? c.decodeIfPresent(String.self, forKey: .ctTitleId)
        ctSize         = try? c.decodeIfPresent(String.self, forKey: .ctSize)
        ctDate         = try? c.decodeIfPresent(String.self, forKey: .ctDate)
        ctAmount       = try? c.decodeIfPresent(String.self, forKey: .ctAmount)
        ctNotes        = try? c.decodeIfPresent(String.self, forKey: .ctNotes)
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
        label        = (try? c.decodeIfPresent(String.self, forKey: .label)) ?? ""
        chemistryId  = try? c.decodeIfPresent(Int.self,    forKey: .chemistryId)
        chemTypeName = try? c.decodeIfPresent(String.self, forKey: .chemTypeName)
        stepTime     = try? c.decodeIfPresent(Int.self,    forKey: .stepTime)
        stepTemp     = try? c.decodeIfPresent(Double.self, forKey: .stepTemp)
        notes        = try? c.decodeIfPresent(String.self, forKey: .notes)
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
    var label: String?
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
func drParseDate(_ s: String) -> Date {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
    return f.date(from: s) ?? Date()
}
func drFormatDate(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
}
func drToday() -> String { drFormatDate(Date()) }
