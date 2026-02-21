//
//  WalletRecoveryViewModel.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 1/31/24.
//

import BitcoinDevKit
import Foundation
import SwiftUI

@Observable
@MainActor
class WalletRecoveryViewModel {
    let bdkClient: BDKClient

    var backupInfo: BackupInfo?
    var publicDescriptor: Descriptor?
    var publicChangeDescriptor: Descriptor?
    var walletRecoveryViewError: AppError?
    var showingWalletRecoveryViewErrorAlert: Bool

    init(
        bdkClient: BDKClient = .live,
        backupInfo: BackupInfo? = nil,
        walletRecoveryViewError: AppError? = nil,
        showingWalletRecoveryViewErrorAlert: Bool = false
    ) {
        self.bdkClient = bdkClient
        self.backupInfo = backupInfo
        self.walletRecoveryViewError = walletRecoveryViewError
        self.showingWalletRecoveryViewErrorAlert = showingWalletRecoveryViewErrorAlert
    }

    func getNetwork() -> Network {
        let savedNetwork = bdkClient.getNetwork()
        let clientType = bdkClient.getClientType()
        return clientType == .kyoto ? .signet : savedNetwork
    }

    func getBackupInfo(network: Network) {
        do {
            let backupInfo = try bdkClient.getBackupInfo()
            let cleanChangeDescriptor = backupInfo.changeDescriptor.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let externalPublicDescriptor = try Descriptor.init(
                descriptor: backupInfo.descriptor,
                network: network
            )
            self.publicDescriptor = externalPublicDescriptor

            if !cleanChangeDescriptor.isEmpty {
                let internalPublicDescriptor = try Descriptor.init(
                    descriptor: cleanChangeDescriptor,
                    network: network
                )
                self.publicChangeDescriptor = internalPublicDescriptor
            } else {
                self.publicChangeDescriptor = nil
            }

            self.backupInfo = backupInfo
        } catch {
            self.walletRecoveryViewError = .generic(message: error.localizedDescription)
            self.showingWalletRecoveryViewErrorAlert = true
        }
    }

    var descriptorsExportText: String? {
        guard let backupInfo, let publicDescriptor else { return nil }
        let cleanChangeDescriptor = backupInfo.changeDescriptor.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let internalDescriptorsSection: String = {
            guard
                let publicChangeDescriptor,
                !cleanChangeDescriptor.isEmpty
            else {
                return ""
            }

            return """

                Internal Private: \(cleanChangeDescriptor)

                Internal Public: \(publicChangeDescriptor)
                """
        }()

        return """
            External Private: \(backupInfo.descriptor)

            External Public: \(publicDescriptor)\(internalDescriptorsSection)
            """
    }

}
