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
3. Server Relay

The game requires a Python Flask relay to synchronize moves.

    Host the provided relay_server.py on PythonAnywhere or any public VPS.

    Update the Const HOST$ in the .bas file to your server address.

🎮 How to Play (Tutorial)

    The War Room: Upon launching, you will see 5 slots. Empty slots are for new games; active slots let you resume battles.

    Matchmaking: Press [ENTER] to join the queue. The game will assign you a Match ID.

    Deployment: - Use Arrow Keys to move your ships.

        Press [SPACE] to rotate.

        Press [ENTER] to lock the position.

        Note: The "Iron Wall" logic prevents ships from clipping outside the 10x10 grid.

    Battle: - When it's your turn, move the cursor and press [ENTER] to fire.

        Press [V] at any time to toggle between your Fleet View and the Radar View.

        Press [ESC] to return to the War Room and check other active matches.

⚠️ BETA PHASE: Call for Testers

This project is currently in Beta Testing. We are looking for community feedback to identify edge cases and optimize network latency.
🛡️ Known Issues & Troubleshooting

    Desyncs: If the network is unstable, polling might lag. Check the status bar at the bottom.

    Index Errors: We implemented guards for n_idx, but please report if the ship placement sequence breaks.

🔧 How to contribute

If you find a bug:

    Open an Issue on this repository.

    Provide your WebMite version and a brief description of the error.

    Every reported bug is analyzed and fixed with AI assistance!

Author: rwr0n1n

Co-Developer: Gemini AI

Firmware Base: WebMite by Peter Mather & Geoff Graham.
