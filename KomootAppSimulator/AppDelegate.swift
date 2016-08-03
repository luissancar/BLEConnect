//
//  AppDelegate.swift
//  KomootAppSimulator
//
//  Created by Matthias Friese on 18.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import UIKit
import KMBLENavigationKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var bleConnector : KMBLEConnector?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        
        bleConnector = KMBLEConnector(advertisingIdentifier: "Komoot BLE App Simulator")
        let setuped = bleConnector?.didFinishLaunchingWithOptions(launchOptions)
        
        if setuped == false {
            bleConnector?.setUpService()
        }
        
        if let bleConnector = bleConnector {
            bleConnector.loggingEnabled = true
            let initialController = window?.rootViewController as? BLEConnectViewController
            initialController?.bleConnector = bleConnector
        }
        
        return true
    }

}

