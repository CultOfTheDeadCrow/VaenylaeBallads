---
phase: 01-wotlk-compatibility-port
plan: 02
subsystem: addon-compatibility
tags: [lua, wow-addon, wotlk, lua51, setscript, this-to-self, drag-to-move, button-toggle]

# Dependency graph
requires: [01-01]
provides:
  - "All 7 SetScript closures use explicit self parameter — zero this references in SetScript callbacks"
  - "MainFrame drag-to-move restored (OnDragStart/OnDragStop at lines 307-308)"
  - "LineEditorFrame drag-to-move restored (OnDragStart/OnDragStop at lines 493-494)"
  - "modeBtn toggle works without Lua error (OnClick at lines 444-451)"
  - "channelBtn cycles SAY/YELL/EMOTE without Lua error (OnClick at lines 538-554)"
  - "emoteTypeBtn toggles Custom/Built-in without Lua error (OnClick at lines 572-581)"
affects: [01-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SetScript closures declare function(self) even for single-line drag handlers"
    - "Multi-line button toggle closures use self: throughout (GetText, SetText, GetFontString)"

key-files:
  created: []
  modified:
    - VaenylaeBard.lua

key-decisions:
  - "StaticPopupDialogs this references at lines 773/776/788 intentionally deferred to plan 01-03 (PORT-06) — they are not SetScript closures"
  - "Upvalue-only closures at lines 313 and 504-507 left untouched — they use f: upvalue, not this, and were already correct"

patterns-established:
  - "Single-line drag SetScript closures: function(self) self:StartMoving()/StopMovingOrSizing()"
  - "Multi-line button OnClick closures: all method calls via self: not this:"

requirements-completed: [PORT-05]

# Metrics
duration: 5min
completed: 2026-05-12
---

# Phase 1 Plan 2: SetScript this→self (7 Closures) Summary

**All 7 SetScript closures converted from `this` global to explicit `self` parameter — drag-to-move and button toggle interactions restored for WoW 3.3.5a**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-12T18:38:00Z
- **Completed:** 2026-05-12T18:42:46Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- MainFrame OnDragStart/OnDragStop (lines 307-308): `function()` with `this:` → `function(self)` with `self:` — drag-to-move restored
- LineEditorFrame OnDragStart/OnDragStop (lines 493-494): same fix — drag-to-move restored on line editor
- modeBtn OnClick (lines 444-451): signature + all 4 `this:` references converted — Auto/Manual toggle works
- channelBtn OnClick (lines 538-554): signature + all 6 `this:` references converted — SAY/YELL/EMOTE cycling works
- emoteTypeBtn OnClick (lines 572-581): signature + 2 `this:` references converted — Custom/Built-in toggle works

## Task Commits

Each task was committed atomically:

1. **Task 1: MainFrame and LineEditorFrame drag handlers** - `3ed03d6` (feat)
2. **Task 2: modeBtn, channelBtn, and emoteTypeBtn OnClick closures** - `cb27db7` (feat)

## Files Created/Modified

- `VaenylaeBard.lua` — 19 edits total: 4 drag handler lines (307, 308, 493, 494) and 15 button closure lines (444, 445, 446, 448, 450, 538, 541, 542, 545, 546, 549, 550, 572, 575, 578)

## Decisions Made

- StaticPopupDialogs `this` references at lines 773, 776, 788 intentionally left for plan 01-03 (PORT-06). These are dialog table function values, not SetScript closures — they are outside the scope of this plan's 7-closure objective and were always intended for 01-03.
- Upvalue-only closures at line 313 (MainFrame closeBtn) and lines 504-507 (LineEditorFrame closeBtn) were not modified — they correctly use `f` upvalue and do not reference `this`.

## Deviations from Plan

None — plan executed exactly as written. The 3 remaining `this` references after Task 2 (lines 773, 776, 788) are in StaticPopupDialogs scope explicitly assigned to plan 01-03.

## Known Stubs

None.

## Threat Flags

None — all edits are mechanical this→self substitutions at enumerated lines with no logic change. Post-edit grep confirms zero `this` references in any SetScript callback.

## User Setup Required

None.

## Next Phase Readiness

- PORT-05 complete. All 7 SetScript closures use explicit self parameter.
- Both frames drag-to-move correctly; all three toggle buttons operate without Lua errors.
- Remaining for Phase 01: PORT-06 (StaticPopupDialogs this→self navigation), covered in plan 01-03.

## Self-Check: PASSED

- [x] Line 307: `f:SetScript("OnDragStart", function(self) self:StartMoving() end)`
- [x] Line 308: `f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)`
- [x] Line 493: `f:SetScript("OnDragStart", function(self) self:StartMoving() end)`
- [x] Line 494: `f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)`
- [x] Line 444: `modeBtn:SetScript("OnClick", function(self)`
- [x] Line 538: `channelBtn:SetScript("OnClick", function(self)`
- [x] Line 572: `emoteTypeBtn:SetScript("OnClick", function(self)`
- [x] grep `\bthis:\b` in SetScript closures: zero results
- [x] Upvalue-only closures at lines 313, 504-507 unchanged
- [x] Commit 3ed03d6 exists (Task 1)
- [x] Commit cb27db7 exists (Task 2)

---
*Phase: 01-wotlk-compatibility-port*
*Completed: 2026-05-12*
