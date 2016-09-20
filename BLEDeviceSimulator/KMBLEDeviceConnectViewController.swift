//
//  KMBLEDeviceConnectViewController.swift
//  KMBLENavigationKit
//
//  Created by Matthias Friese on 19.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import UIKit
import CoreBluetooth

protocol KMBLEDeviceConnectViewControllerDelegate : AnyObject {
    func connectController(connectController: KMBLEDeviceConnectViewController, didConnectToPeripheral peripheral: CBPeripheral)
}

class KMBLEDeviceConnectViewController: UIViewController {
    
    @IBOutlet weak var searchingDevicesIndicator: UIActivityIndicatorView!
    @IBOutlet weak var searchingDevicesLabel: UILabel!
    @IBOutlet weak var deviceTableView: UITableView!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    weak var delegate : KMBLEDeviceConnectViewControllerDelegate?
    
    private var peripherals = [CBPeripheral]()
    
    var central : KMBLECentral?
    
    override func viewDidLoad() {
        deviceTableView.isHidden = true
        
        if let central = central {
            central.delegate = self
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let central = central {
            searchingDevicesLabel.isHidden = false
            searchingDevicesIndicator.startAnimating()
            central.startDiscovery()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let central = central {
            searchingDevicesLabel.isHidden = true
            searchingDevicesIndicator.stopAnimating()
            central.stopDiscovery()
        }
    }
    
    
    //MARK: Actions
    
    
    @IBAction func handleTapOnDismissButton(sender: AnyObject) {
        dismissViewController()
    }
    
    
    //MARK: private methods
    
    private func dismissViewController() {
        if let presentingController = self.presentingViewController {
            presentingController.dismissViewControllerAnimated(true, completion: nil)
        }
    }
}

extension KMBLEDeviceConnectViewController : UITableViewDataSource {
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("deviceCell")
        
        if let deviceCell = cell as? KMBLEBluetoothDeviceCell {
            let peripheral = peripherals[indexPath.row]
            deviceCell.deviceNameLabel.text = peripheral.name != nil ? peripheral.name : peripheral.identifier.UUIDString
        }
        
        return cell!
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
}

extension KMBLEDeviceConnectViewController : UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let central = central {
            let peripheral = peripherals[indexPath.row]
            central.connect(peripheral)
        }
    }
    
}

extension KMBLEDeviceConnectViewController : KMBLECentralDelegate {
    func central(central: KMBLECentral, didDiscoverPeripherals foundPeripherals: [CBPeripheral]) {
        searchingDevicesLabel.isHidden = true
        searchingDevicesIndicator.stopAnimating()
        peripherals = foundPeripherals
        deviceTableView.isHidden = false
        deviceTableView.reloadData()
    }
    
    func central(central: KMBLECentral, didFailConnectToPeripheral: CBPeripheral, error: NSError?) {
        let alert = UIAlertController(title: "Connection error", message: error?.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func central(central: KMBLECentral, didConnectToPeripheral peripheral: CBPeripheral) {
        if let delegate = delegate {
            delegate.connectController(connectController: self, didConnectToPeripheral: peripheral)
        }
        dismiss(animated: true, completion: nil)
    }
    
    func central(central: KMBLECentral, didDisconnectFromPeripheral: CBPeripheral) {
        
    }
}
