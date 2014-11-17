/*
 * MFRC522 - Library to use ARDUINO RFID MODULE KIT 13.56 MHZ WITH TAGS SPI W AND R BY COOQROBOT.
 * The library file MFRC522.h has a wealth of useful info. Please read it.
 * The functions are documented in MFRC522.cpp.
 *
 * Based on code Dr.Leong   ( WWW.B2CQSHOP.COM )
 * Created by Miguel Balboa (circuitito.com), Jan, 2012.
 * Rewritten by Søren Thing Andersen (access.thing.dk), fall of 2013 (Translation to English, refactored, comments, anti collision, cascade levels.)
 * Released into the public domain.
 *
 * Sample program showing how to read data from a PICC using a MFRC522 reader on the Arduino SPI interface.
 *----------------------------------------------------------------------------- empty_skull 
 * Aggiunti pin per arduino Mega
 * add pin configuration for arduino mega
 * http://mac86project.altervista.org/
 ----------------------------------------------------------------------------- Nicola Coppola
 * Pin layout should be as follows:
 * Signal     Pin              Pin               Pin
 *            Arduino Uno      Arduino Mega      MFRC522 board
 * ------------------------------------------------------------
 * Reset      9                5                 RST
 * SPI SS     10               53                SDA
 * SPI MOSI   11               51                MOSI
 * SPI MISO   12               50                MISO
 * SPI SCK    13               52                SCK
 *
 * The reader can be found on eBay for around 5 dollars. Search for "mf-rc522" on ebay.com. 
 */

#include <SPI.h>
#include <MFRC522.h>

#define lockPin 8
#define SS_PIN 10
#define RST_PIN 9

// Create MFRC522 instance.
MFRC522 mfrc522(SS_PIN, RST_PIN);

// Var to store the read card ID
String cardID;

// State of the lock (read from serial)
int lockState = 0;

// Time to leave unlocked
int unlockms = 1000;

// Counter for the unlock time
long unlocktime = millis();

void setup() {
  Serial.begin(9600);	// Initialize serial communications with the PC
  
  // Setup the relay pin for the door lock
  pinMode(lockPin,OUTPUT);
  
  // Unlock door for a few seconds
  digitalWrite(lockPin,HIGH);
  delay(100);
  digitalWrite(lockPin,LOW);
    
  SPI.begin();	        // Init SPI bus
  mfrc522.PCD_Init();	// Init MFRC522 card
  //Serial.println("Scan PICC to see UID and type...");
  
  
}

void loop() {
  // If the door has been unlocked for the specified time
  if (millis() - unlocktime > unlockms) {
    digitalWrite(lockPin,LOW);
  }
  
  // Listen for a response from the perl script
  if (Serial.available() > 0) {
    lockState = Serial.read();
    
    Serial.println(lockState);
    
    if (lockState > 48) {
      digitalWrite(lockPin,HIGH);
      unlocktime = millis();
    }
  }
  
  // If a new card placed on the reader
  if ( ! mfrc522.PICC_IsNewCardPresent()) {
    return;
  }
  
  // Card placed, get serial and continue
  if ( ! mfrc522.PICC_ReadCardSerial()) {
    return;
  }
  
  // Dump debug info about the card. PICC_HaltA() is automatically called.
  //mfrc522.PICC_DumpToSerial(&(mfrc522.uid));
  
  //Serial.print("Card ID: ");
  cardID = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    cardID+= mfrc522.uid.uidByte[i];
  } 
  Serial.println(cardID);
  
  // Stop reading this card
  mfrc522.PICC_HaltA();
  
}

