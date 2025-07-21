Step 1: Install Arduino IDE
Visit the official Arduino website:
https://www.arduino.cc/en/software

Download the latest version for your operating system (Windows, macOS, or Linux).

Install the Arduino IDE following the installation wizard.

🔌 Step 2: How to Run the Provided Code
Requirements:
✅ Arduino IDE installed
✅ ESP32 Board

1️⃣ Install ESP32 Board in Arduino IDE
Open Arduino IDE.

Go to: File > Preferences

In the "Additional Boards Manager URLs," add this link:
https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json

Go to: Tools > Board > Boards Manager…

Search for ESP32 and click Install.

2️⃣ Select the Board
Go to:
Tools > Board > Select ESP32 Dev Module

3️⃣ Connect & Upload
Connect your ESP32 via USB.

Select the correct COM port from Tools > Port.

Paste the provided code into Arduino IDE.

Click ✅ Verify to compile.

Click 🔼 Upload to flash the ESP32.

If everything is correct, you will see in Serial Monitor (baud 115200):
✅ WiFi connected
✅ Sensor values
✅ Sending data to ThingSpeak successfully

🌐 Step 3: ThingSpeak Cloud Data Sending
1️⃣ Create Free ThingSpeak Account:
Go to: https://thingspeak.com/

Sign up and create two channels:

Channel 1: For gases (H2, CH4, etc.)

Channel 2: For load & temperature.

Get API Keys for both channels from the "API Keys" tab.

In the provided code:

cpp
Copy
Edit
const char* channel1ApiKey = "Your Channel 1 Key";
const char* channel2ApiKey = "Your Channel 2 Key";
Replace these with your own keys.

2️⃣ How Data is Sent
The ESP32 sends HTTP requests every 15 seconds to ThingSpeak:

Channel 1: 8 fields for gas concentrations

Channel 2: 2 fields for load and temperature

You can verify this live on ThingSpeak in your Channel View.



//////////////////////////////////////////////////////////////////

Ardinuo


1️⃣ Download Arduino IDE:
👉 https://www.arduino.cc/en/software

2️⃣ Install Board Packages:

For Arduino UNO: Already built-in.

 How to Upload Code
✅ For Arduino UNO:
Select Arduino UNO from Tools > Board

Select correct COM Port

Write code (no WiFi unless using extra module)

Upload directly via USB


////////////////////////////////////////////

