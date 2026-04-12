# ⚓ Pico Naval Online (PicoCalc Edition) - Beta v5.8.1

A retro-multiplayer Battleship game for the **ClockworkPi PicoCalc** using networked communication.



## 🚀 The Project
This is an online version of the classic Naval Battle game, optimized for the **Raspberry Pi Pico 2W (RP2350)**. It features a multi-slot system that allows you to manage up to 5 concurrent matches on different "theaters of war."

### 💻 Verified Hardware Setup
This project has been tested and is 100% functional on:
- **Device:** ClockworkPi PicoCalc (Retro calculator shell).
- **MCU:** Raspberry Pi Pico 2W (RP2350).
- **Firmware:** WebMite MMBasic v6.02.01.

---

## 🛠️ Installation & Setup

### 1. Firmware
Ensure your Pico 2W is running **WebMite v6.02.01** or higher. This version is critical for stable TCP/IP communication and handling the RP2350's memory architecture.

### 2. Network Configuration
Connect your PicoCalc to WiFi via the WebMite console:
```mmbasic
OPTION WIFI "Your_SSID", "Your_Password"
