import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'services/notifications.dart';
import 'misc/constants.dart' as constants;

final Logger logger = Logger();

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<_AirData> data = [];

  @override
  void initState() {
    super.initState();

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    messaging.getInitialMessage().then((RemoteMessage? message) async {
      var client = http.Client();
      try {
        logger.i("getInitialMessage");
        // Obtain the token
        var headers = {
          'Content-Type': 'application/json',
        };

        var response =
            await client.post(Uri.parse('${constants.measurifyUrl}/login'),
                headers: headers,
                body: jsonEncode({
                  "username": constants.measurifyUser,
                  "password": constants.measurifyPassword,
                  "tenant": constants.measurifyTenant
                }));

        if (response.statusCode != 200) {
          throw "Failed to post data: ${response.statusCode}";
        }

        final token = jsonDecode(response.body)["token"];

        // Obtain previous data using token
        headers = {
          'Authorization': token,
        };

        DateTime today = DateTime.now();
        String dateStr = "${today.year}-${today.month}-${today.day}";

        var response_ = await client.get(
          Uri.parse(
              '${constants.measurifyUrl}/measurements?filter={"startDate":{"\$gt": "$dateStr"}}&limit=60'),
          headers: headers,
        );

        if (response_.statusCode != 200) {
          throw "Failed to get data: ${response_.statusCode}";
        }

        List<dynamic> oldData = jsonDecode(response_.body)['docs'];

        //Populate charts
        data = [];

        for (dynamic item in oldData.reversed) {
          var gasValues = item['samples'][0]['values'];
          data.add(_AirData(
              DateTime.parse(item['endDate']).millisecondsSinceEpoch,
              gasValues[0].toDouble(),
              gasValues[1].toDouble(),
              gasValues[2].toDouble()));
        }
        setState(() {});
      } catch (e) {
        logger.e("Error: $e");
      } finally {
        client.close();
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      logger.i("onMessage");

      try {
        Map<String, dynamic> dataBody = message.data;

        logger.d(dataBody["body"].toString());

        var decodedData = jsonDecode(dataBody["body"].toString());

        var gasValues = decodedData['samples'][0]['values'];
        var timestamp = decodedData["startDate"] is int
            ? decodedData["startDate"]
            : DateTime.parse(decodedData["startDate"]).millisecondsSinceEpoch;

        logger.d(
            "$timestamp\nCO: ${gasValues[0]} ppm\nNO2: ${gasValues[1]} ppm\nCH4: ${gasValues[2]} ppm");

        if (gasValues[0] >= constants.coThreshold ||
            gasValues[1] >= constants.no2Threshold ||
            gasValues[2] >= constants.ch4Threshold) {
          NotificationService().showNotification(
              title: "Avviso superamento soglia",
              body: "Un gas ha superato i livelli i soglia!");
        }

        if (data.isNotEmpty && data.length >= 60) {
          data.removeAt(0);
        }

        setState(() {
          data.add(_AirData(timestamp, gasValues[0].toDouble(),
              gasValues[1].toDouble(), gasValues[2].toDouble()));
        });
      } catch (e) {
        logger.e("Error: $e");
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      logger.i("onMessageOpenedApp");

      try {
        Map<String, dynamic> dataBody = message.data;

        var decodedData = jsonDecode(dataBody["body"].toString());

        var gasValues = decodedData['samples'][0]['values'];
        var timestamp = decodedData["startDate"] is int
            ? decodedData["startDate"]
            : DateTime.parse(decodedData["startDate"]).millisecondsSinceEpoch;

        logger.d(
            "$timestamp\nCO: ${gasValues[0]} ppm\nNO2: ${gasValues[1]} ppm\nCH4: ${gasValues[2]} ppm");

        if (data.isNotEmpty && data.length >= 60) {
          data.removeAt(0);
        }

        setState(() {
          data.add(_AirData(timestamp, gasValues[0].toDouble(),
              gasValues[1].toDouble(), gasValues[2].toDouble()));
        });
      } catch (e) {
        logger.e("Error: $e");
      }
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    messaging
        .requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        )
        .then((value) => logger.i("Settings registered: $value"));

    messaging.getToken().then((token) {
      assert(token != null);
      logger.d('Token: $token');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Air Quality monitor'),
        ),
        body: Center(
            child: SingleChildScrollView(
          child: Column(
            children: [
              FittedBox(
                  child: DataTable(
                columns: const [
                  DataColumn(label: Text('Gas')),
                  DataColumn(label: Text('Concentration (ppm)')),
                  DataColumn(label: Text('Alert')),
                ],
                rows: [
                  DataRow(
                    cells: [
                      const DataCell(
                        Text(
                          'CO',
                        ),
                      ),
                      DataCell(Align(
                          alignment: Alignment.center,
                          child: Text(data.isNotEmpty
                              ? data.last.co.toString()
                              : "n.d."))),
                      DataCell(
                        Text(data.isNotEmpty
                            ? (data.last.co > constants.coThreshold
                                ? 'HIGH'
                                : 'NORMAL')
                            : "n.a."),
                      ),
                    ],
                  ),
                  DataRow(
                    cells: [
                      const DataCell(
                        Text(
                          'NO2',
                        ),
                      ),
                      DataCell(Align(
                          alignment: Alignment.center,
                          child: Text(data.isNotEmpty
                              ? data.last.no2.toString()
                              : "n.d."))),
                      DataCell(
                        Text(data.isNotEmpty
                            ? (data.last.no2 > constants.no2Threshold
                                ? 'HIGH'
                                : 'NORMAL')
                            : "n.a."),
                      ),
                    ],
                  ),
                  DataRow(
                    cells: [
                      const DataCell(
                        Text(
                          'CH4',
                        ),
                      ),
                      DataCell(Align(
                          alignment: Alignment.center,
                          child: Text(data.isNotEmpty
                              ? data.last.ch4.toString()
                              : "n.d."))),
                      DataCell(
                        Text(data.isNotEmpty
                            ? (data.last.ch4 > constants.ch4Threshold
                                ? 'HIGH'
                                : 'NORMAL')
                            : "n.a."),
                      ),
                    ],
                  ),
                ],
              )),
              ///////////////////////////
              const SizedBox(height: 10),
              ///////////////////////////
              SfCartesianChart(
                primaryXAxis: DateTimeAxis(),
                // Chart title
                title: ChartTitle(text: 'Gases concentration'),
                // Enable legend
                legend:
                    const Legend(isVisible: true, position: LegendPosition.top),
                // Enable tooltip
                tooltipBehavior: TooltipBehavior(enable: true),
                palette: const <Color>[Colors.teal, Colors.green, Colors.brown],
                series: <ChartSeries<_AirData, DateTime>>[
                  LineSeries<_AirData, DateTime>(
                    dataSource: data,
                    xValueMapper: (_AirData air, _) =>
                        DateTime.fromMillisecondsSinceEpoch(air.timestamp),
                    yValueMapper: (_AirData air, _) => air.co,
                    name: 'CO (ppm)',
                    // Enable data label
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                  LineSeries<_AirData, DateTime>(
                    dataSource: data,
                    xValueMapper: (_AirData air, _) =>
                        DateTime.fromMillisecondsSinceEpoch(air.timestamp),
                    yValueMapper: (_AirData air, _) => air.no2,
                    name: 'NO2 (ppm)',
                    // Enable data label
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                  LineSeries<_AirData, DateTime>(
                    dataSource: data,
                    xValueMapper: (_AirData air, _) =>
                        DateTime.fromMillisecondsSinceEpoch(air.timestamp),
                    yValueMapper: (_AirData air, _) => air.ch4,
                    name: 'CH4 (ppm)',
                    // Enable data label
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
              ///////////////////////////
              const SizedBox(height: 10),
              ///////////////////////////
              Text(
                  'Last Update: ${data.isNotEmpty ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(data.last.timestamp).toLocal()) : "n.d."}'),
            ],
          ),
        )));
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  logger.i("Handling a background message: ${message.messageId}");
  try {
    Map<String, dynamic> dataBody = message.data;

    var decodedData = jsonDecode(dataBody["body"].toString());

    var gasValues = decodedData['samples'][0]['values'];
    var timestamp = decodedData["startDate"];

    logger.d(
        "$timestamp\nCO: ${gasValues[0]} ppm\nNO2: ${gasValues[1]} ppm\nCH4: ${gasValues[2]} ppm");

    if (gasValues[0] >= constants.coThreshold ||
        gasValues[1] >= constants.no2Threshold ||
        gasValues[2] >= constants.ch4Threshold) {
      NotificationService().showNotification(
          title: "Avviso superamento soglia",
          body: "Un gas ha superato i livelli i soglia!");
    }
  } catch (e) {
    logger.e("Error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService().initNotification();
  await Firebase.initializeApp();
  runApp(
    const MaterialApp(
      home: MyHomePage(),
    ),
  );
}

class _AirData {
  _AirData(this.timestamp, this.co, this.no2, this.ch4);

  final int timestamp;
  final double co;
  final double no2;
  final double ch4;
}
