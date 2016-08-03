//
//  BLEDeviceSimulatorTests.swift
//  BLEDeviceSimulatorTests
//
//  Created by Matthias Friese on 20.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import XCTest
import KMBLENavigationKit

class BLEDeviceSimulatorTests: XCTestCase {
    
    
    func testDecoding() {
        
        let navigationObject = KMBLENavigationDataObject(direction:NavigationDirection.TurnStraight, distance: UInt(1234), streetname: "Lennéstraße")
        
        let data = navigationObject.convertToNSData()
        
        
        let decodedObject = KMBLENavigationObject(data: data)
        
        XCTAssertEqual(navigationObject.identifier, decodedObject.identifier)
        XCTAssertEqual(navigationObject.direction, decodedObject.direction)
        XCTAssertEqual(navigationObject.distance, decodedObject.distance)
        XCTAssertEqual(navigationObject.streetname, decodedObject.streetname)
    }
    
}
