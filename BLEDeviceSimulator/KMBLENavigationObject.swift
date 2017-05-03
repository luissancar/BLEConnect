//
//  KMBLENavigationObject.swift
//  KMBLENavigationKit
//
//  Created by Matthias Friese on 20.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import Foundation
import UIKit
import KMBLENavigationKit

class KMBLENavigationObject: NSObject {

    private(set) var identifier : UInt32
    private(set) var direction : NavigationDirection
    private(set) var distance : UInt32
    private(set) var streetname : String?
    
    init(data: NSData) {
        let bytes = data.bytes
        var start = 0
        
        var identifierValue : UInt32 = 0
        data.getBytes(&identifierValue, range: NSMakeRange(start, MemoryLayout<UInt32>.size))
        self.identifier = identifierValue
        start += MemoryLayout<UInt32>.size
        
        let direction : UnsafePointer<UInt8> = bytes.bindMemory(to: UInt8.self, capacity: 1)
        if let parsedDirection =  NavigationDirection(rawValue: direction[start]) {
            self.direction = parsedDirection
        } else {
            self.direction = .unknown
        }
        
        start += MemoryLayout<UInt8>.size
        
        var distanceValue : UInt32 = 0
        data.getBytes(&distanceValue, range: NSMakeRange(start, MemoryLayout<UInt32>.size))
        self.distance = distanceValue
        start += MemoryLayout<UInt32>.size
        
        var streetnameBytes : [UInt8] = [UInt8](repeating: 0, count: data.length - start)
        data.getBytes(&streetnameBytes, range:NSMakeRange(start, streetnameBytes.count))
        self.streetname = String(bytes: streetnameBytes, encoding: String.Encoding.utf8)
        
        super.init()
        
    }
    
    func navigationImage() -> UIImage? {
        switch direction {
        case .turnStraight:
            return UIImage(named: "ic_nav_arrow_keep_going")
        case .start:
            return UIImage(named: "ic_nav_arrow_start")
        case .finish:
            return UIImage(named: "ic_nav_arrow_finish")
        case .leftRoute:
             return UIImage(named: "ic_nav_outof_route")
        case .turnLeft:
            return UIImage(named: "ic_nav_arrow_turn_left")
        case .turnRight:
            return UIImage(named: "ic_nav_arrow_turn_right")
        case .turnU:
            return UIImage(named: "ic_nav_arrow_uturn")
        case .turnForkLeft:
            return UIImage(named: "ic_nav_arrow_fork_left")
        case .turnForkRight:
            return UIImage(named: "ic_nav_arrow_fork_right")
        case .turnSharpRight:
            return UIImage(named: "ic_nav_arrow_turn_hard_right")
        case .turnSharpLeft:
            return UIImage(named: "ic_nav_arrow_turn_hard_left")
        case .turnSlightLeft:
            return UIImage(named: "ic_nav_arrow_keep_left")
        case .turnSlightRight:
            return UIImage(named: "ic_nav_arrow_keep_right")
        case .roundaboutCCW11:
            return UIImage(named: "ic_nav_roundabout_ccw1_1")
        case .roundaboutCCW12:
            return UIImage(named: "ic_nav_roundabout_ccw1_2")
        case .roundaboutCCW13:
            return UIImage(named: "ic_nav_roundabout_ccw1_3")
        case .roundaboutCCW22:
            return UIImage(named: "ic_nav_roundabout_ccw2_2")
        case .roundaboutCCW23:
            return UIImage(named: "ic_nav_roundabout_ccw2_3")
        case .roundaboutCCW33:
            return UIImage(named: "ic_nav_roundabout_ccw3_3")
        case .roundaboutCW11:
            return UIImage(named: "ic_nav_roundabout_cw1_1")
        case .roundaboutCW12:
            return UIImage(named: "ic_nav_roundabout_cw1_2")
        case .roundaboutCW13:
            return UIImage(named: "ic_nav_roundabout_cw1_3")
        case .roundaboutCW22:
            return UIImage(named: "ic_nav_roundabout_cw_2_2")
        case .roundaboutCW23:
            return UIImage(named: "ic_nav_roundabout_cw_2_3")
        case .roundaboutCW33:
            return UIImage(named: "ic_nav_roundabout_cw3_3")
        case .exitRoundaboutLeft:
            return UIImage(named: "ic_nav_roundabout_exit_cw")
        case .exitRoundaboutRight:
            return UIImage(named: "ic_nav_roundabout_exit_ccw")
        case .roundaboutFallback:
            return UIImage(named: "ic_nav_roundabout_fallback")
        default:
            return nil
        }
    }
    
    override var description: String {
        get {
            return "identifier: \(self.identifier)\ndirection: \(self.direction)\ndistance: \(self.distance)\nstreetname: \(self.streetname ?? "NONE")"
        }
    }
    
}
