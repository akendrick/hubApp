import Foundation

// MARK: - Lookup tables

struct DRLookup: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
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
}

// MARK: - Paper

struct DRPaper: Identifiable, Codable {
    var id: Int
    var manufacturer: String?
    var label: String?
    var weight: Double?
    var hotPress: Int?
    var treatmentChemistryId: Int?
    var treatmentLabel: String?
    var notes: String?

    var displayName: String {
        [manufacturer, label].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
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
    var notes: String?

    var displayName: String {
        let base = paperLabel ?? [manufacturer, label].compactMap { $0 }.joined(separator: " ")
        return mark + (base.isEmpty ? "" : " (\(base))")
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

    /// Format: "TITLE.YY.MM" or "#id YY.MM"
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

    /// Format: "TITLE.YY.MM" or "#id YY.MM"
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
    var paperId: Int?
    var paperLabel: String?
    var photoSize: String?
    var dateSensitized: String?
    var dateExposed: String?
    // Exposure
    var testStrip: Int?
    var times: [DRPhotoTime]
    // Development
    var paperSoakTime: Int?
    var paperSoakTemp: Double?
    var hotDevelopTime: Int?
    var hotDevelopTemp: Double?
    var coolDevelopTime: Int?
    var coolDevelopTemp: Double?
    // Image
    var imagePath: String?
    var notes: String?
    // Layers
    var layers: [DRPhotoLayer]
}

// MARK: - Photo Times

struct DRPhotoTime: Codable, Identifiable {
    var id: UUID = UUID()
    var durationMinutes: Double?

    init(durationMinutes: Double? = nil) {
        self.durationMinutes = durationMinutes
    }

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

// MARK: - Request bodies

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
    var treatmentChemistryId: Int?
    var notes: String?
}

struct DRSupportPaperRequest: Encodable {
    var paperId: Int
    var mark: String
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
    var paperId: Int?
    var photoSize: String?
    var dateSensitized: String?
    var dateExposed: String?
    var testStrip: Bool
    var paperSoakTime: Int?
    var paperSoakTemp: Double?
    var hotDevelopTime: Int?
    var hotDevelopTemp: Double?
    var coolDevelopTime: Int?
    var coolDevelopTemp: Double?
    var notes: String?
    var times: [DRTimeRequest]
    var layers: [DRLayerRequest]
}

struct DRTimeRequest: Encodable {
    var durationMinutes: Double
}

struct DRLayerRequest: Encodable {
    var supportPaperId: Int?
    var negativeId: Int?
    var carbonTissueId: Int?
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
