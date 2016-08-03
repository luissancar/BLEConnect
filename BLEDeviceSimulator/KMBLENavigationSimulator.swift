//
//  KMBLENavigationSimulator.swift
//  KMBLENavigationKit
//
//  Created by Matthias Friese on 21.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import Foundation
import CocoaLumberjack
import KMBLENavigationKit

class KMBLENavigationInstruction : NSObject {
    
    let title : String?
    let subtitle : String?
    let direction : NavigationDirection
    let timeIntervalToNextInstruction : NSTimeInterval
    
    init(title: String?, subtitle: String?, direction: NavigationDirection, timeInterval: NSTimeInterval) {
        self.title = title
        self.subtitle = subtitle
        self.direction = direction
        self.timeIntervalToNextInstruction = timeInterval
        super.init()
    }
}

protocol KMBLENavigationSimulatorDelegate : AnyObject {
    func  navigationSimulator(naviagtionSimulator: KMBLENavigationSimulator, didSendInstruction: KMBLENavigationInstruction)
    func navigationSimulator(naviagtionSimulator: KMBLENavigationSimulator, didFailSendingInstruction: KMBLENavigationInstruction, connectionErrorType: KMBLEConnectionErrorType)
}

class KMBLENavigationSimulator: NSObject {
    
    weak var delegate : KMBLENavigationSimulatorDelegate?
    
    var instructions    : [KMBLENavigationInstruction]?
    private var currentIndex = 0
    private var running = false
    private var nextInstructionTimer : NSTimer?
    private var bleConnector : KMBLEConnector
    
    init(fileURL: NSURL, bleConnector: KMBLEConnector) {
        self.bleConnector = bleConnector
        super.init()
        
        parseFile(fileURL)
    }
    
    func start() {
        if running == false {
            currentIndex = 0
            running = true
            sendNextInstruction()
        }
    }
    
    func stop() {
        if running == true {
            running = false
            nextInstructionTimer?.invalidate()
        }
    }
    
    //MARK: private methods
    
    @objc private func sendNextInstruction() {
        if let instructions = instructions {
            if running == true {
                nextInstructionTimer?.invalidate()
                if currentIndex < instructions.count {
                    let instruction = instructions[currentIndex]
                    currentIndex += 1
                    var distance = UInt(0)
                    if let subtitle = instruction.subtitle {
                        var distanceStrings = extractDistanceFromString(instruction.subtitle!)
                        if distanceStrings.count > 0 {
                            let distanceString = distanceStrings[0]
                            let numberFormatter = NSNumberFormatter()
                            numberFormatter.numberStyle = .DecimalStyle
                            var distanceNumber = numberFormatter.numberFromString(distanceString)!.doubleValue

                            if subtitle.hasSuffix("km") {
                                distanceNumber *= 1000
                            }
                            distance = UInt(distanceNumber)
                        }
                    }
            
                    var streetname = instruction.title
                    if let originalStreetname = streetname {
                        if originalStreetname.hasSuffix("\"") == true && originalStreetname.hasPrefix("\"") == true {
                            let range = Range<String.Index>(originalStreetname.startIndex.advancedBy(1)..<originalStreetname.endIndex.advancedBy(-1))
                            streetname = originalStreetname.substringWithRange(range)
                        }
                    }
                    
                    let navigationInstruction = KMBLENavigationDataObject(direction: instruction.direction, distance: distance, streetname: streetname)
                    let errorType = bleConnector.sendNavigationDataObject(navigationInstruction)
                    if let delegate = delegate {
                        if errorType == .Success {
                            delegate.navigationSimulator(self, didSendInstruction: instruction)
                        } else {
                            delegate.navigationSimulator(self, didFailSendingInstruction: instruction, connectionErrorType: errorType)
                        }
                    }
                    nextInstructionTimer = NSTimer.scheduledTimerWithTimeInterval(instruction.timeIntervalToNextInstruction, target: self, selector: #selector(sendNextInstruction), userInfo: nil, repeats: false)
                }
            }
        }
    }
    
    private func extractDistanceFromString(text: String) -> [String] {
        
        let regex = try! NSRegularExpression(pattern: "([0-9,.])+", options: NSRegularExpressionOptions.CaseInsensitive)
        let nsString = text as NSString
        let results = regex.matchesInString(text,
                                            options: NSMatchingOptions.ReportCompletion, range: NSMakeRange(0, nsString.length))
        
        return results.map { (result:NSTextCheckingResult) -> String in
            return nsString.substringWithRange(result.range)
        }
    }
    
    private func parseFile(fileURL: NSURL) {
        var parsedInstructions = [KMBLENavigationInstruction]()
        var fileDataString : String?
        do {
            fileDataString = try String(contentsOfURL: fileURL, encoding: NSUTF8StringEncoding)
        } catch let err as NSError {
            DDLogError("error while reading file from url \(fileURL). Error: \(err.localizedDescription)")
            return
        }
        if let fileDataString = fileDataString {
            let lines = fileDataString.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet()).filter{!$0.isEmpty}
            
            for (index, line) in lines.enumerate() {
                let lineComponents = line.componentsSeparatedByString(",")
                if lineComponents.count != 14 {
                    DDLogWarn("component count != 14. Ignore line \(line)")
                    continue;
                }
                var timeInterval = NSTimeInterval(0)
                if index+1 < lines.count {
                    let nextLine = lines[index+1]
                    let nextLineComponents = nextLine.componentsSeparatedByString(",")
                    if nextLineComponents.count == 14 {
                        //timeintervals in log file are miliseconds
                        let currentLineTimeInterval = NSTimeInterval(lineComponents[12])!
                        let nextLineTimeInterval =  NSTimeInterval(nextLineComponents[12])!
                        timeInterval = (nextLineTimeInterval - currentLineTimeInterval) / 1000.0
                    }
                }
                
                let directionString = lineComponents[11]
                let directionUInt8 = UInt8(directionString)
                var direction = NavigationDirection(rawValue: directionUInt8!)!
                
                if direction == .Roundabout {
                    let filename = lineComponents[10]
                    switch filename {
                    case "ic_nav_roundabout_ccw1_1":
                        direction = .RoundaboutCCW11
                    case "ic_nav_roundabout_ccw1_2":
                        direction = .RoundaboutCCW12
                    case "ic_nav_roundabout_ccw1_3":
                        direction = .RoundaboutCCW13
                    case "ic_nav_roundabout_ccw2_2":
                        direction = .RoundaboutCCW22
                    case "ic_nav_roundabout_ccw2_3":
                        direction = .RoundaboutCCW23
                    case "ic_nav_roundabout_ccw3_3":
                        direction = .RoundaboutCCW33
                    case "ic_nav_roundabout_cw1_1":
                        direction = .RoundaboutCW11
                    case "ic_nav_roundabout_cw1_2":
                        direction = .RoundaboutCW12
                    case "ic_nav_roundabout_cw1_3":
                        direction = .RoundaboutCW13
                    case "ic_nav_roundabout_cw2_2":
                        direction = .RoundaboutCW22
                    case "ic_nav_roundabout_cw2_3":
                        direction = .RoundaboutCW23
                    case "ic_nav_roundabout_cw3_3":
                        direction = .RoundaboutCCW33
                    case "ic_nav_roundabout_exit_ccw":
                        direction = .ExitRoundaboutRight
                    case "ic_nav_roundabout_exit_cw":
                        direction = .ExitRoundaboutLeft
                    default:
                        direction = .RoundaboutFallback
                    }
                }
                
                let instruction = KMBLENavigationInstruction(title: lineComponents[8], subtitle: lineComponents[9], direction: direction, timeInterval: timeInterval)
                parsedInstructions.append(instruction)
            }
            
            self.instructions = parsedInstructions
        }
    }
}