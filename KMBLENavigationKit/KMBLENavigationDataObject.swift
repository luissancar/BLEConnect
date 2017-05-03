//
//  KMBLENaviagationDataObject.swift
//  KMBLENavigationKit
//
//  Created by Matthias Friese on 19.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import Foundation

@objc open class KMBLENavigationDataObject: NSObject {
    
    fileprivate(set) var identifier : UInt32
    fileprivate(set) var direction : NavigationDirection
    fileprivate(set) var distance : UInt32
    fileprivate(set) var streetname : String?
    
    open override var description: String {
        get {
            return "identifier: \(self.identifier)\ndirection: \(direction.rawValue)\n distance:\(distance)\nstreetname: \(streetname ?? "NONE")"
        }
    }
    
    override fileprivate init() {
        self.identifier = arc4random()
        self.direction = NavigationDirection.unknown
        self.distance = 0
    }
    
    
    /**
     Designated Initializer.
    */
    public init(direction: NavigationDirection, distance: UInt, streetname:String?) {
        self.identifier = arc4random()
        self.direction = direction
        self.distance = UInt32(distance)
        self.streetname = streetname
    }
    
    /**
     Produces a NSData object from the navigation object. For details please check [BLEConnect Documentation](https://github.com/komoot/BLEConnect)
    */
    func convertToNSData() -> Data {
        let data = NSMutableData()
        data.append(&identifier, length: MemoryLayout<UInt32>.size)
        data.append(&direction, length: MemoryLayout<UInt8>.size)
        data.append(&distance, length: MemoryLayout<UInt32>.size)
        if let streetname = self.streetname {
            data.append(streetname.data(using: String.Encoding.utf8)!)
        }
        return data as Data
    }
    
}
