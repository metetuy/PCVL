import CryptoKit
import Foundation
import Security

// MARK: - Update Installer

/// Downloads a release's zipped app, verifies it and swaps it in for the running app.
/// The zip must carry an Ed25519 signature from the release key (scripts/release.sh
/// signs it), and the app inside must have the running app's bundle identifier and a
/// valid code signature — from the same team when the running app has one. So a
/// tampered release asset is never installed. Disk and signature work runs off the
/// main actor.
nonisolated enum UpdateInstaller {
    /// The release key's public half, from `swift scripts/update-signer.swift public-key`.
    /// Empty means updates can be found but not installed.
    static let publicKey = "EK9L+1ZPn4JN6954BA9+eRKglrMTWpIeKiRibWRJS90="

    /// Replaces the app at `appURL` with `release`. The running process keeps working
    /// from the old files until it quits; `relaunch` then opens the new version.
    @concurrent
    static func install(
        _ release: UpdateRelease,
        replacing appURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let publicKey = Data(base64Encoded: publicKey).flatMap({ try? Curve25519.Signing.PublicKey(rawRepresentation: $0) }) else {
            throw UpdateError.notConfigured
        }
        try checkLocation(of: appURL)
        guard let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier else { throw UpdateError.wrongApp }

        // On the app's volume, so the final swap is a rename rather than a copy.
        let workFolder = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: appURL, create: true
        )
        defer { try? FileManager.default.removeItem(at: workFolder) }

        let archive = workFolder.appendingPathComponent("update.zip")
        let signature = try await downloadSignature(release.signatureURL)
        try await download(release.downloadURL, to: archive, progress: progress)
        guard let archiveData = FileManager.default.contents(atPath: archive.path),
              publicKey.isValidSignature(signature, for: archiveData) else {
            throw UpdateError.invalidSignature
        }

        let newApp = try extractApp(from: archive, into: workFolder.appendingPathComponent("extracted"))
        guard let bundle = Bundle(url: newApp),
              bundle.bundleIdentifier == bundleIdentifier,
              let versionString = bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
              AppVersion(versionString) == release.version else {
            throw UpdateError.wrongApp
        }
        try verifyCodeSignature(of: newApp, identifier: bundleIdentifier, teamIdentifier: runningTeamIdentifier())

        _ = try FileManager.default.replaceItemAt(appURL, withItemAt: newApp)
    }

    /// Opens the app at `appURL` once this process has quit. The caller terminates
    /// right after; the path goes in as `$1`, so it needs no quoting.
    static func relaunch(_ appURL: URL) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$1\"",
            "sh",
            appURL.path,
        ]
        try process.run()
    }

    // MARK: - Steps

    /// A quarantined app opened from Downloads runs from a read-only random path
    /// (App Translocation); replacing that would not update the real copy.
    private static func checkLocation(of appURL: URL) throws {
        if appURL.path.contains("/AppTranslocation/") { throw UpdateError.translocated }
        let folder = appURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folder.path),
              FileManager.default.isWritableFile(atPath: appURL.path) else {
            throw UpdateError.notWritable(folder: folder.lastPathComponent)
        }
    }

    private static func downloadSignature(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard response.statusCode == 200 else { throw UpdateError.requestFailed(statusCode: response.statusCode) }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let signature = Data(base64Encoded: text) else { throw UpdateError.invalidSignature }
        return signature
    }

    private static func download(
        _ url: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        var observation: NSKeyValueObservation?
        defer { observation?.invalidate() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let task = URLSession.shared.downloadTask(with: url) { location, response, error in
                // The temporary file is deleted once this handler returns, so move it here.
                do {
                    if let error { throw error }
                    guard let location, let response = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    guard response.statusCode == 200 else {
                        throw UpdateError.requestFailed(statusCode: response.statusCode)
                    }
                    try FileManager.default.moveItem(at: location, to: destination)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            observation = task.progress.observe(\.fractionCompleted) { taskProgress, _ in
                progress(taskProgress.fractionCompleted)
            }
            task.resume()
        }
    }

    /// Unzips with `ditto` (keeps the bundle's symlinks and signature intact) and
    /// returns the one app at the top of the archive.
    static func extractApp(from archive: URL, into folder: URL) throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, folder.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.invalidArchive }

        let apps = try FileManager.default
            .contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard apps.count == 1 else { throw UpdateError.invalidArchive }
        return apps[0]
    }

    // MARK: - Code Signing

    /// The developer team that signed the running app, nil for ad hoc builds.
    static func runningTeamIdentifier() -> String? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let info = info as? [String: Any] else { return nil }
        return info[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// Checks the whole bundle (every architecture, nested code, nothing added or
    /// changed since signing) against its identifier, plus the team when given.
    static func verifyCodeSignature(of appURL: URL, identifier: String, teamIdentifier: String?) throws {
        let isPlain: (String) -> Bool = { $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") } }
        guard isPlain(identifier), teamIdentifier.map(isPlain) ?? true else { throw UpdateError.invalidSignature }

        var requirementText = "identifier \"\(identifier)\""
        if let teamIdentifier {
            requirementText += " and anchor apple generic and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
        }
        var requirement: SecRequirement?
        var staticCode: SecStaticCode?
        guard SecRequirementCreateWithString(requirementText as CFString, [], &requirement) == errSecSuccess,
              SecStaticCodeCreateWithPath(appURL as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else {
            throw UpdateError.invalidSignature
        }

        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        guard SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess else {
            throw UpdateError.invalidSignature
        }
    }
}
