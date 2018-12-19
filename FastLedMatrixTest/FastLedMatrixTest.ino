  #define ESP32
  #include <FastLED.h>
 #define NUM_LEDS 144
 #define NUM_STRIPE 5
 #define DATA_PIN  #not used (12 -> 19)
 CRGB leds[NUM_LEDS*NUM_STRIPE];

int l = 0;
void setup() {
  // put your setup code here, to run once:
    pinMode(18, OUTPUT);
    FastLED.addLeds<WS2811, 18>(leds, 0, NUM_LEDS);
    FastLED.setBrightness(70);

}

void loop() {
  // put your main code here, to run repeatedly:
  l++;
  for(int i=0; i<NUM_LEDS; i++)
  {
    leds[i].r = (2*i)%l*l;
    leds[i].b = 200-i/l;
    leds[i].g = 50;
        
  }
   FastLED.show(); 

  delay(300);
    for(int i=NUM_LEDS; i<NUM_LEDS; i++)
  {
    leds[i] = CRGB::Black;        
  }
      FastLED.show(); 


}
