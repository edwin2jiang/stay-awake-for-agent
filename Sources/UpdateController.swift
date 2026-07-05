import AppKit
import Foundation

struct AppUpdateInfo {
    let version: String
    let tagName: String
    let releaseURL: URL
    let assetName: String
    let downloadURL: URL
}

struct AppUpdateCheckResult {
    let latestVersion: String
    let releaseURL: URL
    let update: AppUpdateInfo?
}

final class UpdateController {
    private let latestReleaseURL = URL(string: "https://api.github.com/repos/edwin2jiang/stay-awake-for-agent/releases/latest")!

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    func checkForUpdate() async throws -> AppUpdateCheckResult {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Stay-Awake-for-Agent", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let latestVersion = Self.normalizedVersion(release.tagName)
        let releaseURL = release.htmlURL

        guard Self.compareVersions(latestVersion, currentVersion) == .orderedDescending else {
            return AppUpdateCheckResult(latestVersion: latestVersion, releaseURL: releaseURL, update: nil)
        }

        guard let asset = release.assets.first(where: { asset in
            asset.name.hasSuffix(".dmg") && asset.name.contains("macOS-universal")
        }) else {
            throw UpdateFailure("找到了新版，但没有找到可下载的 DMG。")
        }

        return AppUpdateCheckResult(
            latestVersion: latestVersion,
            releaseURL: releaseURL,
            update: AppUpdateInfo(
                version: latestVersion,
                tagName: release.tagName,
                releaseURL: releaseURL,
                assetName: asset.name,
                downloadURL: asset.browserDownloadURL
            )
        )
    }

    func download(_ update: AppUpdateInfo) async throws -> URL {
        let (temporaryURL, response) = try await URLSession.shared.download(from: update.downloadURL)
        try validateHTTPResponse(response)

        let downloadsURL = try FileManager.default.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let destinationURL = downloadsURL.appendingPathComponent(update.assetName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    func openDownloadedUpdate(at fileURL: URL) {
        NSWorkspace.shared.open(fileURL)
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateFailure("GitHub 请求失败：HTTP \(httpResponse.statusCode)")
        }
    }

    private static func normalizedVersion(_ version: String) -> String {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let rhsParts = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let maxCount = max(lhsParts.count, rhsParts.count)

        for index in 0..<maxCount {
            let lhsValue = index < lhsParts.count ? lhsParts[index] : 0
            let rhsValue = index < rhsParts.count ? rhsParts[index] : 0

            if lhsValue > rhsValue { return .orderedDescending }
            if lhsValue < rhsValue { return .orderedAscending }
        }

        return .orderedSame
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private struct UpdateFailure: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
