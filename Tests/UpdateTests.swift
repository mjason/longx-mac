import XCTest
import Sparkle
@testable import LongX

final class UpdateTests: XCTestCase {
    @MainActor func testSparkleUsesSignedFeedAndSupportsAutomaticInstallation() {
        let checker = UpdateChecker(startingUpdater: false)
        let info = Bundle.main.infoDictionary!
        XCTAssertEqual(info["SUFeedURL"] as? String, "https://github.com/mjason/longx-mac/releases/latest/download/appcast.xml")
        XCTAssertEqual(Data(base64Encoded: info["SUPublicEDKey"] as! String)?.count, 32)
        for key in ["SUEnableInstallerLauncherService", "SUEnableAutomaticChecks", "SUAutomaticallyUpdate", "SUVerifyUpdateBeforeExtraction", "SURequireSignedFeed"] {
            XCTAssertEqual(info[key] as? Bool, true, key)
        }
        XCTAssertNotNil(checker.controller.updater)
    }
}
