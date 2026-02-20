//
//  BDKSwiftExampleWalletError.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 6/4/23.
//

import Foundation

enum WalletError: Error {
    case blockchainConfigNotFound
    case dbNotFound
    case notSigned
    case walletNotFound
    case fullScanUnsupported
    case backendNotImplemented
    case invalidWif
    case unsupportedWifForSelectedNetwork
    case uncompressedWifNotSupportedForSelectedType
    case noFundsFoundForSelectedWifType
    case walletAlreadyExistsForSweep
}

extension WalletError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .blockchainConfigNotFound:
            return "Blockchain configuration not found"
        case .dbNotFound:
            return "Database not found"
        case .notSigned:
            return "Transaction not signed"
        case .walletNotFound:
            return "Wallet not found"
        case .fullScanUnsupported:
            return "Full scan is not supported by the selected blockchain client"
        case .backendNotImplemented:
            return "The selected blockchain backend is not yet implemented"
        case .invalidWif:
            return "Invalid private key (WIF)"
        case .unsupportedWifForSelectedNetwork:
            return "This wallet only supports testnet/signet/regtest WIF keys"
        case .uncompressedWifNotSupportedForSelectedType:
            return
                "BIP84/BIP86 require a compressed WIF (typically starts with c on test networks)"
        case .noFundsFoundForSelectedWifType:
            return "No funds found for the selected script type"
        case .walletAlreadyExistsForSweep:
            return
                "Cannot sweep to a new wallet while an existing wallet is present. Delete it first."
        }
    }
}
