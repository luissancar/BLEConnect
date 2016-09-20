//
//  KMBLENavigationSimulatorTests.swift
//  KMBLENavigationKit
//
//  Created by Matthias Friese on 21.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import XCTest
import KMBLENavigationKit

class KMBLENavigationSimulatorTests: XCTestCase {


    func testSimpleParsing() {
        let filePath = Bundle.init(for: KMBLENavigationSimulatorTests.self).path(forResource: "testExport", ofType: "csv")
        XCTAssertNotNil(filePath)
        
        let fileURL = URL(fileURLWithPath: filePath!, isDirectory: false)
        XCTAssertNotNil(fileURL)
        
        let bleConnector = KMBLEConnector(advertisingIdentifier: "test")
        
        let simulator = KMBLENavigationSimulator(fileURL: fileURL, bleConnector: bleConnector)
        XCTAssertNotNil(simulator)
        XCTAssertNotNil(simulator.instructions)
        XCTAssertEqual(simulator.instructions!.count, 138)
        
    }
    
    func testRoundaboutParsing() {
        let filePath = Bundle.init(for: KMBLENavigationSimulatorTests.self).path(forResource: "testRoundaboutExport", ofType: "csv")
        XCTAssertNotNil(filePath)
        
        let fileURL = URL(fileURLWithPath: filePath!, isDirectory: false)
        XCTAssertNotNil(fileURL)
        let bleConnector = KMBLEConnector(advertisingIdentifier: "test")
        
        let simulator = KMBLENavigationSimulator(fileURL: fileURL, bleConnector: bleConnector)
        XCTAssertNotNil(simulator)
        XCTAssertNotNil(simulator.instructions)
        XCTAssertEqual(simulator.instructions!.count, 89)
        let instruction = simulator.instructions![30]
        XCTAssertEqual(NavigationDirection.RoundaboutCCW13.rawValue, instruction.direction.rawValue)
    }
    
    func testShortenString() {
        let originalString = "\"Kiepenheuerallee\""
        
        let shortenString = originalString.substring(with: Range<String.Index>(originalString.characters.index(originalString.startIndex, offsetBy: 1)..<originalString.characters.index(originalString.endIndex, offsetBy: -1)))
        XCTAssertEqual("Kiepenheuerallee", shortenString)
    }

}
