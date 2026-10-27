import Foundation
import Testing
@testable import PCVL

/// The updater's pure parts (versions, release parsing) and its verification steps,
/// run against the test host app. Nothing here touches the network.
@MainActor
struct UpdateTests {
    // MARK: - Versions

    @Test func parsesVersions() throws {
        #expect(try #require(AppVersion("1.2")).components == [1, 2])
        #expect(try #require(AppVersion("v1.2.3")).components == [1, 2, 3])
        #expect(AppVersion(" V10 ")?.description == "10")
        #expect(AppVersion("") == nil)
        #expect(AppVersion("1..2") == nil)
        #expect(AppVersion("1.2-beta") == nil)
        #expect(AppVersion("+1") == nil)
    }

    @Test func comparesVersions() throws {
        let v = { (string: String) in AppVersion(string)! }
        #expect(v("1.2") == v("1.2.0"), "missing components count as zero")
        #expect(v("1.10") > v("1.9"), "numeric, not text, order")
        #expect(v("2") > v("1.9.9"))
        #expect(v("1.0.1") > v("1"))
        #expect(!(v("1.2") < v("1.2.0")))
    }

    // MARK: - Releases

    private func release(tag: String, assets: [String]) throws -> GitHubRelease {
        let assetsJSON = assets.map {
            #"{"name": "\#($0)", "browser_download_url": "https://github.com/metetuy/PCVL/releases/download/\#(tag)/\#($0)"}"#
        }
        let json = """
        {"tag_name": "\(tag)", "body": "  Fixes  ", "html_url": "https://github.com/metetuy/PCVL/releases/tag/\(tag)",
         "assets": [\(assetsJSON.joined(separator: ","))]}
        """
        return try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
    }

    @Test func offersNewerSignedRelease() throws {
        let latest = try release(tag: "v1.1", assets: ["Notes.txt", "PCVL-1.1.zip", "PCVL-1.1.zip.sig"])
        let update = try #require(try latest.update(over: AppVersion("1.0")!))
        #expect(update.version == AppVersion("1.1")!)
        #expect(update.notes == "Fixes")
        #expect(update.downloadURL.lastPathComponent == "PCVL-1.1.zip")
        #expect(update.signatureURL.lastPathComponent == "PCVL-1.1.zip.sig")
    }

    @Test func ignoresSameOrOlderRelease() throws {
        let latest = try release(tag: "v1.1", assets: ["PCVL-1.1.zip", "PCVL-1.1.zip.sig"])
        #expect(try latest.update(over: AppVersion("1.1.0")!) == nil)
        #expect(try latest.update(over: AppVersion("2.0")!) == nil)
    }

    @Test func rejectsReleaseWithoutSignedZip() throws {
        let unsigned = try release(tag: "v1.1", assets: ["PCVL-1.1.zip"])
        #expect(throws: UpdateError.missingDownload(AppVersion("1.1")!)) { try unsigned.update(over: AppVersion("1.0")!) }

        let badTag = try release(tag: "latest", assets: [])
        #expect(throws: UpdateError.unreadableTag("latest")) { try badTag.update(over: AppVersion("1.0")!) }
    }

    // MARK: - Verification

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PCVLTests.Update.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private var hostApp: URL { Bundle.main.bundleURL }
    private var hostIdentifier: String { Bundle.main.bundleIdentifier! }

    @Test func acceptsTheRunningAppsSignature() throws {
        try UpdateInstaller.verifyCodeSignature(
            of: hostApp, identifier: hostIdentifier, teamIdentifier: UpdateInstaller.runningTeamIdentifier()
        )
        #expect(throws: UpdateError.invalidSignature) {
            try UpdateInstaller.verifyCodeSignature(of: hostApp, identifier: "com.example.Other", teamIdentifier: nil)
        }
    }

    @Test func rejectsAModifiedBundle() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let copy = folder.appendingPathComponent("PCVL.app")
        try FileManager.default.copyItem(at: hostApp, to: copy)
        try Data("injected".utf8).write(to: copy.appendingPathComponent("Contents/Resources/extra.txt"))

        #expect(throws: UpdateError.invalidSignature) {
            try UpdateInstaller.verifyCodeSignature(of: copy, identifier: hostIdentifier, teamIdentifier: nil)
        }
    }

    @Test func zipRoundTripKeepsTheSignature() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = folder.appendingPathComponent("PCVL.zip")

        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        zip.arguments = ["-c", "-k", "--keepParent", hostApp.path, archive.path]
        try zip.run()
        zip.waitUntilExit()
        #expect(zip.terminationStatus == 0)

        let extracted = try UpdateInstaller.extractApp(from: archive, into: folder.appendingPathComponent("extracted"))
        #expect(extracted.lastPathComponent == hostApp.lastPathComponent)
        try UpdateInstaller.verifyCodeSignature(of: extracted, identifier: hostIdentifier, teamIdentifier: nil)
    }

    // MARK: - Updater

    @Test func startsReadyToCheck() {
        let suite = "PCVLTests.Update.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let updater = Updater(defaults: defaults, currentVersion: AppVersion("1.0")!)
        #expect(updater.status == .idle)
        #expect(updater.action == .check)
        #expect(updater.checksAutomatically, "on by default")
        #expect(updater.availableRelease == nil)
    }
}
