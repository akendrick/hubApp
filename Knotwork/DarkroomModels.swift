import Foundation

// MARK: - Lookup tables

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
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value ? 1 : 0 }
        return nil
    }

    func decodeLossyDoubleIfPresent(forKey key: K) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }
}

private struct DRAnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where K == DRAnyCodingKey {
    func decodeLossyString(forKeys keys: [String]) -> String? {
        for keyString in keys {
            let key = DRAnyCodingKey(keyString)
            if let s = try? decodeIfPresent(String.self, forKey: key) {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if let i = try? decodeIfPresent(Int.self, forKey: key) {
                return String(i)
            }
            if let d = try? decodeIfPresent(Double.self, forKey: key) {
                return String(d)
            }
        }
        return nil
    }
}

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
    var isCarbonDev: Bool { devMode == "carbon" }   // alias used in options view

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeLossyIntIfPresent(forKey: .id) ?? 0
        name = c.decodeLossyStringIfPresent(forKey: .name) ?? ""
        hasLayers = c.decodeLossyIntIfPresent(forKey: .hasLayers) ?? 0
        devMode = c.decodeLossyStringIfPresent(forKey: .devMode) ?? "simple"
    }
}

// MARK: - Chemistry

struct DRChemistry: Identifiable, Codable {
    var id: Int
    var label: String?          // user-supplied name e.g. "IndiaInkSample"
    var dateCreated: String
    var typeId: Int?
    var typeName: String?
    var percentSolution: Double?
    var createdFromIds: String?
    var notes: String?

    /// Display label: "IndiaInkSample (Gelatin)" or "Gelatin Mar 5" for unlabelled records
    var menuLabel: String {
        let type = typeName ?? "Chemistry"
        if let l = label, !l.isEmpty { return "\(l) (\(type))" }
        // Fallback: type + month/day for legacy records without a label
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
        let raw = try decoder.container(keyedBy: DRAnyCodingKey.self)
        id = c.decodeLossyIntIfPresent(forKey: .id) ?? 0
        label = c.decodeLossyStringIfPresent(forKey: .label)
            ?? raw.decodeLossyString(forKeys: ["chem-label", "chem_label", "chemLabel", "title", "title_id", "titleId", "name"])
        dateCreated = c.decodeLossyStringIfPresent(forKey: .dateCreated) ?? ""
        typeId = c.decodeLossyIntIfPresent(forKey: .typeId)
        typeName = c.decodeLossyStringIfPresent(forKey: .typeName)
        percentSolution = c.decodeLossyDoubleIfPresent(forKey: .percentSolution)
        createdFromIds = c.decodeLossyStringIfPresent(forKey: .createdFromIds)
        notes = c.decodeLossyStringIfPresent(forKey: .notes)
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
        id = c.decodeLossyIntIfPresent(forKey: .id) ?? 0
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
        id = c.decodeLossyIntIfPresent(forKey: .id) ?? 0
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeLossyIntIfPresent(forKey: .id) ?? 0
        titleId = c.decodeLossyStringIfPresent(forKey: .titleId)
        size = c.decodeLossyStringIfPresent(forKey: .size)
        chemistryId = c.decodeLossyIntIfPresent(forKey: .chemistryId)
        chemType = c.decodeLossyStringIfPresent(forKey: .chemType)
        amountPoured = c.decodeLossyStringIfPresent(forKey: .amountPoured)
        datePoured = c.decodeLossyStringIfPresent(forKey: .datePoured) ?? ""
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
        id = c.decodeLossyIntIfPresent(forKey: .id) ?? 0
        titleId = c.decodeLossyStringIfPresent(forKey: .titleId)
        dateCreated = c.decodeLossyStringIfPresent(forKey: .dateCreated) ?? ""
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
    var thumbPath: String?
    var notes: String?
    // Children
    var layers: [DRPhotoLayer]
    var finishing: [DRFinishingStep]

    var showLayers: Bool  { (typeHasLayers ?? 0) != 0 }
    var isCarbon: Bool    { typeDevMode == "carbon" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeLossyIntIfPresent(forKey: .id) ?? 0
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
        thumbPath = c.decodeLossyStringIfPresent(forKey: .thumbPath)
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

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(hasLayers ? 1 : 0, forKey: .hasLayers)
        try c.encode(devMode, forKey: .devMode)
    }

    enum CodingKeys: String, CodingKey {
        case name, hasLayers, devMode
    }
}

struct DRChemistryRequest: Encodable {
    var label: String?
    var dateCreated: String
    var typeId: Int?
    var percentSolution: Double?
    var createdFromId: Int?
    var notes: String?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(label, forKey: .label)
        try c.encodeIfPresent(label, forKey: .chemLabel)
        try c.encodeIfPresent(label, forKey: .title)
        try c.encodeIfPresent(label, forKey: .titleId)
        try c.encode(dateCreated, forKey: .dateCreated)
        try c.encodeIfPresent(typeId, forKey: .typeId)
        try c.encodeIfPresent(percentSolution, forKey: .percentSolution)
        try c.encodeIfPresent(createdFromId, forKey: .createdFromId)
        try c.encodeIfPresent(notes, forKey: .notes)
    }

    enum CodingKeys: String, CodingKey {
        case label
        case chemLabel = "chem-label"
        case title, titleId, dateCreated, typeId, percentSolution, createdFromId, notes
    }
}

struct DRPaperRequest: Encodable {
    var manufacturer: String?
    var label: String?
    var weight: Double?
    var hotPress: Bool
    var notes: String?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(manufacturer, forKey: .manufacturer)
        try c.encodeIfPresent(label, forKey: .label)
        try c.encodeIfPresent(weight, forKey: .weight)
        try c.encode(hotPress ? 1 : 0, forKey: .hotPress)
        try c.encodeIfPresent(notes, forKey: .notes)
    }

    enum CodingKeys: String, CodingKey {
        case manufacturer, label, weight, hotPress, notes
    }
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

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(photoTypeId, forKey: .photoTypeId)
        try c.encodeIfPresent(paperId, forKey: .paperId)
        try c.encodeIfPresent(photoSize, forKey: .photoSize)
        try c.encodeIfPresent(dateSensitized, forKey: .dateSensitized)
        try c.encodeIfPresent(dateExposed, forKey: .dateExposed)
        try c.encode(testStrip ? 1 : 0, forKey: .testStrip)
        try c.encodeIfPresent(exposureDuration, forKey: .exposureDuration)
        try c.encode(times, forKey: .times)
        try c.encodeIfPresent(paperSoakTime, forKey: .paperSoakTime)
        try c.encodeIfPresent(paperSoakTemp, forKey: .paperSoakTemp)
        try c.encodeIfPresent(hotDevelopTime, forKey: .hotDevelopTime)
        try c.encodeIfPresent(hotDevelopTemp, forKey: .hotDevelopTemp)
        try c.encodeIfPresent(coolDevelopTime, forKey: .coolDevelopTime)
        try c.encodeIfPresent(coolDevelopTemp, forKey: .coolDevelopTemp)
        try c.encodeIfPresent(developTime, forKey: .developTime)
        try c.encodeIfPresent(developTemp, forKey: .developTemp)
        try c.encodeIfPresent(developNotes, forKey: .developNotes)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(layers, forKey: .layers)
        try c.encode(finishing, forKey: .finishing)
    }

    enum CodingKeys: String, CodingKey {
        case title, photoTypeId, paperId, photoSize, dateSensitized, dateExposed
        case testStrip, exposureDuration, times
        case paperSoakTime, paperSoakTemp, hotDevelopTime, hotDevelopTemp, coolDevelopTime, coolDevelopTemp
        case developTime, developTemp, developNotes, notes, layers, finishing
    }
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
