import Foundation

// MARK: - App Version

/// A dotted numeric version such as "1.2" or "v1.2.3". Missing components count as
/// zero, so 1.2 and 1.2.0 are the same version.
nonisolated struct AppVersion: Comparable, CustomStringConvertible {
    let components: [Int]

    init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespaces)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(parts.count) else { return nil }

        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ ("0"..."9").contains($0) }), let number = Int(part) else { return nil }
            numbers.append(number)
        }
        components = numbers
    }

    /// The running app's `CFBundleShortVersionString` (MARKETING_VERSION).
    static var current: AppVersion {
        let string = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return AppVersion(string) ?? AppVersion("0")!
    }

    var description: String {
        components.map(String.init).joined(separator: ".")
    }

    private func padded(to count: Int) -> [Int] {
        components + Array(repeating: 0, count: max(0, count - components.count))
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        return lhs.padded(to: count) == rhs.padded(to: count)
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        return lhs.padded(to: count).lexicographicallyPrecedes(rhs.padded(to: count))
    }
}

// MARK: - Update Release

/// A newer release that can be installed: its version, notes, the zipped app and the
/// zip's Ed25519 signature.
nonisolated struct UpdateRelease: Equatable {
    let version: AppVersion
    let notes: String
    let pageURL: URL
    let downloadURL: URL
    let signatureURL: URL
}

// MARK: - GitHub Release

/// The fields of GitHub's `releases/latest` response the updater reads.
nonisolated struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let body: String?
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case htmlURL = "html_url"
        case assets
    }

    /// The update this release offers over `current`: nil when it is not newer. The
    /// tag names the version ("v1.2"), the first .zip asset holds the app and the
    /// asset named like it plus ".sig" its signature (scripts/release.sh uploads both).
    func update(over current: AppVersion) throws -> UpdateRelease? {
        guard let version = AppVersion(tagName) else { throw UpdateError.unreadableTag(tagName) }
        guard version > current else { return nil }
        guard let archive = assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }),
              let signature = assets.first(where: { $0.name == archive.name + ".sig" }) else {
            throw UpdateError.missingDownload(version)
        }
        return UpdateRelease(
            version: version,
            notes: body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            pageURL: htmlURL,
            downloadURL: archive.browserDownloadURL,
            signatureURL: signature.browserDownloadURL
        )
    }
}

// MARK: - Errors

nonisolated enum UpdateError: LocalizedError, Equatable {
    case requestFailed(statusCode: Int)
    case unreadableTag(String)
    case missingDownload(AppVersion)
    case translocated
    case notWritable(folder: String)
    case invalidArchive
    case wrongApp
    case notConfigured
    case invalidSignature

    var errorDescription: String? {
        switch self {
        case .requestFailed(let statusCode):
            return statusCode == 403
                ? "GitHub is limiting requests right now. Try again later."
                : "GitHub responded with an error (\(statusCode))."
        case .unreadableTag(let tag):
            return "The latest release's tag “\(tag)” isn't a version number."
        case .missingDownload(let version):
            return "Release \(version) has no signed .zip download yet."
        case .translocated:
            return "Move PCVL to your Applications folder and open it from there, then try again."
        case .notWritable(let folder):
            return "PCVL can't replace itself in “\(folder)”."
        case .invalidArchive:
            return "The download doesn't contain PCVL."
        case .wrongApp:
            return "The download is a different app or version than the release."
        case .notConfigured:
            return "This build of PCVL has no update key, so updates can't be verified."
        case .invalidSignature:
            return "The update's signature doesn't match. It was not installed."
        }
    }
}
