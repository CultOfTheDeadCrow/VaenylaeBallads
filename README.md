# VaenylaeBard

A World of Warcraft addon for [Turtle WoW](https://turtlecraft.gg/) that lets you compose, manage, and perform scripted bardic performances — sequences of chat messages and emotes with configurable timing.

---

## Features

- **Song composer** — create named songs with any number of lines
- **Per-line control** — set text, channel (SAY / YELL / EMOTE), emote, and delay for each line
- **Auto & manual playback** — run a performance on a timer or step through it line by line
- **Live playback display** — see the current and next line during a performance
- **Pause / resume** — suspend auto playback without losing your place
- **Flood protection** — enforces a minimum 1.5-second delay between lines
- **Persistent storage** — songs are saved between sessions via WoW SavedVariables

---

## Installation

1. Download or clone this repository.
2. Copy the `VaenylaeBard` folder into your WoW addons directory:
   ```
   World of Warcraft/Interface/AddOns/VaenylaeBard/
   ```
3. Launch the game and enable **VaenylaeBard** in the AddOn list on the character select screen.

> Requires Turtle WoW (Interface version 11307). Not compatible with retail or other WoW clients.

---

## Usage

### Opening the manager

```
/vbard
/vaenylaebard
```

### Playback commands

| Command | Description |
|---|---|
| `/vbard play` | Start auto playback of the selected song |
| `/vbard play manual` | Start manual playback (you control each step) |
| `/vbard next` | Send the next line (manual mode only) |
| `/vbard stop` | Stop the current performance |

### Composing a song

1. Open the manager with `/vbard`.
2. Click **Add Song** and give it a name.
3. Select the song, then add lines using the line editor.
4. For each line, set:
   - **Text** — what gets sent to chat
   - **Channel** — SAY, YELL, or EMOTE
   - **Emote** — an optional emote to fire alongside the line
   - **Emote type** — Built-in WoW emote (`DoEmote`) or custom (`/emote` text)
   - **Delay** — seconds to wait before this line plays (minimum 1.5s)

---

## Slash Commands Reference

| Command | Description |
|---|---|
| `/vbard` | Toggle the song manager UI |
| `/vbard play` | Auto playback |
| `/vbard play manual` | Manual step playback |
| `/vbard next` | Advance one line (manual mode) |
| `/vbard stop` | Stop playback |
| `/vbard debug` | Toggle debug logging |

---

## Project Structure

```
VaenylaeBard/
├── VaenylaeBard.lua   # All addon logic and UI
└── VaenylaeBard.toc   # Addon manifest
```

---

## Compatibility

- **Server:** Turtle WoW
- **Interface:** 11307 (WoW 1.12.1 era)
- **Language:** Lua 5.0

---

## Author

**Vaenylae** — built for Turtle WoW roleplay.
