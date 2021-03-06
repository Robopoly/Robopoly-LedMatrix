/*  OctoWS2811 VideoDisplay.ino - Video on LEDs, from a PC, Mac, Raspberry Pi
    http://www.pjrc.com/teensy/td_libs_OctoWS2811.html
    Copyright (c) 2013 Paul Stoffregen, PJRC.COM, LLC

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.


    Use the robopoly processing matrix contoller available on github
    
    When using more than 1 esp32 to display a video image, connect
    the Frame Sync signal between every board.  All boards will
    synchronize their WS2811 update using this signal.

    Beware of image distortion from long LED strip lengths.  During
    the WS2811 update, the LEDs update in sequence, not all at the
    same instant!  The first pixel updates after 30 microseconds,
    the second pixel after 60 us, and so on.  A strip of SYNC_PIN0 LEDs
    updates in 3.6 ms, which is 10.8% of a 30 Hz video frame time.
    Doubling the strip length to 240 LEDs increases the lag to 21.6%
    of a video frame.  For best results, use shorter length strips.
    Multiple boards linked by the frame sync signal provides superior
    video timing accuracy.

    A Multi-TT USB hub should be used if 2 or more Teensy boards
    are connected.  The Multi-TT feature allows proper USB bandwidth
    allocation.  Single-TT hubs, or direct connection to multiple
    ports on the same motherboard, may give poor performance.
*/

  #include <EEPROM.h>

  #include <FastLED.h>

// The actual arrangement of the LEDs connected to this Teensy 3.0 board.
// LED_HEIGHT *must* be a multiple of 8.  When 16, 24, 32 are used, each
// strip spans 2, 3, 4 rows.  LED_LAYOUT indicates the direction the strips
// are arranged.  If 0, each strip begins on the left for its first row,
// then goes right to left for its second row, then left to right,
// zig-zagging for each successive row.
#define LED_WIDTH      12   // number of LEDs horizontally
#define LED_HEIGHT     12   // number of LEDs vertically 
#define LED_LAYOUT     0    // 0 = even rows left->right (bottom-up), 1 = even rows right->left (up->bottom)
#define LED_ORIENTATION 0   // 0 = horizontal rows, 1 = vertical (if 1 LED HEIGHT/WIDTH will be inversed)
#define NB_STRIPE      1
// The portion of the video image to show on this set of LEDs.  All 4 numbers
// are percentages, from 0 to 100.  For a large LED installation with many
// Teensy 3.0 boards driving groups of LEDs, these parameters allow you to
// program each Teensy to tell the video application which portion of the
// video it displays.  By reading these numbers, the video application can
// automatically configure itself, regardless of which serial port COM number
// or device names are assigned to each Teensy 3.0 by your operating system.
// now stored in EPPROM and serial modifiable (p)
#define VIDEO_XOFFSET_ADDR  1
#define VIDEO_YOFFSET_ADDR  10       // display entire image
#define VIDEO_WIDTH_ADDR    20
#define VIDEO_HEIGHT_ADDR   30

byte VIDEO_XOFFSET;
byte VIDEO_YOFFSET;  
byte VIDEO_WIDTH;    
byte VIDEO_HEIGHT; 


const int ledsPerStrip = (LED_WIDTH * LED_HEIGHT) / NB_STRIPE;

#define SYNC_PIN 11
typedef long elapsedMicros; //to check if enough TODO
typedef long elapsedMillis; //to check if enough TODO

elapsedMicros elapsedUsecSinceLastFrameSync = 0;

CRGB leds[LED_WIDTH * LED_HEIGHT];

void setup() {
    FastLED.addLeds<WS2812, 17>(leds, 0, ledsPerStrip);
    /*FastLED.addLeds<WS2811, 13>(leds, ledsPerStrip, 2*ledsPerStrip);
    FastLED.addLeds<WS2811, 14>(leds, 2*ledsPerStrip, 3*ledsPerStrip);
    FastLED.addLeds<WS2811, 15>(leds, 3*ledsPerStrip, 4*ledsPerStrip);
    FastLED.addLeds<WS2811, 16>(leds, 4*ledsPerStrip, 5*ledsPerStrip);
    FastLED.addLeds<WS2811, 16>(leds, 5*ledsPerStrip, 6*ledsPerStrip);
    FastLED.addLeds<WS2811, 16>(leds, 6*ledsPerStrip, 7*ledsPerStrip);
    FastLED.addLeds<WS2811, 16>(leds, 7*ledsPerStrip, 8*ledsPerStrip);*/
    pinMode(SYNC_PIN, INPUT_PULLUP); // Frame Sync
    Serial.begin(1000000);
    Serial.setTimeout(50);
    Serial.println(ledsPerStrip);
    FastLED.setBrightness(20);
    FastLED.show();

/*
 VIDEO_XOFFSET = EEPROM.get(VIDEO_XOFFSET_ADDR, VIDEO_XOFFSET);
 delay(500);
 VIDEO_YOFFSET = EEPROM.read(VIDEO_YOFFSET_ADDR);  
  delay(500);

 VIDEO_WIDTH   = EEPROM.read(VIDEO_WIDTH_ADDR);
  delay(500);

 VIDEO_HEIGHT  = EEPROM.read(VIDEO_HEIGHT_ADDR);

*/

 VIDEO_XOFFSET = 0;
 VIDEO_YOFFSET = 0;
 VIDEO_WIDTH   = 100;
 VIDEO_HEIGHT  = 100;
 
    
}

void loop() {
//
// wait for a Start-Of-Message character:
// 'n' = Frame of image or text not needing sync
// 'b' = BrightnessValue in %
// 's' = Set the image offset and size on this board
//
//   '*' = Frame of image data, with frame sync pulse to be sent
//         a specified number of microseconds after reception of
//         the first byte (typically at 75% of the frame time, to
//         allow other boards to fully receive their data).
//         Normally '*' is used when the sender controls the pace
//         of playback by transmitting each frame as it should
//         appear.
//   
//   '$' = Frame of image data, with frame sync pulse to be sent
//         a specified number of microseconds after the previous
//         frame sync.  Normally this is used when the sender
//         transmits each frame as quickly as possible, and we
//         control the pacing of video playback by updating the
//         LEDs based on time elapsed from the previous frame.
//
//   '%' = Frame of image data, to be displayed with a frame sync
//         pulse is received from another board.  In a multi-board
//         system, the sender would normally transmit one '*' or '$'
//         message and '%' messages to all other boards, so every
//         Teensy 3.0 updates at the exact same moment.
//
//   '@' = Reset the elapsed time, used for '$' messages.  This
//         should be sent before the first '$' message, so many
//         frames are not played quickly if time as elapsed since
//         startup or prior video playing.
//   
//   '?' = Query LED and Video parameters.  Teensy 3.0 responds
//         with a comma delimited list of information.
//
  int startChar = Serial.read();
    
    if (startChar == 'n') {
    // receive a "no time" frame - we display the byte no taking care of timing
    
    Serial.readBytes((char *)leds, sizeof(leds));
    FastLED.show();
    
    }
    else if (startChar == 'b') {
    // receive a percent britghness value
    
    int brightness = Serial.parseInt();
    brightness = ((float)brightness/(float)100)*256;
    FastLED.setBrightness(brightness);
    Serial.println(brightness);
    FastLED.show();
    
    }
   else if (startChar == '*') {
    // receive a "master" frame - we send the frame sync to other boards
    // the sender is controlling the video pace.  The 16 bit number is
    // how far into this frame to send the sync to other boards.
    unsigned int startAt = micros();
    unsigned int usecUntilFrameSync = 0;
    int count = Serial.readBytes((char *)&usecUntilFrameSync, 2);
    if (count != 2) return;
    count = Serial.readBytes((char *)leds, sizeof(leds));
    if (count == sizeof(leds)) {
      unsigned int endAt = micros();
      unsigned int usToWaitBeforeSyncOutput = 100;
      if (endAt - startAt < usecUntilFrameSync) {
        usToWaitBeforeSyncOutput = usecUntilFrameSync - (endAt - startAt);
      }
      digitalWrite(SYNC_PIN, HIGH);
      pinMode(SYNC_PIN, OUTPUT);
      delayMicroseconds(usToWaitBeforeSyncOutput);
      digitalWrite(SYNC_PIN, LOW);
      // WS2811 update begins immediately after falling edge of frame sync
      digitalWrite(13, HIGH);
      FastLED.show();
      digitalWrite(13, LOW);
    }

  } else if (startChar == '$') {
    // receive a "master" frame - we send the frame sync to other boards
    // we are controlling the video pace.  The 16 bit number is how long
    // after the prior frame sync to wait until showing this frame
    unsigned int usecUntilFrameSync = 0;
    int count = Serial.readBytes((char *)&usecUntilFrameSync, 2);
    if (count != 2) return;
    count = Serial.readBytes((char *)leds, sizeof(leds));
    if (count == sizeof(leds)) {
      digitalWrite(SYNC_PIN, HIGH);
      pinMode(SYNC_PIN, OUTPUT);
      while (elapsedUsecSinceLastFrameSync < usecUntilFrameSync) /* wait */ ;
      elapsedUsecSinceLastFrameSync -= usecUntilFrameSync;
      digitalWrite(SYNC_PIN, LOW);
      // WS2811 update begins immediately after falling edge of frame sync
      FastLED.show();
    }

  } else if (startChar == '%') {
    // receive a "slave" frame - wait to show it until the frame sync arrives
    pinMode(SYNC_PIN, INPUT_PULLUP);
    unsigned int unusedField = 0;
    int count = Serial.readBytes((char *)&unusedField, 2);
    if (count != 2) return;
    count = Serial.readBytes((char *)leds, sizeof(leds));
    if (count == sizeof(leds)) {
      elapsedMillis wait = 0;
      while (digitalRead(SYNC_PIN) != HIGH && wait < 30) ; // wait for sync high
      while (digitalRead(SYNC_PIN) != LOW && wait < 30) ;  // wait for sync high->low
      // WS2811 update begins immediately after falling edge of frame sync
      if (wait < 30) {
        FastLED.show();
      }
    }

  } else if (startChar == '@') {
    // reset the elapsed frame time, for startup of '$' message playing
    elapsedUsecSinceLastFrameSync = 0;

  } else if (startChar == '?') {
    // when the video application asks, give it all our info
    // for easy and automatic configuration
    Serial.print(LED_WIDTH);
    Serial.write(',');
    Serial.print(LED_HEIGHT);
    Serial.write(',');
    Serial.print(LED_LAYOUT);
    Serial.write(',');
    Serial.print(LED_ORIENTATION);
    Serial.write(',');
    Serial.print(0);
    Serial.write(',');
    Serial.print(VIDEO_XOFFSET);
    Serial.write(',');
    Serial.print(VIDEO_YOFFSET);
    Serial.write(',');
    Serial.print(VIDEO_WIDTH);
    Serial.write(',');
    Serial.print(VIDEO_HEIGHT);
    Serial.write(',');
    Serial.print(0);
    Serial.write(',');
    Serial.print(0);
    Serial.write(',');
    Serial.print(0);
    Serial.println();

  } 
   else if (startChar == 's') {
    // receive video position to store in EPPROM for future ask (values : sVIDEO_XOFFSET,VIDEO_YOFFSET,VIDEO_WIDTH,VIDEO_HEIGHT) ESP will restart in order for the change to take effet
  Serial.print(Serial.readStringUntil(',').toInt());

    
    EEPROM.write(VIDEO_XOFFSET_ADDR,   Serial.readStringUntil(',').toInt());
    EEPROM.write(VIDEO_YOFFSET_ADDR,   Serial.readStringUntil(',').toInt());
    EEPROM.write(VIDEO_WIDTH_ADDR,     Serial.readStringUntil(',').toInt());
    EEPROM.write(VIDEO_HEIGHT_ADDR,    Serial.readStringUntil(',').toInt());

    delay(5000);
    EEPROM.commit();
    delay(5000);

   VIDEO_XOFFSET = EEPROM.get(VIDEO_XOFFSET_ADDR, VIDEO_XOFFSET);
   VIDEO_YOFFSET = EEPROM.read(VIDEO_YOFFSET_ADDR);   
   VIDEO_WIDTH   = EEPROM.read(VIDEO_WIDTH_ADDR);
   VIDEO_HEIGHT  = EEPROM.read(VIDEO_HEIGHT_ADDR);

  Serial.print(EEPROM.read(VIDEO_WIDTH_ADDR));
    Serial.print(VIDEO_WIDTH);

    ESP.restart();
  }
  else if (startChar == 'g') {
    // rglediator input
   while(1){
    int i =0 ;
    while(i < LED_HEIGHT*LED_WIDTH)
    {
           while (!Serial.available()) {}
          leds[i].r = Serial.read();
           while (!Serial.available()) {}
          leds[i].g = Serial.read();
           while (!Serial.available()) {}
          leds[i].b = Serial.read();
    FastLED.show();

          i++;    
          
    }
   }

  }
  else if (startChar >= 0) {
    // discard unknown characters
  }
}



/*
public void set(int val, int addr)
{
EEPROM.write(addr,highByte(val);
EEPROM.write(addr+1,lowByte(val);
}

public int get(int val, int addr)
{
byte high = EEPROM.read(addr);
byte low = EEPROM.read(addr+1);
int myInteger=word(high,low);
return myInteger;

}
*/
