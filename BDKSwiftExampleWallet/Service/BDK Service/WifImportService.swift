//
//  WifImportService.swift
//  BDKSwiftExampleWallet
//

import BitcoinDevKit
import Foundation

enum WifDescriptorType: String, CaseIterable, Identifiable {
    case wpkh
    case tr

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wpkh: return "BIP84 (SegWit)"
        case .tr: return "BIP86 (Taproot)"
        }
    }

    func descriptorString(wif: String) -> String {
        switch self {
        case .wpkh:
            return "wpkh(\(wif))"
        case .tr:
            return "tr(\(wif))"
        }
    }
}

struct WifDiscoveryResult: Equatable, Identifiable {
    let type: WifDescriptorType
    let utxoCount: Int
    let txCount: Int
    let balanceSats: UInt64
    let isSupported: Bool

    var id: String { type.id }
    var hasFunds: Bool { balanceSats > 0 || utxoCount > 0 || txCount > 0 }
}

struct WifSweepResult: Equatable {
    let destinationAddress: String
    let txid: String
    let sweptSats: UInt64
}

struct WifSweepPreparation {
    let sourceWallet: Wallet
    let balanceSats: UInt64
}

struct WifImportService {
    func isLikelyWif(_ input: String) -> Bool {
        let value = normalizedWif(input)
        guard value.count == 51 || value.count == 52 else { return false }
        guard value.range(of: "[\\s:()/]", options: .regularExpression) == nil else {
            return false
        }
        guard let first = value.first, "59KLc".contains(first) else { return false }
        return (try? DescriptorSecretKey.fromString(privateKey: value)) != nil
    }

    func sweepAddressType(for type: WifDescriptorType) -> AddressType {
        switch type {
        case .tr:
            return .bip86
        case .wpkh:
            return .bip84
        }
    }

    func descriptorForImportedWallet(
        wif: String,
        type: WifDescriptorType,
        network: Network
    ) throws -> Descriptor {
        let validatedWif = try validateWif(wif, for: network)
        try validateWifForDescriptorType(validatedWif)
        return try Descriptor(
            descriptor: type.descriptorString(wif: validatedWif),
            network: network
        )
    }

    func discoverWif(
        wif: String,
        network: Network,
        esploraURL: String
    ) throws -> [WifDiscoveryResult] {
        let validatedWif = try validateWif(wif, for: network)

        return WifDescriptorType.allCases.map { type in
            do {
                try validateWifForDescriptorType(validatedWif)
                let wallet = try inMemoryWallet(
                    wif: validatedWif,
                    type: type,
                    network: network
                )
                try syncWallet(wallet, esploraURL: esploraURL)
                return WifDiscoveryResult(
                    type: type,
                    utxoCount: wallet.listUnspent().count,
                    txCount: wallet.transactions().count,
                    balanceSats: wallet.balance().total.toSat(),
                    isSupported: true
                )
            } catch {
                return WifDiscoveryResult(
                    type: type,
                    utxoCount: 0,
                    txCount: 0,
                    balanceSats: 0,
                    isSupported: false
                )
            }
        }
    }

    func prepareSweep(
        wif: String,
        type: WifDescriptorType,
        network: Network,
        esploraURL: String
    ) throws -> WifSweepPreparation {
        let validatedWif = try validateWif(wif, for: network)
        try validateWifForDescriptorType(validatedWif)

        let sourceWallet = try inMemoryWallet(
            wif: validatedWif,
            type: type,
            network: network
        )
        try syncWallet(sourceWallet, esploraURL: esploraURL)

        let sweepBalance = sourceWallet.balance().total.toSat()
        guard sweepBalance > 0 else {
            throw WalletError.noFundsFoundForSelectedWifType
        }

        return WifSweepPreparation(
            sourceWallet: sourceWallet,
            balanceSats: sweepBalance
        )
    }

    func sweepSourceWallet(
        _ sourceWallet: Wallet,
        destinationAddress: String,
        network: Network,
        esploraURL: String,
        feeRate: UInt64
    ) throws -> String {
        let script = try Address(address: destinationAddress, network: network)
            .scriptPubkey()
        let psbt = try TxBuilder()
            .drainWallet()
            .drainTo(script: script)
            .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate))
            .finish(wallet: sourceWallet)

        let isSigned = try sourceWallet.sign(psbt: psbt)
        if !isSigned {
            throw WalletError.notSigned
        }

        let _ = try sourceWallet.finalizePsbt(psbt: psbt)
        let transaction = try psbt.extractTx()
        let txid = transaction.computeTxid().description
        let esplora = EsploraClient(url: esploraURL)
        try esplora.broadcast(transaction: transaction)
        return txid
    }

    private func normalizedWif(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isTestNetworkWif(_ wif: String) -> Bool {
        guard let first = wif.first else { return false }
        return first == "9" || first == "c"
    }

    private func isCompressedWif(_ wif: String) -> Bool {
        guard let first = wif.first else { return false }
        return first == "K" || first == "L" || first == "c"
    }

    private func validateWifForDescriptorType(_ wif: String) throws {
        guard isCompressedWif(wif) else {
            throw WalletError.uncompressedWifNotSupportedForSelectedType
        }
    }

    private func validateWif(_ input: String, for network: Network) throws -> String {
        let wif = normalizedWif(input)
        guard isLikelyWif(wif) else {
            throw WalletError.invalidWif
        }
        if network != .bitcoin && !isTestNetworkWif(wif) {
            throw WalletError.unsupportedWifForSelectedNetwork
        }
        if network == .bitcoin && isTestNetworkWif(wif) {
            throw WalletError.unsupportedWifForSelectedNetwork
        }
        return wif
    }

    private func inMemoryWallet(
        wif: String,
        type: WifDescriptorType,
        network: Network
    ) throws -> Wallet {
        let descriptor = try Descriptor(
            descriptor: type.descriptorString(wif: wif),
            network: network
        )
        let tempPersister = try Persister.newInMemory()
        return try Wallet.createSingle(
            descriptor: descriptor,
            network: network,
            persister: tempPersister
        )
    }

    private func syncWallet(_ wallet: Wallet, esploraURL: String) throws {
        let client = EsploraClient(url: esploraURL)
        let fullScanRequest = try wallet.startFullScan().build()
        let update = try client.fullScan(
            request: fullScanRequest,
            stopGap: UInt64(20),
            parallelRequests: UInt64(5)
        )
        let _ = try wallet.applyUpdate(update: update)
    }
}
