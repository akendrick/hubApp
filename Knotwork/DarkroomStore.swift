import Foundation

@MainActor
class DarkroomStore: ObservableObject {

    let serverURL: String
    let apiKey: String

    @Published var photoTypes:    [DRPhotoType]    = []
    @Published var chemistryTypes:[DRLookup]       = []
    @Published var negativeTypes: [DRLookup]       = []
    @Published var chemistry:     [DRChemistry]    = []
    @Published var papers:        [DRPaper]        = []
    @Published var supportPapers: [DRSupportPaper] = []
    @Published var carbonTissues: [DRCarbonTissue] = []
    @Published var negatives:     [DRNegative]     = []
    @Published var photos:        [DRPhoto]        = []

    @Published var isLoading    = false
    @Published var errorMessage: String?

    init(serverURL: String, apiKey: String) {
        self.serverURL = serverURL
        self.apiKey    = apiKey
    }

    // MARK: - Bootstrap

    func loadTypes() async {
        do {
            async let pt: [DRPhotoType] = fetch("photo_types")
            async let ct: [DRLookup]   = fetch("chemistry_types")
            async let nt: [DRLookup]   = fetch("negative_types")
            (photoTypes, chemistryTypes, negativeTypes) = try await (pt, ct, nt)
        } catch { errorMessage = error.localizedDescription }
    }

    // Load everything needed to render the photo form
    func loadAllForPhotoForm() async {
        isLoading = true; defer { isLoading = false }
        do {
            async let pt: [DRPhotoType]    = fetch("photo_types")
            async let sp: [DRSupportPaper] = fetch("support_paper")
            async let ct: [DRCarbonTissue] = fetch("carbon_tissue")
            async let neg: [DRNegative]    = fetch("negative")
            async let c:   [DRChemistry]   = fetch("chemistry")
            async let p:   [DRPaper]       = fetch("paper")
            (photoTypes, supportPapers, carbonTissues, negatives, chemistry, papers) = try await (pt, sp, ct, neg, c, p)
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Tab loaders

    func loadPhotos() async {
        isLoading = true; defer { isLoading = false }
        do { photos = try await fetch("photo") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadSupportPapers() async {
        do { supportPapers = try await fetch("support_paper") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadCarbonTissues() async {
        do { carbonTissues = try await fetch("carbon_tissue") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadNegatives() async {
        do { negatives = try await fetch("negative") }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Photo Types CRUD

    func addPhotoType(_ req: DRPhotoTypeRequest) async throws {
        _ = try await DarkroomAPIClient.create(serverURL: serverURL, apiKey: apiKey, res: "photo_types", body: req)
        photoTypes = try await fetch("photo_types")
    }
    func updatePhotoType(id: Int, _ req: DRPhotoTypeRequest) async throws {
        try await DarkroomAPIClient.update(serverURL: serverURL, apiKey: apiKey, res: "photo_types", id: id, body: req)
        photoTypes = try await fetch("photo_types")
    }
    func deletePhotoType(id: Int) async {
        do {
            try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "photo_types", id: id)
            photoTypes.removeAll { $0.id == id }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Support Paper CRUD

    func addSupportPaper(_ req: DRSupportPaperRequest) async throws {
        _ = try await DarkroomAPIClient.create(serverURL: serverURL, apiKey: apiKey, res: "support_paper", body: req)
        await loadSupportPapers()
    }
    func updateSupportPaper(id: Int, _ req: DRSupportPaperRequest) async throws {
        try await DarkroomAPIClient.update(serverURL: serverURL, apiKey: apiKey, res: "support_paper", id: id, body: req)
        await loadSupportPapers()
    }
    func deleteSupportPaper(id: Int) async {
        do { try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "support_paper", id: id)
            supportPapers.removeAll { $0.id == id }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Carbon Tissue CRUD

    func addCarbonTissue(_ req: DRCarbonTissueRequest) async throws {
        _ = try await DarkroomAPIClient.create(serverURL: serverURL, apiKey: apiKey, res: "carbon_tissue", body: req)
        await loadCarbonTissues()
    }
    func updateCarbonTissue(id: Int, _ req: DRCarbonTissueRequest) async throws {
        try await DarkroomAPIClient.update(serverURL: serverURL, apiKey: apiKey, res: "carbon_tissue", id: id, body: req)
        await loadCarbonTissues()
    }
    func deleteCarbonTissue(id: Int) async {
        do { try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "carbon_tissue", id: id)
            carbonTissues.removeAll { $0.id == id }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Negative CRUD

    func addNegative(_ req: DRNegativeRequest) async throws {
        _ = try await DarkroomAPIClient.create(serverURL: serverURL, apiKey: apiKey, res: "negative", body: req)
        await loadNegatives()
    }
    func updateNegative(id: Int, _ req: DRNegativeRequest) async throws {
        try await DarkroomAPIClient.update(serverURL: serverURL, apiKey: apiKey, res: "negative", id: id, body: req)
        await loadNegatives()
    }
    func deleteNegative(id: Int) async {
        do { try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "negative", id: id)
            negatives.removeAll { $0.id == id }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Photo CRUD

    func addPhoto(_ req: DRPhotoRequest) async throws -> Int {
        try await DarkroomAPIClient.create(serverURL: serverURL, apiKey: apiKey, res: "photo", body: req)
    }
    func updatePhoto(id: Int, _ req: DRPhotoRequest) async throws {
        try await DarkroomAPIClient.update(serverURL: serverURL, apiKey: apiKey, res: "photo", id: id, body: req)
        await loadPhotos()
    }
    func deletePhoto(id: Int) async {
        do { try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "photo", id: id)
            photos.removeAll { $0.id == id }
        } catch { errorMessage = error.localizedDescription }
    }
    func uploadPhotoImage(photoId: Int, imageData: Data, mimeType: String) async throws {
        _ = try await DarkroomAPIClient.uploadImage(serverURL: serverURL, apiKey: apiKey, photoId: photoId, imageData: imageData, mimeType: mimeType)
        await loadPhotos()
    }

    // MARK: - Private

    private func fetch<T: Decodable>(_ res: String) async throws -> T {
        try await DarkroomAPIClient.list(T.self, serverURL: serverURL, apiKey: apiKey, res: res)
    }
}
