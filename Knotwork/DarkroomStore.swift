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

    private func present(_ error: Error) {
        if error is CancellationError { return }
        errorMessage = error.localizedDescription
    }

    private func loadResource<T: Decodable>(_ res: String, assign: (T) -> Void) async -> String? {
        do {
            let value: T = try await fetch(res)
            assign(value)
            return nil
        } catch {
            return "\(res): \(error.localizedDescription)"
        }
    }

    private func presentPartialFailures(_ failures: [String]) {
        guard !failures.isEmpty else { return }
        errorMessage = "Some Darkroom data did not load.\n" + failures.joined(separator: "\n")
    }

    // MARK: - Bootstrap

    func loadTypes() async {
        errorMessage = nil
        var failures: [String] = []

        if let failure: String = await loadResource("photo_types", assign: { (value: [DRPhotoType]) in
            photoTypes = value
        }) {
            failures.append(failure)
        }
        if let failure: String = await loadResource("chemistry_types", assign: { (value: [DRLookup]) in
            chemistryTypes = value
        }) {
            failures.append(failure)
        }
        if let failure: String = await loadResource("negative_types", assign: { (value: [DRLookup]) in
            negativeTypes = value
        }) {
            failures.append(failure)
        }

        presentPartialFailures(failures)
    }

    // Load everything needed to render the photo form
    func loadAllForPhotoForm() async {
        isLoading = true; defer { isLoading = false }
        errorMessage = nil
        var failures: [String] = []

        if let failure: String = await loadResource("photo_types", assign: { (value: [DRPhotoType]) in
            photoTypes = value
        }) {
            failures.append(failure)
        }
        if let failure: String = await loadResource("support_paper", assign: { (value: [DRSupportPaper]) in
            supportPapers = value
        }) {
            failures.append(failure)
        }
        if let failure: String = await loadResource("carbon_tissue", assign: { (value: [DRCarbonTissue]) in
            carbonTissues = value
        }) {
            failures.append(failure)
        }
        if let failure: String = await loadResource("negative", assign: { (value: [DRNegative]) in
            negatives = value
        }) {
            failures.append(failure)
        }
        if let failure: String = await loadResource("chemistry", assign: { (value: [DRChemistry]) in
            chemistry = value
        }) {
            failures.append(failure)
        }
        if let failure: String = await loadResource("paper", assign: { (value: [DRPaper]) in
            papers = value
        }) {
            failures.append(failure)
        }

        presentPartialFailures(failures)
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

    func loadChemistry() async {
        do { chemistry = try await fetch("chemistry") }
        catch { present(error) }
    }
    func loadNegatives() async {
            do { negatives = try await fetch("negative") }
            catch { present(error) }
        }

        func loadPapers() async {
            do { papers = try await fetch("paper") }
            catch { present(error) }
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
            } catch { present(error) }
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
        } catch { present(error) }
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
    func uploadPhotoImage(photoId: Int, imageData: Data, mimeType: String) async throws {
        _ = try await DarkroomAPIClient.uploadImage(serverURL: serverURL, apiKey: apiKey, photoId: photoId, imageData: imageData, mimeType: mimeType)
        await loadPhotos()
    }

    // MARK: - Private

    private func fetch<T: Decodable>(_ res: String) async throws -> T {
        try await DarkroomAPIClient.list(T.self, serverURL: serverURL, apiKey: apiKey, res: res)
    }
}
