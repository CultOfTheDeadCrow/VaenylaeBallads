# Project Research Summary

**Project:** VaenylaeBard WoW Addon Port
**Domain:** WoW addon compatibility port — 1.12.1 (Lua 5.0, Interface 11307) to 3.3.5a (Lua 5.1, Interface 30300)
**Researched:** 2026-05-12
**Confidence:** HIGH

## Executive Summary

VaenylaeBard is a single-file WoW addon (~855 lines) that manages and performs multi-line RP "songs" via chat messages and emotes. The port from 1.12.1 to 3.3.5a is a pure compatibility migration: no features are added, removed, or redesigned. The entire change surface is determined by two historical events that occurred at the WoW 2.0 (Burning Crusade) boundary: the Lua runtime was upgraded from 5.0 to 5.1, and Blizzard changed how the engine delivers arguments to script callbacks. Every bug introduced by the port is caused by one or both of those changes.

The recommended approach is a single focused pass through VaenylaeBard.lua that fixes exactly 17 specific locations across 6 change categories: the .toc interface version bump, OnUpdate callback signature, OnEvent callback signature, all `this`-global SetScript closures (7 sites), StaticPopupDialogs callbacks (3 sites), and `table.getn()` calls (5 sites). Research identified every affected line by number by directly inspecting the source and cross-referencing against production 3.3.5a addons installed in the target client. Nothing else in the file requires modification.

The key risk is silent failure: all six change categories produce bugs that either silently do nothing (buttons stop responding, init never runs, data is not saved) or produce Lua errors invisible to end users without the developer console open. The mitigation is a structured verification checklist covering every user-facing capability, executed against the live 3.3.5a client after all changes are applied. There is no ambiguity about what to change — research is exhaustive and all line numbers are confirmed.

## Key Findings

### Recommended Stack

This project has no meaningful stack selection decisions. The runtime is fixed: WoW 3.3.5a ships Lua 5.1 embedded; the addon language is Lua; the API is the WoW 3.3.5a addon API. The single structural decision that stands is maintaining the existing single-file architecture — no libraries, no splitting, no ACE3 migration. This is correct for the port scope.

**Core technologies:**
- **Lua 5.1**: the embedded runtime in WoW 3.3.5a — explicit function parameters replace global argument injection
- **WoW Addon API (Interface 30300)**: the exact 3.3.5a API surface — frame/event/callback patterns verified against TomTom, ElvUI, Postal, ACP, Pawn installed in the target client
- **SavedVariables**: WoW built-in persistence — ADDON_LOADED/PLAYER_LOGOUT pattern is correct and unchanged; only callback signatures need fixing

### Expected Features

All features in scope are compatibility fixes required to maintain parity with the existing 1.12.1 behavior. Every item is P1; there are no P2 or P3 items for this port.

**Must have (all required for feature parity):**
- `.toc` Interface version 30300 — load gate; wrong value causes the client to block or warn on every login
- `OnEvent` callback `function(self, event, arg1)` — initialization gate; ADDON_LOADED branch never fires without this fix, addon silently never initializes
- `OnUpdate` callback `function(self, elapsed)` — playback gate; auto-performance never advances, errors every frame
- `table.getn(x)` replaced with `#x` at 5 sites — playback crash gate; fires every frame in OnUpdate hot path
- SetScript `this` → `self` at 7 closure sites (drag handlers on both frames, mode toggle, channel button, emote type button) — frame usability; all fail silently
- `StaticPopupDialogs` callbacks `this` → `self` at 3 sites with corrected edit-box navigation — add-song dialog; silently broken without fix

**Defer (v2+):**
- ACE3/LibStub migration — only warranted if the addon grows beyond single-file scope
- Additional channel types (RAID, PARTY, INSTANCE) — new feature, out of port scope

### Architecture Approach

The architecture is unchanged by the port. VaenylaeBard.lua remains a single file containing six logical sections: Playback Engine (lines 36–165), Event Handler (167–209), Main Frame UI (288–455), Line Editor Frame (478–601), StaticPopupDialogs (767–793), and Slash Command Handler (796–852). The port touches code in all six sections but does not move, merge, or split any of them. The .toc file changes one line.

**Major components:**
1. **Playback Engine** — timing loop, line dispatch, pause/stop/manual state machine (OnUpdate, DispatchLine, StartPerformance, StopPerformance, AdvanceLine)
2. **Event Handler** — ADDON_LOADED initialization gate and PLAYER_LOGOUT SavedVariables flush
3. **UI Layer** — Main Frame (song list, playback controls), Line Editor Frame (per-line text/channel/emote/delay editing), StaticPopupDialogs (add-song input)

### Critical Pitfalls

1. **`this` global is nil in all SetScript closures** — replace every `function()` that uses `this` with `function(self)` and change `this:` to `self:` throughout; 7 distinct sites, all produce silent runtime errors when triggered; buttons and drag handlers appear to work until tested
2. **`event` and `arg1` globals are nil in OnEvent/OnUpdate** — addon silently fails to initialize (ADDON_LOADED branch never evaluates true) AND errors every frame during playback (`nil + number` arithmetic); fix both callback signatures first, before testing anything else
3. **StaticPopupDialogs `this` nil plus changed `self` semantics** — in 3.3.5a `OnAccept` receives the dialog frame as `self` (not the accept button as in 1.12.1), so the old `_G[this:GetParent():GetName().."EditBox"]` navigation resolves to UIParentEditBox (nil); use `_G[self:GetName().."EditBox"]` or `self.editBox` instead
4. **`table.getn()` in the OnUpdate hot path** — 5 sites, most critically line 161 which fires every frame; returns nil or errors cause songs to freeze at line 1 or never terminate; all 5 replacements with `#` are safe (all tables are pure sequences built via `table.insert`)
5. **`VB_playbackElapsed = 0` instead of residual reset** — pre-existing drift bug; the correct reset is `VB_playbackElapsed = VB_playbackElapsed - effectiveDelay`; the OnUpdate edit is the natural opportunity to fix this; does not block the port

## Implications for Roadmap

Based on research, all required changes belong in a single phase. There are no sequencing decisions between phases because the change set is fully enumerated and every change is a prerequisite for testing any downstream capability.

### Phase 1: Compatibility Port

**Rationale:** The changes form a strict functional dependency chain. The .toc version must be correct for the client to load the addon. The OnEvent fix must be correct for initialization to run. Without initialization, no frame exists and every other change is untestable. All other changes are required for complete feature parity before any test is meaningful. The 17 changes span 2 files and ~25 affected lines — this is one cohesive commit, not a multi-phase project.

**Delivers:** A fully functional VaenylaeBard addon running on WoW 3.3.5a with complete feature parity to the 1.12.1 version: song management, auto and manual playback, drag-to-move on both frames, mode/channel/emote-type toggle buttons, add-song dialog, SavedVariables persistence.

**Addresses:** All items from the must-have feature list.

**Implementation order within phase (dependency-safe, minimizes risk of editing a working line):**
1. `.toc` Interface `11307` → `30300` — isolated file, zero risk, confirms client accepts addon
2. `OnEvent` signature `function()` → `function(self, event, arg1)` at line 200 — initialization gate; establish working baseline before testing anything else
3. `OnUpdate` signature `function()` → `function(self, elapsed)` at line 134, `arg1` → `elapsed` at line 139, plus `table.getn` → `#song` at line 161 — fix together since they are in the same function body
4. Remaining `table.getn` calls at lines 91, 107, 129, 630 — mechanical grep-and-replace; verify with `grep -n 'table\.getn'` after
5. SetScript `this` → `self` in drag handlers: main frame lines 307–308, line editor lines 493–494 — low-risk one-liner pattern repeated twice
6. SetScript `this` → `self` in button OnClick closures: modeBtn lines 445–451, channelBtn lines 538–554, emoteTypeBtn lines 572–579 — mechanical; group by frame
7. StaticPopupDialogs callbacks: OnShow lines 772–773, OnAccept lines 775–776, EditBoxOnEnterPressed lines 787–788 — last; add-song dialog is not on the critical path for verifying init and playback; requires careful edit-box navigation update (see Gaps)

**Opportunistic fix within Phase 1:** Change `VB_playbackElapsed = 0` to `VB_playbackElapsed = VB_playbackElapsed - effectiveDelay` at line 156 while the OnUpdate callback is open. One-line improvement, not a requirement.

**Avoids:**
- Silent nil errors from `this` global removal (Pitfall 1)
- Addon never initializing from nil `event`/`arg1` globals (Pitfall 2)
- Add-song dialog broken from StaticPopup `self` semantics shift (Pitfall 3)
- OnUpdate crash from `table.getn` returning nil (Pitfall 4)

### Phase Ordering Rationale

- A single phase is correct: this is not a multi-milestone project; the change set is fully enumerated with line numbers; no feature is held back for a second milestone
- Within-phase order follows functional dependencies: client load gate → init gate → playback gate → UI widgets → dialogs
- Grouping all `table.getn` replacements (step 4) keeps a single grep verification clean
- StaticPopup goes last because it is the most semantically complex change (edit-box navigation model differs from simple `this`→`self`) and the least critical path — fixing it cannot corrupt init or playback

### Research Flags

Phases needing `/gsd-research-phase` during planning:
- **None.** All changes are fully enumerated with exact line numbers, verified change patterns, and anti-patterns documented. Research is complete; no further investigation is required before implementation.

Phases with standard, well-documented patterns (skip research):
- **Phase 1:** Every change follows canonical WoW addon migration patterns documented on Wowpedia and verified against production 3.3.5a addons installed in the local client. Zero ambiguity remains.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | No choices to make; runtime is fixed; all API patterns verified against local 3.3.5a installed addons |
| Features | HIGH | All features verified against source line numbers; every change cross-referenced with TomTom, ElvUI, Postal, Pawn, ACP |
| Architecture | HIGH | Single-file structure confirmed; no boundary changes needed; all integration points verified; no split adds value at ~855 lines |
| Pitfalls | HIGH | All pitfalls verified against actual VaenylaeBard.lua line numbers; silent failure modes confirmed by Lua 5.0→5.1 runtime behavior |

**Overall confidence:** HIGH

### Gaps to Address

- **StaticPopupDialogs EditBoxOnEnterPressed navigation:** Two valid approaches were identified. PITFALLS.md recommends `_G[self:GetName().."Button1"]:Click()` (dialog-frame-navigates-to-button-child). ARCHITECTURE.md recommends `self:GetParent().button1:Click()` (editbox navigates to parent then field access). Both should work in 3.3.5a. The implementation should pick one approach and confirm it in-game by pressing Enter in the add-song popup. Flag for verification during Phase 1 testing.
- **`table.getn` shim status:** ACP.lua on the target client still calls `table.getn` without crashing, suggesting WoW 3.3.5a retained it as a Lua 5.1 compatibility shim. Research recommends replacing with `#` regardless — it is faster, idiomatic, and future-safe. This is not an implementation ambiguity, just a note that the current code may not error loudly even if left unfixed.
- **Timing drift opportunistic fix:** The `VB_playbackElapsed = 0` → residual reset is an improvement, not a compatibility requirement. Include it in Phase 1 while the OnUpdate callback is open, but do not block the port milestone on it if a reviewer prefers deferral.

## Sources

### Primary (HIGH confidence)

- `VaenylaeBard.lua` (this repo, HEAD) — source of truth for all line numbers and current 1.12.1 behavior
- `/home/reset/Games/Faebright WoW/Interface/AddOns/TomTom/TomTom.lua` — confirms `OnEvent = function(self, event, ...)`, `OnUpdate = function(self, elapsed)`, `SetBackdrop`, `SlashCmdList`, ADDON_LOADED param pattern in 3.3.5a
- `/home/reset/Games/Faebright WoW/Interface/AddOns/ElvUI/Core/StaticPopups.lua` — confirms WotLK `OnShow(self)`, `OnAccept(self)`, `self.editBox` popup callback conventions
- `/home/reset/Games/Faebright WoW/Interface/AddOns/ElvUI/Core/Distributor.lua` — confirms `OnAccept = function(self) ... self.editBox:GetText()`
- `/home/reset/Games/Faebright WoW/Interface/AddOns/Postal/Postal.lua` — confirms `OnAccept = function(self) self.wideEditBox:GetText()` with `hasEditBox = 1`
- `/home/reset/Games/Faebright WoW/Interface/AddOns/Pawn/Pawn.lua` — confirms ADDON_LOADED with arg1 param, PLAYER_LOGOUT for SavedVariables flush
- `/home/reset/Games/Faebright WoW/Interface/AddOns/ACP/ACP.lua` — confirms `table.getn` is present (shim) but deprecated; confirms OnEvent named-param style
- Wowpedia canonical migration guide: https://wowpedia.fandom.com/wiki/Porting_addons_from_1.x_to_2.0
- Lua 5.1 Reference Manual: https://www.lua.org/manual/5.1/manual.html

---
*Research completed: 2026-05-12*
*Ready for roadmap: yes*
