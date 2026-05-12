# Feature Research

**Domain:** WoW addon compatibility port (1.12.1 Lua 5.0 -> 3.3.5a Lua 5.1)
**Researched:** 2026-05-12
**Confidence:** HIGH — All findings verified against Lua source in the VaenylaeBard.lua file itself plus
multiple installed WotLK 3.3.5a addons (TomTom, ElvUI, Postal, ACP, Pawn, MBB) present on the
target machine at `/home/reset/Games/Faebright WoW/Interface/AddOns/`.

---

## Feature Landscape

### Table Stakes (Users Expect These)

These are features that already exist and must keep working after the port.
Every row below maps to a concrete API difference that will silently break
or noisily crash the feature if left unfixed.

| Feature | API Change in 3.3.5a | Complexity | Risk if Ignored |
|---------|----------------------|------------|-----------------|
| Auto playback (OnUpdate timer) | `SetScript("OnUpdate", function(self, elapsed)` — `elapsed` is the 2nd param; `arg1` global is nil | LOW | Silent: timer never advances; performance hangs on line 1 forever |
| Any event-driven behavior (ADDON_LOADED, PLAYER_LOGOUT) | `SetScript("OnEvent", function(self, event, ...)` — `event` and `arg1` are params, not globals | LOW | Silent on PLAYER_LOGOUT: DB not saved; Crash on ADDON_LOADED: `arg1` is nil, addon never initialises |
| ADDON_LOADED guard (initialisation gate) | `arg1` (addon name) passed as 3rd param `...` or explicit `arg1` named param; must check `arg1 == "VaenylaeBard"` via param | LOW | Silent: InitializeAddon() fires for every addon that loads, not just VaenylaeBard; corrupt DB state possible |
| Drag-to-move (main frame, line editor) | `SetScript("OnDragStart", function(self) self:StartMoving() end)` — `this` global is nil | LOW | Runtime error: attempt to call method on nil; frame becomes immovable and spews errors |
| Mode toggle button (modeBtn OnClick) | `SetScript("OnClick", function(self) ... self:GetText() ... self:SetText(...)` — `this` is nil | LOW | Runtime error on click; mode switch broken |
| StaticPopupDialogs OnShow (add-song dialog) | `OnShow = function(self) self.editBox:SetFocus() end` — `this` is nil; in WotLK `self` is the popup frame, `self.editBox` is the embedded edit box | MEDIUM | Runtime error; edit box never focused (cosmetic but breaks UX flow) |
| StaticPopupDialogs OnAccept (add-song dialog) | `OnAccept = function(self) ... self.editBox:GetText() ...` — in WotLK `self` is the popup dialog frame; the edit box child is `self.editBox` not `_G[this:GetParent():GetName() .. "EditBox"]` | MEDIUM | Current code navigates from `this` (button) upward; `this` is nil so runtime error; song never added |
| StaticPopupDialogs EditBoxOnEnterPressed | `EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end` — `self` is the editbox; `this` is nil | LOW | Runtime error on Enter key in popup; dialog doesn't close cleanly |
| SavedVariables persistence (PLAYER_LOGOUT save) | PLAYER_LOGOUT is still the correct event in 3.3.5a (confirmed in Pawn, AceDB-3.0, Postal/AceDB); no change needed to event registration | NONE | No action needed |
| SavedVariables loading (ADDON_LOADED init) | Blizzard loads SavedVariables before ADDON_LOADED fires for the matching addon; pattern is correct; only the param-vs-global issue matters (see ADDON_LOADED row above) | LOW | No structural change; fix only the param read |
| Song list button count display | `table.getn(songData)` returns nil/errors in Lua 5.1 (function removed); replace with `#songData` | LOW | Runtime error in UpdateSongList; song list buttons show error text |
| Performance engine line count checks | `table.getn(song)` used in StartPerformance, AdvanceLine, OnUpdate loop (5 call sites) | LOW | Runtime errors mid-performance; performance stops or never starts |
| .toc Interface version | Must be `30300` not `11307`; wrong value causes client to mark addon out-of-date (load-blocked on strict servers or shows "!" in addon list) | LOW | Addon may refuse to load; definitely shows warning |
| Slash command registration | `SLASH_VAENYLAEBARD1`, `SlashCmdList["VAENYLAEBARD"]` — pattern is identical in 3.3.5a; no change needed | NONE | No action needed |
| SendChatMessage channel names | "SAY", "YELL", "EMOTE", "RAID", "PARTY" are identical across 1.12.1 and 3.3.5a; no change needed | NONE | No action needed |
| DoEmote built-in emotes | `DoEmote(token)` signature is unchanged; token strings ("WAVE", "BOW", etc.) are the same | NONE | No action needed |
| Frame creation (CreateFrame) | `CreateFrame("Frame", name, parent)` is identical; no change needed | NONE | No action needed |
| SetBackdrop availability | `SetBackdrop` exists on Frame objects in 3.3.5a (confirmed: TomTom uses `TomTomBlock:SetBackdrop({...})` on a pure-Lua CreateFrame result); the existing code already avoids SetBackdrop (uses `CreateTexture` with `SetTexture(0,0,0,0.8)`) | NONE | No action needed; existing texture approach is safe |
| `_G["name"]` lookups | Global table access pattern unchanged; no change needed | NONE | No action needed |

---

### Differentiators (Competitive Advantage)

Not applicable — this milestone is a pure compatibility port with zero feature additions.

---

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| VARIABLES_LOADED instead of ADDON_LOADED | Some WotLK guides suggest it for SavedVariables safety | VARIABLES_LOADED fires after all addons load but does NOT pass the addon name; you cannot guard it to "our addon only"; every reload triggers it; ADDON_LOADED with param check is the correct and standard WotLK pattern (confirmed: TomTom, Pawn, Postal/AceAddon-3.0 all use ADDON_LOADED) | Keep ADDON_LOADED; fix param read only |
| ACE3 / LibStub migration | Modern WotLK addons use it | Out of scope per PROJECT.md; pure port only; adding libraries is scope creep | Defer to post-port milestone |
| Compat shim (`this = self`) | Tempting one-liner to avoid touching all closures | Hides the real fix; shim breaks if callback receives self as implicit upvalue; not how WotLK addons are written; produces latent bugs | Fix each SetScript closure individually |

---

## Feature Dependencies

```
[.toc Interface 30300]
    (required first — addon must load before anything else runs)

[OnEvent param fix (self, event, arg1)]
    └──required by──> [ADDON_LOADED guard]
                          └──required by──> [InitializeAddon]
                                               └──required by──> [CreateMainFrame]
                                               └──required by──> [CreateLineEditorFrame]

[OnUpdate param fix (self, elapsed)]
    └──required by──> [Auto playback engine]

[table.getn -> # replacement]
    └──required by──> [StartPerformance (line count check)]
    └──required by──> [AdvanceLine (line count check)]
    └──required by──> [OnUpdate loop (line count check)]
    └──required by──> [UpdateSongList (display count)]

[SetScript closure this -> self fix]
    └──required by──> [OnDragStart / OnDragStop (both frames)]
    └──required by──> [Mode toggle button OnClick]
    └──required by──> [StaticPopup OnShow, OnAccept, EditBoxOnEnterPressed]
```

### Dependency Notes

- **.toc fix is load-gate:** If Interface version is wrong the client may refuse to load the addon at
  all; every other fix is moot until this is correct.
- **OnEvent fix is init-gate:** ADDON_LOADED handler reads `arg1` as a global (nil in 3.3.5a); if not
  fixed, `InitializeAddon()` either never fires or fires for every addon loaded, corrupting the DB.
- **table.getn is a crash-gate for playback:** All five call sites are in hot paths (OnUpdate fires
  every frame); a nil return from `table.getn` crashes the performance engine on first tick.
- **StaticPopup this->self is independent:** Broken popup blocks the add-song workflow but does not
  affect playback.
- **SetBackdrop is already safe:** Existing code uses `CreateTexture` fallback; no dependency fix
  needed.

---

## MVP Definition

### Launch With (v1 — all required for feature parity)

- [ ] `.toc` Interface: 30300 — load gate
- [ ] `OnUpdate` callback: `function(self, elapsed)` — auto playback gate
- [ ] `OnEvent` callback: `function(self, event, arg1)` or `function(self, event, ...)` — init and save gate
- [ ] `table.getn(x)` -> `#x` at all 5 call sites — playback crash gate
- [ ] All `SetScript` closures: `this` -> `self` (OnDragStart, OnDragStop on both frames; mode toggle OnClick) — frame usability
- [ ] `StaticPopupDialogs` callbacks: `this` -> `self`, fix edit-box access pattern — add-song dialog

### Add After Validation (v1.x)

None — this is a port, not a product.

### Future Consideration (v2+)

- [ ] ACE3/LibStub migration — only if addon grows beyond single-file scope
- [ ] Additional channel types (RAID, PARTY, INSTANCE) — new feature, not this milestone

---

## Feature Prioritization Matrix

| Change | User Impact | Implementation Cost | Priority |
|--------|-------------|---------------------|----------|
| .toc Interface 30300 | CRITICAL (addon won't load) | LOW (1 line) | P1 |
| OnEvent param fix | CRITICAL (init never runs) | LOW (1 line) | P1 |
| OnUpdate param fix | HIGH (playback broken) | LOW (1 line) | P1 |
| table.getn -> # (5 sites) | HIGH (playback crashes) | LOW (5 lines) | P1 |
| SetScript this->self, drag handlers | MEDIUM (frames non-draggable, errors) | LOW (4 closures) | P1 |
| SetScript this->self, mode toggle | MEDIUM (mode switch broken) | LOW (1 closure) | P1 |
| StaticPopupDialogs this->self | MEDIUM (add-song dialog broken) | MEDIUM (3 callbacks, edit-box path) | P1 |

All changes are P1. The port has no P2 or P3 items — every item above is required for feature parity.

---

## API Change Reference (Concise)

### `this` global — REMOVED in 2.0, gone in 3.3.5a

In 1.12.1 (Lua 5.0), every `SetScript` callback and XML `<Script>` block received the owner frame
as the `this` implicit global. In 3.3.5a (Lua 5.1), `this` is always `nil` in script callbacks.
The frame is passed as the **first explicit parameter** (`self` by convention).

Verified against: TomTom.lua L30 `function(self, event, ...)`, ElvUI StaticPopups.lua
`OnShow = function(self, ...)`, ACP.lua `function OnRenameSet(this)` (old code that still works
because the function is wired as a standalone named function receiving the frame as first arg).

**In VaenylaeBard.lua — all occurrences of `this` in SetScript closures must become `self`:**
- Line 307: `OnDragStart` on main frame
- Line 308: `OnDragStop` on main frame
- Line 445: `OnClick` on mode toggle button (`this:GetText()`, `this:SetText()`)
- Line 492: `OnDragStart` on line editor frame
- Line 493: `OnDragStop` on line editor frame
- Lines 773, 776, 788: StaticPopupDialogs callbacks

### `event`, `arg1` globals — REMOVED in 2.0, gone in 3.3.5a

In 1.12.1, `OnEvent` received no parameters; `event`, `arg1`..`arg9` were implicit globals.
In 3.3.5a, `OnEvent` receives `(self, event, ...)` as explicit parameters.

**In VaenylaeBard.lua:**
- Line 200: `eventFrame:SetScript("OnEvent", function()` -> `function(self, event, arg1)`
- Line 201: reads `event` global (nil) and `arg1` global (nil)
- Line 139: `playbackFrame:SetScript("OnUpdate", function()` -> `function(self, elapsed)`
- Line 139: reads `arg1` global as elapsed time (nil; causes `VB_playbackElapsed` to never advance)

### `table.getn(t)` — REMOVED in Lua 5.1

`table.getn` was the Lua 5.0 way to get sequence length. Lua 5.1 removed it; the `#` operator
replaces it for sequence tables (tables with integer keys 1..n). All song arrays in VaenylaeBard
are pure sequences built with `table.insert`, so `#` is correct.

Verified against: MBB.lua uses `table.maxn` (different function); TomTom uses `#` throughout;
`table.getn` still appears in ACP.lua (older port) but is not recommended.

**In VaenylaeBard.lua — 5 call sites:**
- Line 91: `table.getn(song)` in StartPerformance
- Line 107: `table.getn(song)` in StartPerformance debug
- Line 129: `table.getn(song)` in AdvanceLine
- Line 161: `table.getn(song)` in OnUpdate
- Line 630: `table.getn(songData)` in UpdateSongList

### StaticPopupDialogs callback signatures

In WotLK 3.3.5a, the Blizzard `StaticPopup` frame machinery calls:
- `OnShow(dialog, data)` — `dialog` is the popup Frame object (e.g. `StaticPopup1`)
- `OnAccept(dialog, data, data2)` — same; `dialog` is the popup frame, not a button
- `EditBoxOnEnterPressed(editbox)` — `editbox` is the EditBox widget

Verified against ElvUI StaticPopups.lua L476-488 (OnShow calls `OnShow(self, self.data)`),
L684-686 (OnAccept calls `OnAccept(self, self.data, self.data2)`), and
Postal.lua L213 `OnAccept = function(self) Postal.db:SetProfile(self.wideEditBox:GetText()) end`.

**Current VaenylaeBard code at lines 772-789 uses `this` (nil) and constructs edit-box name via
`_G[this:GetParent():GetName() .. "EditBox"]` — this is the 1.12.1 pattern where `this` was
the Accept button and `this:GetParent()` was the popup frame.** In 3.3.5a, `self` IS the popup
frame directly, and `self.editBox` is the embedded edit-box child.

Correct WotLK pattern:
```lua
OnShow = function(self)
    self.editBox:SetFocus()
end,
OnAccept = function(self)
    local songName = self.editBox:GetText()
    -- ...
end,
EditBoxOnEnterPressed = function(self)
    -- self is the editBox; self:GetParent() is the popup dialog
    local songName = self:GetText()
    -- ... then trigger accept logic ...
    self:GetParent():Hide()
end,
```

### SetBackdrop — Available in 3.3.5a, but not needed

`SetBackdrop({bgFile=..., edgeFile=..., ...})` is a valid method on Frame objects in 3.3.5a
(confirmed: TomTom L308 `TomTomBlock:SetBackdrop({...})`). The existing code already avoids
it (uses `CreateTexture` with solid color). No change required.

### ADDON_LOADED event behavior — same in 3.3.5a

`ADDON_LOADED` fires once per addon as it is loaded, passing the addon name as the first event
argument. The guard `if arg1 == "VaenylaeBard"` is the correct pattern — it just needs to read
`arg1` as a function parameter not a global (see OnEvent fix above). Confirmed: TomTom L49
`function TomTom:ADDON_LOADED(event, addon)`, Pawn L111 `elseif Event == "ADDON_LOADED" then
PawnOnAddonLoaded(arg1, ...)`.

### PLAYER_LOGOUT for SavedVariables — same in 3.3.5a

`PLAYER_LOGOUT` is the correct event for flushing data before save in 3.3.5a. The Blizzard
engine writes SavedVariables globals to disk after this event. Confirmed: Pawn L115, Postal
AceDB-3.0 L351, L378. No structural change needed — only the `OnEvent` param fix.

### Slash command registration — unchanged

`SLASH_FOO1 = "/cmd"` plus `SlashCmdList["FOO"] = function(msg)` is identical between
1.12.1 and 3.3.5a. Confirmed: TomTom L1027, 1033, 1041; MBB.lua L147-148. No change needed.

### SendChatMessage channel strings — unchanged

"SAY", "YELL", "EMOTE" are valid `type` arguments in 3.3.5a. No change needed.

### DoEmote — unchanged

`DoEmote(token)` signature is identical. No change needed.

---

## Sources

- `VaenylaeBard.lua` (this repo) — source of truth for all `this`/`arg1` occurrences
- `/home/reset/Games/Faebright WoW/Interface/AddOns/TomTom/TomTom.lua` — 3.3.5a addon; confirms
  `SetScript("OnEvent", function(self, event, ...)`, `SetScript("OnUpdate", function(self, elapsed)`,
  `SetBackdrop({...})`, `SlashCmdList`, ADDON_LOADED param pattern
- `/home/reset/Games/Faebright WoW/Interface/AddOns/ElvUI/Core/StaticPopups.lua` — confirms
  WotLK `OnShow(self, data)` and `OnAccept(self, data, data2)` StaticPopup callback convention;
  confirms `self.editBox` access pattern
- `/home/reset/Games/Faebright WoW/Interface/AddOns/Postal/Postal.lua` — confirms
  `OnAccept = function(self) self.wideEditBox:GetText() end` with `hasEditBox`
- `/home/reset/Games/Faebright WoW/Interface/AddOns/ACP/ACP.lua` — confirms `table.getn` still
  compiles (not hard-removed from WotLK's Lua build?) but `#` is standard; confirms OnEvent
  `function(this, event, arg1, ...)` named-param style still valid
- `/home/reset/Games/Faebright WoW/Interface/AddOns/Pawn/Pawn.lua` — confirms ADDON_LOADED
  with arg1 param and PLAYER_LOGOUT for SavedVariables flush
- `/home/reset/Games/Faebright WoW/Interface/AddOns/MBB/MBB.lua` + `MBB.xml` — confirms
  `this` global is injected by XML `<OnEvent>` blocks (legacy pattern still works via XML
  but NOT via `SetScript` in Lua 5.1); VaenylaeBard uses Lua `SetScript` so `this` will be nil

---

*Feature research for: VaenylaeBard WotLK port (1.12.1 -> 3.3.5a)*
*Researched: 2026-05-12*
