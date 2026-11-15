# Batch 26: reliable skip votes and overlapping wave spawns

**Required follow-up:** install [batch 27](studio-batch-27-wave-timing-fix.md) to fix the authored wave timing references.

Install together, then restart the Studio play session.

## Replace

- [ ] **ModuleScript** `ServerScriptService.Main.Round`
- [ ] **Script** `ServerScriptService.Timer`
- [ ] **LocalScript** `StarterGui.GameGui.GameController`

## Add

- [ ] **ModuleScript** `ServerScriptService.Simulation.WaveService`
- [ ] **ModuleScript** `ServerScriptService.Simulation.WaveState`

No new events, functions, UI assets, EnemyService changes, or Mob wrapper changes are needed. Replace the existing Timer script; do not leave a second countdown script running.

## Behavior

A passed skip advances to the next wave without waiting for the current wave's spawn sequence. Remaining enemy groups continue spawning alongside the next wave, using the existing shared EnemyService spawn budget. Already-spawned enemies remain. The ordinary wave reward is granted once, and a successful skip bypasses the separate reward-message delay. Batch 28 restores the five-second intermission countdown after a skip.

Round no longer blocks inside GetEasy/GetNormal/GetHard: it launches one scoped spawn job per wave and monitors progression independently. Pending jobs are tracked across overlapping waves. Clearing the map between groups does not finish a wave while spawns are pending. Old jobs stop on match end, and guarded group calls cannot start spawning into a later match generation.

The final wave is not skippable. Victory requires all pending jobs from every overlapping wave to finish and the Mobs folder to be empty. Final timer expiry alone cannot declare victory. A spawn-job error reports a warning and interrupts wave progression rather than silently granting completion (batch 27).

## Votes and UI

Votes are server-owned and tracked by player UserId, once per wave. Closed-window, duplicate, outsider, stale-wave, paused, and ended-match requests are rejected. The client sends the wave it voted on. Votes reset each wave. Membership changes recalculate the requirement using the live player roster, not potentially stale PlrValue.

The previous quorum is preserved: one vote in solo; otherwise all but one player. For example, 3 players require 2 votes. Passing on the prompt continues to hide it locally without voting. A player's choice is local to that wave; a delayed RPC or old hide event cannot dismiss the next wave's prompt. The prompt reads server attributes SkipOpen/SkipRequired and the existing VoteSkipValue.

## Timer configuration

The timer is driven by the shared game clock, so pause and timescale changes apply consistently. The old per-Wave.Changed countdown workers are removed. Empty-map gaps no longer stop the timer prematurely.

- **Optional Number attribute** `workspace.Info.WaveDurationSeconds`: explicit duration for each new wave.
- Otherwise, the authored per-wave timing in Main.Round defines the duration (batch 27). For definitions without authored timing, the existing Min/Sec values at WaveService initialization define the duration. If both are zero, the fallback is **90 seconds**. Each wave starts with a fresh duration rather than inheriting the prior wave's zeroed timer.
- Existing **Value** `workspace.Info.SkipTime`: remaining-time threshold for opening skip. Its existing MMSS encoding is preserved: `30` means 00:30 remaining, `110` means 01:10 remaining. Set it at or above the full wave duration to open immediately. A zero threshold leaves no manual skip window before timeout.
- Min/Sec remain the replicated countdown mirrors. Set WaveDurationSeconds to configure duration, rather than editing the mirrors during a wave.
- `workspace.Info.WaveSpawning` is a replicated boolean attribute indicating any pending wave spawn job, including overlapping jobs from earlier waves.

Normal timeout may also advance while spawns continue. Non-skipped clears/timeouts retain the existing reward-message and intermission delays. Final-wave completion rules take precedence over its timer.

The new controller uses constant-time enemy membership tracking rather than repeatedly allocating the whole Mobs child list. It adds no per-enemy listeners and no per-enemy polling. Spawning still obeys EnemyService's global frame budget.

## Studio tests

1. Use a long, multi-group wave. Pass a skip before spawning finishes. The next wave should begin promptly, and every remaining enemy from the previous wave should still spawn.
2. With 3 players, verify 2 distinct votes are required; repeated clicks from one player must not count twice. Verify votes reset next wave.
3. Test passing locally, late joining, a player leaving during a vote, and clicking as the wave changes. The new prompt should remain correct.
4. Kill a group before the next group begins. The empty gap must not finish the wave or stop its timer.
5. Pause during overlapping spawning, then change timescale. Confirm timers and spawn delays pause/scale together and votes cannot advance a paused match.
6. Check one wave reward per transition and the existing NoWaveReward/Death Wish modifiers.
7. On the final wave, let the timer expire while enemies or queued jobs remain. Victory must wait for all of them.
8. Lose/end the match during overlap. Confirm no remaining groups spawn afterward or leak into a restarted match.

Automated tests execute the actual Round.StartGame flow with the actual WaveService and a deterministic game-clock fixture. They cover immediate next-wave start mid-spawn, retained groups, single rewards, pause, final pending-spawn safety, stale/duplicate votes, roster changes, and old-generation isolation. UI feel, live multiplayer replication, and installed timer values still need Studio testing.
