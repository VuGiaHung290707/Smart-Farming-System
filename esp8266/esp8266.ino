#include <ArduinoJson.h>
#include <ESP8266WiFi.h>
#include <ESP8266WiFiMulti.h>
#include <WiFiManager.h>  // v0.16.0 https://github.com/tzapu/WiFiManager
#include <SocketIoClient.h>
#include <cstring>
/*v0.3 fix error beginSSL
  - SocketIoClient.cpp: const char* fingerprint --> const uint8_t* fingerprint
  - SocketIoClient.h:  const char* fingerprint = DEFAULT_FINGERPRINT)--> const uint8_t* fingerprint = NULL
*/
#define SOIL_HUMIDITY_SENSOR A0
#define WATER_PUMP D0

ESP8266WiFiMulti wifimulti;
SocketIoClient socketio;

//char host[] = "192.168.1.7";
//int port = 3484;
char host[] = "smart-farming-system.glitch.me";
int port = 80;

char username[] = "esp";
char password[] = "1234";

uint64_t timedelay;

double soilhumidity;

StaticJsonDocument<200> data;

bool on_off = false;
bool isWatering = false;
bool isWatering1 = false;
bool handwaterb = false;

void setup() {
  // put your setup code here, to run once:
  pinMode(SOIL_HUMIDITY_SENSOR, INPUT);
  pinMode(WATER_PUMP, OUTPUT);

  Serial.begin(115200);

  Serial.println("Wifi Connecting...)");

  WiFiManager wifimanager;
  wifimanager.setAPStaticIPConfig(IPAddress(10, 0, 1, 1), IPAddress(10, 0, 1, 1), IPAddress(255, 255, 255, 0));
  wifimanager.autoConnect(username, password);

  Serial.println("Wifi Connected!");

  socketio.begin(host, port);

  delay(1000);
}

void loop() {
  // put your main code here, to run repeatedly:
  socketio.loop();
  if (millis() - timedelay > 5000) {
    timedelay = millis();
    Read_Sensor();
    Water();
    if (handwaterb == true) {
      Handwater();
    }
  }
  socketio.on("ServerToSensor", ServerToSensor);
  socketio.on("HandWater", [](const char* payload, unsigned int unused) {
    handwaterb = true;
  });
}
void Handwater() {
  if (soilhumidity < 75 && !isWatering1) {
    digitalWrite(WATER_PUMP, HIGH);
    isWatering1 = true;
    socketio.emit("UpdateHistory");
    Serial.println("Bắt đầu tưới");
  } else if (soilhumidity > 85 && isWatering1) {
    digitalWrite(WATER_PUMP, LOW);
    isWatering1 = false;
    Serial.println("Dừng tưới");
    handwaterb = false;
  } else if (isWatering1) {
    Serial.println("Đang tưới thủ công");
  } else {
    handwaterb = false;
    Serial.println("Tắt tưới thủ công");
  }
}

void Water() {
  if (on_off == true) {
    if (soilhumidity < 70 && !isWatering) {
      digitalWrite(WATER_PUMP, HIGH);
      isWatering = true;
      socketio.emit("UpdateHistory");
      Serial.println("Bắt đầu tưới");
    } else if (soilhumidity > 85 && isWatering) {
      digitalWrite(WATER_PUMP, LOW);
      isWatering = false;
      Serial.println("Dừng tưới");
    }
  } else {
    Serial.println("Không cần tưới");
  }
}

void Read_Sensor() {
  soilhumidity = analogRead(SOIL_HUMIDITY_SENSOR);
  soilhumidity = 100 - map(soilhumidity, 0, 1023, 0, 100);
  Serial.println(soilhumidity);

  data["data"]["soilhumidity"] = soilhumidity;

  char message[256];
  serializeJson(data, message);
  socketio.emit("SensorToServer", message);
}

void ServerToSensor(const char* data, size_t len) {
  Serial.println(data);
  if (strcmp(data, "On") == 0) {
    on_off = true;
    Serial.println(1);
  } else {
    on_off = false;
    Serial.println(0);
  }
}