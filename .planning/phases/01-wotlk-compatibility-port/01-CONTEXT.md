# Phase 1: WotLK Compatibility Port - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Apply all Lua 5.0→5.1 compatibility fixes to VaenylaeBard.lua and update VaenylaeBard.toc so the addon runs on WoW 3.3.5a (Interface 30300) with complete feature parity to the 1.12.1 version. Zero feature additions. 17 specific change sites fully enumerated by research with exact line numbers. After changes, copy addon to the Faebright WoW install for in-game testing.

</domain>

<decisions>
## Implementation Decisions

### StaticPopupDialogs Navigation
- `OnShow` editbox access: `self.editBox:SetFocus()` (direct field, matches ElvUI/Postal 3.3.5a conventions)
- `OnAccept` editbox access: `self.editBox:GetText()` (same direct-field pattern)
- `EditBoxOnEnterPressed` button click: `self:GetParent().button1:Click()` (field access on parent frame)

### Deployment
- After all edits are committed, copy the addon folder to `/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/` via `cp -r`
- Copy is the final task of this phase, enabling immediate in-game testing

### Code Hygiene
- Update the line 198 comment (`-- In WoW 1.12.1 (Lua 5.0)...`) to describe 3.3.5a behavior instead
- Keep phase-ref comments (e.g. `-- Phase 3: PLAY-01`) — accurate and useful

### Claude's Discretion
- Implementation order within the changes: .toc → OnEvent → OnUpdate+table.getn hotpath → remaining table.getn → SetScript this→self (drag handlers then button closures) → StaticPopupDialogs → comment update
- Include opportunistic timing drift fix (`VB_playbackElapsed = VB_playbackElapsed - effectiveDelay`) while the OnUpdate callback is open

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `VaenylaeBard.lua` — single 855-line file, all logic in one place; no modules to manage
- `VaenylaeBard.toc` — 6-line manifest; only the Interface line changes
- Research files in `.planning/research/` contain exact line numbers, before/after patterns verified against production 3.3.5a addons in the local client

### Established Patterns
- All 3.3.5a callback signatures follow `function(self, ...)` — self is always first explicit param
- StaticPopupDialogs use `self.editBox` for hasEditBox popups (ElvUI, Postal confirmed)
- `#table` is the Lua 5.1 idiomatic replacement for `table.getn(table)`
- `SetScript("OnUpdate", function(self, elapsed) ... end)` — elapsed replaces global arg1

### Integration Points
- After code edits committed: deploy to `/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/`
- All changes are in two files: `VaenylaeBard.lua` and `VaenylaeBard.toc`

</code_context>

<specifics>
## Specific Ideas

- SUMMARY.md implementation order: .toc → OnEvent → OnUpdate+table.getn hotpath → remaining table.getn → SetScript this→self (drag handlers: lines 307-308, 493-494; button closures: lines 445-451, 538-554, 572-579) → StaticPopupDialogs (lines 772-789) → comment hygiene
- Opportunistic timing fix: change line ~156 from `VB_playbackElapsed = 0` to `VB_playbackElapsed = VB_playbackElapsed - effectiveDelay`
- The existing line 198 comment should be updated from "In WoW 1.12.1 (Lua 5.0)..." to explain the 3.3.5a/Lua 5.1 approach
- Verification checklist (5 success criteria) maps to: (1) load game → no warning, (2) /vbard opens with saved songs, (3) auto-play runs to end cleanly, (4) all toggle buttons and drag work, (5) Add Song dialog saves correctly

</specifics>

<deferred>
## Deferred Ideas

- ENH-01: LibStub/ACE3 migration — out of port scope
- ENH-02: RAID/PARTY/INSTANCE channel types — new feature, v2+
- None — discussion stayed within phase scope

</deferred>
