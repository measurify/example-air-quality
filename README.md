# Design and implementation of an embedded system for real-time air quality monitoring of a working environment

The system collects and processes data related to substances, and subsequently, information regarding gas concentrations in the air is sent to an Application Programming Interface (API) framework called Measurify. Finally, to allow a user-friendly visualization of the data, a cross-platform application has been created to view current conditions, time series of recent readings, and receive push notifications when a gas exceeds the established threshold.

## Edge Part

### Description

This Arduino sketch measures concentrations of gases, including Carbon Monoxide (CO), Nitrogen Dioxide (NO2), and Methane (CH4), and posts the data to the Measurify server. The sketch uses the MutichannelGasSensor library for interfacing with the gas sensor and the WiFiNINA library for handling WiFi connections. Gas concentration data is sent to the Measurify server through HTTP POST requests at regular intervals.

### Prerequisites

To use the Arduino sketch, you will need the following hardware components:

- Arduino Uno Rev2 Wi-Fi
- Grove - Multichannel Gas Sensor (v1)

Make sure you have the necessary libraries installed:

- [WiFiNINA](https://www.arduino.cc/reference/en/libraries/wifinina/)
- [Multichannel Gas Sensor](https://www.arduino.cc/reference/en/libraries/grove-multichannel-gas-sensor/)
- [Wire](https://www.arduino.cc/reference/en/language/functions/communication/wire/)

### Instructions

1. Configure WiFi settings by updating the `ssid` and `pass` variables.
2. Adjust server details such as `server` and `port` accordingly.
3. Set the number of samples per hour (`SAMPLES_PER_HOUR`) and sensor pre-heat time (`PRE_HEAT_TIME`) as needed.
4. Change the Measurify credentials inside `postData` function.
5. Run the sketch on your Arduino board and observe the gas concentration readings on the Serial Monitor.

> [!TIP]
> Ensure a maximum of 60 samples per hour and a pre-heat time of 5 minutes for optimal performance.

## Client Part

### Description

This Flutter application is designed to monitor air quality data. The app utilizes Firebase for cloud messaging, as well as the Syncfusion Flutter Charts package for visualizing gas concentration data over time.

### Prerequisites

Before running the app, ensure you have:

- Firebase project set up with the necessary configurations.
- Measurify API credentials (username, password, and tenant) configured in `constants.dart`.

### Features

- Real-time monitoring of CO, NO2, and CH4 concentrations in the air.
- Integration with the Measurify API for data retrieval and storage.
- Push notifications for alerting users when gas concentrations exceed predefined thresholds.
- Time series visualization using Syncfusion charts.

<p align="center">
  <img width="350" height="263" src="images/push.png" hspace="10">
  <img width="290" height="400" src="images/main.png" hspace="10">
</p>

> [!IMPORTANT]  
> Add `google-services.json` file from Firebase under the `android/app` directory.
