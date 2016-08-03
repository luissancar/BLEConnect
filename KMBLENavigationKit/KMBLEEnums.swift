
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
    case Unknown = 0
    case TurnStraight
    case Start
    case Finish
    case TurnSlightLeft
    case TurnLeft
    case TurnSharpLeft
    case TurnSharpRight
    case TurnRight
    case TurnSlightRight
    case TurnForkRight
    case TurnForkLeft
    case TurnU
    case Poi
    case Roundabout
    case ExitRoundaboutLeft
    case ExitRoundaboutRight
    case RoundaboutCCW11
    case RoundaboutCCW12
    case RoundaboutCCW13
    case RoundaboutCCW22
    case RoundaboutCCW23
    case RoundaboutCCW33
    case RoundaboutCW11
    case RoundaboutCW12
    case RoundaboutCW13
    case RoundaboutCW22
    case RoundaboutCW23
    case RoundaboutCW33
    case RoundaboutFallback
    case LeftRoute
}