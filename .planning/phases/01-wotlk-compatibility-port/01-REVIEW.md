---
phase: 01-wotlk-compatibility-port
reviewed: 2026-05-12T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - VaenylaeBard.lua
  - VaenylaeBard.toc
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-05-12
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Both files were reviewed against the 17-change WoW 3.3.5a compatibility port specification documented in `01-PATTERNS.md` and `01-RESEARCH.md`. All 17 planned changes (PORT-01 through PORT-07) were applied correctly — no Lua 5.0 globals (`this`, `arg1`/`arg2` outside parameters, `table.getn`, `table.foreach`, `table.foreachi`, `getglobal`) remain, all `SetScript` closures carry the `self` parameter, the `OnEvent` and `OnUpdate` signatures match the verified 3.3.5a analogs, and the residual-subtraction timing fix is in place.

Three defects were found below the port-change surface: one potential Lua runtime error in the line-list renderer, one dead variable in the UI sync function, and one non-idiomatic `StaticPopupDialogs` field value. Two additional informational issues concern comment accuracy and a minor NOW/NEXT label pre-fire state.

---

## Warnings

### WR-01: Unguarded `line.text` concatenation crashes `UpdateLineList` on nil

**File:** `VaenylaeBard.lua:673`
**Issue:** `btn:SetText(i .. ". " .. line.text)` will throw a Lua runtime error (`attempt to concatenate a nil value (field 'text')`) if any stored line record lacks a `.text` key. This can happen with corrupted or legacy `SavedVariables` data, or any manually-edited `.WTF` file. Every other site that reads `line.text` already uses a nil-safe default (`line.text or ""`), making this the only unguarded call site in the file.
**Fix:**
```lua
btn:SetText(i .. ". " .. (line.text or ""))
```

---

### WR-02: `hasEditBox = true` diverges from the integer convention documented in analogs

**File:** `VaenylaeBard.lua:771`
**Issue:** `hasEditBox = true` uses a Lua boolean. The verified 3.3.5a analogs (ElvUI Distributor, Postal) and the own `01-PATTERNS.md` documentation (lines 379, 427) consistently use `hasEditBox = 1`. WoW 3.3.5a `StaticPopup.lua` checks this field with truthiness (`if popup.hasEditBox then`), so the dialog will open correctly. However, the engine then sets `self.editBox` only when it deems the dialog to have an edit box. If any engine path uses an integer comparison (`popup.hasEditBox == 1`) rather than a truthiness check — possible in C-side FrameXML glue code that is not inspectable without the client source — `self.editBox` will be nil at runtime, causing `OnShow` and `OnAccept` to throw immediately. The risk is low but non-zero, and the fix is trivial.
**Fix:**
```lua
hasEditBox = 1,
```

---

### WR-03: `stopBtn` fetched but never used in `UpdatePerformanceControls`

**File:** `VaenylaeBard.lua:249`
**Issue:** `local stopBtn = _G["VaenylaeBardStopButton"]` is assigned but no method is ever called on it within the function body (lines 246–285). The stop button's visibility is not managed by this function — it remains permanently visible as a child of `controlsRow`. The dead variable adds noise and could mislead a future maintainer into thinking stop-button state is being synchronized when it is not.
**Fix:** Remove the unused local or, if stop-button visibility management is intended, add the appropriate `stopBtn:Show()` / `stopBtn:Hide()` calls alongside the other button state updates:
```lua
-- Remove line 249, or replace with intentional visibility logic, e.g.:
-- stopBtn:Show()  (always, when controlsRow is shown)
```

---

## Info

### IN-01: Comments at lines 631 and 674 misattribute a Lua 5.1 issue to Lua 5.0

**File:** `VaenylaeBard.lua:631`, `VaenylaeBard.lua:674`
**Issue:** Both `capturedName` and `capturedIndex` are correctly captured per-iteration, and the rationale comment says `-- capture per-iteration; loop vars are shared in Lua 5.0`. The variable-sharing problem in generic `for` loops (`pairs`, `ipairs`) exists in Lua 5.1 as well — it is not a 5.0-only issue. The comment will mislead a future reader into thinking the capture can be removed now that the code runs on Lua 5.1.
**Fix:** Update both comments to describe the actual Lua 5.1 behavior:
```lua
local capturedName = songName  -- capture per-iteration; generic for vars are shared upvalues in Lua 5.1
local capturedIndex = i        -- capture per-iteration; generic for vars are shared upvalues in Lua 5.1
```

---

### IN-02: NOW label pre-set to un-fired line 1 on performance start

**File:** `VaenylaeBard.lua:400-403`
**Issue:** When the Play button is clicked, the inline label initialization block (lines 393–414) sets the NOW label to `song[1].text` and the NEXT label to `song[2].text` before line 1 has actually fired. The NOW label is semantically defined as "just-dispatched line," but at start time it previews a line that has not yet been sent. In auto mode line 1 fires after `effectiveDelay` seconds; in manual mode it fires on the next button click. Until that moment, the NOW label shows content that has not been performed. This does not affect correctness of delivery, but it may confuse a performer watching the UI.
**Fix:** Clear both labels at start and let `UpdateNowNext()` populate them after the first dispatch, or relabel NOW as "NEXT UP" for the pre-fire state. No code change is strictly required for correctness.

---

## Port Changes — Verified Correct

All 17 enumerated changes from the phase plan are present and correct:

| Change | Site | Verified |
|--------|------|---------|
| PORT-01 | `VaenylaeBard.toc:1` — Interface `30300` | OK |
| PORT-02 | `VaenylaeBard.lua:200` — `OnEvent function(self, event, arg1)` | OK |
| PORT-03 | `VaenylaeBard.lua:134,139` — `OnUpdate function(self, elapsed)` + `elapsed` body var | OK |
| PORT-04 (×5) | Lines 91, 107, 129, 161, 630 — `#` replaces `table.getn` | OK |
| PORT-05a | Lines 307–308 — MainFrame drag `self` | OK |
| PORT-05b | Lines 444–451 — modeBtn `self` | OK |
| PORT-05c | Lines 493–494 — LineEditorFrame drag `self` | OK |
| PORT-05d | Lines 538–554 — channelBtn `self` | OK |
| PORT-05e | Lines 572–581 — emoteTypeBtn `self` | OK |
| PORT-06 | Lines 772–789 — StaticPopup `self.editBox` and `self:GetParent().button1:Click()` | OK |
| PORT-07 | Line 156 — residual subtraction `VB_playbackElapsed - effectiveDelay` | OK |
| Comment hygiene | Lines 198–199 — updated to 3.3.5a/Lua 5.1 wording | OK |

No remaining `this`, `arg1`/`arg2` globals, `table.getn`, `table.foreach`, `table.foreachi`, `getglobal`, or `setglobal` calls detected.

---

_Reviewed: 2026-05-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
