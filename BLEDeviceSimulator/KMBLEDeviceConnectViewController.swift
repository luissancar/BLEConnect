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
    
    weak var delegate : KMBLEDeviceConnectViewControllerDelegate?
    
    private var peripherals = [CBPeripheral]()
    
    var central : KMBLECentral?
    
    override func viewDidLoad() {
        deviceTableView.hidden = true
        
        if let central = central {
            central.delegate = self
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if let central = central {
            searchingDevicesLabel.hidden = false
            searchingDevicesIndicator.startAnimating()
            central.startDiscovery()
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        if let central = central {
            searchingDevicesLabel.hidden = true
            searchingDevicesIndicator.stopAnimating()
            central.stopDiscovery()
        }
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .Default
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
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
        searchingDevicesLabel.hidden = true
        searchingDevicesIndicator.stopAnimating()
        peripherals = foundPeripherals
        deviceTableView.hidden = false
        deviceTableView.reloadData()
    }
    
    func central(central: KMBLECentral, didFailConnectToPeripheral: CBPeripheral, error: NSError?) {
        let alert = UIAlertController(title: "Connection error", message: error?.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func central(central: KMBLECentral, didConnectToPeripheral peripheral: CBPeripheral) {
        if let delegate = delegate {
            delegate.connectController(self, didConnectToPeripheral: peripheral)
        }
        dismissViewController()
    }
    
    func central(central: KMBLECentral, didDisconnectFromPeripheral: CBPeripheral) {
        
    }
}