# Pitfalls Research

**Domain:** WoW Addon Port — 1.12.1 (Lua 5.0) to 3.3.5a (Lua 5.1)
**Researched:** 2026-05-12
**Confidence:** HIGH — all pitfalls verified against actual source code in VaenylaeBard.lua

---

## Critical Pitfalls

### Pitfall 1: `this` Global Silently Becomes nil in SetScript Closures

**What goes wrong:**
In 3.3.5a, `this` is not injected as a global inside `SetScript` callback functions. Any closure that references `this` gets `nil`, and calling a method on `nil` causes a Lua error that silently kills the callback — the script handler simply stops executing. There is no crash message visible in chat; the UI element just stops responding.

**Why it happens:**
In 1.12.1 (Lua 5.0), the engine set `this` as a global before calling any `SetScript` callback. Developers never had to think about which frame they were operating on. In 3.3.5a (Lua 5.1), the engine passes the frame as the first explicit parameter. Old code that uses `this` compiles fine — `this` is just a global variable reference — so no load-time error is raised. The error only occurs at runtime when the callback fires.

**Specific locations in VaenylaeBard.lua:**

- Line 307: `f:SetScript("OnDragStart", function() this:StartMoving() end)`
  - The closure has `f` in scope and could use `f:StartMoving()`, but uses `this` instead. In 3.3.5a, `this` is nil; dragging the main frame produces a silent nil error. Fix: `function(self) self:StartMoving() end`
- Line 308: `f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)` — same problem.
- Lines 445–450: `modeBtn:SetScript("OnClick", function() if this:GetText() == "Auto" then ... end)`. The outer scope has `modeBtn` available, but `this` is used. In 3.3.5a the mode toggle button silently stops toggling. Fix: `function(self) if self:GetText() == "Auto" then ... end`
- Lines 493–494: `CreateLineEditorFrame` has the same `OnDragStart`/`OnDragStop` pattern for the line editor frame.
- Lines 538–553: `channelBtn:SetScript("OnClick", function() ... this:SetText("YELL") ... this:GetFontString():SetTextColor(...)`. Outer scope has `channelBtn`. In 3.3.5a, clicking the channel cycle button silently errors; channel never changes. Fix: `function(self) ... self:SetText(...) ... self:GetFontString():SetTextColor(...) end`
- Lines 572–580: `emoteTypeBtn:SetScript("OnClick", function() ... this:SetText("Built-in") ... )`. Same pattern.

**Silent failure mode:** The button or frame stops responding with no visible error in the default chat frame. Only `/script print(this)` or `/eventtrace` reveals nil. Users see a "frozen" UI.

**How to avoid:**
Replace every `SetScript` callback signature `function()` with `function(self)` and replace every `this` reference inside that callback with `self`. For the drag handlers specifically, the upvalue `f` is also correct (`f:StartMoving()`), but using the explicit `self` parameter is canonical and more readable.

**Warning signs:**
- Any `SetScript` callback declared as `function()` with zero parameters that references `this` anywhere in its body.
- Buttons that compile cleanly but silently stop functioning on 3.3.5a.

**Phase to address:** Phase 1 (core compatibility fixes) — must be resolved before any functional testing on a 3.3.5a client.

---

### Pitfall 2: `arg1` and `event` Globals Silently nil in OnEvent/OnUpdate

**What goes wrong:**
In 3.3.5a, `OnEvent` callbacks receive `(self, event, ...)` as explicit parameters. `OnUpdate` callbacks receive `(self, elapsed)`. The globals `event` and `arg1` are not set. Reading them returns `nil`.

For `OnEvent`: `event == "ADDON_LOADED"` evaluates to `false` (nil ~= string), so `InitializeAddon()` is never called. The addon loads silently but the UI is never created and SavedVariables are never wired up. This looks like the addon "didn't load" but no error is shown.

For `OnUpdate`: `arg1` is nil; `VB_playbackElapsed = VB_playbackElapsed + arg1` produces `attempt to perform arithmetic on a nil value`. This error fires every frame while a song is playing — dozens of times per second — flooding the error log. Even if the error is suppressed, `VB_playbackElapsed` never advances, so songs never advance past line 1.

**Why it happens:**
In 1.12.1, the WoW Lua environment set `event` and `arg1`–`arg9` as globals before each callback. The 3.3.5a engine no longer does this. The old function signature `function()` with no parameters is syntactically valid in Lua 5.1 and loads without error.

**Specific locations in VaenylaeBard.lua:**

- Lines 200–209: `eventFrame:SetScript("OnEvent", function()` — reads globals `event` (line 201) and `arg1` (line 201). Fix: `function(self, event, ...)` and capture `local addonName = ...` for the ADDON_LOADED check. Or: `function(self, event, arg1)` since this handler only needs the first vararg.
- Line 134–165: `playbackFrame:SetScript("OnUpdate", function()` — reads global `arg1` on line 139. Fix: `function(self, elapsed)` and replace `arg1` with `elapsed`.

**Silent failure mode:**
- ADDON_LOADED branch: addon initializes nothing. No frames are created. `/vbard` prints "Frame not found! Try /vbard debug" but debug mode itself can't be toggled because it uses the slash handler which calls `_G["VaenylaeBardMainFrame"]`. No Lua error is raised — the condition simply evaluates false.
- OnUpdate: Lua error every frame during playback. `VB_playbackElapsed` may become NaN or stay at 0, meaning auto-performance never advances.

**How to avoid:**
`OnEvent`: change to `function(self, event, ...)` (or `function(self, event, arg1)` for clarity). Check for `event == "ADDON_LOADED"` using the parameter, not the global.
`OnUpdate`: change to `function(self, elapsed)`. Replace `arg1` with `elapsed` on line 139.

**Warning signs:**
- `eventFrame:SetScript("OnEvent", function()` with no parameters and `event` or `arg1` used in body.
- `playbackFrame:SetScript("OnUpdate", function()` with no parameters and `arg1` used in body.
- Any SetScript callback for "OnEvent" or "OnUpdate" with an empty parameter list.

**Phase to address:** Phase 1 — same pass as `this` removal. These two pitfalls together account for the addon being entirely non-functional on 3.3.5a at load.

---

### Pitfall 3: StaticPopupDialogs Callbacks — `this` Points to the Wrong Frame

**What goes wrong:**
`StaticPopupDialogs` callbacks in 1.12.1 receive the popup frame via the `this` global. In 3.3.5a they receive it as `self` (first explicit parameter). However, the semantics differ from `SetScript` closures in one critical way: the `this` available inside a `StaticPopupDialogs` callback is the *popup frame itself*, not the edit box or button. Code that chains `this:GetParent()` or `this:GetName()` to navigate to child widgets will produce nil method errors silently if `this` is nil.

**Specific locations in VaenylaeBard.lua:**

- Line 773 (OnShow): `_G[this:GetName() .. "EditBox"]:SetFocus()` — `this` is the popup frame. In 3.3.5a, `this` is nil; `this:GetName()` errors; the EditBox never receives focus on popup open. The popup opens but the user must click into the edit box manually.
- Line 776 (OnAccept): `_G[this:GetParent():GetName() .. "EditBox"]:GetText()` — `this` is the accept button. Wait — in 1.12.1 `OnAccept` receives the accept button as `this`, not the popup frame. In 3.3.5a, `OnAccept` receives `self` as the *popup frame* (StaticPopup_Show's self is the dialog frame). This is a semantic shift: the navigation `this:GetParent()` assumed button-as-self; if self becomes the frame itself, `:GetParent()` returns UIParent, breaking the widget name derivation entirely. `songName` becomes the result of calling `:GetText()` on the wrong widget (likely nil or "").
- Line 788 (EditBoxOnEnterPressed): `_G[this:GetParent():GetName() .. "Button1"]:Click()` — same parent-navigation problem.

**Why it happens:**
Blizzard changed the `self` reference semantics for `StaticPopupDialogs` callbacks between 1.12 and WotLK. The 1.12 convention was `this` = the widget closest to the action (button for OnAccept, editbox for EditBoxOnEnterPressed). WotLK passes the dialog frame itself as `self` to `OnAccept` and `OnShow`. This means the `GetParent()` chain that worked in 1.12 breaks in a way that silently returns a wrong widget rather than throwing an obvious error.

**Silent failure mode:**
- OnShow: AutoFocus silently fails. Popup opens, looks normal, but cursor is not in the edit box.
- OnAccept: `_G[UIParent:GetName() .. "EditBox"]` — `UIParent:GetName()` is "UIParent", so `_G["UIParentEditBox"]` is nil. `:GetText()` errors. The "Add" button press does nothing; no song is created, no error in chat.
- EditBoxOnEnterPressed: Same navigation failure; pressing Enter does nothing.

**How to avoid:**
Replace the parent-navigation pattern with direct widget names constructed from the known dialog key:
```lua
OnShow = function(self)
    _G[self:GetName() .. "EditBox"]:SetFocus()
end,
OnAccept = function(self)
    local songName = _G[self:GetName() .. "EditBox"]:GetText()
    ...
end,
EditBoxOnEnterPressed = function(self)
    _G[self:GetName() .. "Button1"]:Click()
end,
```
In 3.3.5a, `self` in `OnShow` is the popup dialog frame and `:GetName()` gives "StaticPopup1" (or whatever slot). All child widget names are derived from that.

**Warning signs:**
- Any `StaticPopupDialogs` callback with no parameters that references `this`.
- `this:GetParent()` chains inside `OnAccept` or `EditBoxOnEnterPressed`.
- Popup opens, looks fine, but clicking "Add" produces no result.

**Phase to address:** Phase 1 — part of the `this` global removal pass. The StaticPopup callbacks need careful testing separately from regular SetScript callbacks because the self semantics differ.

---

### Pitfall 4: `table.getn()` on Non-Sequence Tables Returns Incorrect Results

**What goes wrong:**
`table.getn(t)` is deprecated in Lua 5.1 and removed entirely in later versions. On 3.3.5a's Lua 5.1, `table.getn` may still exist as a compatibility shim, but its behavior on tables with non-integer keys or with holes is undefined and may differ from `#`. More importantly, `VaenylaeBardSongs` is a dictionary keyed by song name strings, and each song is a sequence table of line objects. `table.getn(songData)` on line 630 of `UpdateSongList` may return 0 or an incorrect count if called on the dictionary rather than a sequence.

The specific risk: `table.getn(song)` in `StartPerformance`, `AdvanceLine`, and the `OnUpdate` handler are called on the per-song sequence array — these are legitimate sequence tables and `table.getn` / `#` will agree as long as there are no holes. The silent risk is that if a line is deleted by setting `song[i] = nil` rather than using `table.remove`, the sequence gets a hole and `#song` can return a count that stops before the hole. With `table.getn`, the behavior is the same. The actual bug would be introduced by the hole, not by which counting function is used — but the port is the right time to audit this.

**Why it happens:**
`table.getn(t)` was the only way to get array length in Lua 5.0. Developers porting code often do a mechanical find-replace and miss places where the table is not a pure sequence, or they forget that `table.getn` with a metatable `__len` and the `#` operator have different dispatch behavior.

**Specific locations in VaenylaeBard.lua:**
- Line 91: `table.getn(song) == 0` — song is a sequence; safe to replace with `#song == 0`
- Line 107: `table.getn(song)` in debug string — safe
- Line 129: `VB_playIndex > table.getn(song)` — safe
- Line 161: `VB_playIndex > table.getn(song)` in OnUpdate — safe; this is also the highest-frequency call site (every frame)
- Line 630: `table.getn(songData)` for button label — safe (songData is a per-song sequence)

All five sites operate on per-song line arrays that are only modified via `table.insert` and direct integer index assignment. No holes are created by `SaveLine()`. All replacements with `#` are safe.

**Silent failure mode:**
On 3.3.5a, if `table.getn` is not present in the global environment (it is absent in strict Lua 5.1 runtimes), all five call sites error silently, causing: StartPerformance to show "Selected song has no lines" for every song, auto-playback to never stop at the end (or to error every frame), and the song list buttons to show "0 lines" for all songs.

**How to avoid:**
Replace all five `table.getn(x)` calls with `#x`. This is a pure mechanical substitution at all five sites. Do not use `table.getn` as a fallback; the `#` operator is the canonical Lua 5.1 idiom.

**Warning signs:**
- Any `table.getn(` in the source.
- Song list shows "(0 lines)" for songs that have lines.
- Auto-performance never ends (or errors on every OnUpdate tick).

**Phase to address:** Phase 1 — mechanical, low-risk, do in the same commit as the other compatibility fixes.

---

### Pitfall 5: OnUpdate `elapsed` Accumulation — Drift from Using the Wrong Zero-Reset Strategy

**What goes wrong:**
The `OnUpdate` handler accumulates `elapsed` in `VB_playbackElapsed`. When a line fires, it resets `VB_playbackElapsed = 0`. This is almost correct but loses the "overshoot" — the amount by which `VB_playbackElapsed` exceeded `effectiveDelay` in the final tick. Over a long song this drift is small but measurable: each line fires slightly late by up to one frame (16ms at 60fps). More critically, if `elapsed` is ever large (frame spike, alt-tab return), `VB_playbackElapsed` will be set to 0 instead of the residual `VB_playbackElapsed - effectiveDelay`, causing the next line to wait the full delay again rather than compensating.

**Why it happens:**
The naive reset pattern (`elapsed = 0`) is correct for simple timers but does not preserve sub-frame accuracy. This is a pre-existing issue in the 1.12.1 code, but it surfaces more noticeably in the 3.3.5a port because the `arg1` → `elapsed` fix is the moment a developer re-examines this code path.

**How to avoid:**
When resetting after a line fires, use the residual: `VB_playbackElapsed = VB_playbackElapsed - effectiveDelay` instead of `VB_playbackElapsed = 0`. This carries forward the overshoot and keeps timing accurate.

This is a pre-existing bug worth fixing during the port, but it is not a regression introduced by the port itself. Treat it as an opportunistic fix, not a blocking requirement.

**Warning signs:**
- `VB_playbackElapsed = 0` immediately after a line is dispatched in the OnUpdate handler (line 156).
- Subtle drift in timing for long songs (10+ lines).

**Phase to address:** Phase 1 as an opportunistic fix while editing the OnUpdate callback for the `arg1` → `elapsed` change. Do not block the port on it.

---

### Pitfall 6: PLAYER_LOGOUT SavedVariables Race — Writing to DB After It Has Already Been Flushed

**What goes wrong:**
The `PLAYER_LOGOUT` handler at lines 204–208 writes `VaenylaeBardDB.songs = VaenylaeBardSongs`. This is the correct pattern for WoW addon SavedVariables — the engine serializes `VaenylaeBardDB` to disk after `PLAYER_LOGOUT` fires. However, the risk is that `VaenylaeBardSongs` is a reference to `VaenylaeBardDB.songs` (set on line 182: `VaenylaeBardSongs = VaenylaeBardDB.songs`). The assignment on line 206 is therefore a no-op: `VaenylaeBardDB.songs = VaenylaeBardDB.songs`. This is not a bug — it is redundant but harmless — as long as `VaenylaeBardSongs` is never reassigned to point at a different table.

The real risk: if `VaenylaeBardSongs` is ever reassigned (e.g., `VaenylaeBardSongs = {}` to clear all songs), the reference breaks. `VaenylaeBardDB.songs` still points to the old table, and the PLAYER_LOGOUT handler faithfully writes the old table back to disk, silently discarding all changes made after the reassignment.

**Why it happens:**
Lua reference semantics are invisible. Both variables point to the same table after `InitializeAddon`, so mutations (table.insert, etc.) are correctly persisted. But a table replacement breaks the aliasing silently.

**Specific risk in VaenylaeBard.lua:**
Currently no code reassigns `VaenylaeBardSongs` to a new table after initialization, so the current implementation is safe. The risk is latent — it would manifest if a "clear all songs" feature is added without also updating `VaenylaeBardDB.songs`. The PLAYER_LOGOUT handler write on line 206 is belt-and-suspenders and is correct to keep.

**How to avoid:**
Keep the PLAYER_LOGOUT write. If any future code needs to replace the songs table wholesale, use `wipe(VaenylaeBardSongs)` and re-populate in place, rather than `VaenylaeBardSongs = {}`. Alternatively, always write `VaenylaeBardDB.songs = VaenylaeBardSongs` in PLAYER_LOGOUT and never use `wipe` — both strategies work; pick one and document it.

**Warning signs:**
- Any code that assigns `VaenylaeBardSongs = {}` or `VaenylaeBardSongs = newTable` outside of `InitializeAddon`.
- Songs disappear on relog even though they appeared in the UI during the session.

**Phase to address:** Phase 1 — note as a latent risk in the code review; no code change needed now, but add a comment warning about the aliasing.

---

### Pitfall 7: `SendChatMessage` and `DoEmote` Taint / Security in 3.3.5a

**What goes wrong:**
In 3.3.5a, the WoW client enforces "taint" rules: protected functions (SendChatMessage, DoEmote) can only be called from unsecured addon code if they are not called from a path that was initiated by a secure frame or a Blizzard-protected callback. Taint errors look like: `"Action Blocked: An AddOn has tried to call the protected function SendChatMessage()"` in the chat frame.

For VaenylaeBard, `SendChatMessage` and `DoEmote` are called from `DispatchLine`, which is called from the `OnUpdate` handler and from `AdvanceLine`. These are both addon-initiated callbacks, not Blizzard-protected secure paths. This means taint is not an issue for the addon's current call paths.

However, two edge cases exist:
1. If `DispatchLine` is ever called from inside a secure frame's `OnClick` — for example, if a future "play immediately" button is added using a Blizzard-protected template that runs in secure context — the call to `SendChatMessage` will be blocked.
2. In WotLK, `DoEmote` with some built-in emotes may internally trigger animation state changes that are taint-sensitive. This is a latent risk only.

**Why it happens:**
WotLK introduced the action bar protection system (no-taint API) to prevent addons from auto-casting spells. `SendChatMessage` and `DoEmote` are not in the protected function list for WotLK — they are protected only against being called from within a Blizzard secure frame execution path. An addon calling them directly from OnUpdate is fine.

**Current status:** The existing call paths (OnUpdate timer callback, slash command handler, `AdvanceLine` triggered by slash command or button click on an unsecured frame) are all clean. No changes needed for the 3.3.5a port.

**How to avoid:**
Keep `SendChatMessage` and `DoEmote` calls in addon-level (unsecured) code. Never move them into an `OnClick` handler on a frame that uses a Blizzard secure template for action bar interactions. The current architecture is safe.

**Warning signs:**
- "Action Blocked" error in chat when attempting to perform.
- `SendChatMessage` called from inside a `SecureHandler` or `SecureActionButton` callback.

**Phase to address:** No code change needed in Phase 1. Flag as a constraint for any future phase that adds playback-trigger UI widgets.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keep `VaenylaeBardSongs` as an alias for `VaenylaeBardDB.songs` | Simpler access throughout | Silent data loss if alias is broken by reassignment | Acceptable as long as no "clear all" feature is added; add a comment |
| `VB_playbackElapsed = 0` instead of residual reset | Simpler code | Sub-frame timing drift accumulates over long songs | Acceptable for RP use case where timing precision is low |
| Single-file addon (no modules) | No loading order issues | Global function namespace pollution (`StopPerformance`, `UpdateSongList`, etc. are global) | Acceptable at current scale; would need refactor if addon grows |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| StaticPopupDialogs in 3.3.5a | Assuming `OnAccept` self is the accept button (1.12.1 behavior) | In 3.3.5a, `self` in `OnAccept` is the dialog frame; derive child names from `self:GetName()` |
| SavedVariables and PLAYER_LOGOUT | Writing a nil check on `VaenylaeBardDB` before writing — if the DB was never initialized, data is silently dropped | Ensure `InitializeAddon` always creates the DB table on ADDON_LOADED before PLAYER_LOGOUT can fire |
| `OnUpdate` and `elapsed` | Using the elapsed value before the `arg1` → `elapsed` rename; both references in the same function body | Rename in a single atomic edit; grep for `arg1` after the edit to confirm zero remaining references |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `table.getn(song)` inside OnUpdate every frame | Minor CPU overhead; negligible at small song size | Replace with `#song` (computed the same way but no function call overhead) | Not a real threshold issue for this addon; fix anyway during the port |
| `UpdateNowNext()` and `UpdatePerformanceControls()` called every OnUpdate tick that fires a line | UI string updates on every line dispatch | Calls are gated by the `if VB_playbackElapsed >= effectiveDelay` check; only fires when a line dispatches, not every frame | Not a problem at current scale |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Calling `SendChatMessage` from a Blizzard secure execution path | "Action Blocked" error; performance breaks | Keep dispatch in OnUpdate / slash handler; never embed in a SecureActionButton template |
| Allowing user-supplied text in `DoEmote(emote)` where emote is a built-in emote token | No security risk in itself, but invalid tokens are silently ignored by the client | Validate against known token list or let the client silently drop invalid tokens — current approach is acceptable |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| StaticPopup EditBox not auto-focused (caused by `this` nil on OnShow) | User must manually click into the song name box; easy to overlook | Fix `OnShow` to use `self` so `SetFocus()` fires correctly |
| Mode toggle button silently non-functional (caused by `this` nil on OnClick) | User cannot switch between Auto and Manual mode; no error shown | Fix `modeBtn` OnClick to use `self` |
| Channel cycle button silently non-functional | User cannot change channel from SAY; all performance lines go to SAY regardless of saved settings | Fix `channelBtn` OnClick to use `self` |

---

## "Looks Done But Isn't" Checklist

- [ ] **`this` removal:** Verify every `SetScript` callback signature — not just the ones that obviously use `this`. The `OnDragStart`/`OnDragStop` handlers look trivial (one-liners) and are easy to miss.
- [ ] **`event` global:** After fixing `OnEvent` signature, search for bare `event` used as a variable name elsewhere in the file — it may exist as an upvalue or local with a different meaning that looks correct but shadows the parameter.
- [ ] **`arg1` in OnUpdate:** After adding `elapsed` parameter, confirm the variable `arg1` is completely absent from the OnUpdate body. A single remaining reference causes a runtime error every frame.
- [ ] **StaticPopup `OnAccept` navigation:** After changing `this` to `self`, verify that `self:GetName()` returns the correct dialog frame name (e.g., "StaticPopup1") and that `_G["StaticPopup1EditBox"]` is the actual widget name Blizzard uses. Test by opening the popup in-game and calling `/script print(StaticPopup1EditBox)`.
- [ ] **`table.getn` removal:** Run `grep -n 'table\.getn' VaenylaeBard.lua` after the fix — should return zero results.
- [ ] **TOC Interface version:** `## Interface: 11307` must become `## Interface: 30300`. A mismatch causes a "This addon was designed for a different version of WoW" warning in the addon manager and may cause load-order differences.
- [ ] **SavedVariables persistence:** After a full relog, confirm songs saved in the previous session appear in the manager. This validates both the ADDON_LOADED fix (DB is initialized) and the PLAYER_LOGOUT write (DB is flushed).

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| `this` nil in all SetScript closures | LOW | Grep for `this`, replace with `self` parameter; test each affected widget by interacting with it in-game |
| `arg1`/`event` globals nil | LOW | Edit two functions (OnEvent, OnUpdate); verify with `/script print(event)` inside a test handler |
| StaticPopup `this` nil — songs not saving | MEDIUM | Fix callback signatures; test by adding a song via popup and relogging to confirm persistence |
| `table.getn` absent | LOW | Five mechanical replacements; confirmed by grep |
| SavedVariables reference break (future) | MEDIUM | Audit all code that touches `VaenylaeBardSongs` for table replacement vs. mutation |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| `this` global in SetScript closures (7 sites) | Phase 1: Compatibility Port | All buttons respond correctly in-game; drag works on both frames |
| `event`/`arg1` globals in OnEvent (2 uses) | Phase 1: Compatibility Port | Addon initializes on load; SavedVariables persist across relog |
| `arg1` in OnUpdate | Phase 1: Compatibility Port | Auto-performance advances lines at correct intervals |
| StaticPopup `this` (3 callbacks, 2 semantic differences) | Phase 1: Compatibility Port | Add Song popup: EditBox auto-focuses, Add button creates song, Enter key works |
| `table.getn` (5 call sites) | Phase 1: Compatibility Port | Song list shows correct line counts; performance stops at last line |
| TOC Interface version | Phase 1: Compatibility Port | No version mismatch warning in addon manager |
| SavedVariables alias latent risk | Phase 1: Code Review | Add comment; no immediate fix needed unless "clear all" is added |
| SendChatMessage/DoEmote taint | Phase 1: Awareness | No code change; verify no "Action Blocked" during performance test |
| OnUpdate elapsed drift (opportunistic) | Phase 1: Opportunistic | Fix reset to use residual; verify timing is correct on a 5-line test song |

---

## Sources

- Source code inspection of VaenylaeBard.lua (all findings verified against specific line numbers)
- WoW API change documentation for 1.12 → 2.0 → 3.3.5a: `this` global removal, `arg1`/`event` removal, StaticPopupDialogs self semantics change are all established facts of the WoW addon API transition
- Lua 5.0 → 5.1 reference: `table.getn` deprecated in 5.1; `#` operator introduced in 5.1
- Confidence: HIGH — all pitfalls are present in the actual source code at the line numbers cited

---
*Pitfalls research for: WoW addon 1.12.1 to 3.3.5a port (VaenylaeBard)*
*Researched: 2026-05-12*
