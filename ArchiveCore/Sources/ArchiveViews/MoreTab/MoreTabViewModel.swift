//
//  MoreTabViewModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable force_unwrapping

import Combine
import SwiftUI

final public class MoreTabViewModel: ObservableObject, Log {

    let qualities: [String]  = ["100% - Lossless 🤯", "75% - Good 👌 (Default)", "50% - Normal 👍", "25% - Small 💾"]
    let storageTypes: [String]  = StorageType.allCases.map(\.title).map { "\($0)" }
    @Published var error: Error?
    @Published var selectedQualityIndex = UserDefaults.PDFQuality.toIndex(UserDefaults.appGroup.pdfQuality) ?? UserDefaults.PDFQuality.defaultQualityIndex
    @Published var selectedArchiveType = StorageType.getCurrent()
    @Published var showArchiveTypeSelection = false
    @Published var subscriptionStatus: LocalizedStringKey = "Inactive ❌"

    private let iapService: IAPServiceAPI
    private let archiveStore: ArchiveStoreAPI
    private var disposables = Set<AnyCancellable>()

    public init(iapService: IAPServiceAPI, archiveStore: ArchiveStoreAPI) {
        self.iapService = iapService
        self.archiveStore = archiveStore
        $selectedQualityIndex
            .sink { selectedQuality in
                UserDefaults.appGroup.pdfQuality = UserDefaults.PDFQuality.allCases[selectedQuality]
            }
            .store(in: &disposables)

        $selectedArchiveType
            .dropFirst()
            .sink { selectedArchiveType in

                let type: PathManager.ArchivePathType
                switch selectedArchiveType {
                    case .iCloudDrive:
                        type = .iCloudDrive
                    case .appContainer:
                        type = .appContainer
                    #if os(macOS)
                    case .local:
                        // TODO: fix this
                        type = .local(URL(string: "")!)
                    #endif
                }

                do {
                    let archiveUrl = try PathManager.shared.getArchiveUrl()
                    let untaggedUrl = try PathManager.shared.getUntaggedUrl()

                    try PathManager.shared.setArchiveUrl(with: type)

                    self.showArchiveTypeSelection = false
                    DispatchQueue.global(qos: .userInitiated).async {
                        archiveStore.update(archiveFolder: archiveUrl, untaggedFolders: [untaggedUrl])
                    }
                } catch {
                    self.error = error
                }
            }
            .store(in: &disposables)

        iapService.appUsagePermittedPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { appUsagePermitted in
                self.subscriptionStatus = appUsagePermitted ? "Active ✅" : "Inactive ❌"
            }
            .store(in: &disposables)
    }

    func showIntro() {
        log.info("More table view show: intro")
        NotificationCenter.default.post(name: .introChanges, object: true)
    }

    func showPermissions() {
        log.info("More table view show: app permissions")
        #if os(macOS)
        // TODO: handle settings
        #else
        guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString) else { fatalError("Could not find settings url!") }
        open(settingsAppURL)
        #endif
    }

    func resetApp() {
        log.info("More table view show: reset app")
        // remove all temporary files
        try? FileManager.default.removeItem(at: PathConstants.tempImageURL)

        // remove all user defaults
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.appGroup.removePersistentDomain(forName: bundleIdentifier)
        } else {
            log.error("Bundle Identifier not found.")
        }

        DispatchQueue.main.async {
            self.error = AlertDataModel.createAndPost(title: "Reset App", message: "Please restart the app to complete the reset.", primaryButtonTitle: "OK")
        }
    }

    var manageSubscriptionUrl: URL {
        URL(string: "https://apps.apple.com/account/subscriptions")!
    }

    var macOSAppUrl: URL {
        URL(string: "https://macos.pdf-archiver.io")!
    }
}
