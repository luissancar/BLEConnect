//
//  ViewController.swift
//  BLEDeviceSimulator
//
//  Created by Matthias Friese on 18.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import UIKit
import CoreBluetooth
import LumberjackConsole

class DeviceSimulatorViewController: UIViewController {

    var central : KMBLECentral? {
        didSet {
            central?.delegate = self
            central?.dataDelegate = self
        }
    }
    
    @IBOutlet weak var connectButton : UIButton!
    @IBOutlet weak var console: PTEConsoleTableView!
    
    @IBOutlet weak var navigationImageView: UIImageView!
    @IBOutlet weak var navigationStreetnameLabel: UILabel!
    @IBOutlet weak var navigationDistanceLabel: UILabel!
    
    private var connectedPeripherals = [CBPeripheral]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        connectButton.layer.cornerRadius = 6.0
        connectButton.clipsToBounds = true
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if let central = central {
            central.delegate = self
        }
        
        updateButtonStates()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let deviceNavigationController = segue.destinationViewController as? UINavigationController {
            if let deviceConnectViewController = deviceNavigationController.viewControllers.first as? KMBLEDeviceConnectViewController {
                deviceConnectViewController.central = central
                deviceConnectViewController.delegate = self
            }
        }
        super.prepareForSegue(segue, sender: sender)
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
        if identifier == "bleDeviceSegue" {
            if let central = central {
                if connectedPeripherals.count > 0 {
                    central.disconnectPeripherals()
                    return false
                } else {
                    return true
                }
            }
            return false
        }
        return true
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    //MARK: private functions
    
    private func updateButtonStates() {
            if connectedPeripherals.count > 0 {
                connectButton.setBackgroundImage(UIImage(color: UIColor(hex: "#F1F1F1")!), forState: UIControlState.Normal)
                connectButton.setBackgroundImage(UIImage(color: UIColor(hex: "#D2D2D2")!), forState: UIControlState.Highlighted)
                connectButton.setTitle("Disconnect", forState: UIControlState.Normal)
                connectButton.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
            } else {
                connectButton.setBackgroundImage(UIImage(color: UIColor(hex: "#78B62E")!), forState: UIControlState.Normal)
                connectButton.setBackgroundImage(UIImage(color: UIColor(hex: "#5E9422")!), forState: UIControlState.Highlighted)
                connectButton.setTitle("Start Connection", forState: UIControlState.Normal)
                connectButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
            }
        
    }
    
    private func resetSimulationViewState() {
        navigationImageView.image = nil
        navigationDistanceLabel.text = "distance"
        navigationStreetnameLabel.text = "street"
    }
}

extension DeviceSimulatorViewController : KMBLECentralDelegate {
    
    func central(central: KMBLECentral, didConnectToPeripheral peripheral: CBPeripheral) {
        self.connectedPeripherals.append(peripheral)
        updateButtonStates()
        resetSimulationViewState()
    }
    
    func central(central: KMBLECentral, didDiscoverPeripherals: [CBPeripheral]) {
        
    }
    
    func central(central: KMBLECentral, didDisconnectFromPeripheral peripheral: CBPeripheral) {
        if let index = connectedPeripherals.indexOf(peripheral) {
            self.connectedPeripherals.removeAtIndex(index)
        }
        
        self.updateButtonStates()
        self.resetSimulationViewState()
    }
    
    func central(central: KMBLECentral, didFailConnectToPeripheral: CBPeripheral, error: NSError?) {
        
    }
    
}

extension DeviceSimulatorViewController: KMBLEDataDelegate {
    func centralDidReceiveDataObject(dataObject: KMBLENavigationObject) {
        navigationStreetnameLabel.text = dataObject.streetname
        let unitString = "m"

        navigationDistanceLabel.text = "\(dataObject.distance) \(unitString)"
        navigationImageView.image = dataObject.navigationImage()?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
    }
}

extension DeviceSimulatorViewController : KMBLEDeviceConnectViewControllerDelegate {
    func connectController(connectController: KMBLEDeviceConnectViewController, didConnectToPeripheral peripheral: CBPeripheral) {
        self.connectedPeripherals.append(peripheral)
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
        
        guard let cgImage = image?.CGImage else { return nil }
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
