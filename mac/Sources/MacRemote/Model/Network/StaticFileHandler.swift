import FlyingFox
import Foundation

/// Sert l'export statique Next.js (`web/out`).
struct StaticFileHandler: HTTPHandler {
    let root: URL

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        let rootPath = root.standardizedFileURL.path
        var path = request.path
        if path.hasSuffix("/") { path += "index.html" }

        var file = root.appendingPathComponent(path).standardizedFileURL
        guard file.path.hasPrefix(rootPath + "/") else {
            return HTTPResponse(statusCode: .notFound)
        }
        if file.pathExtension.isEmpty { file.appendPathExtension("html") }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return HTTPResponse(statusCode: .notFound)
        }

        let cacheControl = path.hasPrefix("/_next/static/") ? "public, max-age=31536000, immutable" : "no-cache"
        return try HTTPResponse(
            statusCode: .ok,
            headers: [
                .contentType: Self.contentType(for: file.pathExtension),
                .cacheControl: cacheControl,
            ],
            body: HTTPBodySequence(file: file)
        )
    }

    static func contentType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": "text/html; charset=utf-8"
        case "js": "text/javascript; charset=utf-8"
        case "css": "text/css; charset=utf-8"
        case "json": "application/json"
        case "webmanifest": "application/manifest+json"
        case "txt": "text/plain; charset=utf-8"
        case "svg": "image/svg+xml"
        case "png": "image/png"
        case "ico": "image/x-icon"
        case "woff2": "font/woff2"
        default: "application/octet-stream"
        }
    }
}
