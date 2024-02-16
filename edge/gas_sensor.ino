// Author: Dario Giardini
// Purpose: Posting gases measurements to Measurify server
// Last Modified: Jan 7, 2024

#include <Wire.h>
#include <MutichannelGasSensor.h>
#include <WiFiNINA.h>

//Number of samples per hour (MAX 60)
#define SAMPLES_PER_HOUR 60
//Sensor pre-heat time, 5 minutes
#define PRE_HEAT_TIME 300000

//WiFi settings
char ssid[] = "iPhone";
char pass[] = "12345@!6";

//Server details
char server[] = "students.measurify.org";
const int port = 443;

//WiFi client and initial status
WiFiSSLClient client;
int status = WL_IDLE_STATUS;

void init(float*, int);                                        //Array initialiazion to -1
float getMean(float[], int);                                   //Mean hourly concentration of gases
bool checkTimer(unsigned long, unsigned long, unsigned long);  //True when the timer is over
void post(float[]);                                            //Post to the server

float coData[SAMPLES_PER_HOUR];   //Carbon monoxid data
float no2Data[SAMPLES_PER_HOUR];  //Nitrogen dioxide data
float ch4Data[SAMPLES_PER_HOUR];  //Methane data
int coIndex = 0;                  //Start index
int no2Index = 0;                 //Start index
int ch4Index = 0;                 //Start index
float gasData[] = { 0, 0, 0 };    //Mean data {CO, NO2, CH4}

//Avoid overflow with currentMillis - previousMillis >= interval (unsigned)
unsigned long previousMeasureMillis = 0;
//Sampling interval in milliseconds      
const unsigned long measureInterval = floor(min(3600000 / SAMPLES_PER_HOUR, 60000));  

//Avoid overflow with currentMillis - previousMillis >= interval (unsigned)
unsigned long previousPostMillis = 0;        
//Post interval in milliseconds
const unsigned long postInterval = max(measureInterval, 600000);	

//Flag if connection to server failed
bool previousPostMissed = false;  
//Flag  if sample failed 
bool previousDataMissed = false;  

//Gases name with thresholds
enum Gas {
  CARBON_MONOXIDE = 30,
  NITROGEN_DIOXIDE = 5,
  METHANE = 1000
};

void setup() {
  Serial.begin(9600);

  while (status != WL_CONNECTED) {
    Serial.print("Attempting to connect to Network named: ");
    Serial.println(ssid);
    status = WiFi.begin(ssid, pass);
  }

  Serial.print("SSID: ");
  Serial.println(WiFi.SSID());

  Serial.println("WiFi initialization completed");

  init(coData, SAMPLES_PER_HOUR);
  init(no2Data, SAMPLES_PER_HOUR);
  init(ch4Data, SAMPLES_PER_HOUR);

  Serial.println("Data initialization completed");

  Serial.println("Sensor initialization and pre-heating (5 minutes)");
  gas.begin(0x04);  //the default I2C address of the slave is 0x04
  gas.powerOn();
  delay(PRE_HEAT_TIME);
  Serial.println("Gas sensor initialization completed");
}

void loop() {
  unsigned long currentMillis = millis();
  float measure;
  Gas type;

  if (previousDataMissed || checkTimer(currentMillis, previousMeasureMillis, measureInterval)) {
    previousDataMissed = false;
    Serial.println("Sampling gas data...");
    if (!isnan(measure = gas.measure_CO()) && measure >= 0) {
      coData[coIndex] = measure;
      gasData[0] = getMean(coData, SAMPLES_PER_HOUR);
      type = CARBON_MONOXIDE;

      Serial.print("CO value: ");
      Serial.print(coData[coIndex]);
      Serial.print(", CO average: ");
      Serial.print(gasData[0]);
      Serial.print(", Checking threshold: ");
      Serial.println(checkThreshold(gasData[0], type) ? "OVER" : "OK");

      coIndex = coIndex < (SAMPLES_PER_HOUR - 1) ? coIndex + 1 : 0;
    }

    if (!isnan(measure = gas.measure_NO2()) && measure >= 0) {
      no2Data[no2Index] = measure;
      gasData[1] = getMean(no2Data, SAMPLES_PER_HOUR);
      type = NITROGEN_DIOXIDE;

      Serial.print("NO value: ");
      Serial.print(no2Data[no2Index]);
      Serial.print(", NO average: ");
      Serial.print(gasData[1]);
      Serial.print(", Checking threshold: ");
      Serial.println(checkThreshold(gasData[1], type) ? "OVER" : "OK");

      no2Index = no2Index < (SAMPLES_PER_HOUR - 1) ? no2Index + 1 : 0;
    }

    if (!isnan(measure = gas.measure_CH4()) && measure >= 0) {
      ch4Data[ch4Index] = measure;
      gasData[2] = getMean(ch4Data, SAMPLES_PER_HOUR);
      type = METHANE;

      Serial.print("CH4 value: ");
      Serial.print(ch4Data[ch4Index]);
      Serial.print(", CH4 average: ");
      Serial.print(gasData[2]);
      Serial.print(", Checking threshold: ");
      Serial.println(checkThreshold(gasData[2], type) ? "OVER" : "OK");

      ch4Index = ch4Index < (SAMPLES_PER_HOUR - 1) ? ch4Index + 1 : 0;
    }

    previousMeasureMillis = currentMillis;

    Serial.println("---------------------------------------------------------------");
  }

  if (previousPostMissed || checkTimer(currentMillis, previousPostMillis, postInterval)) {
    if (client.connect(server, port)) {
      previousPostMissed = false;
      Serial.println("Making POST...");
      post(gasData);
      previousPostMillis = currentMillis;
    } else if (WiFi.status() != WL_CONNECTED) {  //Check WiFi connection
      previousPostMissed = true;
      Serial.println("Cannot make POST. Lost WiFi connection, reconnecting...");
      //Attempt to reconnect until sample timer is over and flag missed post 
      while (WiFi.status() != WL_CONNECTED) {  
        unsigned long extraMillis = millis();
        WiFi.begin(ssid, pass);
        //This avoids sampling blockage
        if (checkTimer(extraMillis, previousMeasureMillis, measureInterval)) {  
          previousDataMissed = true;
          break;
        }
      }
    } else {  
      //Cannot connect to server and flag missed post 
      previousPostMissed = true;
      Serial.println("Cannot make POST. Cannot connect to the server");
    }
  }
}

void init(float* array, int length) {
  for (int i = 0; i < length; i++) {
    array[i] = -1;
  }
}

float getMean(float array[], int length) {
  float hold = 0;
  int j = 0;

  for (int i = 0; i < length; i++) {
    if (array[i] >= 0) {
      hold += array[i];
      j++;
    }
  }

  return (j != 0) ? (float)hold / j : 0;
}

bool checkTimer(unsigned long currentMillis, unsigned long previousMillis, unsigned long interval) {
  return (currentMillis - previousMillis) >= interval;
}

bool checkThreshold(float value, Gas type) {
  bool isOver = false;
  switch (type) {
    case CARBON_MONOXIDE:
      isOver = value > CARBON_MONOXIDE;
      break;
    case NITROGEN_DIOXIDE:
      isOver = value > NITROGEN_DIOXIDE;
      break;
    case METHANE:
      isOver = value > METHANE;
      break;
    default:
      break;
  }
  return isOver;
}

void post(float data[]) {
  // Prepare the POST request
  String postData = "{\"thing\":\"room1\",\"feature\":\"gas-values\",\"device\":\"gas-detector\",\"samples\":[{\"values\":[" + String(data[0]) + "," + String(data[1]) + "," + String(data[2]) + "]}],\"tags\":[]}";

  // Send the POST request
  client.println("POST /v1/measurements HTTP/1.1");
  client.println("Host: students.measurify.org");
  client.println("Content-Type: application/json");
  client.println("Authorization: DVC eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXZpY2UiOnsiX2lkIjoiZ2FzLWRldGVjdG9yIiwiZmVhdHVyZXMiOlsiZ2FzLXZhbHVlcyJdLCJ0aGluZ3MiOlsicm9vbTEiXSwic2NyaXB0cyI6W10sInBlcmlvZCI6IjVzIiwiY3ljbGUiOiIxMG0iLCJyZXRyeVRpbWUiOiIxMHMiLCJzY3JpcHRMaXN0TWF4U2l6ZSI6NSwibWVhc3VyZW1lbnRCdWZmZXJTaXplIjoyMCwiaXNzdWVCdWZmZXJTaXplIjoyMCwic2VuZEJ1ZmZlclNpemUiOjIwLCJzY3JpcHRTdGF0ZW1lbnRNYXhTaXplIjo1LCJzdGF0ZW1lbnRCdWZmZXJTaXplIjoxMCwibWVhc3VyZW1lbnRCdWZmZXJQb2xpY3kiOiJkZWNpbWF0aW9uIiwib3duZXIiOiI2NDVlMGFiMTczOWFhYjAwMWVmZThjNDAifSwidGVuYW50Ijp7InBhc3N3b3JkaGFzaCI6dHJ1ZSwiX2lkIjoiR2FzLVRlbmFudCIsIm9yZ2FuaXphdGlvbiI6Ik1lYXN1cmlmeSBvcmciLCJhZGRyZXNzIjoiTWVhc3VyaWZ5IFN0cmVldCwgR2Vub3ZhIiwiZW1haWwiOiJpbmZvQG1lYXN1cmlmeS5vcmciLCJwaG9uZSI6IiszOTEwMzIxODc5MzgxNyIsImRhdGFiYXNlIjoiR2FzLVRlbmFudCJ9LCJpYXQiOjE2ODQ0MjI0MzQsImV4cCI6MzMyNDIwMjI0MzR9.2l6QGaQx4hMhw_DQd27PZ1b1K0kn7jUr5_p631_SNJ4");
  client.print("Content-Length: ");
  client.println(postData.length());
  client.println();
  client.print(postData);

  Serial.println("POST request sent");

  //Server response
  /*delay(1000);

  while (client.available()) {
    char c = client.read();
    Serial.write(c);
  }

  Serial.println("Server response received");*/
}
