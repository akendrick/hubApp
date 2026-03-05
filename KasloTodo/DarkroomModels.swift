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
    var hotPress: Int?           // MySQL tinyint → 0 or 1
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
        return "\(mark) (\(base))"
    }
}

// MARK: - Carbon Tissue

struct DRCarbonTissue: Identifiable, Codable {
    var id: Int
    var size: String?
    var chemistryId: Int?
    var chemType: String?
    var amountPoured: String?
    var datePoured: String
    var notes: String?

    var displayName: String {
        let parts = ["#\(id)", size, datePoured].compactMap { $0 }
        return parts.joined(separator: " ")
    }
}

// MARK: - Negative

struct DRNegative: Identifiable, Codable {
    var id: Int
    var dateCreated: String
    var typeId: Int?
    var typeName: String?
    var settingsNotes: String?

    var displayName: String { "#\(id) \(typeName ?? "") \(dateCreated)" }
}

// MARK: - Exposure + Times

struct DRExposureTime: Codable, Identifiable {
    var id: UUID
    var durationMinutes: Double?

    init(durationMinutes: Double? = nil) {
        id = UUID()
        self.durationMinutes = durationMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        durationMinutes = try? c.decodeIfPresent(Double.self, forKey: .durationMinutes)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
    }

    enum CodingKeys: String, CodingKey { case durationMinutes }
}

struct DRExposure: Identifiable, Codable {
    var id: Int
    var dateExposed: String
    var testStrip: Int?          // 0 or 1
    var negativeId: Int?
    var negType: String?
    var negDate: String?
    var times: [DRExposureTime]
    var paperSoakTime: Int?
    var paperSoakTemp: Double?
    var hotDevelopTime: Int?
    var hotDevelopTemp: Double?
    var coolDevelopTime: Int?
    var coolDevelopTemp: Double?
    var notes: String?
}

// MARK: - Photo + Layers

struct DRPhotoLayer: Codable, Identifiable {
    var id: UUID
    var supportPaperId: Int?
    var negativeId: Int?
    var carbonTissueId: Int?
    var spMark: String?
    var spPaperLabel: String?
    var negType: String?
    var negDate: String?
    var ctSize: String?
    var ctDate: String?

    init(supportPaperId: Int? = nil, negativeId: Int? = nil, carbonTissueId: Int? = nil) {
        id = UUID()
        self.supportPaperId = supportPaperId
        self.negativeId = negativeId
        self.carbonTissueId = carbonTissueId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        supportPaperId  = try? c.decodeIfPresent(Int.self,    forKey: .supportPaperId)
        negativeId      = try? c.decodeIfPresent(Int.self,    forKey: .negativeId)
        carbonTissueId  = try? c.decodeIfPresent(Int.self,    forKey: .carbonTissueId)
        spMark          = try? c.decodeIfPresent(String.self,  forKey: .spMark)
        spPaperLabel    = try? c.decodeIfPresent(String.self,  forKey: .spPaperLabel)
        negType         = try? c.decodeIfPresent(String.self,  forKey: .negType)
        negDate         = try? c.decodeIfPresent(String.self,  forKey: .negDate)
        ctSize          = try? c.decodeIfPresent(String.self,  forKey: .ctSize)
        ctDate          = try? c.decodeIfPresent(String.self,  forKey: .ctDate)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(supportPaperId, forKey: .supportPaperId)
        try c.encodeIfPresent(negativeId,     forKey: .negativeId)
        try c.encodeIfPresent(carbonTissueId, forKey: .carbonTissueId)
    }

    enum CodingKeys: String, CodingKey {
        case supportPaperId, negativeId, carbonTissueId
        case spMark, spPaperLabel, negType, negDate, ctSize, ctDate
    }
}

struct DRPhoto: Identifiable, Codable {
    var id: Int
    var dateSensitized: String?
    var dateExposed: String?
    var paperId: Int?
    var paperLabel: String?
    var photoSize: String?
    var gelatinChemistryId: Int?
    var gelatinType: String?
    var amountUsed: String?
    var exposureId: Int?
    var exposureDate: String?
    var notes: String?
    var layers: [DRPhotoLayer]
}

// MARK: - Request bodies (sent to API on POST / PATCH)
// All fields camelCase → encoder converts to snake_case automatically

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
    var size: String?
    var chemistryId: Int?
    var amountPoured: String?
    var datePoured: String
    var notes: String?
}

struct DRNegativeRequest: Encodable {
    var dateCreated: String
    var typeId: Int?
    var settingsNotes: String?
}

struct DRExposureRequest: Encodable {
    var dateExposed: String
    var testStrip: Bool
    var negativeId: Int?
    var paperSoakTime: Int?
    var paperSoakTemp: Double?
    var hotDevelopTime: Int?
    var hotDevelopTemp: Double?
    var coolDevelopTime: Int?
    var coolDevelopTemp: Double?
    var notes: String?
    var times: [DRTimeRequest]
}

struct DRTimeRequest: Encodable {
    var durationMinutes: Double
}

struct DRPhotoRequest: Encodable {
    var dateSensitized: String?
    var dateExposed: String?
    var paperId: Int?
    var photoSize: String?
    var gelatinChemistryId: Int?
    var amountUsed: String?
    var exposureId: Int?
    var notes: String?
    var layers: [DRLayerRequest]
}

struct DRLayerRequest: Encodable {
    var supportPaperId: Int?
    var negativeId: Int?
    var carbonTissueId: Int?
}
