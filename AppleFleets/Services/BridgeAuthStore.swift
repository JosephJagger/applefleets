// Pairing design adapted from rakshith48/healthkit-cli (MIT).
import Foundation
import Security

private let bridgeKeychainService = "com.local.applefleets.bridge"
private let bridgeKeychainAccount = "paired-macs"

@MainActor
final class BridgeAuthStore: ObservableObject {
    struct PairedMac: Codable, Identifiable, Equatable {
        let id: String
        let name: String
        let host: String
        let pairedAt: Date
    }

    @Published private(set) var pairingCode = ""
    @Published private(set) var pairedMacs: [PairedMac] = []

    init() {
        pairedMacs = Self.load(service: bridgeKeychainService, account: bridgeKeychainAccount)
        refreshCode()
    }

    func consume(code: String, macName: String, host: String) -> String? {
        guard code == pairingCode else { return nil }
        let token = UUID().uuidString + UUID().uuidString
        pairedMacs.append(PairedMac(id: token, name: macName, host: host, pairedAt: Date()))
        save()
        refreshCode()
        return token
    }

    nonisolated func validates(_ token: String) -> Bool {
        Self.load(service: bridgeKeychainService, account: bridgeKeychainAccount).contains { $0.id == token }
    }

    func revoke(_ mac: PairedMac) {
        pairedMacs.removeAll { $0.id == mac.id }
        save()
    }

    func destinations() -> [PairedMac] { pairedMacs }

    private func refreshCode() {
        pairingCode = String(format: "%06d", Int.random(in: 0...999_999))
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(pairedMacs) else { return }
        let key: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: bridgeKeychainService,
            kSecAttrAccount as String: bridgeKeychainAccount
        ]
        SecItemDelete(key as CFDictionary)
        var item = key
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private nonisolated static func load(service: String, account: String) -> [PairedMac] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return [] }
        return (try? JSONDecoder().decode([PairedMac].self, from: data)) ?? []
    }
}
