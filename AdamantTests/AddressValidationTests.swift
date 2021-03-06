//
//  AddressValidationTests.swift
//  AdamantTests
//
//  Created by Anokhov Pavel on 10.01.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import XCTest
@testable import Adamant

class AddressValidationTests: XCTestCase {
	
    func testValidAddress() {
		let address = "U1234567890123456"
		XCTAssertTrue(AdamantUtilities.validateAdamantAddress(address: address))
    }
	
	func testMustBeLongerThanSixDigits() {
		let address = "U12345"
		XCTAssertFalse(AdamantUtilities.validateAdamantAddress(address: address))
	}
	
	func testMustHaveLeadingU() {
		let address1 = "B12345678910"
		let address2 = "12345678910"
		let address3 = "1U2345678910"
		
		XCTAssertFalse(AdamantUtilities.validateAdamantAddress(address: address1))
		XCTAssertFalse(AdamantUtilities.validateAdamantAddress(address: address2))
		XCTAssertFalse(AdamantUtilities.validateAdamantAddress(address: address3))
	}
	
	func testOnlyNumbers() {
		let address1 = "U12345d67890"
		let address2 = "U12345d7890_"
		
		XCTAssertFalse(AdamantUtilities.validateAdamantAddress(address: address1))
		XCTAssertFalse(AdamantUtilities.validateAdamantAddress(address: address2))
	}
	
	func testCapitalU() {
		let address = "u12345d67890"
		XCTAssertFalse(AdamantUtilities.validateAdamantAddress(address: address))
	}
	
	func testNoWhitespaces() {
		let address1 = " U12345d67890"
		let address2 = "U12345d67890 "
		
		XCTAssertFalse(AdamantUtilities.validateAdamantAddress(address: address1))
		XCTAssertFalse(AdamantUtilities.validateAdamantAddress(address: address2))
	}
}
