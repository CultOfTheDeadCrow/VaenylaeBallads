# Requirements: VaenylaeBard

**Defined:** 2026-05-12
**Core Value:** A bard can script and perform a full song — text, emotes, channels, and pacing — without manual typing during the performance.

## v1 Requirements

Requirements for the WotLK Port milestone. All changes are compatibility fixes to achieve feature parity on WoW 3.3.5a.

### Compatibility Port

- [ ] **PORT-01**: .toc Interface version reads `30300` (was `11307`) so the 3.3.5a client loads the addon without an out-of-date warning
- [ ] **PORT-02**: `OnEvent` callback receives `self`, `event`, and `arg1` as explicit function parameters so ADDON_LOADED initialization fires correctly
- [ ] **PORT-03**: `OnUpdate` callback receives `self` and `elapsed` as explicit function parameters so the auto-playback timer advances each frame
- [ ] **PORT-04**: All 5 `table.getn()` calls replaced with the `#` operator so song-length checks do not crash in Lua 5.1
- [ ] **PORT-05**: All 7 `SetScript` closures that referenced the `this` global declare `self` as an explicit first parameter so drag handlers, mode toggle, channel button, and emote-type button respond correctly
- [ ] **PORT-06**: `StaticPopupDialogs` `OnShow`, `OnAccept`, and `EditBoxOnEnterPressed` callbacks reference `self` instead of `this`, with corrected editbox navigation, so the Add Song dialog accepts input correctly
- [ ] **PORT-07**: `VB_playbackElapsed` reset uses residual subtraction (`VB_playbackElapsed - effectiveDelay`) instead of a hard zero so playback timing does not drift under load

## v2 Requirements

Deferred to a future milestone. Not in current roadmap.

### WotLK Enhancements

- **ENH-01**: Migrate to LibStub/ACE3 if addon grows beyond single-file scope
- **ENH-02**: Add RAID, PARTY, INSTANCE_CHAT channel types to the line editor

## Out of Scope

| Feature | Reason |
|---------|--------|
| New features | Pure compatibility port — no feature additions in this milestone |
| LibStub / ACE3 migration | YAGNI — addon is ~855 lines, single file is appropriate |
| Retail or other WoW clients | Targeting 3.3.5a only |
| UI redesign | No visual changes — behavior parity only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PORT-01 | Phase 1 | Pending |
| PORT-02 | Phase 1 | Pending |
| PORT-03 | Phase 1 | Pending |
| PORT-04 | Phase 1 | Pending |
| PORT-05 | Phase 1 | Pending |
| PORT-06 | Phase 1 | Pending |
| PORT-07 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 7 total
- Mapped to phases: 7
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-12*
*Last updated: 2026-05-12 after initial definition*
