---
phase: 01-wotlk-compatibility-port
plan: 03
subsystem: addon-compatibility
tags: [lua, wow-addon, wotlk, lua51, staticpopup, this-to-self, editbox, deployment]

# Dependency graph
requires: [01-01, 01-02]
provides:
  - "StaticPopupDialogs OnShow: function(self), self.editBox:SetFocus() — auto-focus on popup open"
  - "StaticPopupDialogs OnAccept: function(self), self.editBox:GetText() — song name read from editBox"
  - "StaticPopupDialogs EditBoxOnEnterPressed: function(self), self:GetParent().button1:Click() — Enter saves song"
  - "All 17 WotLK compatibility changes verified by post-edit grep suite (zero obsolete patterns)"
  - "VaenylaeBard.lua and VaenylaeBard.toc deployed to Faebright WoW AddOns directory"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "StaticPopupDialogs callbacks receive self as the popup frame (not the button) in 3.3.5a"
    - "self.editBox direct field access (WoW engine sets this field on hasEditBox=1 dialogs)"
    - "self:GetParent().button1 lowercase field for Accept button in 3.3.5a popup frame"

key-files:
  created:
    - /home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/VaenylaeBard.lua
    - /home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/VaenylaeBard.toc
  modified:
    - VaenylaeBard.lua

key-decisions:
  - "self IS the popup frame in 3.3.5a OnAccept (not the button as in 1.12.1 — no GetParent() needed for editBox)"
  - "self.editBox preferred over _G[self:GetName()..\"EditBox\"] — direct field set by WoW engine for hasEditBox=1 dialogs"
  - "self:GetParent().button1 lowercase field chosen per CONTEXT.md locked decision (ElvUI/Core/Distributor.lua line 577)"

patterns-established:
  - "StaticPopupDialogs callbacks always declare self as explicit first parameter in 3.3.5a"
  - "editBox accessed as self.editBox direct field, not via _G string navigation"

requirements-completed: [PORT-06]

# Metrics
duration: 4min
completed: 2026-05-12
---

# Phase 1 Plan 3: StaticPopupDialogs PORT-06 Fixes and Deployment Summary

**StaticPopupDialogs callbacks converted from `this` global to explicit `self` with self.editBox navigation; all 17 compatibility fixes verified by post-edit grep; addon deployed to Faebright WoW**

## Performance

- **Duration:** 4 min
- **Started:** 2026-05-12T18:42:00Z
- **Completed:** 2026-05-12T18:45:52Z
- **Tasks:** 2 completed (Task 3 is a human-verify checkpoint — pending user in-game testing)
- **Files modified:** 1

## Accomplishments

- StaticPopupDialogs OnShow (line 772-773): `function()` + `_G[this:GetName().."EditBox"]:SetFocus()` → `function(self)` + `self.editBox:SetFocus()`
- StaticPopupDialogs OnAccept (line 775-776): `function()` + `_G[this:GetParent():GetName().."EditBox"]:GetText()` → `function(self)` + `self.editBox:GetText()`
- StaticPopupDialogs EditBoxOnEnterPressed (line 787-788): `function()` + `_G[this:GetParent():GetName().."Button1"]:Click()` → `function(self)` + `self:GetParent().button1:Click()`
- Post-edit grep verification suite: all 7 checks passed (zero obsolete patterns; all updated values confirmed)
- Deployed VaenylaeBard.lua and VaenylaeBard.toc to `/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/`

## Task Commits

Each task was committed atomically:

1. **Task 1: StaticPopupDialogs callbacks — this→self with self.editBox navigation (PORT-06)** - `7c68997` (feat)
2. **Task 2: Post-edit grep verification and deployment** - No new commit required (all changes committed in Task 1; working tree was clean; deployment is filesystem-only)

## Files Created/Modified

- `VaenylaeBard.lua` — 6 edits: OnShow signature (line 772), OnShow body (line 773), OnAccept signature (line 775), OnAccept body (line 776), EditBoxOnEnterPressed signature (line 787), EditBoxOnEnterPressed body (line 788)
- `/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/VaenylaeBard.lua` — deployed copy
- `/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/VaenylaeBard.toc` — deployed copy

## Decisions Made

- `self` IS the popup frame in 3.3.5a OnAccept (not the button as in 1.12.1). The 1.12.1 OnAccept received the button widget as `this` and needed `this:GetParent()` to reach the frame. In 3.3.5a, `self` is already the popup frame — no GetParent() needed to access editBox.
- `self.editBox` chosen over `_G[self:GetName().."EditBox"]` string navigation. WoW engine automatically sets the `.editBox` field on hasEditBox=1 popup frames, confirmed by ElvUI/Core/Distributor.lua reference.
- `self:GetParent().button1` lowercase field per CONTEXT.md locked decision (ElvUI/Core/Distributor.lua line 577 precedent).

## Post-Edit Grep Verification Results

All checks run from worktree root:

| Check | Command | Result |
|-------|---------|--------|
| table.getn | `grep -n 'table\.getn'` | PASS: zero results |
| this: references | `grep -n '\bthis:'` | PASS: zero results |
| this word boundary | `grep -n '\bthis\b'` | PASS: zero results |
| playbackElapsed.*arg1 | `grep -n 'playbackElapsed.*arg1'` | PASS: zero results |
| Interface version | `grep -n 'Interface:' VaenylaeBard.toc` | PASS: `## Interface: 30300` |
| OnEvent signature | `grep -n 'OnEvent.*function'` | PASS: `function(self, event, arg1)` |
| OnUpdate signature | `grep -n 'OnUpdate.*function'` | PASS: `function(self, elapsed)` |

## Checkpoint Pending (Task 3)

Task 3 is `type="checkpoint:human-verify"` — requires in-game testing on the 3.3.5a Faebright WoW client. The addon is deployed and ready for verification. See checkpoint details in completion message.

## Deviations from Plan

**1. [Rule 3 - Blocking resolved] Task 2 commit step skipped — working tree already clean**
- **Found during:** Task 2 Step 2
- **Issue:** The plan's Task 2 Step 2 instructs `git add VaenylaeBard.toc VaenylaeBard.lua` and a summary commit. However Task 1 already committed VaenylaeBard.lua atomically (per-task commit protocol), and VaenylaeBard.toc had no changes in this plan (already correct from plan 01-01). Working tree was clean with nothing to stage.
- **Fix:** Proceeded directly to deployment (Step 3). All 17 changes are correctly captured across the atomic per-task commits in plans 01-01, 01-02, and 01-03.
- **No impact:** git log shows the complete fix history; all changes are committed.

## Known Stubs

None.

## Threat Flags

None — edits are mechanical this→self substitutions in StaticPopupDialogs callbacks. Deployment is a local filesystem cp with no network involvement. No new trust boundaries introduced.

## User Setup Required

In-game verification required (Task 3 checkpoint). Start Faebright WoW (3.3.5a) and execute the 5-point success criteria checklist.

## Next Phase Readiness

- All 17 WotLK compatibility fixes complete (PORT-01 through PORT-07)
- Addon deployed to Faebright WoW
- Awaiting human in-game verification (SC-1 through SC-5)
- Note from STATE.md: If SC-5 EditBoxOnEnterPressed pressing Enter does nothing, fallback is `_G[self:GetParent():GetName().."Button1"]:Click()` at line 788

## Self-Check: PASSED

- [x] Line 772: `OnShow = function(self)`
- [x] Line 773: `self.editBox:SetFocus()`
- [x] Line 775: `OnAccept = function(self)`
- [x] Line 776: `local songName = self.editBox:GetText()`
- [x] Line 787: `EditBoxOnEnterPressed = function(self)`
- [x] Line 788: `self:GetParent().button1:Click()`
- [x] grep `_G[this`: zero results
- [x] grep `table.getn`: zero results
- [x] grep `\bthis:`: zero results
- [x] grep `\bthis\b`: zero results
- [x] grep `playbackElapsed.*arg1`: zero results
- [x] VaenylaeBard.toc Interface: 30300
- [x] OnEvent: function(self, event, arg1)
- [x] OnUpdate: function(self, elapsed)
- [x] VaenylaeBard.lua deployed to Faebright WoW
- [x] VaenylaeBard.toc deployed to Faebright WoW
- [x] Commit 7c68997 exists (Task 1)

---
*Phase: 01-wotlk-compatibility-port*
*Completed: 2026-05-12*
