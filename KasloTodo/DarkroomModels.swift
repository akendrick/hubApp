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
    var hasLayers: Int      // 0/1 from server
    var devMode: String     // "carbon" | "simple"

    var showLayers: Bool  { hasLayers != 0 }
    var isCarbon: Bool    { devMode == "carbon" }
    var isCarbonDev: Bool { isCarbon }
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

    init(
        id: Int,
        dateCreated: String,
        typeId: Int? = nil,
        typeName: String? = nil,
        percentSolution: Double? = nil,
        createdFromIds: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.dateCreated = dateCreated
        self.typeId = typeId
        self.typeName = typeName
        self.percentSolution = percentSolution
        self.createdFromIds = createdFromIds
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.drDecodeInt(.id) ?? 0
        dateCreated = try c.drDecodeString(.dateCreated) ?? ""
        typeId = try c.drDecodeIntIfPresent(.typeId)
        typeName = try c.drDecodeStringIfPresent(.typeName)
        percentSolution = try c.drDecodeDoubleIfPresent(.percentSolution)
        createdFromIds = try c.drDecodeStringIfPresent(.createdFromIds)
        notes = try c.drDecodeStringIfPresent(.notes)
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
}

// MARK: - Support Paper

struct DRSupportPaper: Identifiable, Codable {
    var id: Int
    var paperId: Int?
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

    init(
        id: Int,
        paperId: Int?,
        mark: String,
        paperLabel: String? = nil,
        manufacturer: String? = nil,
        label: String? = nil,
        weight: Double? = nil,
        hotPress: Int? = nil,
        treatmentChemistryId: Int? = nil,
        treatmentLabel: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.paperId = paperId
        self.mark = mark
        self.paperLabel = paperLabel
        self.manufacturer = manufacturer
        self.label = label
        self.weight = weight
        self.hotPress = hotPress
        self.treatmentChemistryId = treatmentChemistryId
        self.treatmentLabel = treatmentLabel
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.drDecodeInt(.id) ?? 0
        paperId = try c.drDecodeIntIfPresent(.paperId)
        mark = try c.drDecodeString(.mark) ?? ""
        paperLabel = try c.drDecodeStringIfPresent(.paperLabel)
        manufacturer = try c.drDecodeStringIfPresent(.manufacturer)
        label = try c.drDecodeStringIfPresent(.label)
        weight = try c.drDecodeDoubleIfPresent(.weight)
        hotPress = try c.drDecodeIntIfPresent(.hotPress)
        treatmentChemistryId = try c.drDecodeIntIfPresent(.treatmentChemistryId)
        treatmentLabel = try c.drDecodeStringIfPresent(.treatmentLabel)
        notes = try c.drDecodeStringIfPresent(.notes)
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
func drParseDate(_ s: String) -> Date {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
    return f.date(from: s) ?? Date()
}
func drFormatDate(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
}
func drToday() -> String { drFormatDate(Date()) }

private extension KeyedDecodingContainer {
    func drDecodeString(_ key: Key) throws -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        return nil
    }

    func drDecodeStringIfPresent(_ key: Key) throws -> String? {
        guard contains(key) else { return nil }
        return try drDecodeString(key)
    }

    func drDecodeInt(_ key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    func drDecodeIntIfPresent(_ key: Key) throws -> Int? {
        guard contains(key) else { return nil }
        return try drDecodeInt(key)
    }

    func drDecodeDoubleIfPresent(_ key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}
