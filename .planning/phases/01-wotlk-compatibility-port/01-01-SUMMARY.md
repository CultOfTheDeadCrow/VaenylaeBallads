---
phase: 01-wotlk-compatibility-port
plan: 01
subsystem: addon-compatibility
tags: [lua, wow-addon, wotlk, lua51, interface-version, callback-signatures, table-getn]

# Dependency graph
requires: []
provides:
  - "VaenylaeBard.toc Interface version set to 30300 (WoW 3.3.5a)"
  - "OnEvent callback signature: function(self, event, arg1) — ADDON_LOADED and PLAYER_LOGOUT fire correctly"
  - "OnUpdate callback signature: function(self, elapsed) — auto-playback timer advances each frame"
  - "Timing residual subtraction: VB_playbackElapsed -= effectiveDelay prevents drift"
  - "All five table.getn() calls replaced with # operator — no Lua errors in hot path or UI"
affects: [01-02, 01-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "WoW 3.3.5a SetScript callbacks declare explicit (self, ...) parameters"
    - "Lua 5.1 length operator # used instead of table.getn()"
    - "OnUpdate timing uses residual subtraction to preserve sub-frame overshoot"

key-files:
  created: []
  modified:
    - VaenylaeBard.toc
    - VaenylaeBard.lua

key-decisions:
  - "self declared as explicit first parameter on OnUpdate even though body uses upvalues — required to shift elapsed to the correct position"
  - "Parameter names event and arg1 chosen for OnEvent to make body lines 201-209 diff-free"
  - "Residual subtraction applied opportunistically while OnUpdate body was open (PORT-07)"
  - "Comment at lines 198-199 updated from 1.12.1/Lua 5.0 to 3.3.5a/Lua 5.1 per CONTEXT.md decision"

patterns-established:
  - "SetScript callbacks always declare self as first param, even if unused in body"
  - "# operator used for all sequence table length checks (no table.getn)"

requirements-completed: [PORT-01, PORT-02, PORT-03, PORT-04, PORT-07]

# Metrics
duration: 3min
completed: 2026-05-12
---

# Phase 1 Plan 1: WotLK Core Compatibility Summary

**Interface version bumped to 30300, OnEvent/OnUpdate Lua 5.1 signatures fixed, five table.getn() calls replaced with # operator, and timing drift eliminated via residual subtraction**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-12T18:36:07Z
- **Completed:** 2026-05-12T18:38:36Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- VaenylaeBard.toc: Interface 11307 → 30300, unblocking the 3.3.5a client loader (PORT-01)
- OnEvent/OnUpdate callback signatures fixed for Lua 5.1 explicit parameter passing (PORT-02, PORT-03)
- Timing drift fixed with residual subtraction reset on VB_playbackElapsed (PORT-07)
- All five table.getn() calls replaced with # operator — zero remain in file (PORT-04)

## Task Commits

Each task was committed atomically:

1. **Task 1: .toc Interface bump, OnEvent/OnUpdate signatures, residual subtraction** - `c180e2a` (feat)
2. **Task 2: Replace all five table.getn() calls with # operator** - `b56a358` (feat)

## Files Created/Modified
- `VaenylaeBard.toc` - Interface field updated from 11307 to 30300
- `VaenylaeBard.lua` - Six edits: OnUpdate signature+body (lines 134, 139), residual subtraction (line 156), comment update (lines 198-199), OnEvent signature (line 200), five table.getn replacements (lines 91, 107, 129, 161, 630)

## Decisions Made
- `self` declared as explicit first parameter on OnUpdate even though the body accesses all state via upvalues. Required: WoW always passes the owning frame as parameter 1; writing `function(elapsed)` would receive the frame object as elapsed, producing garbage timing.
- Parameter names `event` and `arg1` chosen for OnEvent body compatibility: old global names become local parameter names with identical values, making lines 201-209 diff-free.
- Residual subtraction applied opportunistically while OnUpdate body was open (per CONTEXT.md "Claude's Discretion" note).

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

**Worktree path confusion:** Initial edits were applied to main repo files (`/home/reset/Dev/Repos/VaenylaeBallads/VaenylaeBard.lua`) instead of worktree files. Reverted main repo changes with `git checkout -- VaenylaeBard.toc VaenylaeBard.lua` and re-applied all edits to the correct worktree path. No impact on committed output — all commits are correctly on the worktree branch.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- PORT-01/02/03/04/07 complete. Addon will load in 3.3.5a without out-of-date warning.
- ADDON_LOADED fires and initializes; auto-playback timer advances correctly; song line counts use # operator.
- Remaining for Phase 01: PORT-05 (this→self in 7 SetScript closures) and PORT-06 (StaticPopupDialogs self navigation), covered in plans 01-02 and 01-03.

## Self-Check: PASSED

- [x] VaenylaeBard.toc contains `## Interface: 30300`
- [x] VaenylaeBard.lua line 134: `function(self, elapsed)`
- [x] VaenylaeBard.lua line 139: `VB_playbackElapsed + elapsed`
- [x] VaenylaeBard.lua line 156: `VB_playbackElapsed - effectiveDelay`
- [x] VaenylaeBard.lua lines 198-199: 3.3.5a/Lua 5.1 comment
- [x] VaenylaeBard.lua line 200: `function(self, event, arg1)`
- [x] grep table.getn: zero results
- [x] grep playbackElapsed.*arg1: zero results
- [x] Commit c180e2a exists (Task 1)
- [x] Commit b56a358 exists (Task 2)

---
*Phase: 01-wotlk-compatibility-port*
*Completed: 2026-05-12*
