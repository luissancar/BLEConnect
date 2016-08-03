//
//  ViewController.swift
//  KomootAppSimulator
//
//  Created by Matthias Friese on 18.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import UIKit
import KMBLENavigationKit
import LumberjackConsole
import CocoaLumberjack

class BLEConnectViewController: UIViewController {
    
    var bleConnector : KMBLEConnector? {
        didSet {
            bleConnector?.delegate = self
        }
    }
    
    
    @IBOutlet weak var bluetoothActiveSwitch: UISwitch!
    @IBOutlet weak var sendEventButton: UIButton!
    @IBOutlet weak var startSimulationButton: UIButton!
    
    private var simulating = false
    private var navigationSimulator : KMBLENavigationSimulator?
    private var errorPopupShown = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        updateButtonsBySwitchState()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func handleChangeOnBluetoothSwitch(sender: AnyObject) {
        
        if bluetoothActiveSwitch.on {
             if let bleConnector = bleConnector {
                let errorType = bleConnector.startAdvertisingNavigationService(false)
                
                if errorType != .Success {
                    bluetoothActiveSwitch.on = false
                    handleBluetoothErrorType(errorType)
                }
            }
        } else {
            if let bleConnector = bleConnector {
                bleConnector.stopAdvertisingNavigationService()
            }
        }
        
        updateButtonsBySwitchState()
    }
    
    @IBAction func handleTapOnSendEventButton(sender: AnyObject) {
        if let bleConnector = bleConnector {
            let testEvent = KMBLENavigationDataObject(direction: NavigationDirection(rawValue: UInt8(arc4random_uniform(31)))!, distance: UInt(arc4random_uniform(1500)), streetname: "Kiepenheuerallee \(arc4random_uniform(32))")
            bleConnector.sendNavigationDataObject(testEvent)
        }
    }
    
    @IBAction func handleTapOnSimulationButton(sender: AnyObject) {
        toogleSimulation()
    }
    
    //MARK: private func
    
    private func showErrorAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    private func toogleSimulation() {
        if navigationSimulator == nil {
            let filePath = NSBundle.mainBundle().pathForResource("navigationSimulation", ofType: "csv")
            let fileURL = NSURL(fileURLWithPath: filePath!)
            self.navigationSimulator = KMBLENavigationSimulator(fileURL: fileURL, bleConnector: bleConnector!)
            self.navigationSimulator?.delegate = self
        }
        
        if simulating == true {
            if (UIApplication.sharedApplication().idleTimerDisabled == true) {
                UIApplication.sharedApplication().idleTimerDisabled = false
            }
            simulating = false
            navigationSimulator?.stop()
            startSimulationButton.setTitle("Start simulation", forState: UIControlState.Normal)
            
        } else {
            if (UIApplication.sharedApplication().idleTimerDisabled == false) {
                UIApplication.sharedApplication().idleTimerDisabled = true
            }
            simulating = true
            navigationSimulator?.start()
            startSimulationButton.setTitle("Stop simulation", forState: UIControlState.Normal)
        }
        
        updateSimulationButton()
    }
    
    private func handleBluetoothErrorType(errorType: KMBLEConnectionErrorType) {
        switch errorType {
        case .BluetoothLEUnavailable:
            showErrorAlert("Bluetooth error", message: "Bluetooth LE is not supported on your device")
        case .BluetoothTurnedOff:
            showErrorAlert("Bluetooth error", message: "Bluetooth is turned off")
        case.BluetoothNotAuthorized:
            showErrorAlert("Bluetooth error", message: "Bluetooth is not not authorized")
        default:
            break
        }
    }
    
    private func updateButtonsBySwitchState() {
        if bluetoothActiveSwitch.on {
            for button in [startSimulationButton, sendEventButton] {
                button.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
                button.setBackgroundImage(UIImage(color: UIColor(hex: "#78B62E")!), forState: UIControlState.Normal)
                button.setBackgroundImage(UIImage(color: UIColor(hex: "#5E9422")!), forState: UIControlState.Highlighted)
                
                button.enabled = true
            }
        } else {
            for button in [startSimulationButton, sendEventButton] {
                button.setTitleColor(UIColor(hex: "#8A8A8A"), forState: UIControlState.Disabled)
                button.setBackgroundImage(UIImage(color: UIColor(hex: "#F1F1F1")!), forState: UIControlState.Disabled)
                button.enabled = false
            }
        }
    }
    
    private func updateSimulationButton() {
        if simulating {
            startSimulationButton.setBackgroundImage(UIImage(color: UIColor(hex: "#F1F1F1")!), forState: UIControlState.Normal)
            startSimulationButton.setBackgroundImage(UIImage(color: UIColor(hex: "#D2D2D2")!), forState: UIControlState.Highlighted)
            startSimulationButton.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
        } else {
            startSimulationButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
            startSimulationButton.setBackgroundImage(UIImage(color: UIColor(hex: "#78B62E")!), forState: UIControlState.Normal)
            startSimulationButton.setBackgroundImage(UIImage(color: UIColor(hex: "#5E9422")!), forState: UIControlState.Highlighted)
        }
    }
}

extension UIImage {
    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image.CGImage else { return nil }
        self.init(CGImage: cgImage)
    }
}

extension UIColor {
    convenience init?(hex: String) {
        
        var cString:String = hex.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet() as NSCharacterSet).uppercaseString
        
        if (cString.hasPrefix("#")) {
            cString = cString.substringFromIndex(cString.startIndex.advancedBy(1))
        }
        
        assert((cString.characters.count) == 6)
        
        var rgbValue:UInt32 = 0
        NSScanner(string: cString).scanHexInt(&rgbValue)
        
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}


extension BLEConnectViewController : KMBLEConnectorDelegate {
    
    func centralDidSubscribedToCharacteristic(bleConnector: KMBLEConnector) {
        DDLogInfo("did subscriped")
    }
    
    func centralDidUnsubscribedToCharacteristic(bleConnector: KMBLEConnector) {
        DDLogInfo("did unsubscriped")
    }
    
    func bleConnector(bleConnector: KMBLEConnector, didFailToStartAdvertisingError error: NSError) {
        showErrorAlert("Error", message: error.localizedDescription)
    }
}

extension BLEConnectViewController : KMBLENavigationSimulatorDelegate {
    
    func navigationSimulator(naviagtionSimulator: KMBLENavigationSimulator, didSendInstruction: KMBLENavigationInstruction) {
        self.errorPopupShown = false
    }
    
    func navigationSimulator(naviagtionSimulator: KMBLENavigationSimulator, didFailSendingInstruction: KMBLENavigationInstruction, connectionErrorType: KMBLEConnectionErrorType) {
        if errorPopupShown == true {
            return
        }
        handleBluetoothErrorType(connectionErrorType)
        self.errorPopupShown = true
    }
}