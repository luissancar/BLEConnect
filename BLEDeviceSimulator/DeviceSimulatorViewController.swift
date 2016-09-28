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

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    @IBOutlet weak var connectButton : UIButton!
    @IBOutlet weak var console: PTEConsoleTableView!
    
    @IBOutlet weak var navigationImageView: UIImageView!
    @IBOutlet weak var navigationStreetnameLabel: UILabel!
    @IBOutlet weak var navigationDistanceLabel: UILabel!
    
    fileprivate var connectedPeripherals = [CBPeripheral]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        connectButton.layer.cornerRadius = 6.0
        connectButton.clipsToBounds = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let central = central {
            central.delegate = self
        }
        
        updateButtonStates()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let deviceNavigationController = segue.destination as? UINavigationController {
            if let deviceConnectViewController = deviceNavigationController.viewControllers.first as? KMBLEDeviceConnectViewController {
                deviceConnectViewController.central = central
                deviceConnectViewController.delegate = self
            }
        }
        super.prepare(for: segue, sender: sender)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
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
    
    
    //MARK: private functions
    
    fileprivate func updateButtonStates() {
            if connectedPeripherals.count > 0 {
                connectButton.setBackgroundImage(UIImage(color: UIColor(hex: "#F1F1F1")!), for: UIControlState.normal)
                connectButton.setBackgroundImage(UIImage(color: UIColor(hex: "#D2D2D2")!), for: UIControlState.highlighted)
                connectButton.setTitle("Disconnect", for: UIControlState.normal)
                connectButton.setTitleColor(UIColor.black, for: UIControlState.normal)
            } else {
                connectButton.setBackgroundImage(UIImage(color: UIColor(hex: "#78B62E")!), for: UIControlState.normal)
                connectButton.setBackgroundImage(UIImage(color: UIColor(hex: "#5E9422")!), for: UIControlState.highlighted)
                connectButton.setTitle("Start Connection", for: UIControlState.normal)
                connectButton.setTitleColor(UIColor.white, for: UIControlState.normal)
            }
        
    }
    
    fileprivate func resetSimulationViewState() {
        navigationImageView.image = nil
        navigationDistanceLabel.text = "distance"
        navigationStreetnameLabel.text = "street"
    }
}

extension DeviceSimulatorViewController : KMBLECentralDelegate {
    
    func central(central: KMBLECentral, didConnectToPeripheral peripheral: CBPeripheral) {
        connectedPeripherals.append(peripheral)
        updateButtonStates()
        resetSimulationViewState()
    }
    
    func central(central: KMBLECentral, didDiscoverPeripherals: [CBPeripheral]) {
        
    }
    
    func central(central: KMBLECentral, didDisconnectFromPeripheral peripheral: CBPeripheral) {
        if let index = connectedPeripherals.index(of: peripheral) {
            self.connectedPeripherals.remove(at: index)
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
        navigationImageView.image = dataObject.navigationImage()?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
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
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}

extension UIColor {
    convenience init?(hex: String) {
        
            var cString:String = (hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)).uppercased()
            
            if (cString.hasPrefix("#")) {
                cString = cString.substring(from: cString.index(cString.startIndex, offsetBy: 1))
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
