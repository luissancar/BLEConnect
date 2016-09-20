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
    
    fileprivate var simulating = false
    fileprivate var navigationSimulator : KMBLENavigationSimulator?
    fileprivate var errorPopupShown = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        updateButtonsBySwitchState()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func handleChangeOnBluetoothSwitch(_ sender: AnyObject) {
        
        if bluetoothActiveSwitch.isOn {
             if let bleConnector = bleConnector {
                let errorType = bleConnector.startAdvertisingNavigationService(false)
                
                if errorType != .success {
                    bluetoothActiveSwitch.isOn = false
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
    
    @IBAction func handleTapOnSendEventButton(_ sender: AnyObject) {
        if let bleConnector = bleConnector {
            let testEvent = KMBLENavigationDataObject(direction: NavigationDirection(rawValue: UInt8(arc4random_uniform(31)))!, distance: UInt(arc4random_uniform(1500)), streetname: "Kiepenheuerallee \(arc4random_uniform(32))")
            bleConnector.sendNavigationDataObject(testEvent)
        }
    }
    
    @IBAction func handleTapOnSimulationButton(_ sender: AnyObject) {
        toogleSimulation()
    }
    
    //MARK: private func
    
    fileprivate func showErrorAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    fileprivate func toogleSimulation() {
        if navigationSimulator == nil {
            let filePath = Bundle.main.path(forResource: "navigationSimulation", ofType: "csv")
            let fileURL = URL(fileURLWithPath: filePath!)
            self.navigationSimulator = KMBLENavigationSimulator(fileURL: fileURL, bleConnector: bleConnector!)
            self.navigationSimulator?.delegate = self
        }
        
        if simulating == true {
            if (UIApplication.shared.isIdleTimerDisabled == true) {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            simulating = false
            navigationSimulator?.stop()
            startSimulationButton.setTitle("Start simulation", for: UIControlState())
            
        } else {
            if (UIApplication.shared.isIdleTimerDisabled == false) {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            simulating = true
            navigationSimulator?.start()
            startSimulationButton.setTitle("Stop simulation", for: UIControlState())
        }
        
        updateSimulationButton()
    }
    
    fileprivate func handleBluetoothErrorType(_ errorType: KMBLEConnectionErrorType) {
        switch errorType {
        case .bluetoothLEUnavailable:
            showErrorAlert("Bluetooth error", message: "Bluetooth LE is not supported on your device")
        case .bluetoothTurnedOff:
            showErrorAlert("Bluetooth error", message: "Bluetooth is turned off")
        case.bluetoothNotAuthorized:
            showErrorAlert("Bluetooth error", message: "Bluetooth is not not authorized")
        default:
            break
        }
    }
    
    fileprivate func updateButtonsBySwitchState() {
        if bluetoothActiveSwitch.isOn {
            for button in [startSimulationButton, sendEventButton] {
                button?.setTitleColor(UIColor.white, for: UIControlState())
                button?.setBackgroundImage(UIImage(color: UIColor(hex: "#78B62E")!), for: UIControlState())
                button?.setBackgroundImage(UIImage(color: UIColor(hex: "#5E9422")!), for: UIControlState.highlighted)
                
                button?.isEnabled = true
            }
        } else {
            for button in [startSimulationButton, sendEventButton] {
                button?.setTitleColor(UIColor(hex: "#8A8A8A"), for: UIControlState.disabled)
                button?.setBackgroundImage(UIImage(color: UIColor(hex: "#F1F1F1")!), for: UIControlState.disabled)
                button?.isEnabled = false
            }
        }
    }
    
    fileprivate func updateSimulationButton() {
        if simulating {
            startSimulationButton.setBackgroundImage(UIImage(color: UIColor(hex: "#F1F1F1")!), for: UIControlState())
            startSimulationButton.setBackgroundImage(UIImage(color: UIColor(hex: "#D2D2D2")!), for: UIControlState.highlighted)
            startSimulationButton.setTitleColor(UIColor.black, for: UIControlState())
        } else {
            startSimulationButton.setTitleColor(UIColor.white, for: UIControlState())
            startSimulationButton.setBackgroundImage(UIImage(color: UIColor(hex: "#78B62E")!), for: UIControlState())
            startSimulationButton.setBackgroundImage(UIImage(color: UIColor(hex: "#5E9422")!), for: UIControlState.highlighted)
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
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}

extension UIColor {
    convenience init?(hex: String) {
        
        var cString:String = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) {
            cString = cString.substring(from: cString.characters.index(cString.startIndex, offsetBy: 1))
        }
        
        assert((cString.characters.count) == 6)
        
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}


extension BLEConnectViewController : KMBLEConnectorDelegate {
    
    func centralDidSubscribedToCharacteristic(_ bleConnector: KMBLEConnector) {
        DDLogInfo("did subscriped")
    }
    
    func centralDidUnsubscribedToCharacteristic(_ bleConnector: KMBLEConnector) {
        DDLogInfo("did unsubscriped")
    }
    
    func bleConnector(_ bleConnector: KMBLEConnector, didFailToStartAdvertisingError error: NSError) {
        showErrorAlert("Error", message: error.localizedDescription)
    }
}

extension BLEConnectViewController : KMBLENavigationSimulatorDelegate {
    
    func navigationSimulator(_ naviagtionSimulator: KMBLENavigationSimulator, didSendInstruction: KMBLENavigationInstruction) {
        self.errorPopupShown = false
    }
    
    func navigationSimulator(_ naviagtionSimulator: KMBLENavigationSimulator, didFailSendingInstruction: KMBLENavigationInstruction, connectionErrorType: KMBLEConnectionErrorType) {
        if errorPopupShown == true {
            return
        }
        handleBluetoothErrorType(connectionErrorType)
        self.errorPopupShown = true
    }
}
