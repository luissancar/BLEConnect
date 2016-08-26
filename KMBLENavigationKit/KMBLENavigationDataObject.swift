//
//  KMBLENaviagationDataObject.swift
//  KMBLENavigationKit
//
//  Created by Matthias Friese on 19.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import Foundation

@objc public class KMBLENavigationDataObject: NSObject {
    
    private(set) var identifier : UInt32
    private(set) var direction : NavigationDirection
    private(set) var distance : UInt32
    private(set) var streetname : String?
    
    public override var description: String {
        get {
            return "identifier: \(self.identifier)\ndirection: \(direction.rawValue)\n distance:\(distance)\nstreetname: \(streetname)"
        }
    }
    
    override private init() {
        self.identifier = arc4random()
        self.direction = NavigationDirection.Unknown
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
    func convertToNSData() -> NSData {
        let data = NSMutableData()
        data.appendBytes(&identifier, length: sizeof(UInt32))
        data.appendBytes(&direction, length: sizeof(UInt8))
        data.appendBytes(&distance, length: sizeof(UInt32))
        if let streetname = self.streetname {
            data.appendData(streetname.dataUsingEncoding(NSUTF8StringEncoding)!)
        }
        return data
    }
    
}