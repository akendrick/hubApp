import Foundation

@MainActor
class DarkroomStore: ObservableObject {

    // MARK: - Config (immutable after init)
    let serverURL: String
    let apiKey: String

    // MARK: - State
    @Published var chemistryTypes: [DRLookup]      = []
    @Published var negativeTypes:  [DRLookup]      = []
    @Published var chemistry:      [DRChemistry]   = []
    @Published var papers:         [DRPaper]        = []
    @Published var supportPapers:  [DRSupportPaper] = []
    @Published var carbonTissues:  [DRCarbonTissue] = []
    @Published var negatives:      [DRNegative]     = []
    @Published var exposures:      [DRExposure]     = []
    @Published var photos:         [DRPhoto]        = []

    @Published var isLoading    = false
    @Published var errorMessage: String?

    init(serverURL: String, apiKey: String) {
        self.serverURL = serverURL
        self.apiKey    = apiKey
    }

    // MARK: - Lookup types (needed everywhere for dropdowns)

    func loadTypes() async {
        do {
            async let ct: [DRLookup] = DarkroomAPIClient.list(
                [DRLookup].self, serverURL: serverURL, apiKey: apiKey, res: "chemistry_types")
            async let nt: [DRLookup] = DarkroomAPIClient.list(
                [DRLookup].self, serverURL: serverURL, apiKey: apiKey, res: "negative_types")
            (chemistryTypes, negativeTypes) = try await (ct, nt)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load methods

    func loadChemistry() async {
        isLoading = true
        defer { isLoading = false }
        do { chemistry = try await fetch("chemistry") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadPapers() async {
        isLoading = true
        defer { isLoading = false }
        do { papers = try await fetch("paper") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadSupportPapers() async {
        isLoading = true
        defer { isLoading = false }
        do { supportPapers = try await fetch("support_paper") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadCarbonTissues() async {
        isLoading = true
        defer { isLoading = false }
        do { carbonTissues = try await fetch("carbon_tissue") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadNegatives() async {
        isLoading = true
        defer { isLoading = false }
        do { negatives = try await fetch("negative") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadExposures() async {
        isLoading = true
        defer { isLoading = false }
        do { exposures = try await fetch("exposure") }
        catch { errorMessage = error.localizedDescription }
    }

    func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }
        do { photos = try await fetch("photo") }
        catch { errorMessage = error.localizedDescription }
    }

    // Convenience: load several resources needed by photo/exposure forms
    func loadPhotoFormDeps() async {
        await loadPapers()
        await loadSupportPapers()
        await loadNegatives()
        await loadCarbonTissues()
        await loadExposures()
        await loadPhotos()
    }

    func loadExposureFormDeps() async {
        await loadNegatives()
        await loadExposures()
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
        do {
            try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "chemistry", id: id)
            chemistry.removeAll { $0.id == id }
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
        do {
            try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "paper", id: id)
            papers.removeAll { $0.id == id }
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
        do {
            try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "support_paper", id: id)
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
        do {
            try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "carbon_tissue", id: id)
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
        do {
            try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "negative", id: id)
            negatives.removeAll { $0.id == id }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Exposure CRUD

    func addExposure(_ req: DRExposureRequest) async throws {
        _ = try await DarkroomAPIClient.create(serverURL: serverURL, apiKey: apiKey, res: "exposure", body: req)
        await loadExposures()
    }

    func updateExposure(id: Int, _ req: DRExposureRequest) async throws {
        try await DarkroomAPIClient.update(serverURL: serverURL, apiKey: apiKey, res: "exposure", id: id, body: req)
        await loadExposures()
    }

    func deleteExposure(id: Int) async {
        do {
            try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "exposure", id: id)
            exposures.removeAll { $0.id == id }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Photo CRUD

    func addPhoto(_ req: DRPhotoRequest) async throws {
        _ = try await DarkroomAPIClient.create(serverURL: serverURL, apiKey: apiKey, res: "photo", body: req)
        await loadPhotos()
    }

    func updatePhoto(id: Int, _ req: DRPhotoRequest) async throws {
        try await DarkroomAPIClient.update(serverURL: serverURL, apiKey: apiKey, res: "photo", id: id, body: req)
        await loadPhotos()
    }

    func deletePhoto(id: Int) async {
        do {
            try await DarkroomAPIClient.delete(serverURL: serverURL, apiKey: apiKey, res: "photo", id: id)
            photos.removeAll { $0.id == id }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Private helper

    private func fetch<T: Decodable>(_ res: String) async throws -> T {
        try await DarkroomAPIClient.list(T.self, serverURL: serverURL, apiKey: apiKey, res: res)
    }
}
