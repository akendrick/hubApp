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

    func present(_ error: Error) {
        guard !error.isRequestCancellation else { return }
        errorMessage = error.localizedDescription
    }

    // MARK: - Bootstrap

    func loadTypes() async {
        do {
            async let pt: [DRPhotoType] = fetch("photo_types")
            async let ct: [DRLookup]   = fetch("chemistry_types")
            async let nt: [DRLookup]   = fetch("negative_types")
            (photoTypes, chemistryTypes, negativeTypes) = try await (pt, ct, nt)
        } catch { present(error) }
    }

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
        } catch { present(error) }
    }

    // MARK: - Tab loaders

    func loadPhotos() async {
        isLoading = true; defer { isLoading = false }
        do { photos = try await fetch("photo") }
        catch { present(error) }
    }

    func loadSupportPapers() async {
        do { supportPapers = try await fetch("support_paper") }
        catch { present(error) }
    }

    func loadCarbonTissues() async {
        do { carbonTissues = try await fetch("carbon_tissue") }
        catch { present(error) }
    }

    func loadNegatives() async {
        do { negatives = try await fetch("negative") }
        catch { present(error) }
    }

    // MARK: - Chemistry CRUD

    func loadChemistry() async {
        do { chemistry = try await fetch("chemistry") }
        catch { present(error) }
    }

    func addChemistry(_ req: DRChemistryRequest) async throws {
        _ = try await DarkroomAPIClient.create(serverURL: serverURL, apiKey: apiKey, res: "chemistry", body: req)
        await loadChemistry()
    }
    func updateChemistry(id: Int, _ req: DRChemistryRequest) async throws {
        try await DarkroomAPIClient.update(serverURL: serverURL, apiKey: apiKey, res: "chemistry", id: id, body: req)
        await loadChemistry()
    }
    func deleteChemistry(id: Int) async {
        do { try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "chemistry", id: id)
            chemistry.removeAll { $0.id == id }
        } catch { present(error) }
    }

    // MARK: - Paper CRUD

    func loadPapers() async {
        do { papers = try await fetch("paper") }
        catch { present(error) }
    }

    func addPaper(_ req: DRPaperRequest) async throws {
        _ = try await DarkroomAPIClient.create(serverURL: serverURL, apiKey: apiKey, res: "paper", body: req)
        await loadPapers()
    }
    func updatePaper(id: Int, _ req: DRPaperRequest) async throws {
        try await DarkroomAPIClient.update(serverURL: serverURL, apiKey: apiKey, res: "paper", id: id, body: req)
        await loadPapers()
    }
    func deletePaper(id: Int) async {
        do { try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "paper", id: id)
            papers.removeAll { $0.id == id }
        } catch { present(error) }
    }

    // MARK: - Lookup Types CRUD (chemistry_types, negative_types, finishing_types)

    func addLookupType(resource: String, name: String) async throws {
        _ = try await DarkroomAPIClient.create(serverURL: serverURL, apiKey: apiKey,
                                                res: resource, body: DRLookupRequest(name: name))
        await reloadLookup(res: resource)
    }
    func updateLookupType(resource: String, id: Int, name: String) async throws {
        try await DarkroomAPIClient.update(serverURL: serverURL, apiKey: apiKey,
                                           res: resource, id: id, body: DRLookupRequest(name: name))
        await reloadLookup(res: resource)
    }
    func deleteLookupType(resource: String, id: Int) async {
        do {
            try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: resource, id: id)
            await reloadLookup(res: resource)
        } catch { present(error) }
    }

    private func reloadLookup(res: String) async {
        do {
            let items: [DRLookup] = try await fetch(res)
            switch res {
            case "chemistry_types": chemistryTypes = items
            case "negative_types":  negativeTypes  = items
            default: break
            }
        } catch { present(error) }
    }

    // MARK: - Media URL helper

    /// Builds a full URL for a relative image path stored on the server.
    func mediaURL(for path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return URL(string: "\(base)/\(path)")
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
        } catch { present(error) }
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
        } catch { present(error) }
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
        } catch { present(error) }
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
        } catch { present(error) }
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
        } catch { present(error) }
    }

    // MARK: - Image Upload

    func uploadPhotoImage(photoId: Int, imageData: Data, mimeType: String) async throws {
        let result = try await DarkroomAPIClient.uploadImage(
            serverURL: serverURL, apiKey: apiKey,
            photoId: photoId, imageData: imageData, mimeType: mimeType
        )
        if let idx = photos.firstIndex(where: { $0.id == photoId }) {
            photos[idx].imagePath = result.imagePath
            photos[idx].thumbPath = result.thumbPath
        }
        await loadPhotos()
    }

    // MARK: - Dashboard

    /// Loads photos + chemistry for the dashboard. Serves from cache instantly,
    /// then refreshes in the background.
    func loadRecentForDashboard() async {
        loadDashboardCache()
        guard !serverURL.isEmpty && !apiKey.isEmpty else { return }
        do {
            async let p: [DRPhoto]     = fetch("photo")
            async let c: [DRChemistry] = fetch("chemistry")
            let (newPhotos, newChem) = try await (p, c)
            photos    = newPhotos
            chemistry = newChem
            saveDashboardCache()
        } catch { /* silent — cached data already shown */ }
    }

    private func saveDashboardCache() {
        if let pd = try? JSONEncoder().encode(photos) {
            UserDefaults.standard.set(pd, forKey: "dr_cache_photos")
        }
        if let cd = try? JSONEncoder().encode(chemistry) {
            UserDefaults.standard.set(cd, forKey: "dr_cache_chemistry")
        }
    }

    private func loadDashboardCache() {
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        if photos.isEmpty,
           let d = UserDefaults.standard.data(forKey: "dr_cache_photos"),
           let v = try? dec.decode([DRPhoto].self, from: d) {
            photos = v
        }
        if chemistry.isEmpty,
           let d = UserDefaults.standard.data(forKey: "dr_cache_chemistry"),
           let v = try? dec.decode([DRChemistry].self, from: d) {
            chemistry = v
        }
    }

    // MARK: - Private

    private func fetch<T: Decodable>(_ res: String) async throws -> T {
        try await DarkroomAPIClient.list(T.self, serverURL: serverURL, apiKey: apiKey, res: res)
    }
}
