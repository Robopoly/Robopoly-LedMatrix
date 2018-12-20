/*  OctoWS2811 movie2serial.pde - Transmit video data to 1 or more
      Teensy 3.0 boards running OctoWS2811 VideoDisplay.ino
    http://www.pjrc.com/teensy/td_libs_OctoWS2811.html
    Copyright (c) 2018 Paul Stoffregen, PJRC.COM, LLC

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
*/

// Linux systems (including Raspberry Pi) require 49-teensy.rules in
// /etc/udev/rules.d/, and gstreamer compatible with Processing's
// video library.

// To configure this program, edit the following sections:
//
import g4p_controls.*;
import processing.video.*;
import processing.serial.*;
import java.awt.Rectangle;

// GUI
GButton DImage;
GButton DVideo;
GButton SBrigthness;
GButton LInterfaces;
GButton SInterfaces;
GButton SendRSerial;
GButton ToggleAuto;
int autoReloadImage = 0;

GTextField VLocator;
GTextField ILocator;
GTextField BValue;
GTextField LPort;
GTextField RSerial;

GLabel IList;
GLabel EList;

// END
float gamma = 1.7;

int numPorts=0;  // the number of serial ports in use
int maxPorts=1; // maximum number of serial ports
int stripeNumber = 1; //nombre de bande utilisé

String[] ledSerialName = new String[maxPorts];          // each port's actual name for display reasons
Serial[] ledSerial = new Serial[maxPorts];          // each port's actual Serial port
Rectangle[] ledArea = new Rectangle[maxPorts];      // the area of the movie each port gets, in % (0-100)
int[] ledLayout = new int[maxPorts];        // layout of rows, true = even is left->right (
int[] ledOrientation = new int[maxPorts];   // are rows vertical -> 1 or horizontal -> 0
PImage[] ledImage = new PImage[maxPorts];           // image sent to each port
int[] gammatable = new int[256];
int errorCount=0;
float framerate=0;
int mode = -1; //mode 1 = vid, 0 = img
Movie myMovie;
PImage displayImage;

void settings() {
  size(800, 800);  // create the window
}

void setup() {
  G4P.setMouseOverEnabled(false);
  
  surface.setTitle("Robopoly Matrix Control");
  DImage =         new GButton(this, 20, 20, 100, 30, "Display Image");
  DVideo =         new GButton(this, 20, 60, 100, 30, "Display Video");
  SBrigthness =    new GButton(this, 20, 100, 100, 30, "Set Brightness");
  SInterfaces =    new GButton(this, 20, 140, 100, 30, "Set Interfaces");
  LInterfaces =    new GButton(this, 650, 20, 100 , 30, "List Interfaces");
  SendRSerial =    new GButton(this, 20, 180, 100 , 30, "Send Serial");

  ToggleAuto  =    new GButton(this, 650, 180, 100, 30, "Enable Image Auto Reload");

  ILocator    =    new GTextField(this, 140, 20, 450, 30); 
  VLocator    =    new GTextField(this, 140, 60, 450, 30); 
  BValue      =    new GTextField(this, 140, 100, 300, 30); 
  LPort       =    new GTextField(this, 140, 140, 300, 30); 
  RSerial     =    new GTextField(this, 140, 180, 300, 30); 
  IList       =    new GLabel(this,  610, 60, 180, 40, "");
  EList       =    new GLabel(this,  500, 70, 250, 100, "No errors ...");

  DVideo.addEventHandler(this, "launchVideo");
  DImage.addEventHandler(this, "displayImage");

  VLocator.addEventHandler(this, "selectVid");
  ILocator.addEventHandler(this, "selectImg");
  ILocator.setText("C:\\Users\\teogo\\Downloads\\mario.jpg");
  
  
  LInterfaces.addEventHandler(this, "listIfaces");
  SInterfaces.addEventHandler(this, "setIfaces");

  SBrigthness.addEventHandler(this, "setBrightness");

  SendRSerial.addEventHandler(this, "sendRSerial");

  ToggleAuto.addEventHandler(this, "toggleAuto");
  
  for (int i=0; i < 256; i++) {
    gammatable[i] = (int)(pow((float)i / 255.0, gamma) * 255.0 + 0.5);
  }
  
  loop();
  //serialConfigure("COM12");
}

public void toggleAuto(GButton button, GEvent event){
   autoReloadImage = int((autoReloadImage == 0));
}
public void setIfaces(GButton button, GEvent event){
  EList.setText("No errors...");
  numPorts = 0;
  String[] list = LPort.getText().split(",");
  maxPorts=list.length;
  for(int i=0; i<maxPorts; i++)
  {
    serialConfigure(list[i]);
  }
  EList.setText(join(ledSerialName, ", "));
}

public void sendRSerial(GButton button, GEvent event){
  for(int i=0; i<maxPorts; i++)
  {
    ledSerial[i].write(RSerial.getText());
  }
}
public void listIfaces(GButton button, GEvent event){
  String[] list = Serial.list();
  delay(20);
  println(list);
  String concatStr = join(list, ", ");
  IList.setText(concatStr);
}

public void launchVideo(GButton button, GEvent event) {
    int go;
    try{
    File file = new File(VLocator.getText()); 
    if (file.canRead() != true) throw new NullPointerException();
    myMovie = new Movie(this, VLocator.getText()); 
    if (myMovie == null) throw new NullPointerException();
    mode=1;
     // start the movie :-)
    EList.setText("No errors...");
    go = 1;
    }
    catch(Throwable e)
    {
    EList.setText("cannot load video : "+VLocator.getText());
    go = 0;
    mode=-1;
    }
    if(go == 1) {
      myMovie.loop();
    }
 
}
  String text;
public void displayImage(GButton button, GEvent event) {
  if(myMovie != null){
    myMovie.stop();  // stop the movie :-)
  }
  int go;
  try {
   displayImage = loadImage(ILocator.getText()); //<>// //<>//
  if (displayImage == null) throw new NullPointerException();
  mode=0;
  EList.setText("No errors...");
  go=1;
  }
  catch(Throwable e)
  {
  EList.setText("cannot load image : "+ILocator.getText());
  go=0;
  mode=-1;
  }
  if(go == 1) imageDisplay(displayImage);

}

public void setBrightness(GButton button, GEvent event) {
  String brightness = BValue.getText();
  print("luminosité : ");
  println(brightness);
  for (int i=0; i < numPorts; i++) {
    ledSerial[i].write('b');
    ledSerial[i].write(brightness);
  }
}

public void selectImg(GTextField textfield,  GEvent event) {
  if(event.toString() == "GETS_FOCUS")
  {
    selectInput("Select an image", "imgSelected");
  }
}
public void selectVid(GTextField textfield,  GEvent event) {
  if(event.toString() == "GETS_FOCUS")
  {
    selectInput("Select a video", "vidSelected");
  }
}

public void imgSelected(File selection) {
  if(selection == null)
  {
    return;
  }
  ILocator.setText(selection.getAbsolutePath()); 
  DImage.fireAllEvents(false);
}

public void vidSelected(File selection) {
  if(selection == null)
  {
    return;
  }
  VLocator.setText(selection.getAbsolutePath()); 
  DVideo.fireAllEvents(false);
}

 
// movieEvent runs for each new frame of movie data
void movieEvent(Movie m) {
  println("movieEvent");
  // read the movie's next frame
  m.read();

  //if (framerate == 0) framerate = m.getSourceFrameRate();
  framerate = 30.0; // TODO, how to read the frame rate???

  for (int i=0; i < numPorts; i++) {
    // copy a portion of the movie's image to the LED image
    int xoffset = percentage(m.width, ledArea[i].x);
    int yoffset = percentage(m.height, ledArea[i].y);
    int xwidth =  percentage(m.width, ledArea[i].width);
    int yheight = percentage(m.height, ledArea[i].height);
    ledImage[i].copy(m, xoffset, yoffset, xwidth, yheight,
                     0, 0, ledImage[i].width, ledImage[i].height);
    // convert the LED image to raw data
    byte[] ledData =  new byte[(ledImage[i].width * ledImage[i].height * 3) + 3];
    image2data(ledImage[i], ledData, ledLayout[i], ledOrientation[i], 3);
    if (i == 0) {
      ledData[0] = '*';  // first Teensy is the frame sync master
      int usec = (int)((1000000.0 / framerate) * 0.75);
      ledData[1] = (byte)(usec);   // request the frame sync pulse
      ledData[2] = (byte)(usec >> 8); // at 75% of the frame time
    } else {
      ledData[0] = '%';  // others sync to the master board
      ledData[1] = 0;
      ledData[2] = 0;
    }
    // send the raw data to the LEDs  :-)
    ledSerial[i].write(ledData);
  }
}

void imageDisplay(PImage im) {
  println("imEvent");


  for (int i=0; i < numPorts; i++) {
    // copy a portion of the movie's image to the LED image
    int xoffset = percentage(im.width, ledArea[i].x);
    int yoffset = percentage(im.height, ledArea[i].y);
    int xwidth =  percentage(im.width, ledArea[i].width); //<>//
    int yheight = percentage(im.height, ledArea[i].height);
    
    ledImage[i].copy(im, xoffset, yoffset, xwidth, yheight,
                     0, 0, ledImage[i].width, ledImage[i].height);
    // convert the LED image to raw data
    byte[] ledData =  new byte[(ledImage[i].width * ledImage[i].height * 3) + 3];
    
    image2data(ledImage[i], ledData, ledLayout[i], ledOrientation[i], 1);

      ledData[0] = 'n';  // others sync to the master board
    
    // send the raw data to the LEDs  :-)
    ledSerial[i].write(ledData);
    println(ledData);
  }
}
 //<>//
void image2data(PImage image, byte[] data, int layout, int orientation, int offset)
{
  if(orientation == 0) // horizontal
  {
     image2dataX(image, data, layout, offset);
  }
  if(orientation == 1) //vertical
  {
      image2dataY(image, data, layout, offset);
  }
}
// image2data converts an image to raw data format.  24bit color in the order of the led
// The data array must be the proper size for the image.
void image2dataX(PImage image, byte[] data, int layout, int offset) {
  println("X");
  int x, y, xbegin, xend, xinc, mask;
  int linesPerPin = image.height / stripeNumber; //<>//
  int pixel = 0;
  for(int i=0; i<stripeNumber; i++)
  {
    for (y = 0; y < linesPerPin; y++) 
    {
      if ((y & 1) == (layout == 0 ? 0 : 1)) {
        // even numbered rows are left to right
        xbegin = 0;
        xend = image.width;
        xinc = 1;
      } else {
        // odd numbered rows are right to left
        xbegin = image.width - 1;
        xend = -1;
        xinc = -1;
      }
      for (x = xbegin; x != xend; x += xinc) {        // fetch x pixels from the image, 1 for each pin
          pixel = image.pixels[x + y * image.width];
          pixel = colorWiring(pixel);
          data[offset++] = byte((pixel & 0xFF0000) >> 16);
          data[offset++] = byte((pixel & 0x00FF00) >> 8);
          data[offset++] = byte((pixel & 0x0000FF));
        }
    }
  }
}

void image2dataY(PImage image, byte[] data, int layout, int offset) { //for vertical layouts
  int x, y, ybegin, yend, yinc, mask;
  int linesPerPin = image.width / stripeNumber;
  int pixel = 0;
  for(int i=0; i<stripeNumber; i++)
  {
    for (x = 0; x < linesPerPin; x++) 
    {
      if ((x & 1) == (layout == 0 ? 0 : 1)) {
        // even numbered rows are bottom to up
        ybegin = 0;
        yend = image.height;
        yinc = 1;
      } else {
        // odd numbered rows are up to bottom
        ybegin = image.height - 1;
        yend = -1;
        yinc = -1;
      }
      for (y = ybegin; y != yend; y += yinc) {        // fetch x pixels from the image, 1 for each pin
          pixel = image.pixels[y * image.height + x];
          pixel = colorWiring(pixel);
          data[offset++] = byte((pixel & 0xFF0000) >> 16);
          data[offset++] = byte((pixel & 0x00FF00) >> 8);
          data[offset++] = byte((pixel & 0x0000FF));
        }
    }
  }
}

// translate the 24 bit color from RGB to the actual
// order used by the LED wiring.  GRB is the most common.
int colorWiring(int c) {
  int red = (c & 0xFF0000) >> 16;
  int green = (c & 0x00FF00) >> 8;
  int blue = (c & 0x0000FF);
  red = gammatable[red];
  green = gammatable[green];
  blue = gammatable[blue];
//return c;
return (green << 16) | (red << 8) | (blue); // GRB - most common wiring
}

// ask a Teensy board for its LED configuration, and set up the info for it.
void serialConfigure(String portName) {
  if (numPorts >= maxPorts) {
    EList.setText(EList.getText() + "too many serial ports, please increase maxPorts");
    return;
  }
  if(ledSerial[numPorts] != null)
  {
    ledSerial[numPorts].stop();
  }
  try {
    ledSerial[numPorts] = new Serial(this, portName, 1000000);
    if (ledSerial[numPorts] == null) throw new NullPointerException();
    ledSerial[numPorts].write('?');
  } catch (Throwable e) {
    EList.setText(EList.getText() + "Serial port " + portName + " does not exist or is non-functional \n");
    return;
  }
  delay(50);
  String line = ledSerial[numPorts].readStringUntil(10);
  if (line == null) {
    EList.setText(EList.getText() + "Serial port " + portName + " is not responding. \n Is it really a ESP32 (like) running the correct Robopoly Prgm \n");
    return;
  }
  String param[] = line.split(",");
  if (param.length != 12) {
    EList.setText(EList.getText() + "Error: port " + portName + " did not respond to LED config query \n");
    return;
  }
  // only store the info and increase numPorts if Teensy responds properly
  ledImage[numPorts] = new PImage(Integer.parseInt(param[0]), Integer.parseInt(param[1]), RGB);
  ledArea[numPorts] = new Rectangle(Integer.parseInt(param[5]), Integer.parseInt(param[6]),
                     Integer.parseInt(param[7]), Integer.parseInt(param[8]));
  ledOrientation[numPorts] = (Integer.parseInt(param[2])); //<>//
  ledLayout[numPorts] = (Integer.parseInt(param[3])); //<>//
  ledSerialName[numPorts] = portName;
  numPorts++;
}

// draw runs every time the screen is redrawn - show the movie...
void draw() {
  background(240);
  //println("draw");
  // show the original video
  if(mode == 0)
  image(displayImage, 20, 300);
  
  if(mode == 1)
  image(myMovie, 20, 300);
  

  // then try to show what was most recently sent to the LEDs
  // by displaying all the images for each port.
  for (int i=0; i < numPorts; i++) {
    // compute the intended size of the entire LED array
    int xsize = percentageInverse(ledImage[i].width, ledArea[i].width);
    int ysize = percentageInverse(ledImage[i].height, ledArea[i].height);
    // computer this image's position within it
    int xloc =  percentage(xsize, ledArea[i].x);
    int yloc =  percentage(ysize, ledArea[i].y);
    // show what should appear on the LEDs
    image(ledImage[i], 400 + 240 - xsize / 2 + xloc, 400 + 10 + yloc);
  }
}

// respond to mouse clicks as pause/play
boolean isPlaying = true;
void mousePressed() {
  if (mode == 1 && isPlaying) {
    myMovie.pause();
    isPlaying = false;
  } else if (mode == 1) {
    myMovie.play();
    isPlaying = true;
  }
}

// scale a number by a percentage, from 0 to 100
int percentage(int num, int percent) {
  double mult = percentageFloat(percent);
  double output = num * mult;
  return (int)output;
}

// scale a number by the inverse of a percentage, from 0 to 100
int percentageInverse(int num, int percent) {
  double div = percentageFloat(percent);
  double output = num / div;
  return (int)output;
}

// convert an integer from 0 to 100 to a float percentage
// from 0.0 to 1.0.  Special cases for 1/3, 1/6, 1/7, etc
// are handled automatically to fix integer rounding.
double percentageFloat(int percent) {
  if (percent == 33) return 1.0 / 3.0;
  if (percent == 17) return 1.0 / 6.0;
  if (percent == 14) return 1.0 / 7.0;
  if (percent == 13) return 1.0 / 8.0;
  if (percent == 11) return 1.0 / 9.0;
  if (percent ==  9) return 1.0 / 11.0;
  if (percent ==  8) return 1.0 / 12.0;
  return (double)percent / 100.0;
}

int lastTime = 0;
public void loop()
{
  if(mode == 0 && autoReloadImage == 1 && millis()-lastTime < 30 )
  {
    imageDisplay(displayImage);  
  }
}
