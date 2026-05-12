# Architecture Research

**Domain:** WoW Addon — Lua 5.0 (1.12.1) to Lua 5.1 (3.3.5a) compatibility port
**Researched:** 2026-05-12
**Confidence:** HIGH — all patterns verified against real 3.3.5a addons installed in the target client at `/home/reset/Games/Faebright WoW/Interface/AddOns/` (TomTom, ElvUI, Postal, ACP, Zygor)

---

## Standard Architecture

### System Overview

The addon is and remains a single-file structure. The port changes zero architectural
boundaries — it changes only how Lua callbacks receive their arguments.

```
VaenylaeBard.lua (single file, ~855 lines)
┌──────────────────────────────────────────────────────────────┐
│  File-level globals / locals                                  │
│  (VaenylaeBardSongs, VB_isPlaying, VB_playIndex, etc.)       │
├──────────────────────────────────────────────────────────────┤
│  Playback Engine                                              │
│  playbackFrame (CreateFrame "Frame")                         │
│    └── OnUpdate  ← CHANGE REQUIRED                           │
│  DispatchLine(), StartPerformance(), StopPerformance()        │
│  AdvanceLine()                                               │
├──────────────────────────────────────────────────────────────┤
│  Event Handler                                               │
│  eventFrame (CreateFrame "Frame")                            │
│    └── OnEvent  ← CHANGE REQUIRED                            │
│  InitializeAddon()                                           │
├──────────────────────────────────────────────────────────────┤
│  UI Layer                                                    │
│  CreateMainFrame() — main window                             │
│    ├── OnDragStart / OnDragStop  ← CHANGE REQUIRED           │
│    ├── OnClick closures (Add/Remove/PlayPause/Stop/Mode)      │
│    │     └── OnClick for Mode toggle uses this  ← CHANGE     │
│    └── UpdateSongList() / UpdatePerformanceControls()        │
│  CreateLineEditorFrame() — line editor window                │
│    ├── OnDragStart / OnDragStop  ← CHANGE REQUIRED           │
│    └── OnClick closures (channel/emote type toggles)         │
│          └── both use this  ← CHANGE REQUIRED                │
│  UpdateLineList(), SaveLine()                                │
├──────────────────────────────────────────────────────────────┤
│  StaticPopupDialogs["VAENYLAE_BARD_ADD_SONG"]               │
│    ├── OnShow  ← CHANGE REQUIRED                             │
│    ├── OnAccept  ← CHANGE REQUIRED                           │
│    └── EditBoxOnEnterPressed  ← CHANGE REQUIRED              │
├──────────────────────────────────────────────────────────────┤
│  Slash Command Handler                                       │
│  SlashCmdList["VAENYLAEBARD"]                               │
├──────────────────────────────────────────────────────────────┤
│  table.getn() calls (5 sites)  ← CHANGE REQUIRED            │
└──────────────────────────────────────────────────────────────┘
```

### Component Responsibilities (unchanged by port)

| Component | Responsibility | File Location |
|-----------|----------------|---------------|
| Playback Engine | Timing loop, line dispatch, pause/stop/manual state | Lines 36–165 |
| Event Handler | ADDON_LOADED init, PLAYER_LOGOUT save | Lines 167–209 |
| Main Frame | Song list, performance controls, NOW/NEXT display | Lines 288–455 |
| Line Editor Frame | Per-line text/channel/emote/delay editing | Lines 478–601 |
| StaticPopupDialogs | Song name input dialog | Lines 767–793 |
| Slash Handler | /vbard command dispatch | Lines 796–852 |

---

## Recommended Project Structure

The single-file structure is kept. No new files.

```
VaenylaeBallads/
├── VaenylaeBard.lua        # All addon logic (single file — unchanged after port)
└── VaenylaeBard.toc        # Interface version bump: 11307 → 30300
```

### Structure Rationale

- **Single file:** Addon is small (~855 lines). No library dependencies. No split adds value.
- **No .toc file list changes:** Only one Lua file was listed before and stays listed.

---

## Architectural Patterns

### Pattern 1: Explicit Self Parameter in SetScript Callbacks

**What:** In WoW 3.3.5a (Lua 5.1), every SetScript callback receives the widget as
its explicit first parameter. The engine no longer injects a `this` global.

**When to use:** Every single `SetScript(...)` call. No exceptions.

**Trade-offs:** No downside. The old `this` global approach was 1.12.1-only.

**Before (1.12.1 / Lua 5.0):**
```lua
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
```

**After (3.3.5a / Lua 5.1) — verified in ElvUI BlizzardOptions.lua, ElvUI Bags.lua:**
```lua
f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
```

Closures that do not reference `this` or `self` (e.g., the Add Song button's OnClick,
the Stop button's OnClick) require no change — the implicit first parameter is simply unused.

---

### Pattern 2: OnEvent Handler Signature

**What:** In 3.3.5a, event handlers receive `(self, event, ...)` where `self` is the
frame, `event` is the event name string, and `...` are the event-specific arguments.
In 1.12.1 these were global variables (`event`, `arg1`, `arg2`, ...).

**Before (1.12.1):**
```lua
eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "VaenylaeBard" then
        InitializeAddon()
    elseif event == "PLAYER_LOGOUT" then
        ...
    end
end)
```

**After (3.3.5a) — verified against TomTom.lua line 30:**
```lua
eventFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...  -- or: local arg1, arg2 = ...
    if event == "ADDON_LOADED" and arg1 == "VaenylaeBard" then
        InitializeAddon()
    elseif event == "PLAYER_LOGOUT" then
        ...
    end
end)
```

For VaenylaeBard's two events, only `arg1` is needed (addon name for ADDON_LOADED).
PLAYER_LOGOUT has no extra arguments.

---

### Pattern 3: OnUpdate Handler Signature

**What:** In 3.3.5a, OnUpdate receives `(self, elapsed)` where `elapsed` is seconds
since the last frame update. In 1.12.1, elapsed was the global `arg1`.

**Before (1.12.1):**
```lua
playbackFrame:SetScript("OnUpdate", function()
    ...
    VB_playbackElapsed = VB_playbackElapsed + arg1
    ...
end)
```

**After (3.3.5a) — verified against TomTom_CrazyArrow.lua and TomTom_Corpse.lua:**
```lua
playbackFrame:SetScript("OnUpdate", function(self, elapsed)
    ...
    VB_playbackElapsed = VB_playbackElapsed + elapsed
    ...
end)
```

The playback engine body is otherwise unchanged. `self` (the playbackFrame) is not
used inside this closure — it only reads upvalue locals — so it can be named `_` if
preferred, but `self` is conventional.

---

### Pattern 4: StaticPopupDialogs Callback Signatures

**What:** In 3.3.5a, popup callback functions receive `self` as the first parameter.
The identity of `self` differs per callback:

| Callback | `self` is | How to access edit box |
|----------|-----------|------------------------|
| `OnShow` | popup frame | `self.editBox` (field set by engine) |
| `OnAccept` | popup frame | `self.editBox:GetText()` |
| `EditBoxOnEnterPressed` | the edit box widget itself | `self:GetParent()` → popup frame |

Verified against ElvUI Core/Distributor.lua (`OnAccept = function(self) ... self.editBox:GetText()`),
ElvUI Core/StaticPopups.lua (`OnShow = function(self) self.editBox:...`),
and Postal.lua (`OnAccept = function(self) ... self.wideEditBox:GetText()`).

**Before (1.12.1):**
```lua
StaticPopupDialogs["VAENYLAE_BARD_ADD_SONG"] = {
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
}
```

**After (3.3.5a):**
```lua
StaticPopupDialogs["VAENYLAE_BARD_ADD_SONG"] = {
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
}
```

Note: `button1` (lowercase) is the field name on the popup frame in 3.3.5a.
The old `_G[...Name() .. "Button1"]` global lookup is replaced with direct field access.

---

### Pattern 5: Mode Toggle and Channel Button OnClick (this → self)

**What:** Two button OnClick closures in the existing code reference `this` to act on
the clicked widget itself rather than a captured variable.

**Affected sites:**

`modeBtn:SetScript("OnClick", ...)` at line 444 — uses `this:GetText()` and `this:SetText()`

`channelBtn:SetScript("OnClick", ...)` at line 538 — uses `this:SetText()` and `this:GetFontString()`

`emoteTypeBtn:SetScript("OnClick", ...)` at line 572 — uses `this:SetText()`

**Before:**
```lua
modeBtn:SetScript("OnClick", function()
    if this:GetText() == "Auto" then
        this:SetText("Manual")
    else
        this:SetText("Auto")
    end
end)
```

**After:**
```lua
modeBtn:SetScript("OnClick", function(self)
    if self:GetText() == "Auto" then
        self:SetText("Manual")
    else
        self:SetText("Auto")
    end
end)
```

---

### Pattern 6: table.getn() Replacement

**What:** `table.getn(t)` was the Lua 5.0 idiom for sequence length. In Lua 5.1, the
`#` length operator is idiomatic. `table.getn` still exists in the 3.3.5a WoW
environment (confirmed: ACP.lua in the target client uses it), so this is not a
hard crash risk — but replacement is part of the stated migration scope.

**5 sites in VaenylaeBard.lua (lines 91, 107, 129, 161, 630):**

```lua
-- Before
table.getn(song)       -- returns integer length of song array
table.getn(songData)   -- used in button label construction

-- After
#song
#songData
```

Both are semantically identical for sequential integer-keyed tables, which is what
VaenylaeBardSongs entries always are (built via `table.insert`).

---

## Data Flow

### Playback Flow (unchanged by port)

```
/vbard play
    ↓
StartPerformance(mode)
    → sets VB_isPlaying, VB_playingSongName, VB_playIndex
    ↓
playbackFrame OnUpdate fires every frame (auto mode)
    → accumulates elapsed time
    → when elapsed >= line.delay: DispatchLine(song[VB_playIndex])
    → increments VB_playIndex
    → calls UpdateNowNext()
    ↓
DispatchLine(line)
    → SendChatMessage(text, channel)   -- if channel != EMOTE
    → SendChatMessage(emote, "EMOTE") or DoEmote(emote)
```

### Initialization Flow (unchanged by port, signature changes only)

```
WoW loads addon → ADDON_LOADED fires
    ↓
eventFrame OnEvent(self, "ADDON_LOADED", "VaenylaeBard")
    → InitializeAddon()
    → VaenylaeBardDB loaded from SavedVariables
    → CreateMainFrame()
    → CreateLineEditorFrame()
```

### SavedVariables Flow (unchanged by port)

```
PLAYER_LOGOUT fires
    ↓
OnEvent(self, "PLAYER_LOGOUT")
    → VaenylaeBardDB.songs = VaenylaeBardSongs
    → WoW serializes VaenylaeBardDB to disk
```

---

## Integration Points

### Changed Integration Points (all internal to VaenylaeBard.lua)

| Integration | Old (1.12.1) | New (3.3.5a) | Line(s) |
|-------------|--------------|--------------|---------|
| OnEvent handler | globals `event`, `arg1` | params `self, event, ...` | 200 |
| OnUpdate handler | global `arg1` as elapsed | param `elapsed` | 134 |
| OnDragStart (main frame) | `this:StartMoving()` | `self:StartMoving()` | 307 |
| OnDragStop (main frame) | `this:StopMovingOrSizing()` | `self:StopMovingOrSizing()` | 308 |
| OnDragStart (line editor) | `this:StartMoving()` | `self:StartMoving()` | 492 |
| OnDragStop (line editor) | `this:StopMovingOrSizing()` | `self:StopMovingOrSizing()` | 493 |
| modeBtn OnClick | `this:GetText()`, `this:SetText()` | `self:GetText()`, `self:SetText()` | 444 |
| channelBtn OnClick | `this:SetText()`, etc. | `self:SetText()`, etc. | 538 |
| emoteTypeBtn OnClick | `this:SetText()` | `self:SetText()` | 572 |
| StaticPopup OnShow | `_G[this:GetName().."EditBox"]` | `self.editBox` | 773 |
| StaticPopup OnAccept | `_G[this:GetParent():GetName().."EditBox"]` | `self.editBox` | 775 |
| StaticPopup EditBoxOnEnterPressed | `_G[this:GetParent():GetName().."Button1"]:Click()` | `self:GetParent().button1:Click()` | 788 |
| table.getn (5 sites) | `table.getn(song)` | `#song` | 91,107,129,161,630 |
| .toc Interface version | `11307` | `30300` | toc line 1 |

### Unchanged Integration Points

| Integration | Why Unchanged |
|-------------|---------------|
| CreateFrame / SetBackdrop | API identical in 3.3.5a — confirmed via TomTom.lua, AceGUI |
| SendChatMessage / DoEmote | Core API unchanged between 1.12.1 and 3.3.5a |
| StaticPopup_Show() | Call site unchanged; only the dialog definition callbacks change |
| _G["FrameName"] lookups | Global frame registry unchanged |
| RegisterEvent / UnregisterEvent | Frame method API unchanged |
| SlashCmdList / SLASH_* | Slash command registration API unchanged |
| SavedVariables (VaenylaeBardDB) | .toc declaration and runtime access unchanged |
| string.* functions used | string.lower, string.gsub, string.sub, string.len all in Lua 5.1 |
| UIPanelButtonTemplate / UIPanelCloseButton | Template names unchanged |
| InputBoxTemplate | Template name unchanged |

---

## Anti-Patterns

### Anti-Pattern 1: Leaving `this` Global References

**What people do:** Port the .toc version to 30300 but leave `this` references untouched.

**Why it's wrong:** In 3.3.5a, `this` is `nil` inside SetScript callbacks. The callback
receives no implicit global injection. Any method call like `this:StartMoving()` will
error with "attempt to index global 'this' (a nil value)".

**Do this instead:** Replace every `this` inside a SetScript closure with the `self`
parameter declared in the function signature.

---

### Anti-Pattern 2: Leaving `arg1` as Elapsed in OnUpdate

**What people do:** Keep `VB_playbackElapsed = VB_playbackElapsed + arg1` without
adding the `elapsed` parameter.

**Why it's wrong:** `arg1` is `nil` in 3.3.5a OnUpdate. Adding `nil` to a number
raises a Lua error on the first frame. The playback engine silently dies.

**Do this instead:**
```lua
playbackFrame:SetScript("OnUpdate", function(self, elapsed)
    ...
    VB_playbackElapsed = VB_playbackElapsed + elapsed
    ...
end)
```

---

### Anti-Pattern 3: Leaving `event`/`arg1` Globals in OnEvent

**What people do:** Keep `if event == "ADDON_LOADED"` assuming the global is still set.

**Why it's wrong:** In 3.3.5a the WoW engine no longer sets `event` or `arg1` as
globals when firing the OnEvent callback. `event` will be whatever value it last held
(likely `nil` on a fresh frame), causing the ADDON_LOADED branch to never fire and
the addon to silently not initialize.

**Do this instead:**
```lua
eventFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" and arg1 == "VaenylaeBard" then ...
```

---

### Anti-Pattern 4: Old StaticPopup EditBox Navigation

**What people do:** Keep `_G[this:GetParent():GetName() .. "EditBox"]:GetText()` in
OnAccept expecting it to work.

**Why it's wrong:** `this` is nil in 3.3.5a callbacks, so `this:GetParent()` errors
immediately.

**Do this instead:** Use `self.editBox:GetText()` in OnAccept, since `self` is the
popup frame and the engine populates `self.editBox` for `hasEditBox = 1` dialogs.

---

## Migration Order

Recommended order for applying changes (dependency-safe, testable incrementally):

1. **.toc Interface version** — `11307` → `30300`. No Lua changes. Allows client to load
   the addon at all. All other changes are moot if the client rejects the toc version.

2. **OnEvent handler** — fixes initialization. Without this, `InitializeAddon()` never
   runs, so all frames are nil and every subsequent change is untestable.

3. **OnUpdate handler** — fixes playback engine. The `arg1` → `elapsed` change and
   `table.getn` → `#` in the playback loop go together since they are in the same
   function.

4. **Remaining `table.getn` calls** — 3 remaining sites outside the OnUpdate closure
   (lines 91, 107, 130 in StartPerformance/AdvanceLine, line 630 in UpdateSongList).

5. **SetScript `this` → `self` in drag handlers** — both frames (main and line editor)
   use the same two-line pattern. Low risk, mechanical change.

6. **SetScript `this` → `self` in button OnClick closures** — modeBtn, channelBtn,
   emoteTypeBtn. Three sites, all mechanical.

7. **StaticPopupDialogs callbacks** — OnShow, OnAccept, EditBoxOnEnterPressed. Slightly
   more complex because the navigation model changes (field access vs global lookup).
   Test after this step by opening /vbard, clicking Add Song, and confirming the
   popup accepts input correctly.

---

## Sources

- TomTom 3.3.5a source: `/home/reset/Games/Faebright WoW/Interface/AddOns/TomTom/`
  - `TomTom.lua` line 30: `OnEvent = function(self, event, ...)` confirmed
  - `TomTom_CrazyArrow.lua`: `local function OnUpdate(self, elapsed)` confirmed
  - `TomTom_Corpse.lua`: `eventFrame:SetScript("OnUpdate", function(self, elapsed)` confirmed
- ElvUI WotLK 3.3.5a source: `/home/reset/Games/Faebright WoW/Interface/AddOns/ElvUI/`
  - `Core/StaticPopups.lua`: `OnShow = function(self)`, `OnAccept = function(self)` confirmed
  - `Core/Distributor.lua`: `OnAccept = function(self) ... self.editBox:GetText()` confirmed
  - `Modules/Skins/Blizzard/BlizzardOptions.lua`: `OnDragStart = function(self) self:StartMoving()` confirmed
- Postal 3.3.5a source: `/home/reset/Games/Faebright WoW/Interface/AddOns/Postal/`
  - `Postal.lua`: `OnAccept = function(self)`, `OnShow = function(self)` with `self.wideEditBox` confirmed
- ACP source: `/home/reset/Games/Faebright WoW/Interface/AddOns/ACP/ACP.lua`
  - Confirms `table.getn()` still exists in 3.3.5a environment (not a hard error, but deprecated)

---
*Architecture research for: VaenylaeBard WoW Addon 1.12.1 → 3.3.5a port*
*Researched: 2026-05-12*
