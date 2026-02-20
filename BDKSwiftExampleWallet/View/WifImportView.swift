//
//  WifImportView.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 5/23/23.
//

import BitcoinUI
import SwiftUI

struct WifImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: WifImportViewModel

    init(viewModel: WifImportViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Private key detected")
                    .font(.headline)

                Text("Pick the script type you want to import or sweep.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ZStack {
                    List(viewModel.discoveryResults) { result in
                        Button {
                            if result.isSupported {
                                viewModel.selectedType = result.type
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.type.displayName)
                                        .fontWeight(.medium)
                                    if result.isSupported {
                                        Text(
                                            "\(result.balanceSats) sats • \(result.utxoCount) UTXOs • \(result.txCount) txs"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    } else {
                                        Text("Not supported for this key")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if viewModel.selectedType == result.type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.primary)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(!result.isSupported)
                    }
                    .listStyle(.plain)
                    .opacity(viewModel.isDiscovering ? 0.3 : 1)
                    .allowsHitTesting(!viewModel.isDiscovering)

                    if viewModel.isDiscovering {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Loading UTXOs...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        viewModel.importSelectedType()
                    } label: {
                        Text("Import Selected Type")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(
                        BitcoinFilled(
                            tintColor: .primary,
                            textColor: Color(uiColor: .systemBackground),
                            isCapsule: true
                        )
                    )
                    .disabled(
                        viewModel.selectedType == nil
                            || viewModel.isDiscovering
                            || viewModel.isProcessing
                    )

                    Button {
                        viewModel.sweepSelectedTypeToNewWallet()
                    } label: {
                        if let fees = viewModel.recommendedFees {
                            Text("Sweep To New Wallet (\(fees.hourFee) sat/vB)")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        } else {
                            Text("Sweep To New Wallet")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                    .buttonStyle(
                        BitcoinFilled(
                            tintColor: .secondary,
                            textColor: Color(uiColor: .systemBackground),
                            isCapsule: true
                        )
                    )
                    .disabled(
                        viewModel.selectedType == nil
                            || viewModel.isDiscovering
                            || viewModel.isProcessing
                            || !viewModel.canSweepSelectedType
                            || viewModel.recommendedFees == nil
                    )
                }
                .padding(.horizontal)

                if viewModel.selectedType != nil
                    && !viewModel.canSweepSelectedType
                    && !viewModel.isDiscovering
                {
                    Text("No funds found for selected type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isProcessing {
                    ProgressView()
                        .padding(.bottom, 8)
                }
            }
            .padding(.top, 12)
            .navigationTitle("WIF Options")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            if viewModel.discoveryResults.isEmpty {
                viewModel.discover()
            }
            viewModel.fetchFees()
        }
        .alert(isPresented: $viewModel.showingErrorAlert) {
            Alert(
                title: Text("Import Error"),
                message: Text(viewModel.onboardingViewError?.description ?? "Unknown"),
                dismissButton: .default(Text("OK")) {
                    viewModel.onboardingViewError = nil
                }
            )
        }
    }
}
