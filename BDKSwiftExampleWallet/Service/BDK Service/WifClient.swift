//
//  WifClient.swift
//  BDKSwiftExampleWallet
//

import BitcoinDevKit
import Foundation

struct WifClient {
    let isLikelyWif: (String) -> Bool
    let discoverWif: (String, Network, String) async throws -> [WifDiscoveryResult]
    let createWalletFromWif:
        (String, WifDescriptorType, Network, String, BlockchainClientType) async throws -> Void
    let sweepWifToNewWallet:
        (
            String,
            WifDescriptorType,
            Network,
            String,
            BlockchainClientType,
            AddressType,
            UInt64
        ) async throws -> WifSweepResult
}

extension WifClient {
    static let live = Self(
        isLikelyWif: { candidate in
            BDKService.shared.isLikelyWif(candidate)
        },
        discoverWif: { wif, network, esploraURL in
            try await Self.runBlocking {
                try BDKService.shared.discoverWif(
                    wif: wif,
                    network: network,
                    esploraURL: esploraURL
                )
            }
        },
        createWalletFromWif: { wif, type, network, esploraURL, clientType in
            try await Self.runBlocking {
                try BDKService.shared.createWallet(
                    wif: wif,
                    type: type,
                    network: network,
                    esploraURL: esploraURL,
                    clientType: clientType
                )
            }
        },
        sweepWifToNewWallet: { wif, type, network, esploraURL, clientType, destinationAddressType, feeRate in
            try await Self.runBlocking {
                try BDKService.shared.sweepWifToNewWallet(
                    wif: wif,
                    type: type,
                    network: network,
                    esploraURL: esploraURL,
                    clientType: clientType,
                    destinationAddressType: destinationAddressType,
                    feeRate: feeRate
                )
            }
        }
    )
}

#if DEBUG
    extension WifClient {
        static let mock = Self(
            isLikelyWif: { candidate in
                let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                guard value.count == 51 || value.count == 52 else { return false }
                guard value.range(of: "[\\s:()/]", options: .regularExpression) == nil else {
                    return false
                }
                guard let first = value.first, "59KLc".contains(first) else { return false }
                return (try? DescriptorSecretKey.fromString(privateKey: value)) != nil
            },
            discoverWif: { _, _, _ in [] },
            createWalletFromWif: { _, _, _, _, _ in },
            sweepWifToNewWallet: { _, _, _, _, _, _, _ in
                WifSweepResult(
                    destinationAddress: "tb1pd8jmenqpe7rz2mavfdx7uc8pj7vskxv4rl6avxlqsw2u8u7d4gfs97durt",
                    txid: "mock-txid",
                    sweptSats: UInt64(0)
                )
            }
        )
    }
#endif

private extension WifClient {
    static func runBlocking<T>(_ work: @escaping () throws -> T) async throws -> T {
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
