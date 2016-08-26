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
import CocoaLumberjack
#endif

@objc public protocol KMBLEConnectorDelegate {
    func bleConnector(bleConnector: KMBLEConnector, didFailToStartAdvertisingError: NSError)
    func centralDidSubscribedToCharacteristic(bleConnector: KMBLEConnector)
    func centralDidUnsubscribedToCharacteristic(bleConnector: KMBLEConnector)
    
    optional
    func bleConnectorConnectionToCentralTimedOut(bleConnector: KMBLEConnector)
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
public enum KMBLEConnectionErrorType: ErrorType {
    case BluetoothUnknowState
    case BluetoothLEUnavailable
    case BluetoothTurnedOff
    case BluetoothNotAuthorized
    case SystemNotConfiguredCorrectly
    case Success
}

@objc public class KMBLEConnector : NSObject {
    
    public weak var delegate : KMBLEConnectorDelegate?
    public var loggingEnabled = false
    private static let restoreIdentifier = "KMBLEConnectorRestoreIdentifier"
    
    private let navigationServiceUUID = "71C1E128-D92F-4FA8-A2B2-0F171DB3436C"
    private let navigationServiceCharacteristicUUID = "503DD605-9BCB-4F6E-B235-270A57483026"
    
    private var advertisingIdentifier : String
    private var peripheralManager : CBPeripheralManager?
    private var navigationCharacteristic : CBMutableCharacteristic?
    
    private var subscribedCentrals = [CBCentral]()
    
    private var navigationService : CBMutableService?
    
    private var lastDataObjects  = [KMBLENavigationDataObject]()
    private var startTimer : NSTimer?
    private let startTimerMaxTime = 120.0
    private var connectionLostTimer : NSTimer?
    
    private let cacheNavigationObjectsCount = 10
    
    private let communicationQueue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)
    
    
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
    public func setUpService() {
        var startOptions = [String: AnyObject]()
        startOptions[CBPeripheralManagerRestoredStateServicesKey] = KMBLEConnector.peripheralManagerRestoreKey()
        peripheralManager = CBPeripheralManager(delegate: self, queue: communicationQueue, options: startOptions)
        
        //move that to a different method
        let backgroundModes = NSBundle.mainBundle().objectForInfoDictionaryKey("UIBackgroundModes") as? [String]
        let backgroundPeripheral = backgroundModes?.contains("bluetooth-peripheral")
        
        assert(backgroundPeripheral == true, "Activate background-mode \"bluetooth-peripheral\"")
    }
    
    
    /** 
     Call this to shutdown the bluetooth system. It will also close the connection to the central.
    */
    public func stopService() {
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
    public func didFinishLaunchingWithOptions(options: [NSObject: AnyObject]?) -> Bool{
        if let peripheralManagerIdentifiers = options?[UIApplicationLaunchOptionsBluetoothPeripheralsKey] as? [String] {
            for identifier in peripheralManagerIdentifiers {
                if identifier == KMBLEConnector.peripheralManagerRestoreKey() {
                    setUpService()
                    return true
                }
            }
        }
        
        return false
    }
    
    /**
     Starts the bluetooth advertising of the komoot navigation service.
     
     - parameters shouldStartTimer: If you set this the advertising will stop automatically after 120 seconds.
     
     - returns: An error type to indicate that the advertising was started or an error happened. See KMBLEConnectionErrorType
     
    */
    public func startAdvertisingNavigationService(shouldStartTimer: Bool) -> KMBLEConnectionErrorType {
        if let peripheralManager = peripheralManager {
            if peripheralManager.state == .PoweredOn {
                if peripheralManager.isAdvertising {
                    stopAdvertisingNavigationService()
                }
                var advertisementData = [String: AnyObject]()
                advertisementData[CBAdvertisementDataServiceUUIDsKey] = [navigationService!.UUID]
                advertisementData[CBAdvertisementDataLocalNameKey] = self.advertisingIdentifier
                peripheralManager.startAdvertising(advertisementData)
                
                if let timer = startTimer {
                    timer.invalidate()
                }
                
                if shouldStartTimer == true {
                    startTimer = NSTimer.scheduledTimerWithTimeInterval(startTimerMaxTime, target: self, selector: #selector(advertisingTimerFired(_:)), userInfo: nil, repeats: false)
                }
                
                if CBPeripheralManager.authorizationStatus() == .Denied {
                    log("couldn't start advertising authorizationStatus == Denied", logLevel: .Warn)
                    return .BluetoothNotAuthorized
                    
                } else {
                    log("did start advertising", logLevel: .Info)
                    return .Success
                }
            } else {
                if peripheralManager.state == .PoweredOff {
                    return KMBLEConnectionErrorType.BluetoothTurnedOff
                } else if peripheralManager.state == .Unauthorized {
                    return .BluetoothNotAuthorized
                } else if peripheralManager.state == .Unknown {
                    return .BluetoothUnknowState
                }
                return .BluetoothLEUnavailable
            }
        } else {
            return .SystemNotConfiguredCorrectly
        }
        
    }
    
    /**
     Stops the bluetooth advertising of the komoot navigation service. This will automatically happen when a central subscripted to the service characteristic.
    */
    public func stopAdvertisingNavigationService() {
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
    public func sendNavigationDataObject(dataObject: KMBLENavigationDataObject) -> KMBLEConnectionErrorType {
        if let peripheralManager = peripheralManager {
            if (peripheralManager.state == .PoweredOn) {
                if (connectionLostTimer == nil) {
                    restartConnectionLostTimer()
                }
                lastDataObjects.append(dataObject)
                
                if (lastDataObjects.count > cacheNavigationObjectsCount) {
                    lastDataObjects.removeAtIndex(0)
                }
                
                if let navigationCharacteristic = navigationCharacteristic {
                    var success : Bool
                    //refactor this to make it more clear
                    let data = dataObjectForIdentifier(dataObject.identifier)
                    success = peripheralManager.updateValue(data, forCharacteristic: navigationCharacteristic, onSubscribedCentrals: nil)
                    self.log("did send \(dataObject) successful \(success)", logLevel: .Info)
                }
                return .Success
            } else {
                if peripheralManager.state == .PoweredOff {
                    return .BluetoothTurnedOff
                } else if peripheralManager.state == .Unauthorized {
                    return .BluetoothNotAuthorized
                }
                return .BluetoothLEUnavailable
            }
        } else {
            return .SystemNotConfiguredCorrectly
        }
    }
    
    class func peripheralManagerRestoreKey() -> String {
        return restoreIdentifier
    }
    
    //MARK: private methods
    
    private func dataObjectForIdentifier(identifier: UInt32) -> NSData {
        var dataIdentifier = identifier
        return NSData(bytes: &dataIdentifier, length: sizeof(UInt32))
    }
    
    private func configureLogging() {
        #if DEBUG
            DDLog.addLogger(DDTTYLogger.sharedInstance()) // TTY = Xcode console
            DDLog.addLogger(DDASLLogger.sharedInstance()) // ASL = Apple System Logs
        #endif
    }
    
    /**
     logging method will forward to cocoa lumberjack if DEBUG is active otherwise it's sending a notification.
     */
    private func log(message: String, logLevel: KMBLEConnectorLogLevel) {
        if loggingEnabled == false {
            return
        }
        dispatch_async(dispatch_get_main_queue()) { 
            #if DEBUG
                switch logLevel {
                case .Debug:
                    DDLogDebug(message)
                case .Info:
                    DDLogInfo(message)
                case .Error:
                    DDLogError(message)
                case .Warn:
                    DDLogWarn(message)
                }
            #else
                NSNotificationCenter.defaultCenter().postNotificationName("KMBLELogNotification", object: self, userInfo: ["message": "\(logLevel): \(message)"])
            #endif
        }
    }
    
    private func buildService() -> CBMutableService {
        let serviceUUID = CBUUID(string: navigationServiceUUID)
        let serviceNavigationCharacteristicUUID = CBUUID(string: navigationServiceCharacteristicUUID)
        let navigationCharacteristic = CBMutableCharacteristic(type: serviceNavigationCharacteristicUUID,
                                                           properties: CBCharacteristicProperties(rawValue: CBCharacteristicProperties.Notify.rawValue | CBCharacteristicProperties.Read.rawValue),
                                                           value: nil,
                                                           permissions: CBAttributePermissions.Readable)

        self.navigationCharacteristic = navigationCharacteristic
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [navigationCharacteristic]
        return service
    }
    
    private func restoreConnections(services: [CBMutableService]) {
        for service in services {
            //check if it is the right service
            if service.UUID == CBUUID(string: navigationServiceUUID) {
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
    
    @objc private func advertisingTimerFired(timer: NSTimer) {
        if timer.valid {
            stopAdvertisingNavigationService()
        }
        startTimer?.invalidate()
        startTimer = nil
        delegate?.bleConnectorConnectionToCentralTimedOut?(self)
    }
    
    @objc private func handleConnectionLostTimerFired(timer: NSTimer) {
        if timer.valid {
            let errorType = startAdvertisingNavigationService(false)
            //try until bluetooth system is running again
            if errorType == .BluetoothTurnedOff {
                restartConnectionLostTimer()
            }
        }
    }
    
    private func restartConnectionLostTimer() {
        cancelConnectionLostTimer()
        connectionLostTimer = NSTimer.scheduledTimerWithTimeInterval(5.0, target: self, selector: #selector(handleConnectionLostTimerFired(_:)), userInfo: nil, repeats: false)
    }
    
    private func cancelConnectionLostTimer() {
        if let connectionLostTimer = connectionLostTimer {
            connectionLostTimer.invalidate()
        }
    }
}

extension KMBLEConnector: CBPeripheralManagerDelegate {
 
    public func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        log("peripheral manager \(peripheral) switch to state \(peripheral.state)", logLevel: .Debug)

        if (peripheral.state == .PoweredOn && navigationService == nil) {
                navigationService = buildService()
                peripheral.addService(navigationService!)
        }
        
    }
    
    public func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        if let error = error {
            log("error while starting advertising \(error.localizedDescription)", logLevel: .Error)
            if let delegate = delegate {
                dispatch_async(dispatch_get_main_queue(), {
                     delegate.bleConnector(self, didFailToStartAdvertisingError: error)
                })
            }
        } else {
            log("didStartAdvertising", logLevel: .Info)
        }
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        log("added service \(service.UUID.UUIDString) error: \(error?.localizedDescription)", logLevel: .Info)
        //start advertising of service to enable reconnection
        startAdvertisingNavigationService(false)
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        if characteristic.UUID == CBUUID(string: navigationServiceCharacteristicUUID) {
            self.subscribedCentrals.append(central)
        }
        
        stopAdvertisingNavigationService()
        connectionLostTimer?.invalidate()
        connectionLostTimer = nil
        log("didSubscribeToCharacteristic \(characteristic.UUID.UUIDString) by \(central)", logLevel: .Info)
        
        dispatch_async(dispatch_get_main_queue(), {
             self.delegate?.centralDidSubscribedToCharacteristic(self)
        })
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        if characteristic.UUID == CBUUID(string: navigationServiceCharacteristicUUID) {
            if let index = self.subscribedCentrals.indexOf(central) {
                self.subscribedCentrals.removeAtIndex(index)
            }
        }
        if (self.subscribedCentrals.isEmpty) {
            dispatch_async(dispatch_get_main_queue(), {
                self.delegate?.centralDidUnsubscribedToCharacteristic(self)
            })
        }
        
        log("didUnsubscribeFromCharacteristic \(characteristic.UUID.UUIDString) by \(central)", logLevel: .Info)
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, willRestoreState dict: [String : AnyObject]) {
        if let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] {
            self.restoreConnections(services)
        }
    }
    
    public func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        if let lastData = lastDataObjects.last where navigationCharacteristic != nil {
            peripheral.updateValue(lastData.convertToNSData(), forCharacteristic: navigationCharacteristic!, onSubscribedCentrals: nil)
        }
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
        if request.characteristic.UUID.UUIDString == navigationServiceCharacteristicUUID {
            if let dataObject = lastDataObjects.last {
                let dataValue = dataObject.convertToNSData()
                if request.offset > dataValue.length {
                    peripheral.respondToRequest(request, withResult: CBATTError.InvalidOffset)
                    return
                }
                request.value = dataValue.subdataWithRange(NSMakeRange(request.offset, dataValue.length - request.offset))
                peripheral.respondToRequest(request, withResult: CBATTError.Success)
                dispatch_async(dispatch_get_main_queue(), { 
                    self.restartConnectionLostTimer()
                })
                
            } else {
                log("Couldn't find any data objects", logLevel: .Error)
                peripheral.respondToRequest(request, withResult: CBATTError.AttributeNotFound)
            }
        } else {
            log("Couldn't respond to request. \(request) Unknown Characteristic \(request.characteristic.UUID.UUIDString)", logLevel: .Error)
            assert(false, "Couldn't respond to request. \(request) Unknown Characteristic \(request.characteristic.UUID.UUIDString)")
            peripheral.respondToRequest(request, withResult: CBATTError.AttributeNotFound)
        }
    }
    
}