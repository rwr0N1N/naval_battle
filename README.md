# ⚓ Pico Naval Online (PicoCalc Edition)
> **A multiplayer networked Battleship game for the ClockworkPi PicoCalc.**

[![Status](https://img.shields.io/badge/Status-Beta--Testing-orange)](#)
[![Firmware](https://img.shields.io/badge/WebMite-6.02.01-blue)](#)
[![Hardware](https://img.shields.io/badge/Hardware-PicoCalc%20%2F%20RP2350-green)](#)

## 🚀 Overview
This project brings the classic Naval Battle (Battleship) to the **Raspberry Pi Pico 2W**, specifically optimized for the **ClockworkPi PicoCalc** shell. It features a robust multi-slot management system, allowing you to run up to 5 concurrent online matches.

### 💻 Confirmed Hardware Setup
| Component | Specification |
| :--- | :--- |
| **Device** | ClockworkPi PicoCalc |
| **MCU** | Raspberry Pi Pico 2W (RP2350) |
| **Firmware** | WebMite MMBasic v6.02.01 |
| **Display** | VGA/LCD via WebMite Framebuffer |

---

## ⚠️ PROJECT STATUS: BETA
This project is currently in **Active Testing**. While the core gameplay and networking are functional, users may encounter edge-case bugs.

### 🛡️ How to Help
If you find any errors (Network timeouts, graphical glitches, or logic bugs):
1. Open an **Issue** in this repository.
2. Provide details about your hardware and the steps that caused the error.
*Every bug reported will be analyzed and fixed in the next version with AI assistance!*

---

## 🛠️ Installation & Setup

### 1. Firmware Configuration
Your Pico 2W must be running **WebMite v6.02.01** or higher. 
Configure your WiFi connection via the console:

OPTION WIFI "Your_SSID", "Your_Password"

2. Server Relay

The game uses a Python Flask relay to sync data between players.

Upload relay_server.py to your host (e.g., PythonAnywhere).

Update the Const HOST$ in the naval_battle.bas file to point to your URL.

3. Loading the Game

Load the naval_battle.bas file onto your Pico and run it.

🎮 How to Play

The War Room (Lobby)

Slots 1-5: You can manage 5 independent "Theaters of War".

[ENTER]: Search for a new match.

[1-5]: Switch between active battles.

Deployment Phase

Arrow Keys: Move the ship.

[SPACE]: Rotate the ship.

[ENTER]: Confirm placement.

Iron Wall Logic: Ships are automatically clamped to prevent clipping outside the 10x10 grid.

Battle Phase

[ENTER]: Fire your missile on the target.

[V]: Toggle view between your Fleet and the Radar.

[ESC]: Return to the War Room (The game continues in the background).

📜 Acknowledgments

Author: rwr0n1n

AI Collaborator: Gemini AI

MMBasic/WebMite: Peter Mather & Geoff Graham.

Developed for the retro-computing community. Sink 'em all! ⚓🚀
