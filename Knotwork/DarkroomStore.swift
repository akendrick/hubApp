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

    private var isBootstrapping = false

    init(serverURL: String, apiKey: String) {
        self.serverURL = serverURL
        self.apiKey    = apiKey
        restoreCache()
    }

    // MARK: - Bootstrap (single entry point — called once from root view)

    /// Loads all data sequentially. Guarded against concurrent calls.
    func bootstrap() async {
        guard !isBootstrapping else { return }
        isBootstrapping = true
        isLoading = true
        defer { isBootstrapping = false; isLoading = false }
        do {
            photoTypes     = try await fetch("photo_types");    cache(photoTypes,     key: "dr_photoTypes")
            chemistryTypes = try await fetch("chemistry_types"); cache(chemistryTypes, key: "dr_chemistryTypes")
            negativeTypes  = try await fetch("negative_types");  cache(negativeTypes,  key: "dr_negativeTypes")
            chemistry      = try await fetch("chemistry");       cache(chemistry,      key: "dr_chemistry")
            papers         = try await fetch("paper");           cache(papers,         key: "dr_papers")
            supportPapers  = try await fetch("support_paper");  cache(supportPapers,  key: "dr_supportPapers")
            carbonTissues  = try await fetch("carbon_tissue");  cache(carbonTissues,  key: "dr_carbonTissues")
            negatives      = try await fetch("negative");        cache(negatives,      key: "dr_negatives")
            photos         = try await fetch("photo");           cache(photos,         key: "dr_photos")
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Bootstrap

    func loadTypes() async {
        do {
            photoTypes     = try await fetch("photo_types");    cache(photoTypes,     key: "dr_photoTypes")
            chemistryTypes = try await fetch("chemistry_types"); cache(chemistryTypes, key: "dr_chemistryTypes")
            negativeTypes  = try await fetch("negative_types");  cache(negativeTypes,  key: "dr_negativeTypes")
        } catch { errorMessage = error.localizedDescription }
    }

    func loadAllForPhotoForm() async {
        isLoading = true; defer { isLoading = false }
        // Sequential — shared hosting can't handle 6 parallel connections
        do {
            photoTypes    = try await fetch("photo_types");    cache(photoTypes,    key: "dr_photoTypes")
            chemistry     = try await fetch("chemistry");      cache(chemistry,     key: "dr_chemistry")
            papers        = try await fetch("paper");          cache(papers,        key: "dr_papers")
            supportPapers = try await fetch("support_paper"); cache(supportPapers, key: "dr_supportPapers")
            carbonTissues = try await fetch("carbon_tissue"); cache(carbonTissues, key: "dr_carbonTissues")
            negatives     = try await fetch("negative");       cache(negatives,     key: "dr_negatives")
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Tab loaders

    func loadPhotos() async {
        isLoading = true; defer { isLoading = false }
        do { photos = try await fetch("photo"); cache(photos, key: "dr_photos") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadSupportPapers() async {
        do { supportPapers = try await fetch("support_paper"); cache(supportPapers, key: "dr_supportPapers") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadCarbonTissues() async {
        do { carbonTissues = try await fetch("carbon_tissue"); cache(carbonTissues, key: "dr_carbonTissues") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadNegatives() async {
        do { negatives = try await fetch("negative"); cache(negatives, key: "dr_negatives") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadChemistry() async {
        do { chemistry = try await fetch("chemistry"); cache(chemistry, key: "dr_chemistry") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadPapers() async {
        do { papers = try await fetch("paper"); cache(papers, key: "dr_papers") }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Photo Types CRUD

    func addPhotoType(_ req: DRPhotoTypeRequest) async throws {
        _ = try await DarkroomAPIClient.create(serverURL: serverURL, apiKey: apiKey, res: "photo_types", body: req)
        photoTypes = try await fetch("photo_types"); cache(photoTypes, key: "dr_photoTypes")
    }
    func updatePhotoType(id: Int, _ req: DRPhotoTypeRequest) async throws {
        try await DarkroomAPIClient.update(serverURL: serverURL, apiKey: apiKey, res: "photo_types", id: id, body: req)
        photoTypes = try await fetch("photo_types"); cache(photoTypes, key: "dr_photoTypes")
    }
    func deletePhotoType(id: Int) async {
        do {
            try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "photo_types", id: id)
            photoTypes.removeAll { $0.id == id }; cache(photoTypes, key: "dr_photoTypes")
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
            supportPapers.removeAll { $0.id == id }; cache(supportPapers, key: "dr_supportPapers")
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
            carbonTissues.removeAll { $0.id == id }; cache(carbonTissues, key: "dr_carbonTissues")
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
            negatives.removeAll { $0.id == id }; cache(negatives, key: "dr_negatives")
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Chemistry CRUD

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
            chemistry.removeAll { $0.id == id }; cache(chemistry, key: "dr_chemistry")
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Paper CRUD

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
            papers.removeAll { $0.id == id }; cache(papers, key: "dr_papers")
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Lookup Types CRUD

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
        } catch { errorMessage = error.localizedDescription }
    }

    private func reloadLookup(res: String) async {
        do {
            let items: [DRLookup] = try await fetch(res)
            switch res {
            case "chemistry_types": chemistryTypes = items; cache(items, key: "dr_chemistryTypes")
            case "negative_types":  negativeTypes  = items; cache(items, key: "dr_negativeTypes")
            default: break
            }
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
            photos.removeAll { $0.id == id }; cache(photos, key: "dr_photos")
        } catch { errorMessage = error.localizedDescription }
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

    // MARK: - Media URL helper

    func mediaURL(for path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return URL(string: "\(base)/\(path)")
    }

    // MARK: - Dashboard (cache-first for dashboard tab)

    func loadRecentForDashboard() async {
        guard !serverURL.isEmpty && !apiKey.isEmpty else { return }
        do {
            photos    = try await fetch("photo");    cache(photos,    key: "dr_photos")
            chemistry = try await fetch("chemistry"); cache(chemistry, key: "dr_chemistry")
        } catch { /* silent — cached data still shown */ }
    }

    // MARK: - Cache helpers

    /// Restore all cached data on init so tabs show instantly.
    private func restoreCache() {
        photoTypes    = load([DRPhotoType].self,    key: "dr_photoTypes")    ?? []
        chemistryTypes = load([DRLookup].self,      key: "dr_chemistryTypes") ?? []
        negativeTypes  = load([DRLookup].self,      key: "dr_negativeTypes")  ?? []
        photos        = load([DRPhoto].self,        key: "dr_photos")        ?? []
        chemistry     = load([DRChemistry].self,    key: "dr_chemistry")     ?? []
        papers        = load([DRPaper].self,        key: "dr_papers")        ?? []
        supportPapers = load([DRSupportPaper].self, key: "dr_supportPapers") ?? []
        carbonTissues = load([DRCarbonTissue].self, key: "dr_carbonTissues") ?? []
        negatives     = load([DRNegative].self,     key: "dr_negatives")     ?? []
    }

    private func cache<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try? dec.decode(type, from: data)
    }

    // MARK: - Private

    private func fetch<T: Decodable>(_ res: String) async throws -> T {
        try await DarkroomAPIClient.list(T.self, serverURL: serverURL, apiKey: apiKey, res: res)
    }
}
