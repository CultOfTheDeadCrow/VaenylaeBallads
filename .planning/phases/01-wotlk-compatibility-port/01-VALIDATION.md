---
phase: 1
slug: wotlk-compatibility-port
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-12
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — WoW addons have no automated test runner |
| **Config file** | None |
| **Quick run command** | `grep -n 'table\.getn\|this:\|\bthis\b' VaenylaeBard.lua` (expect zero results post-edit) |
| **Full suite command** | In-game: execute the 5-point SC checklist below after deployment |
| **Estimated runtime** | ~5 min (in-game checklist) |

---

## Sampling Rate

- **After every task commit:** Run post-edit grep verification (zero results for `table.getn`, `this:`, `\bthis\b`)
- **After all Lua edits complete:** Run full post-edit grep suite before deploying
- **Before `/gsd-verify-work`:** All 5 SC checklist items must pass in-game
- **Max feedback latency:** Immediate for grep; ~5 min for full in-game suite

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| toc-01 | 01 | 1 | PORT-01 | — | N/A | manual-smoke | `grep -n 'Interface:' VaenylaeBard.toc` (expect 30300) | ✅ | ⬜ pending |
| event-01 | 01 | 1 | PORT-02 | — | N/A | manual-smoke | `grep -n 'OnEvent.*function' VaenylaeBard.lua` (expect `function(self, event, arg1)`) | ✅ | ⬜ pending |
| onupdate-01 | 01 | 1 | PORT-03, PORT-07 | — | N/A | manual-functional | `grep -n 'OnUpdate.*function\|playbackElapsed' VaenylaeBard.lua` | ✅ | ⬜ pending |
| getn-01 | 01 | 1 | PORT-04 | — | N/A | manual-functional | `grep -n 'table\.getn' VaenylaeBard.lua` (expect zero results) | ✅ | ⬜ pending |
| setscript-01 | 01 | 1 | PORT-05 | — | N/A | manual-functional | `grep -n '\bthis:' VaenylaeBard.lua` (expect zero results) | ✅ | ⬜ pending |
| staticpopup-01 | 01 | 1 | PORT-06 | — | N/A | manual-functional | `grep -n 'editBox\|button1' VaenylaeBard.lua` (expect self.editBox and button1 forms) | ✅ | ⬜ pending |
| deploy-01 | 01 | 2 | All | — | N/A | manual-smoke | `ls "/home/reset/Games/Faebright WoW/Interface/AddOns/VaenylaeBard/"` (expect VaenylaeBard.lua, VaenylaeBard.toc) | ✅ W1 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

None — Existing infrastructure covers all phase requirements.

No test files to create. All validation uses grep against source files (automated) and in-game manual checklist (manual-only).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No "out-of-date" warning on login | PORT-01 | WoW client UI; no CLI access | Log in to Faebright 3.3.5a; open addon manager; confirm VaenylaeBard shows no "!" or "outdated" warning |
| ADDON_LOADED fires; songs list populates | PORT-02 | Requires live WoW session | `/vbard` shows manager with song list; re-login preserves saved songs |
| Auto-playback timer advances at correct interval | PORT-03 | Requires live WoW session + timing observation | Start auto-play; observe lines dispatch at ~3s intervals; no Lua errors in chat |
| Song line counts and auto-stop | PORT-04 | Requires live WoW session | Song list shows "(N lines)"; auto-play stops at last line without looping |
| Drag-to-move and toggle buttons respond | PORT-05 | Requires live WoW session | Drag both frames; cycle mode/channel/emote-type through all states; no Lua errors |
| Add Song dialog saves via button and Enter key | PORT-06 | Requires live WoW session | Open popup; type name; Add button saves; open again; Enter saves; song appears in list |
| No timing drift over multi-line song | PORT-07 | Subjective observation in-game | Run 5+ line song; line intervals are consistent; no jitter or stacking |

---

## Five-Point In-Game Checklist

**SC-1 → PORT-01:** Log in to Faebright 3.3.5a. Confirm VaenylaeBard loads with no "!" or out-of-date warning.

**SC-2 → PORT-02, PORT-04:** `/vbard` → manager opens with song list. Re-login → saved songs persist.

**SC-3 → PORT-03, PORT-04, PORT-07:** Select 3+ line song in Auto mode. Click Play. Lines dispatch at correct interval. Song stops at end. No Lua errors.

**SC-4 → PORT-05:** Drag both frames. Toggle mode (Auto↔Manual), channel (SAY→YELL→EMOTE→SAY), emote-type (Custom↔Built-in). All respond. No Lua errors.

**SC-5 → PORT-06:** Add Song popup → type name → Add button saves. Repeat → Enter key saves. Song appears in list.

---

## Post-Edit Grep Verification (before deployment)

```bash
# Must return zero results:
grep -n 'table\.getn' VaenylaeBard.lua
grep -n '\bthis:' VaenylaeBard.lua
grep -n '\bthis\b' VaenylaeBard.lua

# Must show updated values:
grep -n 'Interface:' VaenylaeBard.toc           # expect 30300
grep -n 'OnEvent.*function' VaenylaeBard.lua    # expect function(self, event, arg1)
grep -n 'OnUpdate.*function' VaenylaeBard.lua   # expect function(self, elapsed)
grep -n 'playbackElapsed.*arg1' VaenylaeBard.lua  # expect zero results
```

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` grep verify or manual in-game checklist step
- [ ] Sampling continuity: every task has at least one grep verification command
- [ ] Wave 0: no infrastructure to create
- [ ] No watch-mode flags
- [ ] Feedback latency: grep < 1s per task; full in-game suite ~5 min
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
