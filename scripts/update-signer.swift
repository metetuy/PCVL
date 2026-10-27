// Signs PCVL update archives with an Ed25519 key kept in the login Keychain, or
// in PCVL_UPDATE_SIGNING_KEY on CI (the GitHub secret UPDATE_SIGNING_KEY). The app
// embeds the public key (UpdateInstaller.publicKey) and refuses any download
// whose signature doesn't verify.
//
//   swift scripts/update-signer.swift generate-keys   creates the key once, prints the public key
//   swift scripts/update-signer.swift public-key      prints the public key again
//   swift scripts/update-signer.swift sign <file>     prints the file's signature (base64)
//
// Copying the private key for the GitHub secret:
//   security find-generic-password -s "PCVL Update Signing" -a ed25519 -w | pbcopy

import CryptoKit
import Foundation
import Security

let service = "PCVL Update Signing"
let account = "ed25519"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func storedPrivateKey() -> Curve25519.Signing.PrivateKey? {
    if let text = ProcessInfo.processInfo.environment["PCVL_UPDATE_SIGNING_KEY"], !text.isEmpty {
        guard let raw = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
            fail("PCVL_UPDATE_SIGNING_KEY isn't a base64 Ed25519 private key.")
        }
        return key
    }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecReturnData as String: true,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data,
          let raw = Data(base64Encoded: data) else { return nil }
    return try? Curve25519.Signing.PrivateKey(rawRepresentation: raw)
}

func requirePrivateKey() -> Curve25519.Signing.PrivateKey {
    guard let key = storedPrivateKey() else {
        fail("No signing key in the Keychain. Run: swift scripts/update-signer.swift generate-keys")
    }
    return key
}

let arguments = CommandLine.arguments.dropFirst()
switch arguments.first {
case "generate-keys":
    if let existing = storedPrivateKey() {
        print("A key already exists. Public key:")
        print(existing.publicKey.rawRepresentation.base64EncodedString())
        exit(0)
    }
    let key = Curve25519.Signing.PrivateKey()
    let item: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecAttrLabel as String: service,
        kSecValueData as String: Data(key.rawRepresentation.base64EncodedString().utf8),
    ]
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { fail("Couldn't save the key to the Keychain (\(status)).") }
    print("Saved the private key to the login Keychain as “\(service)”. Back it up: without it,")
    print("installed copies can't be updated. Public key (UpdateInstaller.publicKey):")
    print(key.publicKey.rawRepresentation.base64EncodedString())

case "public-key":
    print(requirePrivateKey().publicKey.rawRepresentation.base64EncodedString())

case "sign":
    guard let path = arguments.dropFirst().first else { fail("Usage: sign <file>") }
    guard let data = FileManager.default.contents(atPath: path) else { fail("Can't read \(path)") }
    let signature = try requirePrivateKey().signature(for: data)
    print(signature.base64EncodedString())

default:
    fail("Usage: swift scripts/update-signer.swift generate-keys | public-key | sign <file>")
}
