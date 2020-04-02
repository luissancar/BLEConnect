![](assets/Komoot-ble-github-header.png)

## BLEConnect

With komoot BLE Connect, you enable your BLE device to show navigation instructions for cycling, running and outdoor routes delivered by komoot Apps for Android and iOS. [https://www.komoot.com/b2b/connect](https://www.komoot.com/b2b/connect)

For questions about partnerships and having your device listed in the komoot Apps please contact us: partner@komoot.de

All you need to implement this is found here:

- [How it works](#headerHowItWorks)
- [BLE Service Specification](#headerBLESpecification)
- [Transferred data](#headerData)  

<a name="headerHowItWorks"></a>
## How it works

### Connect to komoot App
<div style="text-align:center"><img src="assets/BLE-Connect.png" width="673" /></div>

### Pairing on Android (not iOS)
Before a connection can be established, your external BLE device has to be paired (authorized) with the Android OS. Go to the Android Bluetooth settings and pair your device first.

#### Komoot App
The user activates BLE Connect inside the komoot app settings. When doing so, the app starts advertising the komoot navigation BLE service and tells the user to start pairing via their external BLE device.
The komoot app stops advertising once the connection to the characteristic is established.

#### Your device / what you implement
The external BLE device is responsible to establish the connection and subscribing to the komoot navigation service characteristic. Your device should search for the komoot navigation service (UUID defined below). Otherwise it might be possible that you won’t find the komoot app while the app is in background (not visible on iOS in that case).

**Please note**: The advertisement data on iOS are different while the app is running in background. For details please check [Apple developer documentation](https://developer.apple.com/library/ios/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW1).



### Receive Navigation Instructions
<div style="text-align:center"><img src="assets/BLE-SendNavigation.png" width="673" /></div>

#### Komoot App
The komoot app sends instructions data about once per second when a navigation gets started or resumed in the komoot app. The transferred data format is described in detail [below](#headerData).

#### Your device / what you implement
The komoot app announces new data by updating a BLE characteristic. Once you receive a notification about the change, you have to start a read request on that characteristic to get the data object of the last navigation instruction.

The komoot app delivers up to 22 bytes (iOS) or 20 bytes (Android) with the first response. You can do subsequent read request with shifted offsets (22 iOS, 20 Android) to retrieve more information like the rest of the street name if the street name is too long to fit into the first response. When the komoot app delivers less than 22 bytes (iOS) or 20 bytes (Android), or you get an offset error, or a zero-sized byte array you know that you got the complete Navigation Instruction.

### Reconnect and connection status

#### Komoot App
The komoot app repeats the last navigation instruction every 2 seconds. It observes your read requests, and if there hasn’t been a read request for a longer time (5 sec. ), the app assumes that the connection got lost and will start advertising the service again. Your device configured as a BLE central should then initiate a reconnect.

#### Your device / what you implement
You have to start scanning for the navigation service once you detect the connection to the peripheral got lost. After a few seconds, the komoot app will start advertising.

<a name="headerBLESpecification"></a>
## BLE Service Specification

| UUID | Description  | Access  |
|---|---|---|
|71C1E128-D92F-4FA8-A2B2-0F171DB3436C|GATT Primary Service Declaration|Readonly|
|503DD605-9BCB-4F6E-B235-270A57483026|GATT Characteristic to subscribe for navigation updates|Notify, Readonly|

<a name="headerData"></a>
## Transferred Data
When you read the GATT characteristic after you got notified, you will receive the following data.

![Data structure](assets/BLE-Data.png)

- [Identifier](#data_identifier) (UInt32)
- [Direction Arrow](#data_directionArrows) (UInt8)
- [Street](#data_street) (UTF8 string)
- [Distance](#data_distance) (UInt32)

<a name="data_identifier"></a>
### Identifier

UInt32 value to identify a single navigation instruction. Use this identifier for sending the read request to the characteristic. If we get a read request without this identifier, we will deliver the last data object.

<a name="data_directionArrows"></a>
### Direction Arrows

<img src="assets/directions.jpg" width="300" />

The direction will be represented as an UInt8 value. The following list shows the mapping between the image and the corresponding UInt8 value. This list could be extended in future.

You can download the arrows [here](assets/nav-icons/navigationArrows.zip) or make your own design.


| Direction | Number value  | Description |
|:---:|---|---|
|No image|0|Reserved|
|![straight](assets/nav-icons/ic_nav_arrow_keep_going.png)|1|Go Straight|
|![start](assets/nav-icons/ic_nav_arrow_start.png)|2|Start|
|![finish](assets/nav-icons/ic_nav_arrow_finish.png)|3|Finish|
|![slight left](assets/nav-icons/ic_nav_arrow_keep_left.png)|4|Slight Left|
|![left](assets/nav-icons/ic_nav_arrow_turn_left.png)|5|Left|
|![sharp left](assets/nav-icons/ic_nav_arrow_turn_hard_left.png)|6|Sharp Left|
|![sharp right](assets/nav-icons/ic_nav_arrow_turn_hard_right.png)|7|Sharp Right|
|![right](assets/nav-icons/ic_nav_arrow_turn_right.png)|8|Right|
|![slight right](assets/nav-icons/ic_nav_arrow_keep_right.png)|9|Slight Right|
|![fork right](assets/nav-icons/ic_nav_arrow_fork_right.png)|10|Fork Right|
|![fork left](assets/nav-icons/ic_nav_arrow_fork_left.png)|11|Fork Left|
|![u-turn](assets/nav-icons/ic_nav_arrow_uturn.png)|12|U-Turn|
|No image|13|Reserved|
|No image|14|Reserved|
|![roundabout exit left](assets/nav-icons/ic_nav_roundabout_exit_cw.png)|15|Roundabout Exit Left|
|![roundabout exit right](assets/nav-icons/ic_nav_roundabout_exit_ccw.png)|16|Roundabout Exit Right|
|![roundabout CCW exit 1-1](assets/nav-icons/ic_nav_roundabout_ccw1_1.png)|17|Roundabout Counter Clockwise Exit 1 of 1|
|![roundabout CCW exit 1-2](assets/nav-icons/ic_nav_roundabout_ccw1_2.png)|18|Roundabout Counter Clockwise Exit 1 of 2|
|![roundabout CCW exit 1-3](assets/nav-icons/ic_nav_roundabout_ccw1_3.png)|19|Roundabout Counter Clockwise Exit 1 of 3|
|![roundabout CCW exit 2-2](assets/nav-icons/ic_nav_roundabout_ccw2_2.png)|20|Roundabout Counter Clockwise Exit 2 of 2|
|![roundabout CCW exit 2-3](assets/nav-icons/ic_nav_roundabout_ccw2_3.png)|21|Roundabout Counter Clockwise Exit 2 of 3|
|![roundabout CCW exit 3-3](assets/nav-icons/ic_nav_roundabout_ccw3_3.png)|22|Roundabout Counter Clockwise Exit 3 of 3|
|![roundabout CW exit 1-1](assets/nav-icons/ic_nav_roundabout_cw1_1.png)|23|Roundabout Clockwise Exit 1 of 1|
|![roundabout CW exit 1-2](assets/nav-icons/ic_nav_roundabout_cw1_2.png)|24|Roundabout Clockwise Exit 1 of 2|
|![roundabout CW exit 1-3](assets/nav-icons/ic_nav_roundabout_cw1_3.png)|25|Roundabout Clockwise Exit 1 of 3|
|![roundabout CW exit 2-2](assets/nav-icons/ic_nav_roundabout_cw2_2.png)|26|Roundabout Clockwise Exit 2 of 2|
|![roundabout CW exit 2-3](assets/nav-icons/ic_nav_roundabout_cw2_3.png)|27|Roundabout Clockwise Exit 2 of 3|
|![roundabout CW exit 3-3](assets/nav-icons/ic_nav_roundabout_cw3_3.png)|28|Roundabout Clockwise Exit 3 of 3|
|![roundabout fallback](assets/nav-icons/ic_nav_roundabout_fallback.png)|29|Roundabout Fallback|
|![left route](assets/nav-icons/ic_nav_outof_route.png)|30|Out Of Route|
|No image|31…n|We might enhance the table in future versions.|

<a name="data_street"></a>
### Street
<img src="assets/street.jpg" width="300" />

The street is provided as UTF-8 string. The street is starting at byte 21 until the end of the data object.


<a name="data_distance"></a>
### Distance

<img src="assets/distance.jpg" width="300" />


The distance is provided in meters. There is no rounding done by the komoot app. Your implementation is responsible to round and convert into the right measurement system.

This is an example how we do rounding in the komoot app:

| Distance Range | Rounding step | Examples |
|---|---|---|
|0 - 5|0|Now|
|6 - *|10|14 -> 10, 15 -> 20|

### Testing

#### Android
Use an Android device with the Komoot App to test your BLE Navigation device. To simulate a location track use the Lockito App and start a Navigation with the Komoot App. Before that don't forget to pair your device on Android OS and register it in the Komoot App.
Once navigation is started navigation instructions are sent by BLE Connect.
