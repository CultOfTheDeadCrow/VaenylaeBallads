# Phase 1: WotLK Compatibility Port - Pattern Map

**Mapped:** 2026-05-12
**Files analyzed:** 2 (VaenylaeBard.toc, VaenylaeBard.lua)
**Analogs found:** 4 / 4 (TomTom.lua, ElvUI Minimap.lua, ElvUI Distributor.lua, Postal.lua)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `VaenylaeBard.toc` | config | — | — | no analog needed (single integer change) |
| `VaenylaeBard.lua` lines 134, 139 | timer callback | event-driven | `TomTom/TomTom.lua` line 932 | exact |
| `VaenylaeBard.lua` line 156 | timer callback | event-driven | same TomTom OnUpdate | exact |
| `VaenylaeBard.lua` lines 200-201 | event handler | event-driven | `TomTom/TomTom.lua` lines 30-35 | exact |
| `VaenylaeBard.lua` lines 91, 107, 129, 161, 630 | utility expressions | — | — | no analog (language operator, not a pattern) |
| `VaenylaeBard.lua` lines 307-308 | frame drag handler | event-driven | `ElvUI/Modules/Maps/Minimap.lua` lines 197-198 | exact |
| `VaenylaeBard.lua` lines 444-451 | button toggle closure | event-driven | `ElvUI/Modules/Maps/Minimap.lua` lines 197-198 (drag variant) | role-match |
| `VaenylaeBard.lua` lines 493-494 | frame drag handler | event-driven | `ElvUI/Modules/Maps/Minimap.lua` lines 197-198 | exact |
| `VaenylaeBard.lua` lines 538-554 | button toggle closure | event-driven | `ElvUI/Modules/Maps/Minimap.lua` lines 197-198 (drag variant) | role-match |
| `VaenylaeBard.lua` lines 572-581 | button toggle closure | event-driven | `ElvUI/Modules/Maps/Minimap.lua` lines 197-198 (drag variant) | role-match |
| `VaenylaeBard.lua` lines 772-789 | static popup callbacks | request-response | `ElvUI/Core/Distributor.lua` lines 564-582 + `Postal/Postal.lua` lines 212-224 | exact |
| `VaenylaeBard.lua` lines 198-199 | comment | — | — | no analog (prose rewrite) |

---

## Pattern Assignments

### PORT-01: `VaenylaeBard.toc` line 1 — Interface version bump

**No analog needed.** This is a single integer substitution in a metadata file with no Lua logic.

**Before** (`VaenylaeBard.toc` line 1):
```
## Interface: 11307
```

**After:**
```
## Interface: 30300
```

---

### PORT-02: `VaenylaeBard.lua` lines 200-201 — OnEvent callback signature

**Analog:** `/home/reset/Games/Faebright WoW/Interface/AddOns/TomTom/TomTom.lua` lines 30-35

**Analog pattern** (lines 30-35):
```lua
TomTom.eventFrame:SetScript("OnEvent", function(self, event, ...)
	local method = TomTom.events[event]
	if method and TomTom[method] then
		TomTom[method](TomTom, event, ...)
	end
end)
```

**Before** (`VaenylaeBard.lua` lines 200-201):
```lua
eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "VaenylaeBard" then
```

**After:**
```lua
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "VaenylaeBard" then
```

**Rule:** `self` is always first; `event` second; event-specific args follow. Parameter names `event` and `arg1` are chosen deliberately so the body (lines 201-209) needs zero further edits.

---

### PORT-03: `VaenylaeBard.lua` lines 134 and 139 — OnUpdate callback signature + body rename

**Analog:** `/home/reset/Games/Faebright WoW/Interface/AddOns/TomTom/TomTom.lua` line 932

**Analog pattern** (line 932):
```lua
function WorldMap_OnUpdate(self, elapsed)
```
And line 953:
```lua
function Block_OnUpdate(self, elapsed)
```

**Before** (`VaenylaeBard.lua` lines 134, 139):
```lua
-- line 134:
playbackFrame:SetScript("OnUpdate", function()
-- line 139:
    VB_playbackElapsed = VB_playbackElapsed + arg1
```

**After:**
```lua
-- line 134:
playbackFrame:SetScript("OnUpdate", function(self, elapsed)
-- line 139:
    VB_playbackElapsed = VB_playbackElapsed + elapsed
```

**Critical note:** `self` MUST be declared even though the body never uses it. Writing `function(elapsed)` would receive the frame object as `elapsed`, producing garbage (extremely large) timing values. Every song line would fire immediately on the first frame.

---

### PORT-07: `VaenylaeBard.lua` line 156 — Residual subtraction (applied while OnUpdate is open)

**No external analog.** This is a best-practice timer pattern, not tied to a 3.3.5a API change.

**Before** (`VaenylaeBard.lua` line 156):
```lua
        VB_playbackElapsed = 0
```

**After:**
```lua
        VB_playbackElapsed = VB_playbackElapsed - effectiveDelay
```

**Rationale:** Hard-zero discards sub-frame overshoot. Residual subtraction carries it forward, keeping cumulative drift bounded. Apply in the same edit session as PORT-03 since the OnUpdate body is already open.

---

### PORT-04: `VaenylaeBard.lua` — All five `table.getn()` replacements

**No analog needed.** `#table` is a Lua 5.1 language operator, not a library call. The replacement is mechanical.

**Sites and before/after:**

| Line | Before | After |
|------|--------|-------|
| 91 | `table.getn(song) == 0` | `#song == 0` |
| 107 | `table.getn(song)` | `#song` |
| 129 | `VB_playIndex > table.getn(song)` | `VB_playIndex > #song` |
| 161 | `VB_playIndex > table.getn(song)` | `VB_playIndex > #song` |
| 630 | `table.getn(songData)` | `#songData` |

**Grep verification after edit (must return zero):**
```bash
grep -n 'table\.getn' /home/reset/Dev/Repos/VaenylaeBallads/VaenylaeBard.lua
```

**Note on line 630:** The `btn:SetScript("OnClick", ...)` closure immediately below (lines 632-638) uses `capturedName` — an upvalue, not `this`. Do not modify that closure; it is already correct.

---

### PORT-05a: `VaenylaeBard.lua` lines 307-308 — MainFrame drag handlers (this→self)

**Analog:** `/home/reset/Games/Faebright WoW/Interface/AddOns/ElvUI/Modules/Maps/Minimap.lua` lines 197-198

**Analog pattern** (lines 197-198):
```lua
fm:SetScript("OnDragStart", function(self) self:StartMoving() end)
fm:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
```

**Before** (`VaenylaeBard.lua` lines 307-308):
```lua
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
```

**After:**
```lua
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
```

---

### PORT-05b: `VaenylaeBard.lua` lines 444-451 — modeBtn OnClick (this→self)

**Analog:** Same `function(self)` parameter convention as drag handlers above. The body pattern is internal toggle logic.

**Before** (`VaenylaeBard.lua` lines 444-451):
```lua
    modeBtn:SetScript("OnClick", function()
        if this:GetText() == "Auto" then
            this:SetText("Manual")
        else
            this:SetText("Auto")
        end
        VBDebug("Mode toggled to: " .. this:GetText())
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
        VBDebug("Mode toggled to: " .. self:GetText())
    end)
```

---

### PORT-05c: `VaenylaeBard.lua` lines 493-494 — LineEditorFrame drag handlers (this→self)

**Analog:** Same as PORT-05a — `/home/reset/Games/Faebright WoW/Interface/AddOns/ElvUI/Modules/Maps/Minimap.lua` lines 197-198.

**Before** (`VaenylaeBard.lua` lines 493-494):
```lua
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
```

**After:** Identical to PORT-05a:
```lua
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
```

---

### PORT-05d: `VaenylaeBard.lua` lines 538-554 — channelBtn OnClick (this→self)

**Before** (`VaenylaeBard.lua` lines 538-554):
```lua
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
        UpdateTextBoxForChannel(VB_currentChannel)
        VBDebug("Channel set to: " .. VB_currentChannel)
    end)
```

**After:**
```lua
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
        UpdateTextBoxForChannel(VB_currentChannel)
        VBDebug("Channel set to: " .. VB_currentChannel)
    end)
```

---

### PORT-05e: `VaenylaeBard.lua` lines 572-581 — emoteTypeBtn OnClick (this→self)

**Before** (`VaenylaeBard.lua` lines 572-581):
```lua
    emoteTypeBtn:SetScript("OnClick", function()
        if VB_currentEmoteType == "custom" then
            VB_currentEmoteType = "builtin"
            this:SetText("Built-in")
        else
            VB_currentEmoteType = "custom"
            this:SetText("Custom")
        end
        VBDebug("Emote type set to: " .. VB_currentEmoteType)
    end)
```

**After:**
```lua
    emoteTypeBtn:SetScript("OnClick", function(self)
        if VB_currentEmoteType == "custom" then
            VB_currentEmoteType = "builtin"
            self:SetText("Built-in")
        else
            VB_currentEmoteType = "custom"
            self:SetText("Custom")
        end
        VBDebug("Emote type set to: " .. VB_currentEmoteType)
    end)
```

---

### PORT-06: `VaenylaeBard.lua` lines 772-789 — StaticPopupDialogs callbacks (this→self + corrected navigation)

**Primary analog:** `/home/reset/Games/Faebright WoW/Interface/AddOns/ElvUI/Core/Distributor.lua` lines 564-582

**Analog pattern** (lines 564-582):
```lua
    OnAccept = function(self)
        local profileKey = self.editBox:GetText()
        ...
        self:GetParent().button1:Disable()
        ...
        self:GetParent().button1:Enable()
    end,
    OnShow = function(self) self.editBox:SetText(D.profileKey) self.editBox:SetFocus() end,
```

**Supporting analog:** `/home/reset/Games/Faebright WoW/Interface/AddOns/Postal/Postal.lua` lines 212-224

**Postal analog pattern** (lines 212-224):
```lua
    OnAccept = function(self)
        Postal.db:SetProfile(strtrim(self.wideEditBox:GetText()))
    end,
    OnShow = function(self)
        self.wideEditBox:SetText(Postal.db:GetCurrentProfile())
        self.wideEditBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        Postal.db:SetProfile(strtrim(parent.wideEditBox:GetText()))
        parent:Hide()
    end,
```

**Before** (`VaenylaeBard.lua` lines 772-789):
```lua
    OnShow = function()
        _G[this:GetName() .. "EditBox"]:SetFocus()
    end,
    OnAccept = function()
        local songName = _G[this:GetParent():GetName() .. "EditBox"]:GetText()
        if songName and songName ~= "" then
            if VaenylaeBardSongs[songName] then
                print("Song with that name already exists!")
                return
            end
            VaenylaeBardSongs[songName] = {}
            UpdateSongList()
            print("Song '" .. songName .. "' added.")
        end
    end,
    EditBoxOnEnterPressed = function()
        _G[this:GetParent():GetName() .. "Button1"]:Click()
    end,
```

**After (locked decision from CONTEXT.md):**
```lua
    OnShow = function(self)
        self.editBox:SetFocus()
    end,
    OnAccept = function(self)
        local songName = self.editBox:GetText()
        if songName and songName ~= "" then
            if VaenylaeBardSongs[songName] then
                print("Song with that name already exists!")
                return
            end
            VaenylaeBardSongs[songName] = {}
            UpdateSongList()
            print("Song '" .. songName .. "' added.")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent().button1:Click()
    end,
```

**Self semantics in 3.3.5a:**
- `OnShow`: `self` = the popup frame. Engine sets `self.editBox` for `hasEditBox = 1` dialogs.
- `OnAccept`: `self` = the popup frame. Same `.editBox` field.
- `EditBoxOnEnterPressed`: `self` = the EditBox widget. `self:GetParent()` = popup frame. `.button1` = Accept button field (lowercase, confirmed by ElvUI Distributor line 577).

**Open question (from RESEARCH.md):** If `self:GetParent().button1:Click()` does nothing during SC-5, fallback is `_G[self:GetParent():GetName().."Button1"]:Click()`. Verify in-game.

---

### Comment Hygiene: `VaenylaeBard.lua` lines 198-199

**No analog.** Prose rewrite only.

**Before** (`VaenylaeBard.lua` lines 198-199):
```lua
-- In WoW 1.12.1 (Lua 5.0), extra event args come through globals (arg1, arg2, ...),
-- not function parameters. OnEvent receives (self, event) at most.
```

**After:**
```lua
-- In WoW 3.3.5a (Lua 5.1), extra event args are explicit function parameters.
-- OnEvent receives (self, event, ...) where ... are event-specific args.
```

---

## Shared Patterns

### SetScript callback signature convention
**Source:** `/home/reset/Games/Faebright WoW/Interface/AddOns/ElvUI/Modules/Maps/Minimap.lua` lines 197-198
**Apply to:** All 9 SetScript closure sites (PORT-03, PORT-05a through PORT-05e)

```lua
-- Pattern: frame is always first explicit parameter, even when unused in body
frame:SetScript("EventName", function(self, ...) ... end)
```

Corollary: `function()` with zero parameters is only correct for closures whose body never references `self`, `event`, `arg1`, or `elapsed`. Example of a closure that is already correct and must NOT be changed (`VaenylaeBard.lua` line 313):
```lua
closeBtn:SetScript("OnClick", function() f:Hide() end)
```
That closure captures `f` as an upvalue and does not use `this`. Leave it alone.

### `self.editBox` access in hasEditBox StaticPopup dialogs
**Source:** `/home/reset/Games/Faebright WoW/Interface/AddOns/ElvUI/Core/Distributor.lua` lines 569-582
**Apply to:** PORT-06 (`OnShow`, `OnAccept` in `VAENYLAE_BARD_ADD_SONG`)

```lua
-- Engine populates self.editBox on any StaticPopupDialog with hasEditBox = 1
-- Do NOT use _G[self:GetName() .. "EditBox"] — that is the 1.12.1 pattern
OnAccept = function(self)
    local value = self.editBox:GetText()
end,
OnShow = function(self)
    self.editBox:SetFocus()
end,
```

### `#` length operator (replaces `table.getn`)
**No external analog needed.** This is idiomatic Lua 5.1.
**Apply to:** All 5 `table.getn` call sites (PORT-04, lines 91, 107, 129, 161, 630)

```lua
-- Before (Lua 5.0):  table.getn(t)
-- After  (Lua 5.1):  #t
-- Semantics identical for sequence tables (no nil holes), which VaenylaeBardSongs arrays are.
```

---

## Closures That Must NOT Be Changed

The following closures use upvalues only — they capture outer locals (`f`, `capturedName`) and never reference `this`. They are correct in both 1.12.1 and 3.3.5a. Do not touch them during the PORT-05 sweep.

| Line | Closure | Why correct |
|------|---------|-------------|
| 313 | `closeBtn:SetScript("OnClick", function() f:Hide() end)` | captures `f` via upvalue |
| 504-507 | LineEditorFrame closeBtn OnClick (captures `f`) | captures `f` via upvalue |
| 632-638 | song list button OnClick (captures `capturedName`) | captures `capturedName` via upvalue |

**Grep to confirm no false positives were edited:**
```bash
grep -n '\bthis\b' /home/reset/Dev/Repos/VaenylaeBallads/VaenylaeBard.lua
# Must return zero results after all PORT-05 edits
```

---

## Post-Edit Verification Grep Suite

Run from `/home/reset/Dev/Repos/VaenylaeBallads/` before deployment:

```bash
# Must return zero results:
grep -n 'table\.getn'       VaenylaeBard.lua
grep -n '\bthis:'           VaenylaeBard.lua
grep -n '\bthis\b'          VaenylaeBard.lua
grep -n 'playbackElapsed.*arg1' VaenylaeBard.lua

# Must show updated values:
grep -n 'Interface:'        VaenylaeBard.toc          # expect 30300
grep -n 'OnEvent.*function' VaenylaeBard.lua          # expect function(self, event, arg1)
grep -n 'OnUpdate.*function' VaenylaeBard.lua         # expect function(self, elapsed)
```

---

## No Analog Found

| File / Site | Role | Reason |
|-------------|------|--------|
| `VaenylaeBard.toc` line 1 | config | Single-integer field; no pattern to copy |
| `#table` operator (PORT-04) | expression | Language operator; no codebase analog possible |
| `VB_playbackElapsed - effectiveDelay` (PORT-07) | arithmetic | Best practice, not an API pattern |
| Comment lines 198-199 | documentation | Prose rewrite; no code pattern |

---

## Metadata

**Analog search scope:** `/home/reset/Games/Faebright WoW/Interface/AddOns/` (TomTom, ElvUI, Postal, Pawn, ACP)
**Source files scanned:** VaenylaeBard.lua (855 lines), VaenylaeBard.toc (6 lines), TomTom.lua, ElvUI/Modules/Maps/Minimap.lua, ElvUI/Core/Distributor.lua, Postal/Postal.lua
**Pattern extraction date:** 2026-05-12
