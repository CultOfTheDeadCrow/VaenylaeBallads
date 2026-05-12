# Phase 01: WotLK Compatibility Port - Research

**Researched:** 2026-05-12
**Domain:** WoW addon Lua 5.0→5.1 compatibility port (Interface 11307→30300)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **StaticPopupDialogs navigation:**
  - `OnShow` editbox access: `self.editBox:SetFocus()` (direct field, matches ElvUI/Postal 3.3.5a conventions)
  - `OnAccept` editbox access: `self.editBox:GetText()` (same direct-field pattern)
  - `EditBoxOnEnterPressed` button click: `self:GetParent().button1:Click()` (field access on parent frame)
- **Deployment:** After all edits are committed, copy the addon folder to `/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/` via `cp -r`. Copy is the final task of this phase.
- **Code Hygiene:** Update the line 198 comment (`-- In WoW 1.12.1 (Lua 5.0)...`) to describe 3.3.5a behavior instead. Keep phase-ref comments (e.g. `-- Phase 3: PLAY-01`).

### Claude's Discretion

- Implementation order within the changes: .toc → OnEvent → OnUpdate+table.getn hotpath → remaining table.getn → SetScript this→self (drag handlers then button closures) → StaticPopupDialogs → comment update
- Include opportunistic timing drift fix (`VB_playbackElapsed = VB_playbackElapsed - effectiveDelay`) while the OnUpdate callback is open

### Deferred Ideas (OUT OF SCOPE)

- ENH-01: LibStub/ACE3 migration — out of port scope
- ENH-02: RAID/PARTY/INSTANCE channel types — new feature, v2+
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PORT-01 | `.toc` Interface version reads `30300` (was `11307`) so the 3.3.5a client loads without an out-of-date warning | Single-line toc change; exact before/after confirmed from source [VERIFIED: VaenylaeBard.toc line 1] |
| PORT-02 | `OnEvent` callback receives `self`, `event`, and `arg1` as explicit function parameters so ADDON_LOADED fires correctly | Line 200 signature fix, body unchanged; pattern verified against TomTom.lua and Pawn.lua [VERIFIED: source grep] |
| PORT-03 | `OnUpdate` callback receives `self` and `elapsed` as explicit function parameters so the auto-playback timer advances each frame | Lines 134 (signature) and 139 (variable name) [VERIFIED: source grep] |
| PORT-04 | All 5 `table.getn()` calls replaced with the `#` operator | Lines 91, 107, 129, 161, 630 — all confirmed via grep [VERIFIED: source grep] |
| PORT-05 | All 7 `SetScript` closures that referenced `this` declare `self` as explicit first parameter | Lines 307, 308, 444, 445-451, 493, 494, 538-554, 572-579 [VERIFIED: source grep] |
| PORT-06 | `StaticPopupDialogs` callbacks reference `self` with corrected editbox navigation | Lines 772-789 [VERIFIED: source grep] |
| PORT-07 | `VB_playbackElapsed` reset uses residual subtraction instead of hard zero | Line 156 opportunistic fix, applied while OnUpdate is open [VERIFIED: source line 156] |
</phase_requirements>

---

## Summary

VaenylaeBard is an 855-line single-file WoW addon that manages and performs scripted roleplay songs. The port from 1.12.1 (Lua 5.0, Interface 11307) to WoW 3.3.5a (Lua 5.1, Interface 30300) is a pure compatibility migration — no features are added, removed, or redesigned. Every bug introduced by the version gap traces to exactly two historical events at the WoW 2.0 (Burning Crusade) boundary: the embedded Lua runtime was upgraded from 5.0 to 5.1, and Blizzard changed how the engine delivers arguments to script callbacks.

Research has fully enumerated the change surface. There are 17 specific edit sites across two files (VaenylaeBard.toc and VaenylaeBard.lua). All line numbers have been confirmed directly against the source via grep. All patterns have been verified against production 3.3.5a addons installed in the target client (TomTom, ElvUI, Postal, Pawn, ACP). No ambiguity remains about what to change, where, or how.

The key implementation risk is silent failure: all six change categories produce bugs that either silently do nothing (buttons stop responding, initialization never runs, data is not saved) or produce Lua errors invisible to end users without the developer console open. Mitigation is a structured in-game verification checklist covering every user-facing capability, executed against the live 3.3.5a client after all changes are applied. There is no automated test runner for WoW addons — validation is entirely in-game.

**Primary recommendation:** Make all 17 changes in a single commit in dependency-safe order (.toc → OnEvent → OnUpdate+table.getn hotpath → remaining table.getn → SetScript this→self → StaticPopupDialogs → comment update), then deploy and execute the five-point in-game checklist.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Addon load gate (toc version) | WoW client loader | — | Client reads Interface field before executing any Lua |
| ADDON_LOADED initialization | Event Handler (lines 167-209) | — | eventFrame.OnEvent fires ADDON_LOADED; gates all frame creation |
| Auto-playback timer | Playback Engine (lines 36-165) | — | playbackFrame.OnUpdate accumulates elapsed time each frame |
| Frame drag-to-move | UI Layer (lines 288-455, 478-601) | — | OnDragStart/OnDragStop on each frame widget |
| Mode/channel/emote-type toggles | UI Layer (CreateMainFrame, CreateLineEditorFrame) | — | OnClick closures on modeBtn, channelBtn, emoteTypeBtn |
| Add Song dialog | StaticPopupDialogs (lines 767-793) | — | Blizzard StaticPopup subsystem; callbacks receive popup frame as self |
| SavedVariables persistence | Event Handler (PLAYER_LOGOUT) | WoW engine | Engine serializes VaenylaeBardDB after PLAYER_LOGOUT fires |
| Deployment | Filesystem (cp -r) | — | Manual copy after commit; no build step |

---

## Standard Stack

This phase has no stack selection decisions. The runtime is fixed.

### Core

| Component | Version | Purpose | Notes |
|-----------|---------|---------|-------|
| Lua | 5.1 (embedded) | Addon language runtime | Shipped by WoW 3.3.5a; no install required [VERIFIED: Wowpedia migration guide] |
| WoW Addon API | Interface 30300 | Frame/event/callback system | Target client API surface; all patterns verified against local 3.3.5a addons [VERIFIED: local client addons] |
| SavedVariables | Built-in WoW | Persistence via VaenylaeBardDB | ADDON_LOADED/PLAYER_LOGOUT pattern correct; only signature needs fixing [VERIFIED: Pawn.lua, Postal AceDB] |

### What NOT to Change

| Area | Reason |
|------|--------|
| `string.len()`, `string.sub()`, `string.lower()`, `string.gsub()` | Identical in Lua 5.0 and 5.1 [VERIFIED: Lua 5.1 reference] |
| `ipairs()`, `pairs()`, `table.insert()` | Unchanged between versions [VERIFIED: Lua 5.1 reference] |
| `CreateFrame()`, `RegisterEvent()`, `SendChatMessage()`, `DoEmote()` | Core WoW API unchanged [VERIFIED: TomTom.lua, Pawn.lua] |
| `_G[...]` global table access | Pattern identical in both versions [VERIFIED: ElvUI, ACP] |
| `SlashCmdList`, `SLASH_*` | Registration API unchanged [VERIFIED: TomTom L1027, MBB.lua] |
| Closures that do not use `this` | Already correct; upvalue-only closures (e.g., `closeBtn:SetScript("OnClick", function() f:Hide() end)`) need no change [VERIFIED: source inspection] |

---

## Architecture Patterns

### System Architecture Diagram

```
WoW 3.3.5a Client
     |
     | reads ## Interface: 30300 (PORT-01)
     v
VaenylaeBard.lua loads
     |
     | ADDON_LOADED fires
     v
eventFrame.OnEvent(self, event, arg1) ──────────────────────> PORT-02
     |                                                          fix here
     | arg1 == "VaenylaeBard" → InitializeAddon()
     v
  CreateMainFrame() + CreateLineEditorFrame()
     |
     | user opens /vbard → frame:Show()
     |
     +──────────────────────────────────────────────────────────────────+
     |                                                                  |
     | drag-to-move                       mode/channel/emote toggles    |
     | OnDragStart/Stop (self)            OnClick (self)                |
     | PORT-05 fix                        PORT-05 fix                   |
     |                                                                  |
     | Add Song button → StaticPopup_Show()                            |
     |   OnShow(self) → self.editBox:SetFocus()    PORT-06 fix         |
     |   OnAccept(self) → self.editBox:GetText()   PORT-06 fix         |
     |   EditBoxOnEnterPressed(self) → self:GetParent().button1:Click()  |
     +──────────────────────────────────────────────────────────────────+
     |
     | user clicks Play → StartPerformance()
     |   #song check (PORT-04)
     v
playbackFrame.OnUpdate(self, elapsed) ──────────────────────> PORT-03
     |                                                         PORT-07
     | VB_playbackElapsed += elapsed
     | if elapsed >= effectiveDelay:
     |   VB_playbackElapsed = VB_playbackElapsed - effectiveDelay (PORT-07)
     |   DispatchLine() → SendChatMessage() / DoEmote()
     |   VB_playIndex++
     |   if VB_playIndex > #song (PORT-04): StopPerformance()
     v
     PLAYER_LOGOUT → VaenylaeBardDB.songs = VaenylaeBardSongs → WoW serializes to disk
```

### Recommended Project Structure

```
VaenylaeBallads/
├── VaenylaeBard.toc    # Interface version bump only (line 1: 11307 → 30300)
└── VaenylaeBard.lua    # All 16 Lua line changes; single file preserved
```

No new files. No structural changes.

---

## All 17 Change Sites (Verified Against Source)

This is the complete, exhaustive change surface. Every line number confirmed via `grep` against HEAD.

### Change 1: .toc Interface Version (PORT-01)

**File:** `VaenylaeBard.toc`, line 1

```
Before: ## Interface: 11307
After:  ## Interface: 30300
```

**Risk:** NONE — isolated file, zero Lua logic. Wrong value causes "addon may be outdated" warning on every login.
[VERIFIED: VaenylaeBard.toc line 1]

---

### Change 2: OnEvent Callback Signature (PORT-02)

**File:** `VaenylaeBard.lua`, lines 200-201

```lua
-- Before (lines 200-201):
eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "VaenylaeBard" then

-- After:
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "VaenylaeBard" then
```

Body lines 201-209 are unchanged — parameter names `event` and `arg1` are chosen deliberately to match old globals, keeping the body diff-free.
[VERIFIED: source grep line 200-201; pattern confirmed TomTom.lua L30, Pawn.lua L111]

---

### Change 3: OnUpdate Callback Signature (PORT-03)

**File:** `VaenylaeBard.lua`, lines 134 and 139

```lua
-- Line 134 before:
playbackFrame:SetScript("OnUpdate", function()
-- Line 134 after:
playbackFrame:SetScript("OnUpdate", function(self, elapsed)

-- Line 139 before:
    VB_playbackElapsed = VB_playbackElapsed + arg1
-- Line 139 after:
    VB_playbackElapsed = VB_playbackElapsed + elapsed
```

Note: `self` on line 134 is technically unused in the body (all state accessed via upvalues), but must be declared to shift `elapsed` to the correct parameter position. Writing `function(elapsed)` would receive the frame object as `elapsed`, producing garbage timing values.
[VERIFIED: source grep lines 134, 139; pattern confirmed TomTom_Corpse.lua, TomTom_CrazyArrow.lua]

---

### Change 4: OnUpdate Elapsed Reset — Residual Subtraction (PORT-07)

**File:** `VaenylaeBard.lua`, line 156

```lua
-- Before:
        VB_playbackElapsed = 0
-- After:
        VB_playbackElapsed = VB_playbackElapsed - effectiveDelay
```

Applied in the same edit session as Change 3 since the OnUpdate body is already open. Preserves sub-frame overshoot; compensates for frame spikes.
[VERIFIED: source line 156]

---

### Change 5: table.getn #1 — StartPerformance line count guard (PORT-04)

**File:** `VaenylaeBard.lua`, line 91

```lua
-- Before:
    if not song or table.getn(song) == 0 then
-- After:
    if not song or #song == 0 then
```

[VERIFIED: source grep line 91]

---

### Change 6: table.getn #2 — StartPerformance debug string (PORT-04)

**File:** `VaenylaeBard.lua`, line 107

```lua
-- Before:
    VBDebug("StartPerformance mode=" .. tostring(mode) .. " song=" .. VaenylaeBardSelectedSong .. " lines=" .. table.getn(song))
-- After:
    VBDebug("StartPerformance mode=" .. tostring(mode) .. " song=" .. VaenylaeBardSelectedSong .. " lines=" .. #song)
```

[VERIFIED: source grep line 107]

---

### Change 7: table.getn #3 — AdvanceLine boundary check (PORT-04)

**File:** `VaenylaeBard.lua`, line 129

```lua
-- Before:
    if VB_playIndex > table.getn(song) then
-- After:
    if VB_playIndex > #song then
```

[VERIFIED: source grep line 129]

---

### Change 8: table.getn #4 — OnUpdate boundary check (PORT-04) [HOT PATH]

**File:** `VaenylaeBard.lua`, line 161

```lua
-- Before:
        if VB_playIndex > table.getn(song) then
-- After:
        if VB_playIndex > #song then
```

This is the highest-frequency call site — fires every frame while a song is playing.
[VERIFIED: source grep line 161]

---

### Change 9: table.getn #5 — UpdateSongList button label (PORT-04)

**File:** `VaenylaeBard.lua`, line 630

```lua
-- Before:
        btn:SetText(songName .. " (" .. table.getn(songData) .. " lines)")
-- After:
        btn:SetText(songName .. " (" .. #songData .. " lines)")
```

[VERIFIED: source grep line 630]

---

### Change 10: MainFrame OnDragStart — this→self (PORT-05)

**File:** `VaenylaeBard.lua`, line 307

```lua
-- Before:
    f:SetScript("OnDragStart", function() this:StartMoving() end)
-- After:
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
```

[VERIFIED: source grep line 307; pattern confirmed ElvUI BlizzardOptions.lua]

---

### Change 11: MainFrame OnDragStop — this→self (PORT-05)

**File:** `VaenylaeBard.lua`, line 308

```lua
-- Before:
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
-- After:
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
```

[VERIFIED: source grep line 308]

---

### Change 12: modeBtn OnClick — this→self (PORT-05)

**File:** `VaenylaeBard.lua`, lines 444-451

```lua
-- Before (line 444):
    modeBtn:SetScript("OnClick", function()
        if this:GetText() == "Auto" then
            this:SetText("Manual")
        else
            this:SetText("Auto")
        end
        VBDebug("Mode toggled to: " .. this:GetText())
    end)

-- After:
    modeBtn:SetScript("OnClick", function(self)
        if self:GetText() == "Auto" then
            self:SetText("Manual")
        else
            self:SetText("Auto")
        end
        VBDebug("Mode toggled to: " .. self:GetText())
    end)
```

[VERIFIED: source grep lines 444-451]

---

### Change 13: LineEditorFrame OnDragStart — this→self (PORT-05)

**File:** `VaenylaeBard.lua`, line 493

```lua
-- Before:
    f:SetScript("OnDragStart", function() this:StartMoving() end)
-- After:
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
```

[VERIFIED: source grep line 493]

---

### Change 14: LineEditorFrame OnDragStop — this→self (PORT-05)

**File:** `VaenylaeBard.lua`, line 494

```lua
-- Before:
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
-- After:
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
```

[VERIFIED: source grep line 494]

---

### Change 15: channelBtn OnClick — this→self (PORT-05)

**File:** `VaenylaeBard.lua`, lines 538-554

```lua
-- Before (line 538):
    channelBtn:SetScript("OnClick", function()
        if VB_currentChannel == "SAY" then
            VB_currentChannel = "YELL"
            this:SetText("YELL")
            this:GetFontString():SetTextColor(1, 1, 0)
        elseif VB_currentChannel == "YELL" then
            VB_currentChannel = "EMOTE"
            this:SetText("EMOTE")
            this:GetFontString():SetTextColor(1, 0.5, 1)
        else
            VB_currentChannel = "SAY"
            this:SetText("SAY")
            this:GetFontString():SetTextColor(1, 1, 1)
        end
        ...
    end)

-- After:
    channelBtn:SetScript("OnClick", function(self)
        if VB_currentChannel == "SAY" then
            VB_currentChannel = "YELL"
            self:SetText("YELL")
            self:GetFontString():SetTextColor(1, 1, 0)
        elseif VB_currentChannel == "YELL" then
            VB_currentChannel = "EMOTE"
            self:SetText("EMOTE")
            self:GetFontString():SetTextColor(1, 0.5, 1)
        else
            VB_currentChannel = "SAY"
            self:SetText("SAY")
            self:GetFontString():SetTextColor(1, 1, 1)
        end
        ...
    end)
```

[VERIFIED: source grep lines 538-554]

---

### Change 16: emoteTypeBtn OnClick — this→self (PORT-05)

**File:** `VaenylaeBard.lua`, lines 572-581

```lua
-- Before (line 572):
    emoteTypeBtn:SetScript("OnClick", function()
        if VB_currentEmoteType == "custom" then
            VB_currentEmoteType = "builtin"
            this:SetText("Built-in")
        else
            VB_currentEmoteType = "custom"
            this:SetText("Custom")
        end
        ...
    end)

-- After:
    emoteTypeBtn:SetScript("OnClick", function(self)
        if VB_currentEmoteType == "custom" then
            VB_currentEmoteType = "builtin"
            self:SetText("Built-in")
        else
            VB_currentEmoteType = "custom"
            self:SetText("Custom")
        end
        ...
    end)
```

[VERIFIED: source grep lines 572-579]

---

### Change 17: StaticPopupDialogs — this→self with corrected navigation (PORT-06)

**File:** `VaenylaeBard.lua`, lines 772-789

```lua
-- Before:
    OnShow = function()
        _G[this:GetName() .. "EditBox"]:SetFocus()
    end,
    OnAccept = function()
        local songName = _G[this:GetParent():GetName() .. "EditBox"]:GetText()
        ...
    end,
    EditBoxOnEnterPressed = function()
        _G[this:GetParent():GetName() .. "Button1"]:Click()
    end,

-- After (locked decision from CONTEXT.md):
    OnShow = function(self)
        self.editBox:SetFocus()
    end,
    OnAccept = function(self)
        local songName = self.editBox:GetText()
        ...
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent().button1:Click()
    end,
```

In 3.3.5a: `OnShow` self = popup frame (self.editBox is the embedded EditBox, set by engine for hasEditBox=1). `OnAccept` self = popup frame (same). `EditBoxOnEnterPressed` self = the EditBox widget; `self:GetParent()` = popup frame; `.button1` = the Accept button field.
[VERIFIED: source lines 772-789; patterns confirmed ElvUI Core/Distributor.lua, Postal.lua, ElvUI Core/StaticPopups.lua]

---

### Change 18: Comment Hygiene (from CONTEXT.md Decisions)

**File:** `VaenylaeBard.lua`, lines 198-199

```lua
-- Before:
-- In WoW 1.12.1 (Lua 5.0), extra event args come through globals (arg1, arg2, ...),
-- not function parameters. OnEvent receives (self, event) at most.

-- After:
-- In WoW 3.3.5a (Lua 5.1), extra event args are explicit function parameters.
-- OnEvent receives (self, event, ...) where ... are event-specific args.
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| `this` compat shim | `local this = self` at top of callback | Explicit `self` param in signature | Shim hides the fix; can produce subtle bugs if a callback receives self as an upvalue from outer scope; not how WotLK addons are written [VERIFIED: FEATURES.md anti-features] |
| Table length | Keep `table.getn()` | `#table` operator | `table.getn` is deprecated shim in 3.3.5a; `#` is idiomatic, faster (no function call), and future-safe [VERIFIED: Lua 5.1 reference] |
| VARIABLES_LOADED event | Switch to VARIABLES_LOADED for SavedVariables | Keep ADDON_LOADED with arg1 check | VARIABLES_LOADED fires for all addons and does not pass the addon name; ADDON_LOADED is the correct WotLK pattern [VERIFIED: TomTom, Pawn, Postal AceDB] |

---

## Common Pitfalls

### Pitfall 1: `this` global is nil in all SetScript closures
**What goes wrong:** Buttons and drag handles appear to work at load time (no compile error), then silently stop responding when interacted with at runtime.
**Why it happens:** In 3.3.5a, `this` is never injected as a global inside SetScript callbacks. The closure references a nil global.
**How to avoid:** Replace every `function()` that uses `this` with `function(self)` and replace `this:` with `self:` throughout that closure.
**Warning signs:** Any `SetScript` callback declared as `function()` with zero parameters that uses `this` anywhere in its body.
[VERIFIED: PITFALLS.md Pitfall 1; source lines 307, 308, 444-451, 493, 494, 538-554, 572-579]

### Pitfall 2: `event` and `arg1` globals are nil in OnEvent/OnUpdate
**What goes wrong:** ADDON_LOADED branch never fires (nil ~= "ADDON_LOADED") → addon silently never initializes. OnUpdate arithmetic on nil `arg1` → Lua error every frame during playback.
**Why it happens:** In 3.3.5a, the WoW engine no longer sets `event` and `arg1`..`arg9` as globals before each callback.
**How to avoid:** Change OnEvent to `function(self, event, arg1)` and OnUpdate to `function(self, elapsed)`. Rename `arg1` to `elapsed` in the OnUpdate body.
**Warning signs:** Addon loads but `/vbard` prints "Frame not found!" — means InitializeAddon never ran.
[VERIFIED: PITFALLS.md Pitfall 2; source lines 134, 139, 200-201]

### Pitfall 3: Omitting `self` in OnUpdate shifts `elapsed` to wrong position
**What goes wrong:** Writing `function(elapsed)` instead of `function(self, elapsed)` — the frame object is received as `elapsed`, producing garbage (very large) timing values. Every song line fires immediately.
**Why it happens:** WoW always passes the owning frame as the first parameter; any named params shift right.
**How to avoid:** Always include `self` as the first parameter even when it is unused. Use `_` if desired for clarity: `function(_, elapsed)`.
[VERIFIED: STACK.md Change 2 note; ARCHITECTURE.md Pattern 3]

### Pitfall 4: `table.getn` in the OnUpdate hot path (line 161)
**What goes wrong:** If `table.getn` is absent from 3.3.5a's Lua environment, every frame during playback produces a nil-call error. Song freezes at line 1 or never terminates.
**Why it happens:** `table.getn` is deprecated in Lua 5.1. It exists as a shim in WoW 3.3.5a (confirmed: ACP.lua uses it without crashing), but it is not reliable and not idiomatic.
**How to avoid:** Replace all 5 call sites with `#`. Confirm with `grep -n 'table\.getn' VaenylaeBard.lua` after edits — should return zero results.
[VERIFIED: PITFALLS.md Pitfall 4; source grep]

### Pitfall 5: StaticPopup `OnAccept` navigation — self semantics shift
**What goes wrong:** In 1.12.1, `OnAccept` receives the Accept button as `this`; `this:GetParent()` navigates to the popup frame. In 3.3.5a, `self` IS the popup frame directly. The old `self:GetParent()` chain would navigate to UIParent, and `_G["UIParentEditBox"]` is nil. `:GetText()` errors silently; no song is created.
**How to avoid:** Use `self.editBox:GetText()` — the engine populates the `.editBox` field on the popup frame for `hasEditBox = 1` dialogs (locked decision from CONTEXT.md).
[VERIFIED: PITFALLS.md Pitfall 3; ElvUI Core/Distributor.lua, Postal.lua]

### Pitfall 6: Closures that capture outer locals vs. closures that used `this`
**What goes wrong:** Incorrectly editing closures that already work correctly (false positives in a find-replace sweep for `this`).
**Why it happens:** Several OnClick callbacks capture their button via an outer local (`f`, `capturedName`) rather than `this`. These are already correct in both versions.
**How to avoid:** Only edit closures where `this` appears in the body. A sweep of `grep -n 'this:' VaenylaeBard.lua` identifies exactly the sites requiring change.
[VERIFIED: STACK.md "What NOT to Change"; source inspection of lines 313, 342-352]

---

## Anti-Patterns to Avoid

- **Compat shim `local this = self`:** Hides the real fix; introduces latent bugs; not canonical WotLK style.
- **Leaving `function()` with zero parameters on any SetScript:** Will silently fail in 3.3.5a if the body references `this`, `event`, `arg1`, or `elapsed`.
- **Using `VARIABLES_LOADED` instead of `ADDON_LOADED`:** Does not pass the addon name; cannot be guarded per-addon.
- **Replacing `table.getn` with `table.maxn`:** `table.maxn` is for non-sequential tables; overkill and different semantics for pure-sequence arrays.

---

## Deployment

After all changes are committed:

```bash
cp -r /home/reset/Dev/Repos/VaenylaeBallads/. "/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/"
```

Or more precisely, copying just the addon files:

```bash
cp /home/reset/Dev/Repos/VaenylaeBallads/VaenylaeBard.lua "/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/VaenylaeBard.lua"
cp /home/reset/Dev/Repos/VaenylaeBallads/VaenylaeBard.toc "/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/VaenylaeBard.toc"
```

The target directory must exist in the Faebright WoW install. The copy enables immediate in-game testing.

---

## Validation Architecture

> `nyquist_validation: true` is set in config.json — this section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — WoW addons have no automated test runner |
| Config file | None |
| Quick run command | In-game: `/reload` to reload UI with updated addon |
| Full suite command | In-game: execute the 5-point checklist below |

There is no unit test framework for WoW addons. All validation is in-game, interactive, and manual. The equivalent of "test suite green" is completing the five-point in-game checklist without Lua errors.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Validation Method | Automated? |
|--------|----------|-----------|-------------------|------------|
| PORT-01 | No "out-of-date" warning on login | manual-smoke | Log in; check addon list for "!" indicator or warning dialog | Manual-only — WoW client UI |
| PORT-02 | ADDON_LOADED fires; songs list populates; SavedVariables load | manual-smoke | `/vbard` shows manager with previously saved songs after relog | Manual-only — requires WoW client |
| PORT-03 | Auto-playback timer advances each frame | manual-functional | Start auto performance; observe lines dispatching at correct intervals | Manual-only — requires WoW client |
| PORT-04 | Song line counts display correctly; performance stops at last line | manual-functional | Song list shows "(N lines)" for songs with lines; auto-play terminates at end | Manual-only — requires WoW client |
| PORT-05 | Drag handlers and toggle buttons respond | manual-functional | Drag both frames; toggle mode/channel/emote-type buttons through all states | Manual-only — requires WoW client |
| PORT-06 | Add Song dialog accepts input and saves | manual-functional | Open popup; type song name; confirm via Add button and via Enter key | Manual-only — requires WoW client |
| PORT-07 | No timing drift over a multi-line song | manual-observational | Run a 5+ line song in auto mode; observe line dispatch intervals are consistent | Manual-only — subjective observation |

### Five-Point In-Game Checklist (maps to Success Criteria)

**SC-1 → PORT-01:** Log in to the 3.3.5a client. Open the addon manager (or observe on login). VaenylaeBard shows no "!" and no "out-of-date" warning.

**SC-2 → PORT-02, PORT-04:** Type `/vbard`. The Vaenylae Bard Manager frame opens. The song list populates (if songs were saved in a previous session). After logging out and back in, songs from the previous session reappear.

**SC-3 → PORT-03, PORT-04, PORT-07:** Select a song with at least 3 lines. Ensure mode is "Auto". Click Play. Observe each line being dispatched at the configured interval (default 3 seconds). Observe the song stops automatically after the last line (does not loop). No Lua errors appear in chat.

**SC-4 → PORT-05:** Both frames drag-to-move correctly (main frame and line editor). Mode button toggles "Auto" ↔ "Manual". Channel button cycles SAY → YELL → EMOTE → SAY. Emote-type button toggles "Custom" ↔ "Built-in". No Lua errors.

**SC-5 → PORT-06:** Click "Add Song". The popup opens with cursor in the edit box (auto-focus). Type a song name. Click "Add" — song appears in the list. Open the popup again. Type a name. Press Enter — same result.

### Verification Commands (in-game)

```lua
-- After deployment, in WoW chat:
/reload                      -- reloads UI; triggers ADDON_LOADED
/vbard                       -- opens manager (confirms PORT-02)
/vbard debug                 -- enables debug output for tracing

-- To check for remaining nil errors during testing:
-- Open the default Lua error frame with:
-- Interface Options → Help → Display Lua Errors
```

### Post-Edit Grep Verification (before deployment)

Run these from the repo root immediately after making all changes, before copying to the WoW install:

```bash
# Must return zero results:
grep -n 'table\.getn' VaenylaeBard.lua
grep -n '\bthis:' VaenylaeBard.lua
grep -n '\bthis\b' VaenylaeBard.lua

# Must show updated values:
grep -n 'Interface:' VaenylaeBard.toc          # expect 30300
grep -n 'OnEvent.*function' VaenylaeBard.lua   # expect function(self, event, arg1)
grep -n 'OnUpdate.*function' VaenylaeBard.lua  # expect function(self, elapsed)
grep -n 'playbackElapsed.*arg1' VaenylaeBard.lua  # expect zero results
```

### Wave 0 Gaps

None — no test infrastructure to create. All validation is in-game.

---

## Runtime State Inventory

> This is a code-edit-only phase with no runtime rename involved. However, the addon touches SavedVariables.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `VaenylaeBardDB` SavedVariables in WoW's per-character save file | None — data format is unchanged; port only fixes code; existing saved songs survive |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None — no compiled artifacts; Lua is interpreted at load time | None |

**Nothing found requiring data migration.** The SavedVariables format written by 1.12.1 is read correctly by 3.3.5a without conversion.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| WoW 3.3.5a client (Faebright) | In-game testing (all SCs) | ✓ | 3.3.5a (Interface 30300) | None — required for validation |
| Lua 5.1 (embedded in WoW) | Runtime | ✓ | Embedded; no separate install | None — provided by WoW client |
| bash / cp | Deployment task | ✓ | Standard Linux shell | None needed |
| git | Commit before deploy | ✓ | Installed (repo exists) | None needed |

**Missing dependencies with no fallback:** None. All dependencies available.

---

## Security Domain

This phase introduces no network calls, no authentication, no user data beyond locally-scoped WoW SavedVariables, and no external service integration. The WoW addon security surface is:

| ASVS Category | Applies | Notes |
|---------------|---------|-------|
| V2 Authentication | No | No auth layer |
| V3 Session Management | No | WoW handles sessions |
| V4 Access Control | No | No access control layer |
| V5 Input Validation | Partial | Song name and line text are user-supplied strings passed to `SendChatMessage` — WoW server validates/truncates chat messages; no injection risk beyond WoW's own enforcement |
| V6 Cryptography | No | No crypto |

**Taint risk (WoW-specific):** `SendChatMessage` and `DoEmote` called from OnUpdate (addon-initiated, unsecured code path) are safe from WoW's action-bar taint system. No code change needed. If a future phase adds a SecureActionButton that calls into the playback engine, taint would become an issue — flag for that phase.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `table.getn` exists as a compatibility shim in WoW 3.3.5a's Lua environment (confirmed by ACP.lua using it without crash) | Standard Stack / Don't Hand-Roll | Low risk — even if shim is absent, replacing with `#` is still the correct fix; no downside |
| A2 | The target addon directory `/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/` already exists and the WoW install is at that path | Deployment | cp -r would create the directory; but if the path is wrong the copy silently succeeds to the wrong location |
| A3 | `button1` (lowercase) is the correct field name for the Accept button on the StaticPopup frame in 3.3.5a | Change 17 / StaticPopupDialogs | If wrong, EditBoxOnEnterPressed does nothing; fallback is `_G[self:GetParent():GetName().."Button1"]:Click()` — verify in-game |

---

## Open Questions

1. **StaticPopupDialogs `button1` field name confirmation**
   - What we know: CONTEXT.md locked decision is `self:GetParent().button1:Click()`. PITFALLS.md originally recommended `_G[self:GetName().."Button1"]:Click()`.
   - What's unclear: Which exact form is needed in the Faebright 3.3.5a build.
   - Recommendation: Implement the locked decision (`self:GetParent().button1:Click()`); verify in-game during SC-5 by pressing Enter in the Add Song popup. If it fails, try the `_G[...]` form as fallback.

2. **Faebright WoW install path confirmation**
   - What we know: CONTEXT.md specifies `/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/`.
   - What's unclear: Whether the directory already exists (WoW may need to be run once to create the AddOns structure, or the path may need `mkdir -p`).
   - Recommendation: The deployment task should use `mkdir -p` before `cp -r` as a precaution.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `this` global in SetScript callbacks | Explicit `self` first parameter | WoW 2.0 (BC, 2006) | All 7 closure sites require update |
| `event`/`arg1` globals in OnEvent | `(self, event, ...)` explicit params | WoW 2.0 (BC, 2006) | OnEvent and OnUpdate both affected |
| `table.getn(t)` for sequence length | `#t` length operator | Lua 5.1 (2006) | 5 call sites; `#` is faster and idiomatic |
| `VB_playbackElapsed = 0` reset | `VB_playbackElapsed = VB_playbackElapsed - effectiveDelay` | Best practice clarification | Eliminates sub-frame timing drift |

**Deprecated/outdated in this file:**
- `table.getn`: deprecated Lua 5.0 function; `#` is idiomatic Lua 5.1
- `this` global references in SetScript: 1.12.1 injection mechanism; absent in 3.3.5a
- `arg1`/`event` global reads in callbacks: 1.12.1 injection mechanism; must be explicit params

---

## Sources

### Primary (HIGH confidence)
- `VaenylaeBard.lua` (this repo, HEAD) — source of truth for all line numbers; all change sites confirmed via grep [VERIFIED: grep output 2026-05-12]
- `VaenylaeBard.toc` (this repo, HEAD) — confirmed `## Interface: 11307` on line 1 [VERIFIED: file read 2026-05-12]
- `/home/reset/Games/Faebright WoW/Interface/AddOns/TomTom/TomTom.lua` — confirms `OnEvent = function(self, event, ...)`, `OnUpdate = function(self, elapsed)`, `SlashCmdList`, ADDON_LOADED param pattern in 3.3.5a [CITED: local file]
- `/home/reset/Games/Faebright WoW/Interface/AddOns/ElvUI/Core/StaticPopups.lua` — confirms `OnShow(self, data)`, `OnAccept(self, data, data2)`, `self.editBox` popup callback conventions [CITED: local file]
- `/home/reset/Games/Faebright WoW/Interface/AddOns/ElvUI/Core/Distributor.lua` — confirms `OnAccept = function(self) ... self.editBox:GetText()` [CITED: local file]
- `/home/reset/Games/Faebright WoW/Interface/AddOns/Postal/Postal.lua` — confirms `OnAccept = function(self) self.wideEditBox:GetText()` with `hasEditBox = 1` [CITED: local file]
- `/home/reset/Games/Faebright WoW/Interface/AddOns/Pawn/Pawn.lua` — confirms ADDON_LOADED with arg1 param, PLAYER_LOGOUT for SavedVariables flush [CITED: local file]
- `/home/reset/Games/Faebright WoW/Interface/AddOns/ACP/ACP.lua` — confirms `table.getn` still exists as shim; confirms OnEvent named-param style [CITED: local file]

### Secondary (MEDIUM confidence)
- Wowpedia 1.x→2.0 porting guide: https://wowpedia.fandom.com/wiki/Porting_addons_from_1.x_to_2.0 — canonical Blizzard-era migration document [CITED: documentation]
- Lua 5.1 Reference Manual: https://www.lua.org/manual/5.1/manual.html — `table.getn` deprecation, `#` operator, explicit parameter passing [CITED: documentation]

### Previous Research Documents (HIGH confidence — consolidated here)
- `.planning/research/STACK.md` — all 17 change sites tabulated with before/after [CITED: project research]
- `.planning/research/ARCHITECTURE.md` — component map, integration points table, migration order [CITED: project research]
- `.planning/research/PITFALLS.md` — 7 pitfalls with line numbers and silent failure modes [CITED: project research]
- `.planning/research/FEATURES.md` — feature dependency graph, MVP definition, anti-features [CITED: project research]
- `.planning/research/SUMMARY.md` — executive summary, confidence assessment, gaps [CITED: project research]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — runtime is fixed; no library choices; all API patterns verified against local 3.3.5a addons
- Architecture: HIGH — single-file structure confirmed; all 17 change sites verified via source grep against HEAD
- Pitfalls: HIGH — all pitfalls verified against actual line numbers in VaenylaeBard.lua; silent failure modes confirmed by Lua 5.0→5.1 runtime behavior
- Validation: HIGH — 5-point checklist maps directly to the 5 phase success criteria; no ambiguity about what constitutes "done"

**Research date:** 2026-05-12
**Valid until:** 2026-06-12 (stable domain — WoW 3.3.5a API has not changed since 2010)
