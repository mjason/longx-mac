import Combine
import Sparkle

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    let controller: SPUStandardUpdaterController

    init(startingUpdater: Bool = true) {
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyDownloadsUpdates)
            .assign(to: &$automaticallyDownloadsUpdates)
        // Unit tests never run the network scheduler or display update windows.
        if startingUpdater && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            controller.startUpdater()
        }
    }

    func setAutomaticUpdates(_ enabled: Bool) {
        if enabled { controller.updater.automaticallyChecksForUpdates = true }
        controller.updater.automaticallyDownloadsUpdates = enabled
    }

    func check() { controller.checkForUpdates(nil) }
}
