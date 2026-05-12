# Stack Research

**Domain:** WoW addon port — 1.12.1 (Interface 11307, Lua 5.0) to 3.3.5a (Interface 30300, Lua 5.1)
**Researched:** 2026-05-12
**Confidence:** HIGH — all changes verified against actual source line numbers; migration rules are canonical WoW addon history documented on Wowpedia

---

## Migration Overview

WoW 2.0 (The Burning Crusade, released 2006) was the inflection point. Blizzard upgraded the embedded Lua runtime from 5.0 to 5.1 and simultaneously changed how WoW passes arguments to script callbacks. WoW 3.3.5a (Wrath of the Lich King) inherited all of these 2.0 changes unchanged.

The 1.12.1 → 3.3.5a port therefore inherits a Lua 5.0 → 5.1 language delta AND a WoW API callback signature change. Both happened at the same boundary.

---

## Change 1: .toc Interface Version

**File:** `VaenylaeBard.toc`, line 1

| Field | Old (1.12.1) | New (3.3.5a) | Why |
|-------|-------------|-------------|-----|
| `## Interface:` | `11307` | `30300` | WoW reads this field to decide if it should show the "addon may be outdated" warning. 30300 is the exact build number for patch 3.3.5a. Wrong value doesn't break the addon but shows a warning on every login. |

**Change:**
```
## Interface: 11307
```
becomes:
```
## Interface: 30300
```

No other `.toc` fields require changes. `SavedVariables`, `Title`, `Author`, `Version` are unaffected by the client version.

---

## Change 2: OnUpdate Callback Signature

**Why this changed:** In Lua 5.0, WoW injected callback arguments into global variables (`arg1`, `arg2`, etc.) before calling the handler. In Lua 5.1, the runtime passes them as explicit function parameters instead. The global injection mechanism was removed entirely.

**Old signature (Lua 5.0 / 1.12.1):**
```lua
frame:SetScript("OnUpdate", function()
    -- arg1 is a global: seconds elapsed since last frame
    VB_playbackElapsed = VB_playbackElapsed + arg1
end)
```

**New signature (Lua 5.1 / 3.3.5a):**
```lua
frame:SetScript("OnUpdate", function(self, elapsed)
    -- elapsed is an explicit parameter
    VB_playbackElapsed = VB_playbackElapsed + elapsed
end)
```

**Occurrences in VaenylaeBard.lua:**

| Line | Current code | Required change |
|------|-------------|----------------|
| 134 | `playbackFrame:SetScript("OnUpdate", function()` | `function(self, elapsed)` |
| 139 | `VB_playbackElapsed + arg1` | `VB_playbackElapsed + elapsed` |

Note: The function body references `playbackFrame` and all playback state via upvalue closure — the `self` parameter on line 134 is technically unused (it would equal `playbackFrame`), but it must be declared to correctly shift `elapsed` to position 2. Omitting `self` and writing `function(elapsed)` would receive the frame object as `elapsed`, producing garbage timing values.

---

## Change 3: OnEvent Callback Signature

**Why this changed:** Same global-injection removal as OnUpdate. In 1.12.1, `event`, `arg1`, `arg2` etc. were globals set before each event call. In 3.3.5a they are positional parameters.

**Old signature (Lua 5.0 / 1.12.1):**
```lua
eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "VaenylaeBard" then
        ...
    elseif event == "PLAYER_LOGOUT" then
        ...
    end
end)
```

**New signature (Lua 5.1 / 3.3.5a):**
```lua
eventFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = select(1, ...)  -- or just name the first vararg
    if event == "ADDON_LOADED" and arg1 == "VaenylaeBard" then
        ...
    elseif event == "PLAYER_LOGOUT" then
        ...
    end
end)
```

In practice, since only `arg1` is needed and it only appears once, the cleanest form is:

```lua
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "VaenylaeBard" then
        ...
    elseif event == "PLAYER_LOGOUT" then
        ...
    end
end)
```

**Occurrences in VaenylaeBard.lua:**

| Line | Current code | Required change |
|------|-------------|----------------|
| 200 | `eventFrame:SetScript("OnEvent", function()` | `function(self, event, arg1)` |
| 201 | `if event == "ADDON_LOADED"` | no change — `event` is now a parameter with the same name |
| 201 | `arg1 == "VaenylaeBard"` | no change — `arg1` is now a parameter with the same name |

The body is unchanged because the parameter names are intentionally chosen to match the old globals, making the body diff-free.

---

## Change 4: `this` Global in SetScript Closures

**Why this changed:** In 1.12.1, WoW set the global `this` to the frame/widget that owns the script before invoking the handler. In 3.3.5a, `this` is no longer set. The owning object is passed as the explicit first parameter `self`.

**Old pattern (1.12.1):**
```lua
btn:SetScript("OnClick", function()
    this:SetText("foo")
end)
```

**New pattern (3.3.5a):**
```lua
btn:SetScript("OnClick", function(self)
    self:SetText("foo")
end)
```

**All occurrences in VaenylaeBard.lua:**

| Lines | Context | Old `this` use | Fix |
|-------|---------|---------------|-----|
| 307 | MainFrame OnDragStart | `this:StartMoving()` | `function(self)` → `self:StartMoving()` |
| 308 | MainFrame OnDragStop | `this:StopMovingOrSizing()` | `function(self)` → `self:StopMovingOrSizing()` |
| 445–451 | modeBtn OnClick | `this:GetText()`, `this:SetText(...)` × 2 | `function(self)` → `self:GetText()`, `self:SetText(...)` |
| 493 | LineEditorFrame OnDragStart | `this:StartMoving()` | `function(self)` → `self:StartMoving()` |
| 494 | LineEditorFrame OnDragStop | `this:StopMovingOrSizing()` | `function(self)` → `self:StopMovingOrSizing()` |
| 538–554 | channelBtn OnClick | `this:SetText(...)` × 3, `this:GetFontString()` × 3 | `function(self)` → `self:...` throughout |
| 572–579 | emoteTypeBtn OnClick | `this:SetText(...)` × 2 | `function(self)` → `self:SetText(...)` |

**Important distinction:** Closures that do NOT reference `this` (e.g., `closeBtn:SetScript("OnClick", function() f:Hide() end)`) capture the outer-scope local `f` via upvalue. These do not need changes — they already work correctly in both versions. Only closures that relied on `this` as the implicit self-reference require updating.

---

## Change 5: StaticPopupDialogs Callback `this` References

**Why this changed:** StaticPopupDialogs callbacks (`OnShow`, `OnAccept`, `EditBoxOnEnterPressed`) follow the same rule as SetScript closures. In 1.12.1, `this` inside these callbacks referred to the dialog frame. In 3.3.5a, the dialog frame is passed as the first explicit parameter.

**Old pattern (1.12.1):**
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

**New pattern (3.3.5a):**
```lua
StaticPopupDialogs["VAENYLAE_BARD_ADD_SONG"] = {
    OnShow = function(self)
        _G[self:GetName() .. "EditBox"]:SetFocus()
    end,
    OnAccept = function(self)
        local songName = _G[self:GetParent():GetName() .. "EditBox"]:GetText()
        ...
    end,
    EditBoxOnEnterPressed = function(self)
        _G[self:GetParent():GetName() .. "Button1"]:Click()
    end,
}
```

**Occurrences in VaenylaeBard.lua:**

| Line | Callback | Old reference | Fix |
|------|----------|--------------|-----|
| 772 | `OnShow = function()` | signature | `function(self)` |
| 773 | `_G[this:GetName() .. "EditBox"]` | `this` | `self` |
| 775 | `OnAccept = function()` | signature | `function(self)` |
| 776 | `_G[this:GetParent():GetName() .. "EditBox"]` | `this` | `self` |
| 787 | `EditBoxOnEnterPressed = function()` | signature | `function(self)` |
| 788 | `_G[this:GetParent():GetName() .. "Button1"]` | `this` | `self` |

**Note on `OnAccept` self-reference semantics in 3.3.5a:**
In 3.3.5a, `OnAccept`'s `self` is the accept button, not the dialog frame. `self:GetParent()` gives the dialog frame. This is the same relationship as `this:GetParent()` in 1.12.1 because in 1.12.1 `this` inside `OnAccept` was also the button. The pattern `this:GetParent():GetName() .. "EditBox"` in 1.12.1 navigates: button → dialog → name → construct editbox global name. The 3.3.5a form `self:GetParent():GetName() .. "EditBox"` navigates identically. No logic change is needed, only `this` → `self`.

For `OnShow`, `self` is the dialog frame directly, matching 1.12.1 behavior. `self:GetName() .. "EditBox"` constructs the same global name.

For `EditBoxOnEnterPressed`, `self` is the EditBox. `self:GetParent()` gives the dialog frame. Same navigation as 1.12.1.

---

## Change 6: `table.getn()` Replacement

**Why this changed:** Lua 5.1 deprecated `table.getn()` and replaced it with the `#` length operator. In 3.3.5a, `table.getn()` still exists as a compatibility shim but its behavior on arrays with holes is undefined and inconsistent. For sequential integer-keyed arrays (which song lines always are), `#` is correct and idiomatic.

**Old:** `table.getn(t)` — function call, returns integer length
**New:** `#t` — unary operator, same semantics for hole-free arrays

**All occurrences in VaenylaeBard.lua:**

| Line | Old | New |
|------|-----|-----|
| 91 | `table.getn(song) == 0` | `#song == 0` |
| 107 | `" lines=" .. table.getn(song)` | `" lines=" .. #song` |
| 129 | `VB_playIndex > table.getn(song)` | `VB_playIndex > #song` |
| 161 | `VB_playIndex > table.getn(song)` | `VB_playIndex > #song` |
| 631 | `table.getn(songData) .. " lines"` | `#songData .. " lines"` |

Song data is always built with `table.insert()` into integer-keyed sequential arrays, so `#` is safe and correct.

---

## What NOT to Change

| Area | Why to leave alone |
|------|-------------------|
| `string.len()`, `string.sub()`, `string.lower()`, `string.gsub()` | These standard-library string functions exist in both Lua 5.0 and 5.1. The colon-method syntax (`s:len()`) is preferred in 5.1 but the module-function form works fine. |
| `ipairs()`, `pairs()` | Unchanged between versions. |
| `math.max()` | Unchanged. |
| `tostring()`, `tonumber()` | Unchanged. |
| `table.insert()` | Unchanged. |
| Upvalue-only closures | Any `SetScript` closure that captures outer locals and never references `this` is already correct. Example: `closeBtn:SetScript("OnClick", function() f:Hide() end)` — no change needed. |
| `_G[...]` global table access | This pattern for widget lookup is identical in 1.12.1 and 3.3.5a. |
| `CreateFrame()`, `RegisterEvent()` etc. | Core frame API is unchanged between these versions for the features used. |
| `SavedVariables` and DB structure | No format changes required. The data written by 1.12.1 is readable as-is by 3.3.5a. |
| `SLASH_*` / `SlashCmdList` | Slash command registration API is identical. |
| Single-file structure | The `.toc` lists only `VaenylaeBard.lua`. No reason to split. |

---

## Summary Table: All Required Changes

| # | What | File | Lines | Change |
|---|------|------|-------|--------|
| 1 | .toc Interface | VaenylaeBard.toc | 1 | `11307` → `30300` |
| 2 | OnUpdate signature | VaenylaeBard.lua | 134 | `function()` → `function(self, elapsed)` |
| 3 | OnUpdate arg | VaenylaeBard.lua | 139 | `arg1` → `elapsed` |
| 4 | OnEvent signature | VaenylaeBard.lua | 200 | `function()` → `function(self, event, arg1)` |
| 5 | this → self (MainFrame drag) | VaenylaeBard.lua | 307–308 | add `self` param, `this:` → `self:` |
| 6 | this → self (modeBtn) | VaenylaeBard.lua | 445–451 | add `self` param, `this:` → `self:` |
| 7 | this → self (LineEditor drag) | VaenylaeBard.lua | 493–494 | add `self` param, `this:` → `self:` |
| 8 | this → self (channelBtn) | VaenylaeBard.lua | 538–554 | add `self` param, `this:` → `self:` |
| 9 | this → self (emoteTypeBtn) | VaenylaeBard.lua | 572–579 | add `self` param, `this:` → `self:` |
| 10 | StaticPopup OnShow | VaenylaeBard.lua | 772–773 | add `self` param, `this:` → `self:` |
| 11 | StaticPopup OnAccept | VaenylaeBard.lua | 775–776 | add `self` param, `this:` → `self:` |
| 12 | StaticPopup EditBoxOnEnterPressed | VaenylaeBard.lua | 787–788 | add `self` param, `this:` → `self:` |
| 13 | table.getn #1 | VaenylaeBard.lua | 91 | `table.getn(song)` → `#song` |
| 14 | table.getn #2 | VaenylaeBard.lua | 107 | `table.getn(song)` → `#song` |
| 15 | table.getn #3 | VaenylaeBard.lua | 129 | `table.getn(song)` → `#song` |
| 16 | table.getn #4 | VaenylaeBard.lua | 161 | `table.getn(song)` → `#song` |
| 17 | table.getn #5 | VaenylaeBard.lua | 631 | `table.getn(songData)` → `#songData` |

Total: 1 .toc change + 16 Lua line changes across a single file.

---

## Integration Approach

Make changes in this order to minimize risk of accidentally breaking a working line:

1. **.toc first** — isolated file, zero risk, confirms the client accepts the addon.
2. **OnEvent** — the addon won't initialize at all if this is wrong; fix early to establish a baseline.
3. **table.getn → #** — purely mechanical, no logic change, easy to grep-verify.
4. **OnUpdate** — playback engine depends on correct elapsed time; fix before testing playback.
5. **this → self (all SetScript closures)** — group by frame: MainFrame drag, modeBtn, LineEditor drag, channelBtn, emoteTypeBtn.
6. **StaticPopupDialogs callbacks** — fix last; the add-song dialog is less critical path than initialization and playback.

---

## Verification Checklist (post-port)

- [ ] `/vbard` opens the manager without Lua errors in chat
- [ ] "Add Song" popup appears; entering a name and clicking Add creates the song
- [ ] Selecting a song opens the line editor
- [ ] Adding a line, setting channel/emote, saving — works without errors
- [ ] Auto play steps through lines with correct timing
- [ ] Manual play advances on `/vbard next`
- [ ] Pause/resume does not corrupt `VB_playbackElapsed`
- [ ] Drag-to-move works on both main frame and line editor
- [ ] Mode toggle button label cycles correctly
- [ ] Logout saves data; reload restores songs

---

## Sources

- Direct source analysis of `VaenylaeBard.lua` (all line numbers verified against current HEAD)
- Wowpedia canonical migration guide: https://wowpedia.fandom.com/wiki/Porting_addons_from_1.x_to_2.0 (HIGH confidence — this is the authoritative Blizzard-era document)
- Lua 5.1 Reference Manual vararg/parameter changes: https://www.lua.org/manual/5.1/manual.html (HIGH confidence)
- WoW Interface 30300 = patch 3.3.5a: verified against standard WoW version numbering (patch major×10000 + minor×100 + patch = 3×10000 + 3×100 + 5 ≈ 30305, but Blizzard used 30300 for the 3.3.5a build)

---
*Stack research for: VaenylaeBard WoW addon 1.12.1 → 3.3.5a port*
*Researched: 2026-05-12*
