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

        let wifClient = self.wifClient
        let wif = self.wif
        let network = self.network
        let esploraURL = self.esploraURL

        Task {
            defer { isDiscovering = false }
            do {
                let results = try await runBlocking {
                    try wifClient.discoverWif(wif, network, esploraURL)
                }
                discoveryResults = results
                selectedType =
                    results.first(where: { $0.isSupported && $0.hasFunds })?.type
                    ?? results.first(where: { $0.isSupported })?.type
            } catch {
                onboardingViewError = .generic(message: error.localizedDescription)
                showingErrorAlert = true
            }
        }
    }

    func importSelectedType() {
        guard let selectedType else { return }
        guard !isProcessing else { return }
        isProcessing = true

        let wifClient = self.wifClient
        let wif = self.wif
        let network = self.network
        let esploraURL = self.esploraURL
        let clientType = self.clientType

        Task {
            defer { isProcessing = false }
            do {
                try await runBlocking {
                    try wifClient.createWalletFromWif(
                        wif,
                        selectedType,
                        network,
                        esploraURL,
                        clientType
                    )
                }
                isOnboarding = false
                NotificationCenter.default.post(name: .walletCreated, object: nil)
            } catch {
                onboardingViewError = .generic(message: error.localizedDescription)
                showingErrorAlert = true
            }
        }
    }

    func fetchFees() {
        let feeClient = self.feeClient
        Task {
            do {
                recommendedFees = try await feeClient.fetchFees()
            } catch {
                onboardingViewError = .generic(message: error.localizedDescription)
                showingErrorAlert = true
            }
        }
    }

    func sweepSelectedTypeToNewWallet() {
        guard let selectedType else { return }
        guard !isProcessing else { return }
        isProcessing = true

        let wifClient = self.wifClient
        let wif = self.wif
        let network = self.network
        let esploraURL = self.esploraURL
        let clientType = self.clientType
        let destinationAddressType = self.destinationAddressType
        let feeRate = UInt64(recommendedFees?.hourFee ?? 2)

        Task {
            defer { isProcessing = false }
            do {
                _ = try await runBlocking {
                    try wifClient.sweepWifToNewWallet(
                        wif,
                        selectedType,
                        network,
                        esploraURL,
                        clientType,
                        destinationAddressType,
                        feeRate
                    )
                }
                isOnboarding = false
                NotificationCenter.default.post(name: .walletCreated, object: nil)
            } catch {
                onboardingViewError = .generic(message: error.localizedDescription)
                showingErrorAlert = true
            }
        }
    }

    private func runBlocking<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
