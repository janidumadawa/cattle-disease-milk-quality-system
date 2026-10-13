
#include <Wire.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <hd44780.h>
#include <hd44780ioClass/hd44780_I2Cexp.h>

#define ONE_WIRE_BUS 4

OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);
hd44780_I2Cexp lcd;

void setup() {
  Serial.begin(115200);

  Wire.begin(21, 22);

  int lcdStatus = lcd.begin(16, 2);

  if (lcdStatus != 0) {
    Serial.println("LCD initialization failed");
    while (true) {
      delay(100);
    }
  }

  lcd.backlight();
  sensors.begin();

  lcd.setCursor(0, 0);
  lcd.print("Milk Temp Monitor");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");
  delay(2000);
  lcd.clear();
}

void loop() {
  sensors.requestTemperatures();

  float tempC = sensors.getTempCByIndex(0);

  lcd.setCursor(0, 0);
  lcd.print("Milk Temperature");

  lcd.setCursor(0, 1);

  if (tempC == DEVICE_DISCONNECTED_C) {
    lcd.print("Sensor error     ");
    Serial.println("DS18B20 not detected");
  } else {
    lcd.print(tempC, 2);
    lcd.print((char)223);
    lcd.print("C             ");

    Serial.print("Temperature: ");
    Serial.print(tempC, 2);
    Serial.println(" C");
  }

  delay(1000);
}
