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
    
    fileprivate let restoreKey = "KMBLECentralRestoreKey"
    fileprivate static let navigationServiceUUID = "71C1E128-D92F-4FA8-A2B2-0F171DB3436C"
    fileprivate let navigationServiceNotifyCharacteristicUUID = "503DD605-9BCB-4F6E-B235-270A57483026"
    fileprivate let navigationServiceHeartbeatWriteCharacteristicUUID = "6D75DBF0-D763-4147-942A-D97B1BC700CF"
    
    
    fileprivate var centralManager : CBCentralManager!
    fileprivate var foundPeripherals : [CBPeripheral]?
    fileprivate var connectedPeripheral : CBPeripheral?
    fileprivate var observedCharacteristic : CBCharacteristic?
    fileprivate var writeCharacteristic : CBCharacteristic?
    
    private var knownPeripheralIds : [String]?
    private let knownPeripheralIdsUserDefaultsKey = "KMBLECentralKnowPeripheralIdsUserDefaultsKey"
    
    override init() {
        super.init()
        
        knownPeripheralIds = loadKnownPeripheralsFromUserDefaults()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main, options: [CBCentralManagerOptionRestoreIdentifierKey: restoreKey])
    }
    
    func startDiscovery() {
        foundPeripherals = nil
        if #available(iOS 9.0, *) {
            if #available(iOS 10.0, *) {
                if (centralManager.state == CBManagerState.poweredOn && centralManager.isScanning == false) {
                    centralManager.scanForPeripherals(withServices: [CBUUID(string: KMBLECentral.navigationServiceUUIDString())], options: nil)
                }
            } else {
                if (centralManager.state.rawValue == CBCentralManagerState.poweredOn.rawValue && centralManager.isScanning == false) {
                    centralManager.scanForPeripherals(withServices: [CBUUID(string: KMBLECentral.navigationServiceUUIDString())], options: nil)
                }
            }
        } else {
            if (centralManager.state.rawValue == CBCentralManagerState.poweredOn.rawValue) {
                centralManager.scanForPeripherals(withServices: [CBUUID(string: KMBLECentral.navigationServiceUUIDString())], options: nil)
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
                uuids.append(NSUUID(uuidString: idString)!)
            }
            
            let peripherals = centralManager.retrievePeripherals(withIdentifiers: uuids as [UUID])
            foundPeripherals = peripherals
            
            if let foundPeripherals = foundPeripherals {
                for peripheral in foundPeripherals {
                    connect(peripheral: peripheral)
                }
            }
            
        }
        
    }
    
    func connect(peripheral: CBPeripheral) {
        DDLogInfo("trying to connect to peripheral \(peripheral.identifier.uuidString)")
        stopDiscovery()
        centralManager.connect(peripheral, options: nil)
    }
    
    func connectedPeripherals() -> [CBPeripheral] {
        return centralManager.retrieveConnectedPeripherals(withServices: [CBUUID(string: KMBLECentral.navigationServiceUUIDString())])
    }
    
    func disconnectPeripherals() {
        if let connectedPeripheral = connectedPeripheral {
            if let observedCharacteristic = observedCharacteristic {
                connectedPeripheral.setNotifyValue(false, for: observedCharacteristic)
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
        let userDefaults = UserDefaults.standard
        var idsArray : [String]
        if let storedIds = userDefaults.array(forKey: knownPeripheralIdsUserDefaultsKey) as? [String] {
            idsArray = storedIds
        } else {
            idsArray = [String]()
        }
        return idsArray
    }
    
    fileprivate func addKnownPeripheralToUserDefaults(peripheralID: String) {
        knownPeripheralIds = loadKnownPeripheralsFromUserDefaults()
        if knownPeripheralIds?.contains(peripheralID) == false {
            if (knownPeripheralIds?.count)! > 0 {
                knownPeripheralIds?.removeAll()
            }
            knownPeripheralIds?.append(peripheralID)
            let userDefaults = UserDefaults.standard
            userDefaults.set(knownPeripheralIds, forKey: knownPeripheralIdsUserDefaultsKey)
            userDefaults.synchronize()
        }
    }
}

extension KMBLECentral : CBCentralManagerDelegate {
    
    @objc func centralManagerDidUpdateState(_ central: CBCentralManager) {
         DDLogDebug("central manager \(central) switch to state \(central.state)")
        
        if central.state == .poweredOn {
            restoreConnectionToLastKnownPeriperal()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if foundPeripherals == nil {
            foundPeripherals = [CBPeripheral]()
        }
        
        if var foundPeripherals = foundPeripherals {
            foundPeripherals.append(peripheral)
            
            if let delegate = delegate {
                delegate.central(central: self, didDiscoverPeripherals: foundPeripherals)
            }
        }

    
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
        
        let navigationServiceUUIDObject = CBUUID(string: KMBLECentral.navigationServiceUUIDString())
        let recoverPeripherals = peripherals?.filter({ (peripheral: CBPeripheral) -> Bool in
            var found = false
            if let services = peripheral.services {
                for service in services {
                    if service.uuid == navigationServiceUUIDObject {
                        found = true
                        break
                    }
                }
            }
            return found
        })
        foundPeripherals = recoverPeripherals
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DDLogInfo("did connect to peripheral \(peripheral.identifier.uuidString)")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        
        self.addKnownPeripheralToUserDefaults(peripheralID: peripheral.identifier.uuidString)
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DDLogError("error while connecting to peripheral \(error?.localizedDescription ?? "NO DESCRIPTION")")
        if let delegate = delegate {
            delegate.central(central: self, didFailConnectToPeripheral: peripheral, error: error as NSError?)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DDLogInfo("disconnect from peripheral")
        if connectedPeripheral == peripheral {
            delegate?.central(central: self, didDisconnectFromPeripheral: connectedPeripheral!)
            connectedPeripheral = nil
        }
    }
}

extension KMBLECentral: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            DDLogError("error while connecting to peripheral \(error.localizedDescription)")
            if let delegate = delegate {
                delegate.central(central: self, didFailConnectToPeripheral: peripheral, error: error as NSError?)
            }
            return
        }
        
        if let services = peripheral.services {
            if services.count == 0 {
                let error = NSError(domain: "KMBLECentralErrorDomain", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey: "No services found for device"])
                self.delegate?.central(central: self, didFailConnectToPeripheral: peripheral, error: error)
            } else {
                for service in services {
                    DDLogDebug("Discovered service \(service.uuid.uuidString)")
                    if service.uuid.uuidString == KMBLECentral.navigationServiceUUIDString() {
                        DDLogInfo("Check Characteristics for service \(service.uuid.uuidString)")
                        peripheral.discoverCharacteristics(nil, for: service)
                        return
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characterisistics = service.characteristics {
            for characterisistic in characterisistics {
                DDLogDebug("Discovered characteristic \(characterisistic.uuid.uuidString)")
                if characterisistic.uuid.uuidString == navigationServiceNotifyCharacteristicUUID {
                    self.observedCharacteristic = characterisistic
                    peripheral.setNotifyValue(true, for: characterisistic)
                    
                    DDLogInfo("Subscriped for changes on \(characterisistic.uuid.uuidString)")
                    
                    if let delegate = delegate {
                        delegate.central(central: self, didConnectToPeripheral: peripheral)
                    }
                }
                
                if characterisistic.uuid.uuidString == navigationServiceHeartbeatWriteCharacteristicUUID {
                    self.writeCharacteristic = characterisistic
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        DDLogInfo("peripheral \(peripheral.identifier.uuidString) didUpdateValueForCharacteristic \(characteristic) error: \(error?.localizedDescription ?? "NO DESCRIPTION")")
        
        if characteristic.uuid.uuidString == navigationServiceNotifyCharacteristicUUID {
            var valueLength = 0
            if let value = characteristic.value { valueLength = value.count }
            if characteristic.properties == CBCharacteristicProperties.read || characteristic.value == nil || valueLength < 20 {
                //data is not complete. I have to read it first.
                DDLogInfo("request data to read")
                peripheral.readValue(for: characteristic)
            } else {
                DDLogInfo("got data to display. raw data: \(String(describing: characteristic.value))")
                if let data = characteristic.value {
                    let dataObject = KMBLENavigationObject(data: data as NSData)
                    DDLogInfo("parsed data \(dataObject)")
                    
                    DispatchQueue.main.async(execute: {
                        self.dataDelegate?.centralDidReceiveDataObject(dataObject: dataObject)
                    })
                }
            }
        } else {
            DDLogDebug("got data for unknow characteristic \(characteristic.uuid.uuidString)")
        }
    }
    
    
}
