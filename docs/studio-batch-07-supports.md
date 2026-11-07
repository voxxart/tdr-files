# Studio batch 07: support towers, mines and Phaser

Prerequisite: working tower core plus pregame registration fix (32c2cd2). Back up
the place, stop Play, update all listed modules together, then restart the test.
No new events or LocalScripts are required. Keep all earlier module instances.

## Replace five ModuleScripts

| Location | Type |
| --- | --- |
| ServerScriptService.Main.TowerServer | ModuleScript |
| ServerScriptService.Main.Mine | ModuleScript |
| ServerScriptService.Main.Unit | ModuleScript |
| ServerScriptService.TowerSystem.CombatScheduler | ModuleScript |
| ServerScriptService.TowerSystem.Targeting | ModuleScript |

## Add one Folder and nine ModuleScripts

| Location | Type |
| --- | --- |
| ServerScriptService.TowerSystem.Supports | Folder |
| ServerScriptService.TowerSystem.SupportService | ModuleScript |
| ServerScriptService.TowerSystem.Phaser | ModuleScript |
| ServerScriptService.TowerSystem.Supports.Farm | ModuleScript |
| ServerScriptService.TowerSystem.Supports.Tree | ModuleScript |
| ServerScriptService.TowerSystem.Supports.Medic | ModuleScript |
| ServerScriptService.TowerSystem.Supports.Spawner | ModuleScript |
| ServerScriptService.TowerSystem.Supports.MineLayer | ModuleScript |
| ServerScriptService.TowerSystem.Supports.FireRateSupport | ModuleScript |
| ServerScriptService.TowerSystem.Supports.DamageSupport | ModuleScript |

Simulation.TaskScope from the boss batch is reused unchanged. Main.Unit's change
is an optional final cancellation predicate on Spawn, checked after its spawn wait;
this is a boundary fix for spawners, not the full unit-system overhaul.

## Implementation

SupportService owns one scope per tower/role, deduplicates starts, retains generation
zero placements until the first match and never re-enrolls ended generations. The
shared update connection dispatches commander updates rather than a Heartbeat per
commander. Existing healer/spawner coroutines use cancellable game-time waits.
Connections, owned effects/tweens and explicit cleanup run at tower death, removal,
sale or match end. Short-lived Commander/Sergeant activations use the same scopes.

The original support rules are extracted into modules, including buff winner
selection/handoff, Tree shields, Medic targeting, wave payouts and spawner slots.
This is a lifecycle/extraction stage, not a completed declarative support framework.

Mines have one shared proximity/lifetime manager rather than a connection and timer
coroutine per mine. Proximity queries use the tower spatial index, keeping horizontal
range checks. Existing explosions, Boss Buster multipliers, quotas and rewards are
retained. Dead enemies no longer trigger new mines. Lifetime and triggers pause at
zero game speed, and match end removes live mines with counter cleanup. Committed
mines survive sale of their layer until normal expiry/match end, as before.

Phaser phase/shot/ramp deadlines now use match time; stun attributes retain their
existing wall-time contract. Match cleanup emits LostTarget and restores base damage.
All new player ability requests are rejected outside an active match. Commander and
Sergeant duration/cooldown waits are cancellable game time, with their changed stat
values restored on cancellation and duplicate active requests suppressed.

## One combined test session

| Feature | Check |
| --- | --- |
| Pregame placement | Place each support before countdown/wave 1. It must initialize once when the match starts, without duplicate payouts or spawns. |
| Farm | Correct wave payout, Generous Farms/Death Wish/Merchant debuff modifiers, cash UI/sound/orbs. No payout after game over. |
| Tree | AOE heal amount/range/cooldown, no revival, stun shield regeneration/countdown, shield consumption before stun and cleanup on sale/death. |
| Medic | Correct friendly/base healing, upgrades during healing, beam/light/particle release on cancellation, wave-triggered behavior. |
| Commander | Correct firerate/range buffs, multiple-source winner/handoff, upgraded/new targets, corruption, sale/death. Ability duration and CanBuff reset; no stuck ABILITYACTIVE. |
| Sergeant | Same lifecycle checks for damage support and active buff, preserving its authored multiplier. |
| Unit spawner | All three possible slots, placement cooldown, live unit/cooldown/multiplier upgrades, timer UI, linking to owner. No spawn after game over or cancellation during a spawn wait. |
| Mine Layer | Normal quota then Boss Buster quota, throw travel, range/path scatter, counters, explosion/cash, lifetime UI and pause/resume. End while a mine is in flight: no later placement. |
| Phaser/Beamer | StandBy/charge/lock/cooldown transitions, ramped damage, upgrade while locked, stun/corruption, target loss, pause, speed changes, sale/end/restart. |

For all roles: test 1x/2x, a speed change during a wait, pause/resume, sell/death,
game over and immediate restart. No old support callback may mutate the next match.
Recheck regular direct/burst/splash towers because the shared scheduler and targeting
module changed. Inspect Output for missing asset or module dependency warnings.

## Limits to assess in Studio

- Actual visual/model assets are unavailable in the cloud. UI/particles/animation
  parity, commander handoffs and detailed healer balance still need Studio tests.
- Support cleanup cancels server-owned effects. Existing client-only effects still
  use their earlier presentation protocol. Fixed-duration tween/facing presentation
  is not fully retimed when speed changes midway.
- Tree shield and commander callbacks preserve legacy Value bridges and shared
  buff managers. Full modifier arbitration and declarative definitions remain later
  work. Buffed tower upgrades during an active ability require careful parity tests.
- Commander updates share one engine connection but retain per-source recomputation;
  there is no claim of optimal complexity for hundreds of commanders. Healers and
  spawn-slot work still use one cancellable coroutine per supporting tower.
- Outlaw, missile, Reaper, helicopter mode and other specialized ability sequences,
  Scrambler logic, passive regen and global stun timing are not fully migrated here.
  Their activation gate now requires a live match; already-running legacy sequences
  still require the next lifecycle pass. Units spawned successfully still use the
  existing Unit movement/attack system, whose complete overhaul is outstanding.
- This is not a measured production-scale performance result.

## Verification

All 151 game sources compile. The 14 Luau test files and both Python-run integration
fixtures pass. The support fixture runs the actual SupportService/TaskScope with
simulated dependencies, covering pregame enrollment, duplicate registration, shared
updates, signal teardown, completed ability cleanup, tower death, no later-match
re-enrollment and bounded runtime cleanup registration. The existing tower integration
fixture continues to pass. Lexical checks found no unexpected globals in the
extracted support/Phaser modules. Engine fixtures do not replace Studio asset and
actual gameplay tests.
