//
//  KMBLECentral.swift
//  KMBLENavigationKit
//
//  Created by Matthias Friese on 19.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import Foundation
import CoreBluetooth
import CocoaLumberjack

protocol KMBLECentralDelegate : AnyObject {
    
    func central(central: KMBLECentral, didDiscoverPeripherals:[CBPeripheral])
    
    func central(central: KMBLECentral, didConnectToPeripheral:CBPeripheral)
    func central(central: KMBLECentral, didFailConnectToPeripheral:CBPeripheral, error: NSError?)
    func central(central: KMBLECentral, didDisconnectFromPeripheral:CBPeripheral)
}

protocol KMBLEDataDelegate : AnyObject {
    
    func centralDidReceiveDataObject(dataObject: KMBLENavigationObject)
    
}

class KMBLECentral : NSObject {
    
    weak var delegate : KMBLECentralDelegate?
    weak var dataDelegate : KMBLEDataDelegate?
    
    private let restoreKey = "KMBLECentralRestoreKey"
    private static let navigationServiceUUID = "71C1E128-D92F-4FA8-A2B2-0F171DB3436C"
    private let navigationServiceNotifyCharacteristicUUID = "503DD605-9BCB-4F6E-B235-270A57483026"
    private let navigationServiceHeartbeatWriteCharacteristicUUID = "6D75DBF0-D763-4147-942A-D97B1BC700CF"
    
    
    private var centralManager : CBCentralManager!
    private var foundPeripherals : [CBPeripheral]?
    private var connectedPeripheral : CBPeripheral?
    private var observedCharacteristic : CBCharacteristic?
    private var writeCharacteristic : CBCharacteristic?
    
    private var knownPeripheralIds : [String]?
    private let knownPeripheralIdsUserDefaultsKey = "KMBLECentralKnowPeripheralIdsUserDefaultsKey"
    
    override init() {
        super.init()
        
        knownPeripheralIds = loadKnownPeripheralsFromUserDefaults()
        centralManager = CBCentralManager(delegate: self, queue: dispatch_get_main_queue(), options: [CBCentralManagerOptionRestoreIdentifierKey: restoreKey])
    }
    
    func startDiscovery() {
        foundPeripherals = nil
        if #available(iOS 9.0, *) {
            if (centralManager.state == CBCentralManagerState.PoweredOn && centralManager.isScanning == false) {
                centralManager.scanForPeripheralsWithServices([CBUUID(string: KMBLECentral.navigationServiceUUIDString())], options: nil)
            }
        } else {
            if (centralManager.state == CBCentralManagerState.PoweredOn) {
                centralManager.scanForPeripheralsWithServices([CBUUID(string: KMBLECentral.navigationServiceUUIDString())], options: nil)
            }
        }
    }
    
    func stopDiscovery() {
        if #available(iOS 9.0, *) {
            if centralManager.isScanning {
                centralManager.stopScan()
            }
        } else {
            centralManager.stopScan()
        }
    }
    
    func restoreConnectionToLastKnownPeriperal() {
        
        if let knownPeripheralIds = knownPeripheralIds {
            var uuids = [NSUUID]()
            
            for idString in knownPeripheralIds {
                uuids.append(NSUUID(UUIDString: idString)!)
            }
            
            let peripherals = centralManager.retrievePeripheralsWithIdentifiers(uuids)
            foundPeripherals = peripherals
            
            if let foundPeripherals = foundPeripherals {
                for peripheral in foundPeripherals {
                    connect(peripheral)
                }
            }
            
        }
        
    }
    
    func connect(peripheral: CBPeripheral) {
        DDLogInfo("trying to connect to peripheral \(peripheral.identifier.UUIDString)")
        stopDiscovery()
        centralManager.connectPeripheral(peripheral, options: nil)
    }
    
    func connectedPeripherals() -> [CBPeripheral] {
        return centralManager.retrieveConnectedPeripheralsWithServices([CBUUID(string: KMBLECentral.navigationServiceUUIDString())])
    }
    
    func disconnectPeripherals() {
        if let connectedPeripheral = connectedPeripheral {
            if let observedCharacteristic = observedCharacteristic {
                connectedPeripheral.setNotifyValue(false, forCharacteristic: observedCharacteristic)
                self.observedCharacteristic = nil
            }
            centralManager.cancelPeripheralConnection(connectedPeripheral)
        }
    }
    
    class func navigationServiceUUIDString() -> String {
        return navigationServiceUUID
    }
    
    //MARK: private func
    
    private func loadKnownPeripheralsFromUserDefaults() -> [String] {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        var idsArray : [String]
        if let storedIds = userDefaults.arrayForKey(knownPeripheralIdsUserDefaultsKey) as? [String] {
            idsArray = storedIds
        } else {
            idsArray = [String]()
        }
        return idsArray
    }
    
    private func addKnownPeripheralToUserDefaults(peripheralID: String) {
        knownPeripheralIds = loadKnownPeripheralsFromUserDefaults()
        if knownPeripheralIds?.contains(peripheralID) == false {
            if knownPeripheralIds?.count > 0 {
                knownPeripheralIds?.removeAll()
            }
            knownPeripheralIds?.append(peripheralID)
            let userDefaults = NSUserDefaults.standardUserDefaults()
            userDefaults.setObject(knownPeripheralIds, forKey: knownPeripheralIdsUserDefaultsKey)
            userDefaults.synchronize()
        }
    }
}

extension KMBLECentral : CBCentralManagerDelegate {
    
    @objc func centralManagerDidUpdateState(central: CBCentralManager) {
         DDLogDebug("central manager \(central) switch to state \(central.state)")
        
        if central.state == .PoweredOn {
            restoreConnectionToLastKnownPeriperal()
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        if foundPeripherals == nil {
            foundPeripherals = [CBPeripheral]()
        }
        
        if var foundPeripherals = foundPeripherals {
            foundPeripherals.append(peripheral)
            
            if let delegate = delegate {
                delegate.central(self, didDiscoverPeripherals: foundPeripherals)
            }
        }
        
    }
    
    func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
        
        let navigationServiceUUIDObject = CBUUID(string: KMBLECentral.navigationServiceUUIDString())
        let recoverPeripherals = peripherals?.filter({ (peripheral: CBPeripheral) -> Bool in
            var found = false
            if let services = peripheral.services {
                for service in services {
                    if service.UUID == navigationServiceUUIDObject {
                        found = true
                        break
                    }
                }
            }
            return found
        })
        foundPeripherals = recoverPeripherals
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        DDLogInfo("did connect to peripheral \(peripheral.identifier.UUIDString)")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        
        self.addKnownPeripheralToUserDefaults(peripheral.identifier.UUIDString)
        peripheral.discoverServices(nil)
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        DDLogError("error while connecting to peripheral \(error?.localizedDescription)")
        if let delegate = delegate {
            delegate.central(self, didFailConnectToPeripheral: peripheral, error: error)
        }
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        DDLogInfo("disconnect from peripheral")
        if connectedPeripheral == peripheral {
            delegate?.central(self, didDisconnectFromPeripheral: connectedPeripheral!)
            connectedPeripheral = nil
        }
    }
}

extension KMBLECentral: CBPeripheralDelegate {
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if let error = error {
            DDLogError("error while connecting to peripheral \(error.localizedDescription)")
            if let delegate = delegate {
                delegate.central(self, didFailConnectToPeripheral: peripheral, error: error)
            }
            return
        }
        
        if let services = peripheral.services {
            if services.count == 0 {
                let error = NSError(domain: "KMBLECentralErrorDomain", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey: "No services found for device"])
                self.delegate?.central(self, didFailConnectToPeripheral: peripheral, error: error)
            } else {
                for service in services {
                    DDLogDebug("Discovered service \(service.UUID.UUIDString)")
                    if service.UUID.UUIDString == KMBLECentral.navigationServiceUUIDString() {
                        DDLogInfo("Check Characteristics for service \(service.UUID.UUIDString)")
                        peripheral.discoverCharacteristics(nil, forService: service)
                        return
                    }
                }
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if let characterisistics = service.characteristics {
            for characterisistic in characterisistics {
                DDLogDebug("Discovered characteristic \(characterisistic.UUID.UUIDString)")
                if characterisistic.UUID.UUIDString == navigationServiceNotifyCharacteristicUUID {
                    self.observedCharacteristic = characterisistic
                    peripheral.setNotifyValue(true, forCharacteristic: characterisistic)
                    
                    DDLogInfo("Subscriped for changes on \(characterisistic.UUID.UUIDString)")
                    
                    if let delegate = delegate {
                        delegate.central(self, didConnectToPeripheral: peripheral)
                    }
                }
                
                if characterisistic.UUID.UUIDString == navigationServiceHeartbeatWriteCharacteristicUUID {
                    self.writeCharacteristic = characterisistic
                }
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        DDLogInfo("peripheral \(peripheral.identifier.UUIDString) didUpdateValueForCharacteristic \(characteristic) error: \(error?.localizedDescription)")
        
        if characteristic.UUID.UUIDString == navigationServiceNotifyCharacteristicUUID {
            if characteristic.properties == CBCharacteristicProperties.Read || characteristic.value == nil || characteristic.value?.length < 20 {
                //data is not complete. I have to read it first.
                DDLogInfo("request data to read")
                peripheral.readValueForCharacteristic(characteristic)
            } else {
                DDLogInfo("got data to display. raw data: \(characteristic.value)")
                if let data = characteristic.value {
                    let dataObject = KMBLENavigationObject(data: data)
                    DDLogInfo("parsed data \(dataObject)")
                    
                    dispatch_async(dispatch_get_main_queue(), { 
                        self.dataDelegate?.centralDidReceiveDataObject(dataObject)
                    })
                }
            }
        } else {
            DDLogDebug("got data for unknow characteristic \(characteristic.UUID.UUIDString)")
        }
    }
    
    
}