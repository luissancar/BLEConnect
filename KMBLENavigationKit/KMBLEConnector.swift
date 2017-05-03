//
//  KMBLEConnector.swift
//  KMBLENavigationKit
//
//  Created by Matthias Friese on 18.07.16.
//  Copyright © 2016 komoot. All rights reserved.
//

import Foundation
import CoreBluetooth
#if DEBUG
//import CocoaLumberjack
#endif

@objc public protocol KMBLEConnectorDelegate {
    func bleConnector(_ bleConnector: KMBLEConnector, didFailToStartAdvertisingError: NSError)
    func centralDidSubscribedToCharacteristic(_ bleConnector: KMBLEConnector)
    func centralDidUnsubscribedToCharacteristic(_ bleConnector: KMBLEConnector)
    
    @objc optional
    func bleConnectorConnectionToCentralTimedOut(_ bleConnector: KMBLEConnector)
}

/**
    Log Level to use for logging.
*/
enum KMBLEConnectorLogLevel : String {
    case Debug = "DEBUG"
    case Info = "INFO"
    case Warn = "WARN"
    case Error = "ERROR"
}


/**
 Error inidicator to inform about the bluetooth connection errors that could happen.
 - BluetoothUnknowState: The system couldn't get the state of the bluetooth system
 - BluetoothLEUnavailable: The device doesn't support Bluetooth LE
 - BluetoothTurnedOff: The user turned off the bluetooth system
 - BluetoothNotAuthorized: The user declined the bluetooth background permission
 - SystemNotConfiguredCorrectly: You forgot to call setUpService
 - Success: Everything worked well
 */
public enum KMBLEConnectionErrorType: Error {
    case bluetoothUnknowState
    case bluetoothLEUnavailable
    case bluetoothTurnedOff
    case bluetoothNotAuthorized
    case systemNotConfiguredCorrectly
    case success
}

@objc open class KMBLEConnector : NSObject {
    
    open weak var delegate : KMBLEConnectorDelegate?
    open var loggingEnabled = false
    fileprivate static let restoreIdentifier = "KMBLEConnectorRestoreIdentifier"
    
    fileprivate let navigationServiceUUID = "71C1E128-D92F-4FA8-A2B2-0F171DB3436C"
    fileprivate let navigationServiceCharacteristicUUID = "503DD605-9BCB-4F6E-B235-270A57483026"
    
    fileprivate var advertisingIdentifier : String
    fileprivate var peripheralManager : CBPeripheralManager?
    fileprivate var navigationCharacteristic : CBMutableCharacteristic?
    
    fileprivate var subscribedCentrals = [CBCentral]()
    
    fileprivate var navigationService : CBMutableService?
    
    fileprivate var lastDataObjects  = [KMBLENavigationDataObject]()
    fileprivate var startTimer : Timer?
    fileprivate let startTimerMaxTime = 120.0
    fileprivate var connectionLostTimer : Timer?
    
    fileprivate let cacheNavigationObjectsCount = 10
    
    fileprivate let communicationQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
    
    
    /**
     Initializer
     
     - parameter advertisingIdentifier: The string which will get displayed on the external device while the user will connect to the app.
    */
    public init(advertisingIdentifier: String) {
        self.advertisingIdentifier = advertisingIdentifier
        super.init()
    }
    
    /**
     Setup the bluetooth system.
     
     Then you call this method a popup could appear to ask for the background permission "**bluetooth-peripheral**"
     */
    open func setUpService() {
        var startOptions = [String: Any]()
        startOptions[CBPeripheralManagerRestoredStateServicesKey] = KMBLEConnector.peripheralManagerRestoreKey()
        peripheralManager = CBPeripheralManager(delegate: self, queue: communicationQueue, options: startOptions)
        
        //move that to a different method
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        let backgroundPeripheral = backgroundModes?.contains("bluetooth-peripheral")
        
        assert(backgroundPeripheral == true, "Activate background-mode \"bluetooth-peripheral\"")
    }
    
    
    /** 
     Call this to shutdown the bluetooth system. It will also close the connection to the central.
    */
    open func stopService() {
        peripheralManager = nil
        startTimer?.invalidate()
        startTimer = nil
        connectionLostTimer?.invalidate()
        connectionLostTimer = nil
        lastDataObjects.removeAll()
    }
    
    /**
        Call this method from your didFinishLaunchingWithOptions method in the app delegate to restore the connected external devices.
     
        - parameter options: the launch options from the didFinishLaunchingWithOptions method
        
        - returns: Returns a Bool to indicate that the connection was restored.
     */
    open func didFinishLaunchingWithOptions(_ options: [UIApplicationLaunchOptionsKey: Any]?) -> Bool{
        if let options = options {
            if let peripheralManagerIdentifiers = options[UIApplicationLaunchOptionsKey.bluetoothPeripherals] as? [String] {
                for identifier in peripheralManagerIdentifiers {
                    if identifier == KMBLEConnector.peripheralManagerRestoreKey() {
                        setUpService()
                        return true
                    }
                }
            }
            return false
        }
        return false
    }
    
    /**
     Starts the bluetooth advertising of the komoot navigation service.
     
     - parameters shouldStartTimer: If you set this the advertising will stop automatically after 120 seconds.
     
     - returns: An error type to indicate that the advertising was started or an error happened. See KMBLEConnectionErrorType
     
    */
    open func startAdvertisingNavigationService(_ shouldStartTimer: Bool) -> KMBLEConnectionErrorType {
        if let peripheralManager = peripheralManager {
            if peripheralManager.state == .poweredOn {
                if peripheralManager.isAdvertising {
                    stopAdvertisingNavigationService()
                }
                var advertisementData = [String: Any]()
                advertisementData[CBAdvertisementDataServiceUUIDsKey] = [navigationService!.uuid]
                advertisementData[CBAdvertisementDataLocalNameKey] = self.advertisingIdentifier
                peripheralManager.startAdvertising(advertisementData)
                
                if let timer = startTimer {
                    timer.invalidate()
                }
                
                if shouldStartTimer == true {
                    startTimer = Timer.scheduledTimer(timeInterval: startTimerMaxTime, target: self, selector: #selector(advertisingTimerFired(_:)), userInfo: nil, repeats: false)
                }
                
                if CBPeripheralManager.authorizationStatus() == .denied {
                    log("couldn't start advertising authorizationStatus == Denied", logLevel: .Warn)
                    return .bluetoothNotAuthorized
                    
                } else {
                    log("did start advertising", logLevel: .Info)
                    return .success
                }
            } else {
                if peripheralManager.state == .poweredOff {
                    return KMBLEConnectionErrorType.bluetoothTurnedOff
                } else if peripheralManager.state == .unauthorized {
                    return .bluetoothNotAuthorized
                } else if peripheralManager.state == .unknown {
                    return .bluetoothUnknowState
                }
                return .bluetoothLEUnavailable
            }
        } else {
            return .systemNotConfiguredCorrectly
        }
        
    }
    
    /**
     Stops the bluetooth advertising of the komoot navigation service. This will automatically happen when a central subscripted to the service characteristic.
    */
    open func stopAdvertisingNavigationService() {
        if let peripheralManager = peripheralManager {
            if peripheralManager.isAdvertising {
                peripheralManager.stopAdvertising()
                log("stop advertising service", logLevel: .Info)
            }
        }
       
    }
    
    /**
     Enqueues a navigation data object to be send the subscripted centrals. The notification will only send the identifier to the central. The central has to start a read request to get the full information.
     
     - returns: An error type to indicate that the advertising was started or an error happened.  See KMBLEConnectionErrorType
     
     - seealso: [BLEConnect Documentation](https://github.com/komoot/BLEConnect)
     */
    open func sendNavigationDataObject(_ dataObject: KMBLENavigationDataObject) -> KMBLEConnectionErrorType {
        if let peripheralManager = peripheralManager {
            if (peripheralManager.state == .poweredOn) {
                if (connectionLostTimer == nil) {
                    restartConnectionLostTimer()
                }
                lastDataObjects.append(dataObject)
                
                if (lastDataObjects.count > cacheNavigationObjectsCount) {
                    lastDataObjects.remove(at: 0)
                }
                
                if let navigationCharacteristic = navigationCharacteristic {
                    var success : Bool
                    //refactor this to make it more clear
                    let data = dataObjectForIdentifier(dataObject.identifier)
                    success = peripheralManager.updateValue(data, for: navigationCharacteristic, onSubscribedCentrals: nil)
                    self.log("did send \(dataObject) successful \(success)", logLevel: .Info)
                }
                return .success
            } else {
                if peripheralManager.state == .poweredOff {
                    return .bluetoothTurnedOff
                } else if peripheralManager.state == .unauthorized {
                    return .bluetoothNotAuthorized
                }
                return .bluetoothLEUnavailable
            }
        } else {
            return .systemNotConfiguredCorrectly
        }
    }
    
    class func peripheralManagerRestoreKey() -> String {
        return restoreIdentifier
    }
    
    //MARK: private methods
    
    fileprivate func dataObjectForIdentifier(_ identifier: UInt32) -> Data {
        var dataIdentifier = identifier
        return Data(bytes: &dataIdentifier, count: MemoryLayout<UInt32>.size)
    }
    
    fileprivate func configureLogging() {
        #if DEBUG
           // DDLog.addLogger(DDTTYLogger.sharedInstance()) // TTY = Xcode console
           // DDLog.addLogger(DDASLLogger.sharedInstance()) // ASL = Apple System Logs
        #endif
    }
    
    /**
     logging method will forward to cocoa lumberjack if DEBUG is active otherwise it's sending a notification.
     */
    fileprivate func log(_ message: String, logLevel: KMBLEConnectorLogLevel) {
        if loggingEnabled == false {
            return
        }
        DispatchQueue.main.async { 
            #if DEBUG
/*                switch logLevel {
                case .Debug:
                    DDLogDebug(message)
                case .Info:
                    DDLogInfo(message)
                case .Error:
                    DDLogError(message)
                case .Warn:
                    DDLogWarn(message)
                }
 */
            #else
                NotificationCenter.default.post(name: Notification.Name(rawValue: "KMBLELogNotification"), object: self, userInfo: ["message": "\(logLevel): \(message)"])
            #endif
        }
    }
    
    fileprivate func buildService() -> CBMutableService {
        let serviceUUID = CBUUID(string: navigationServiceUUID)
        let serviceNavigationCharacteristicUUID = CBUUID(string: navigationServiceCharacteristicUUID)
        let navigationCharacteristic = CBMutableCharacteristic(type: serviceNavigationCharacteristicUUID,
                                                           properties: CBCharacteristicProperties(rawValue: CBCharacteristicProperties.notify.rawValue | CBCharacteristicProperties.read.rawValue),
                                                           value: nil,
                                                           permissions: CBAttributePermissions.readable)

        self.navigationCharacteristic = navigationCharacteristic
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [navigationCharacteristic]
        return service
    }
    
    fileprivate func restoreConnections(_ services: [CBMutableService]) {
        for service in services {
            //check if it is the right service
            if service.uuid == CBUUID(string: navigationServiceUUID) {
                if let characteristics = service.characteristics as? [CBMutableCharacteristic] {
                    for characteristic in characteristics {
                        if let subscribedCentrals = characteristic.subscribedCentrals {
                            for previousSubscriptedCentral in subscribedCentrals {
                                self.subscribedCentrals.append(previousSubscriptedCentral)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc fileprivate func advertisingTimerFired(_ timer: Timer) {
        if timer.isValid {
            stopAdvertisingNavigationService()
        }
        startTimer?.invalidate()
        startTimer = nil
        delegate?.bleConnectorConnectionToCentralTimedOut?(self)
    }
    
    @objc fileprivate func handleConnectionLostTimerFired(_ timer: Timer) {
        if timer.isValid {
            let errorType = startAdvertisingNavigationService(false)
            //try until bluetooth system is running again
            if errorType == .bluetoothTurnedOff {
                restartConnectionLostTimer()
            }
        }
    }
    
    fileprivate func restartConnectionLostTimer() {
        cancelConnectionLostTimer()
        connectionLostTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(handleConnectionLostTimerFired(_:)), userInfo: nil, repeats: false)
    }
    
    fileprivate func cancelConnectionLostTimer() {
        if let connectionLostTimer = connectionLostTimer {
            connectionLostTimer.invalidate()
        }
    }
}

extension KMBLEConnector: CBPeripheralManagerDelegate {
 
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        log("peripheral manager \(peripheral) switch to state \(peripheral.state)", logLevel: .Debug)

        if (peripheral.state == .poweredOn && navigationService == nil) {
                navigationService = buildService()
                peripheral.add(navigationService!)
        }
        
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            log("error while starting advertising \(error.localizedDescription)", logLevel: .Error)
            if let delegate = delegate {
                DispatchQueue.main.async(execute: {
                     delegate.bleConnector(self, didFailToStartAdvertisingError: error as NSError)
                })
            }
        } else {
            log("didStartAdvertising", logLevel: .Info)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        log("added service \(service.uuid.uuidString) error: \(error?.localizedDescription ?? "NO DESCRIPTION")", logLevel: .Info)
        //start advertising of service to enable reconnection
        let result = startAdvertisingNavigationService(false)
        print(result)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if characteristic.uuid == CBUUID(string: navigationServiceCharacteristicUUID) {
            self.subscribedCentrals.append(central)
        }
        
        stopAdvertisingNavigationService()
        connectionLostTimer?.invalidate()
        connectionLostTimer = nil
        log("didSubscribeToCharacteristic \(characteristic.uuid.uuidString) by \(central)", logLevel: .Info)
        
        DispatchQueue.main.async(execute: {
             self.delegate?.centralDidSubscribedToCharacteristic(self)
        })
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if characteristic.uuid == CBUUID(string: navigationServiceCharacteristicUUID) {
            if let index = self.subscribedCentrals.index(of: central) {
                self.subscribedCentrals.remove(at: index)
            }
        }
        if (self.subscribedCentrals.isEmpty) {
            DispatchQueue.main.async(execute: {
                self.delegate?.centralDidUnsubscribedToCharacteristic(self)
            })
        }
        
        log("didUnsubscribeFromCharacteristic \(characteristic.uuid.uuidString) by \(central)", logLevel: .Info)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        if let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] {
            self.restoreConnections(services)
        }
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        if let lastData = lastDataObjects.last , navigationCharacteristic != nil {
            peripheral.updateValue(lastData.convertToNSData() as Data, for: navigationCharacteristic!, onSubscribedCentrals: nil)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid.uuidString == navigationServiceCharacteristicUUID {
            if let dataObject = lastDataObjects.last {
                let dataValue = dataObject.convertToNSData()
                if request.offset > dataValue.count {
                    peripheral.respond(to: request, withResult: CBATTError.Code._ErrorType.invalidOffset)
                    return
                }
                request.value = dataValue.subdata(in: Range(uncheckedBounds:(request.offset, dataValue.count)))
                peripheral.respond(to: request, withResult: CBATTError.Code._ErrorType.success)
                DispatchQueue.main.async(execute: { 
                    self.restartConnectionLostTimer()
                })
                
            } else {
                log("Couldn't find any data objects", logLevel: .Error)
                peripheral.respond(to: request, withResult: CBATTError.Code._ErrorType.attributeNotFound)
            }
        } else {
            log("Couldn't respond to request. \(request) Unknown Characteristic \(request.characteristic.uuid.uuidString)", logLevel: .Error)
            assert(false, "Couldn't respond to request. \(request) Unknown Characteristic \(request.characteristic.uuid.uuidString)")
            peripheral.respond(to: request, withResult: CBATTError.Code._ErrorType.attributeNotFound)
        }
    }
    
}
