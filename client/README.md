# Air Quality Monitor App

This Flutter application is designed to monitor air quality in a workplace environment. The app utilizes Firebase for cloud messaging, as well as the Syncfusion Flutter Charts package for visualizing gas concentration data over time.

## Features

- Real-time monitoring of CO, NO2, and CH4 concentrations in the air.
- Integration with the Measurify API for data retrieval and storage.
- Push notifications for alerting users when gas concentrations exceed predefined thresholds.
- Historical data visualization using Syncfusion charts.

## Prerequisites

Before running the app, ensure you have:

- Firebase project set up with the necessary configurations.
- Measurify API credentials (username, password, and tenant) configured in `constants.dart`.
- `google-services.json` file from Firebase added under the `android/app` directory.

## Configuration

- Update the following constants in lib/misc/constants.dart with your Measurify API credentials.

## Firebase Cloud Messaging Events

- onMessage handles and display notifications when the app is actively running.
- onMessageOpenedApp handles specific actions when the user interacts with a notification and opens the app.
- getInitialMessage handles notifications that led to the app being opened initially.
