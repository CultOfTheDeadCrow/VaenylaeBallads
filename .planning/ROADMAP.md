# Roadmap: VaenylaeBard

## Overview

A single compatibility pass through VaenylaeBard.lua and VaenylaeBard.toc that migrates the addon from Turtle WoW (1.12.1, Lua 5.0, Interface 11307) to WoW 3.3.5a (Lua 5.1, Interface 30300). All 17 affected locations across 6 change categories are fully enumerated. The milestone is complete when the addon runs on the 3.3.5a client with no regressions against the 1.12.1 behavior.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: WotLK Compatibility Port** - Apply all Lua 5.0→5.1 and Interface 11307→30300 fixes to achieve full feature parity on WoW 3.3.5a

## Phase Details

### Phase 1: WotLK Compatibility Port
**Goal**: VaenylaeBard runs on WoW 3.3.5a with complete feature parity to the 1.12.1 version
**Depends on**: Nothing (first phase)
**Requirements**: PORT-01, PORT-02, PORT-03, PORT-04, PORT-05, PORT-06, PORT-07
**Success Criteria** (what must be TRUE):
  1. The 3.3.5a client loads VaenylaeBard without an out-of-date warning on login
  2. Logging into the game initializes the addon: the songs list populates and SavedVariables load correctly
  3. A song performs in auto mode from the first line to the last without Lua errors, frame freezes, or timing drift
  4. All UI controls respond correctly: both frames drag-to-move, mode/channel/emote-type toggle buttons cycle their states, and playback start/stop/manual advance work
  5. The Add Song dialog accepts keyboard input and saves the new song to the list when confirmed
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. WotLK Compatibility Port | 0/TBD | Not started | - |
