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
        let bytes = UnsafePointer<UInt8>(data.bytes)
        var start = 0
        
        var identifierValue : UInt32 = 0
        data.getBytes(&identifierValue, range: NSMakeRange(start, sizeof(UInt32)))
        self.identifier = identifierValue
        start += sizeof(UInt32)
        
        if let parsedDirection =  NavigationDirection(rawValue: UInt8(bytes[start])) {
            self.direction = parsedDirection
        } else {
            self.direction = .Unknown
        }
        
        start += sizeof(UInt8)
        
        var distanceValue : UInt32 = 0
        data.getBytes(&distanceValue, range: NSMakeRange(start, sizeof(UInt32)))
        self.distance = distanceValue
        start += sizeof(UInt32)
        
        var streetnameBytes : [UInt8] = [UInt8](count: data.length - start, repeatedValue: 0)
        data.getBytes(&streetnameBytes, range:NSMakeRange(start, streetnameBytes.count))
        self.streetname = String(bytes: streetnameBytes, encoding: NSUTF8StringEncoding)
        
        super.init()
        
    }
    
    func navigationImage() -> UIImage? {
        switch direction {
        case .TurnStraight:
            return UIImage(named: "ic_nav_arrow_keep_going")
        case .Start:
            return UIImage(named: "ic_nav_arrow_start")
        case .Finish:
            return UIImage(named: "ic_nav_arrow_finish")
        case .LeftRoute:
             return UIImage(named: "ic_nav_outof_route")
        case .TurnLeft:
            return UIImage(named: "ic_nav_arrow_turn_left")
        case .TurnRight:
            return UIImage(named: "ic_nav_arrow_turn_right")
        case .TurnU:
            return UIImage(named: "ic_nav_arrow_uturn")
        case .TurnForkLeft:
            return UIImage(named: "ic_nav_arrow_fork_left")
        case .TurnForkRight:
            return UIImage(named: "ic_nav_arrow_fork_right")
        case .TurnSharpRight:
            return UIImage(named: "ic_nav_arrow_turn_hard_right")
        case .TurnSharpLeft:
            return UIImage(named: "ic_nav_arrow_turn_hard_left")
        case .TurnSlightLeft:
            return UIImage(named: "ic_nav_arrow_keep_left")
        case .TurnSlightRight:
            return UIImage(named: "ic_nav_arrow_keep_right")
        case .RoundaboutCCW11:
            return UIImage(named: "ic_nav_roundabout_ccw1_1")
        case .RoundaboutCCW12:
            return UIImage(named: "ic_nav_roundabout_ccw1_2")
        case .RoundaboutCCW13:
            return UIImage(named: "ic_nav_roundabout_ccw1_3")
        case .RoundaboutCCW22:
            return UIImage(named: "ic_nav_roundabout_ccw2_2")
        case .RoundaboutCCW23:
            return UIImage(named: "ic_nav_roundabout_ccw2_3")
        case .RoundaboutCCW33:
            return UIImage(named: "ic_nav_roundabout_ccw3_3")
        case .RoundaboutCW11:
            return UIImage(named: "ic_nav_roundabout_cw1_1")
        case .RoundaboutCW12:
            return UIImage(named: "ic_nav_roundabout_cw1_2")
        case .RoundaboutCW13:
            return UIImage(named: "ic_nav_roundabout_cw1_3")
        case .RoundaboutCW22:
            return UIImage(named: "ic_nav_roundabout_cw_2_2")
        case .RoundaboutCW23:
            return UIImage(named: "ic_nav_roundabout_cw_2_3")
        case .RoundaboutCW33:
            return UIImage(named: "ic_nav_roundabout_cw3_3")
        case .ExitRoundaboutLeft:
            return UIImage(named: "ic_nav_roundabout_exit_cw")
        case .ExitRoundaboutRight:
            return UIImage(named: "ic_nav_roundabout_exit_ccw")
        case .RoundaboutFallback:
            return UIImage(named: "ic_nav_roundabout_fallback")
        default:
            return nil
        }
    }
    
    override var description: String {
        get {
            return "identifier: \(self.identifier)\ndirection: \(self.direction)\ndistance: \(self.distance)\nstreetname: \(self.streetname)"
        }
    }
    
}