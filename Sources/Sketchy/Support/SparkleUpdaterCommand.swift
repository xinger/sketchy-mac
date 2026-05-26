import Combine
import Sparkle
import SwiftUI

final class SparkleUpdater {
    private let updaterController: SPUStandardUpdaterController?

    var updater: SPUUpdater? {
        updaterController?.updater
    }

    init(bundle: Bundle = .main) {
        guard
            Self.infoString("SUFeedURL", in: bundle) != nil,
            Self.infoString("SUPublicEDKey", in: bundle) != nil
        else {
            updaterController = nil
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    private static func infoString(_ key: String, in bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            return nil
        }

        return value
    }
}

final class CheckForUpdatesViewModel: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    private var cancellable: AnyCancellable?

    init(updater: SPUUpdater) {
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] canCheckForUpdates in
                self?.canCheckForUpdates = canCheckForUpdates
            }
    }
}

struct CheckForUpdatesCommand: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel

    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates...", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}
