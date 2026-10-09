import Foundation
import SystemConfiguration

enum NetworkInfo {

    /// Nom Bonjour du Mac (ex. « Lukas-MacBook-Pro.local »), stable même si l'IP change.
    static var bonjourHost: String? {
        guard let name = SCDynamicStoreCopyLocalHostName(nil) as String? else { return nil }
        return "\(name).local"
    }

    /// IPv4 du Mac sur le réseau local (Wi-Fi ou Ethernet), en préférant en0.
    static var localIPv4: String? {
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let first = ifaddrPointer else { return nil }
        defer { freeifaddrs(ifaddrPointer) }

        var candidates: [(interface: String, address: String)] = []
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard let addr = entry.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let flags = Int32(entry.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }

            let interface = String(cString: entry.ifa_name)
            guard interface.hasPrefix("en") else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            candidates.append((interface, String(cString: host)))
        }
        return (candidates.first { $0.interface == "en0" } ?? candidates.first)?.address
    }
}
