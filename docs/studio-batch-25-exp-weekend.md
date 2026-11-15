# Batch 25: match-locked 1.5x EXP weekends

Install these scripts together, then restart the play session.

## Replace

- [ ] **ModuleScript** `ServerScriptService.Simulation.MatchService`
- [ ] **Script** `ServerScriptService.Datastore`
- [ ] **LocalScript** `StarterGui.GameGui.GameController`

## Add

- [ ] **ModuleScript** `ReplicatedStorage.GameModules.EXPWeekend`
- [ ] **ModuleScript** `ServerScriptService.Simulation.MatchRewards`
- [ ] **LocalScript** `StarterGui.GameGui.EXPWeekendIndicator`

Use the existing **GuiObject** `StarterGui.GameGui.Modifiers.EXPWeekend` for the badge. Set its authored Visible to false to avoid a loading flash. No remote or Value instance needs to be added. No Commander or VisualElevation changes are included.

## Schedule and match locking

Every Friday at **12:00 PM Eastern local time**, through Sunday **before 8:00 PM Eastern local time**, a newly started match earns **1.5x normal player EXP**. The Friday start is inclusive; Sunday 8:00 PM is excluded. The schedule follows US daylight saving time (EDT in summer, EST in winter), using server UTC time rather than any player's device clock.

Eligibility is captured at `MatchService.Begin`, when the game transitions into its match-start countdown after map/mode selection. It is not captured when a player joins, during voting, at enemy spawn, or at reward payout. The fallback start path for GameRunning is also covered. Repeated initialization of the same generation cannot change the snapshot.

- Start before Friday noon: no bonus for that match, even if it finishes during the event.
- Start during the event: bonus remains for the whole match, even if it finishes after Sunday 8 PM.
- A late-joining player follows that match's captured state.
- A new match captures the current schedule again.

The server applies the multiplier once to the existing end-of-match EXP reward, after gamepass and first-medal EXP bonuses, rounding to the nearest integer. It applies to victory and defeat earnings. Coins, gems, event currency, wins, and battle-pass rewards are unchanged. Saved balances are never multiplied retroactively. This is the existing game match reward path; other places or unrelated EXP award systems would need their own integration.

`MatchRewards` keeps the authoritative eligibility private and publishes `workspace.Info` attributes `EXPWeekendActive` and `EXPWeekendStartedAt` for presentation/debugging. The indicator follows that captured boolean, and the end-screen EXP calculation applies the same weekend factor. There are no periodic clock checks, per-player timers, new reward requests, or additional datastore operations. Existing base reward-display calculations are retained.

The EXPWeekend module contains the 1.5 multiplier and pure Eastern-time schedule logic. Its daylight-saving rules reflect current US rules (second Sunday in March, first Sunday in November).

## Studio checks

1. Install all scripts and confirm `Modifiers.EXPWeekend` is hidden for an ineligible match and visible for an eligible match. Inspect `workspace.Info.EXPWeekendActive` and `EXPWeekendStartedAt` attributes.
2. For deterministic boundary tests, use a test copy of MatchRewards and pass a fixed Unix timestamp to its Begin call; restore the normal server clock before release. Do not change the player's device clock or edit the presentation attribute to test actual rewards.
3. Check a match starting immediately before Friday noon stays normal, and a match starting exactly at Friday noon gets 1.5x.
4. Check an eligible match keeps the badge and bonus past Sunday 8 PM, but the next match starting at/after 8 PM gets neither.
5. Verify awarded and saved EXP with and without gamepass/medal bonuses. Confirm the end screen includes the weekend factor and other reward types are unaffected.
6. Rejoin mid-match and check the same badge/state. Test victory, defeat, and a subsequent match on the same server.

Automated tests compare 10,336 timestamps and boundary cases across 2025–2030 against Python's America/New_York timezone data. They cover summer/winter/DST, inclusive/exclusive cutoffs, match-state locking across both boundaries, duplicate initialization, private reward authority, rounding, late UI binding, and listener cleanup. Live Studio saving and UI presentation still need testing.
