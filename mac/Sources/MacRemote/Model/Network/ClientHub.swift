import FlyingFox
import Foundation

/// Téléphones connectés et authentifiés.
actor ClientHub {
    private var clients: [UUID: AsyncStream<WSMessage>.Continuation] = [:]

    /// Renvoie le nombre de téléphones connectés après l'ajout.
    func add(_ id: UUID, _ continuation: AsyncStream<WSMessage>.Continuation) -> Int {
        clients[id] = continuation
        return clients.count
    }

    /// Renvoie le nouveau nombre de téléphones, ou nil si ce client n'était pas enregistré.
    func remove(_ id: UUID) -> Int? {
        guard clients.removeValue(forKey: id) != nil else { return nil }
        return clients.count
    }

    func broadcast(_ text: String) {
        for continuation in clients.values {
            continuation.yield(.text(text))
        }
    }

    func disconnectAll(with farewell: String) {
        for continuation in clients.values {
            continuation.yield(.text(farewell))
            continuation.yield(.close(.policyViolation))
            continuation.finish()
        }
        clients.removeAll()
    }
}
