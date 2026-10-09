/// L'app au premier plan sur le Mac, celle qui reçoit les raccourcis.
struct FrontmostApp: Equatable, Sendable {
    let name: String
    let bundleID: String?
}
