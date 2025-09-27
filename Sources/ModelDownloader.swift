import Foundation
import Hub

public final class ModelDownloader {
    private let hubApi: HubApi
    private var lastLoggedPercent = -1
    public var downloadBase: URL
    /// - Parameter downloadBase: directory under which `models/<repo-id>/…` will live
    public init(downloadBase: URL) {
        self.hubApi = HubApi(downloadBase: downloadBase)
        self.downloadBase = downloadBase.appendingPathComponent("models")
    }

    /// Downloads the specified files from a Hugging Face repo
    /// into `downloadBase/models/<modelID>/…`
    public func download(
        modelID: String,
        filePatterns: [String] = ["**"],
        progress: @escaping (Double) -> Void = { _ in }
    ) async throws -> URL {
        lastLoggedPercent = -1
        let repo = Hub.Repo(id: modelID)
        let downloadedDir = try await hubApi.snapshot(
            from: repo,
            matching: filePatterns
        ) { prog in
            let percent = Int(prog.fractionCompleted * 100)
            if percent > self.lastLoggedPercent {
                progress(prog.fractionCompleted)
                self.lastLoggedPercent = percent
            }
        }
        return downloadedDir
    }

    /// Download only files under `subfolder/…` inside the HF repo.
    ///
    /// - Parameters:
    ///   - modelID: e.g. `"username/repo-id"`
    ///   - subfolder: the path *inside* the repo you care about, e.g. `"modules/moduleA"`
    ///   - progress: gives you 0.0–1.0 as it downloads
    /// - Returns: URL to `<downloadBase>/models/<modelID>/<subfolder>`
    public func downloadSubfolder(
        modelID: String,
        subfolder: String,
        progress: @escaping (Double) -> Void = { _ in }
    ) async throws -> URL {

        if subfolder == "" {
            return try await download(modelID: modelID, progress: progress)
        }

        lastLoggedPercent = -1
        let repo = Hub.Repo(id: modelID)
        // Only grab files under "modules/moduleA/**"
        let patterns = ["\(subfolder)/**"]
        let snapshotRoot = try await hubApi.snapshot(
            from: repo,
            matching: patterns
        ) { prog in
            let percent = Int(prog.fractionCompleted * 100)
            if percent > self.lastLoggedPercent {
                progress(prog.fractionCompleted)
                self.lastLoggedPercent = percent
            }
        }

        // snapshotRoot is <downloadBase>/models/<modelID>/…
        // you can return the exact subfolder URL if you like:
        return snapshotRoot.appendingPathComponent(subfolder)
    }
}