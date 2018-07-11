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
    let timeIntervalToNextInstruction : TimeInterval
    
    init(title: String?, subtitle: String?, direction: NavigationDirection, timeInterval: TimeInterval) {
        self.title = title
        self.subtitle = subtitle
        self.direction = direction
        self.timeIntervalToNextInstruction = timeInterval
        super.init()
    }
}

protocol KMBLENavigationSimulatorDelegate : AnyObject {
    func  navigationSimulator(_ naviagtionSimulator: KMBLENavigationSimulator, didSendInstruction: KMBLENavigationInstruction)
    func navigationSimulator(_ naviagtionSimulator: KMBLENavigationSimulator, didFailSendingInstruction: KMBLENavigationInstruction, connectionErrorType: KMBLEConnectionErrorType)
}

class KMBLENavigationSimulator: NSObject {
    
    weak var delegate : KMBLENavigationSimulatorDelegate?
    
    var instructions    : [KMBLENavigationInstruction]?
    fileprivate var currentIndex = 0
    fileprivate var running = false
    fileprivate var nextInstructionTimer : Timer?
    fileprivate var bleConnector : KMBLEConnector
    
    init(fileURL: URL, bleConnector: KMBLEConnector) {
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
    
    @objc fileprivate func sendNextInstruction() {
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
                            let numberFormatter = NumberFormatter()
                            numberFormatter.numberStyle = .decimal
                            var distanceNumber = numberFormatter.number(from: distanceString)!.doubleValue

                            if subtitle.hasSuffix("km") {
                                distanceNumber *= 1000
                            }
                            distance = UInt(distanceNumber)
                        }
                    }
            
                    var streetname = instruction.title
                    if let originalStreetname = streetname {
                        if originalStreetname.hasSuffix("\"") == true && originalStreetname.hasPrefix("\"") == true {
                            streetname = String(originalStreetname[originalStreetname.index(originalStreetname.startIndex, offsetBy: 1)..<originalStreetname.index(originalStreetname.endIndex, offsetBy: -1)])
                        }
                    }
                    
                    let navigationInstruction = KMBLENavigationDataObject(direction: instruction.direction, distance: distance, streetname: streetname)
                    let errorType = bleConnector.sendNavigationDataObject(navigationInstruction)
                    if let delegate = delegate {
                        if errorType == .success {
                            delegate.navigationSimulator(self, didSendInstruction: instruction)
                        } else {
                            delegate.navigationSimulator(self, didFailSendingInstruction: instruction, connectionErrorType: errorType)
                        }
                    }
                    nextInstructionTimer = Timer.scheduledTimer(timeInterval: instruction.timeIntervalToNextInstruction, target: self, selector: #selector(sendNextInstruction), userInfo: nil, repeats: false)
                }
            }
        }
    }
    
    fileprivate func extractDistanceFromString(_ text: String) -> [String] {
        
        let regex = try! NSRegularExpression(pattern: "([0-9,.])+", options: NSRegularExpression.Options.caseInsensitive)
        let nsString = text as NSString
        let results = regex.matches(in: text,
                                            options: NSRegularExpression.MatchingOptions.reportCompletion, range: NSMakeRange(0, nsString.length))
        
        return results.map { (result:NSTextCheckingResult) -> String in
            return nsString.substring(with: result.range)
        }
    }
    
    fileprivate func parseFile(_ fileURL: URL) {
        var parsedInstructions = [KMBLENavigationInstruction]()
        var fileDataString : String?
        do {
            fileDataString = try String(contentsOf: fileURL, encoding: String.Encoding.utf8)
        } catch let err as NSError {
            DDLogError("error while reading file from url \(fileURL). Error: \(err.localizedDescription)")
            return
        }
        if let fileDataString = fileDataString {
            let lines = fileDataString.components(separatedBy: CharacterSet.newlines).filter{!$0.isEmpty}
            
            for (index, line) in lines.enumerated() {
                let lineComponents = line.components(separatedBy: ",")
                if lineComponents.count != 14 {
                    DDLogWarn("component count != 14. Ignore line \(line)")
                    continue;
                }
                var timeInterval = TimeInterval(0)
                if index+1 < lines.count {
                    let nextLine = lines[index+1]
                    let nextLineComponents = nextLine.components(separatedBy: ",")
                    if nextLineComponents.count == 14 {
                        //timeintervals in log file are miliseconds
                        let currentLineTimeInterval = TimeInterval(lineComponents[12])!
                        let nextLineTimeInterval =  TimeInterval(nextLineComponents[12])!
                        timeInterval = (nextLineTimeInterval - currentLineTimeInterval) / 1000.0
                    }
                }
                
                let directionString = lineComponents[11]
                let directionUInt8 = UInt8(directionString)
                var direction = NavigationDirection(rawValue: directionUInt8!)!
                
                if direction == .roundabout {
                    let filename = lineComponents[10]
                    switch filename {
                    case "ic_nav_roundabout_ccw1_1":
                        direction = .roundaboutCCW11
                    case "ic_nav_roundabout_ccw1_2":
                        direction = .roundaboutCCW12
                    case "ic_nav_roundabout_ccw1_3":
                        direction = .roundaboutCCW13
                    case "ic_nav_roundabout_ccw2_2":
                        direction = .roundaboutCCW22
                    case "ic_nav_roundabout_ccw2_3":
                        direction = .roundaboutCCW23
                    case "ic_nav_roundabout_ccw3_3":
                        direction = .roundaboutCCW33
                    case "ic_nav_roundabout_cw1_1":
                        direction = .roundaboutCW11
                    case "ic_nav_roundabout_cw1_2":
                        direction = .roundaboutCW12
                    case "ic_nav_roundabout_cw1_3":
                        direction = .roundaboutCW13
                    case "ic_nav_roundabout_cw2_2":
                        direction = .roundaboutCW22
                    case "ic_nav_roundabout_cw2_3":
                        direction = .roundaboutCW23
                    case "ic_nav_roundabout_cw3_3":
                        direction = .roundaboutCCW33
                    case "ic_nav_roundabout_exit_ccw":
                        direction = .exitRoundaboutRight
                    case "ic_nav_roundabout_exit_cw":
                        direction = .exitRoundaboutLeft
                    default:
                        direction = .roundaboutFallback
                    }
                }
                
                let instruction = KMBLENavigationInstruction(title: lineComponents[8], subtitle: lineComponents[9], direction: direction, timeInterval: timeInterval)
                parsedInstructions.append(instruction)
            }
            
            self.instructions = parsedInstructions
        }
    }
}
