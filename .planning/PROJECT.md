# VaenylaeBard

## What This Is

VaenylaeBard is a World of Warcraft addon for roleplay-focused private servers that lets players compose, manage, and perform scripted bardic performances — sequences of chat messages and emotes with configurable timing. The addon targets WoW 3.3.5a (WotLK, Interface 30300).

## Core Value

A bard can script and perform a full song — text, emotes, channels, and pacing — without manual typing during the performance.

## Current Milestone: v1.0 WotLK Port

**Goal:** Port VaenylaeBard from Turtle WoW (1.12.1, Lua 5.0) to WoW 3.3.5a (Lua 5.1) with full feature parity and no regressions.

**Target features:**
- Update .toc Interface version to 30300
- Fix OnUpdate/OnEvent callbacks to use Lua 5.1 function parameter syntax
- Fix all SetScript closures that reference the `this` global
- Fix StaticPopupDialogs callbacks (`this` → `self`)
- Replace `table.getn()` with `#` operator

## Requirements

### Validated

(None yet — first milestone)

### Active

- [ ] .toc Interface version updated to 30300
- [ ] OnUpdate callback uses `elapsed` parameter instead of global `arg1`
- [ ] OnEvent callback uses `self, event, arg1` parameters instead of globals
- [ ] All SetScript closures receive `self` as explicit first parameter (no `this` global)
- [ ] StaticPopupDialogs OnShow / OnAccept / EditBoxOnEnterPressed use `self` not `this`
- [ ] `table.getn()` replaced with `#` throughout

### Out of Scope

- New features — this milestone is a pure compatibility port
- WotLK-specific API improvements (LibStub, ACE3, etc.) — YAGNI
- Retail or other client versions — targeting 3.3.5a only

## Context

- **Origin:** Originally written for Turtle WoW (custom 1.12.1 server), Interface 11307, Lua 5.0
- **Target:** Faebright WoW at `/home/reset/Games/Faebright WoW/` — a 3.3.5a (WotLK) client
- **Lua delta:** Lua 5.0 passed extra event/callback args via globals (`this`, `event`, `arg1`); Lua 5.1 passes them as explicit function parameters
- **Single-file addon:** All logic in `VaenylaeBard.lua` — no split modules

## Constraints

- **Client:** WoW 3.3.5a only (Interface 30300)
- **Scope:** Zero feature changes — every capability that works on Turtle WoW must work identically after the port
- **Single file:** Do not split into multiple Lua files unless required

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Port without feature changes | Establishes a clean 3.3.5a baseline before any WotLK-era additions | — Pending |
| Keep single-file structure | Addon is small enough; splitting adds complexity with no benefit | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-12 after v1.0 milestone start*
