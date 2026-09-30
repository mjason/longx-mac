import XCTest
@testable import LongX

final class UpdateTests: XCTestCase {
    func testVersionOrdering() {
        XCTAssertTrue(ReleaseVersion("v0.10.0")! > ReleaseVersion("0.9.9")!)
        XCTAssertEqual(ReleaseVersion("1.0"), ReleaseVersion("1.0.0"))
        XCTAssertTrue(ReleaseVersion("1.0.0")! < ReleaseVersion("1.0.1")!)
        for invalid in ["", "v", "1..2", "1.0-beta", "1.2.3.4", "-1", "１.２"] {
            XCTAssertNil(ReleaseVersion(invalid), invalid)
        }
    }
    func testReleaseRequiresOfficialDownload() {
        func release(url: String = "https://github.com/mjason/longx-mac/releases/tag/v1.0.0", draft: Bool = false, prerelease: Bool = false, asset: String = "LongX-1.0.0-macOS-universal.zip") -> GitHubRelease {
            GitHubRelease(tag_name: "v1.0.0", html_url: URL(string: url)!, draft: draft, prerelease: prerelease, assets: [.init(name: asset)])
        }
        XCTAssertNotNil(release().downloadableURL)
        XCTAssertNil(release(draft: true).downloadableURL)
        XCTAssertNil(release(prerelease: true).downloadableURL)
        XCTAssertNil(release(asset: "source.zip").downloadableURL)
        XCTAssertNil(release(url: "https://github.com.evil.example/mjason/longx-mac/releases/tag/v1.0.0").downloadableURL)
        XCTAssertNil(release(url: "https://github.com/other/project/releases/tag/v1.0.0").downloadableURL)
        XCTAssertNil(release(url: "http://github.com/mjason/longx-mac/releases/tag/v1.0.0").downloadableURL)
    }
}
