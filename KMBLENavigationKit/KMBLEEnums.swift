
//
//  KMBLEEnums.swift
//  KMBLENavigationKit
//
//  Created by Matthias Friese on 20.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import Foundation

/**
 Enum for direction of a navigation object. Please check [BLEConnect Documentation](https://github.com/komoot/BLEConnect/README.md)
 */
public enum NavigationDirection: UInt8 {
    case unknown = 0
    case turnStraight
    case start
    case finish
    case turnSlightLeft
    case turnLeft
    case turnSharpLeft
    case turnSharpRight
    case turnRight
    case turnSlightRight
    case turnForkRight
    case turnForkLeft
    case turnU
    case poi
    case roundabout
    case exitRoundaboutLeft
    case exitRoundaboutRight
    case roundaboutCCW11
    case roundaboutCCW12
    case roundaboutCCW13
    case roundaboutCCW22
    case roundaboutCCW23
    case roundaboutCCW33
    case roundaboutCW11
    case roundaboutCW12
    case roundaboutCW13
    case roundaboutCW22
    case roundaboutCW23
    case roundaboutCW33
    case roundaboutFallback
    case leftRoute
}
