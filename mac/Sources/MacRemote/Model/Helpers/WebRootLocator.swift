import Foundation

enum WebRootLocator {
    /// Cherche l'export Next.js : variable d'env (dev), ressources de l'app, puis ../web/out (swift run).
    static func locate() -> URL? {
        var candidates: [URL] = []
        if let path = ProcessInfo.processInfo.environment[Constants.Web.devDirectoryEnvironmentKey] {
            candidates.append(URL(fileURLWithPath: path))
        }
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent(Constants.Web.bundleDirectory))
        }
        candidates.append(
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(Constants.Web.devRelativePath)
        )

        return candidates.first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("index.html").path)
        }
    }
}
