//
//  BDKSwiftExampleWalletOnboardingViewModelTests.swift
//  BDKSwiftExampleWalletTests
//
//  Created by Matthew Ramsden on 5/22/23.
//

import XCTest

@testable import BDKSwiftExampleWallet

final class BDKSwiftExampleWalletOnboardingViewModelTests: XCTestCase {
    func testOnboardingClassifiesTestnetWif() {
        let viewModel = OnboardingViewModel(bdkClient: .mock, wifClient: .mock)
        let payload = viewModel.classifyScannedPayload(
            "cMahea7zqjxrtgAbB7LSGbcQUr1uX1ojuat9jZodMN87JcbXMTcA"
        )

        switch payload {
        case .wif(let value):
            XCTAssertEqual(value, "cMahea7zqjxrtgAbB7LSGbcQUr1uX1ojuat9jZodMN87JcbXMTcA")
        case .text:
            XCTFail("Expected WIF payload")
        }
    }

    func testOnboardingKeepsDescriptorsAsText() {
        let viewModel = OnboardingViewModel(bdkClient: .mock, wifClient: .mock)
        let descriptor = "wpkh(cMahea7zqjxrtgAbB7LSGbcQUr1uX1ojuat9jZodMN87JcbXMTcA)"
        let payload = viewModel.classifyScannedPayload(descriptor)

        switch payload {
        case .wif:
            XCTFail("Descriptor should not be classified as raw WIF")
        case .text(let value):
            XCTAssertEqual(value, descriptor)
        }
    }
}
