//
//  WifImportViewModel.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 8/6/23.
//

import BitcoinDevKit
import Foundation
import SwiftUI

@MainActor
class WifImportViewModel: ObservableObject {
    let wifClient: WifClient
    let feeClient: FeeClient
    let wif: String
    let network: Network
    let esploraURL: String
    let clientType: BlockchainClientType
    let destinationAddressType: AddressType

    @AppStorage("isOnboarding") var isOnboarding: Bool?
    @Published var discoveryResults: [WifDiscoveryResult] = []
    @Published var selectedType: WifDescriptorType?
    @Published var isDiscovering = false
    @Published var isProcessing = false
    @Published var recommendedFees: RecommendedFees?
    @Published var onboardingViewError: AppError?
    @Published var showingErrorAlert = false
    private var discoveryTask: Task<Void, Never>?

    var selectedResult: WifDiscoveryResult? {
        guard let selectedType else { return nil }
        return discoveryResults.first(where: { $0.type == selectedType })
    }

    var canSweepSelectedType: Bool {
        selectedResult?.hasFunds == true
    }

    init(
        wifClient: WifClient = .live,
        feeClient: FeeClient = .live,
        wif: String,
        network: Network,
        esploraURL: String,
        clientType: BlockchainClientType,
        destinationAddressType: AddressType
    ) {
        self.wifClient = wifClient
        self.feeClient = feeClient
        self.wif = wif
        self.network = network
        self.esploraURL = esploraURL
        self.clientType = clientType
        self.destinationAddressType = destinationAddressType
    }

    func discover() {
        guard !isDiscovering else { return }
        isDiscovering = true
        discoveryTask = Task {
            defer {
                isDiscovering = false
                discoveryTask = nil
            }
            do {
                let results = try await wifClient.discoverWif(wif, network, esploraURL)
                guard !Task.isCancelled else { return }
                discoveryResults = results
                selectedType =
                    results.first(where: { $0.isSupported && $0.hasFunds })?.type
                    ?? results.first(where: { $0.isSupported })?.type
            } catch is CancellationError {
            } catch {
                presentError(error)
            }
        }
    }

    func cancelDiscovery() {
        discoveryTask?.cancel()
        discoveryTask = nil
        isDiscovering = false
    }

    func importSelectedType() {
        guard let selectedType else { return }
        guard !isProcessing else { return }
        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                try await wifClient.createWalletFromWif(
                    wif,
                    selectedType,
                    network,
                    esploraURL,
                    clientType
                )
                isOnboarding = false
                NotificationCenter.default.post(name: .walletCreated, object: nil)
            } catch {
                presentError(error)
            }
        }
    }

    func fetchFees() {
        let feeClient = self.feeClient
        Task {
            do {
                recommendedFees = try await feeClient.fetchFees()
            } catch {
                presentError(error)
            }
        }
    }

    func sweepSelectedTypeToNewWallet() {
        guard let selectedType else { return }
        guard !isProcessing else { return }
        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                _ = try await wifClient.sweepWifToNewWallet(
                    wif,
                    selectedType,
                    network,
                    esploraURL,
                    clientType,
                    destinationAddressType,
                    UInt64(recommendedFees?.hourFee ?? 2)
                )
                isOnboarding = false
                NotificationCenter.default.post(name: .walletCreated, object: nil)
            } catch {
                presentError(error)
            }
        }
    }

    private func presentError(_ error: Error) {
        onboardingViewError = .generic(message: error.localizedDescription)
        showingErrorAlert = true
    }
}
