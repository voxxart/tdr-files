# Expanded Studio batch 04: five enemies and match timers

Use this checklist instead of the earlier two-aura batch-04 checklist. Starting
point: working batch 03 (d948768). Back up the place. Copy file contents into
matching instances, replacing old copies rather than running both versions.

## Replace nine existing scripts/modules under ServerScriptService

| Location | Type |
| --- | --- |
| EnemyAttacks.Inventor | Script |
| EnemyAttacks.RNG | Script |
| EnemyAttacks.Elm | Script |
| EnemyAttacks.Marauder | Script |
| EnemyAttacks.MerchantOrb | Script |
| EnemyAttacks.Behaviors.DirectTowerAttack | ModuleScript |
| Simulation.AttackScheduler | ModuleScript |
| Timer | Script |
| TotalGameTime | Script |

## Add eleven ModuleScripts under ServerScriptService

Create EnemyAttacks.Auras as a Folder.

| Location | Type |
| --- | --- |
| EnemyAttacks.AuraService | ModuleScript |
| EnemyAttacks.Auras.Inventor | ModuleScript |
| EnemyAttacks.Auras.RNG | ModuleScript |
| EnemyAttacks.Behaviors.Elm | ModuleScript |
| EnemyAttacks.Behaviors.MarauderRewards | ModuleScript |
| EnemyAttacks.Behaviors.Merchant | ModuleScript |
| EnemyAttacks.MerchantEconomy | ModuleScript |
| Simulation.AuraController | ModuleScript |
| Simulation.ThresholdRewards | ModuleScript |
| Simulation.ResourceLedger | ModuleScript |
| Simulation.WaveLifetime | ModuleScript |

No event additions/removals. Leave previous EnemyService, MatchService, MatchClock,
AttackService, Main.Round, Main.TowerDeath and the tested attack adapters in place.

## One test session

| Feature | Expected behavior |
| --- | --- |
| Inventor | Above 400 health disables Buffs/DamageBuffs towers, including new towers. Threshold crossing, death, tag removal and match end remove its owned effects. Multiple casters keep the aura alive. Towers without Config cause no errors. |
| RNG | Above 500 health protects non-RNG enemies, with existing shields/beams. Test multiple casters and handoff; beams rebind. Removal cleans owned welds/shields/values and preserves pre-existing ones. |
| Elm | Heals itself 200 every four game seconds, capped at max health. No revival after zero health. Changes speed/pause with the simulation. |
| Marauder | Every 10–11 game seconds, instant lethal attack against nearest non-flying tower within Range (default 8). Attack animation/sound retained. Range attribute retained; original code ignored cooldown attributes, so defaults remain 10–11. |
| Marauder rewards | One award per health threshold 15619, 10413, 5207, 100; a large hit can cross multiple. Base 10000/player count, original Death Wish formula with numeric EcoDebuff.Value. UI optional; missing UI must not block cash or combat. Healing never resets awards. |
| Merchant orb | First attempt 10–14 game seconds, retries 8–9. Chooses nearest non-flying, non-debuffed Farm within 100 planar studs. Throw at start, sound/projectile at 1 second, orb at 3 seconds, movement release at 3.5. One orb per Merchant. |
| Merchant debuff | Radius 5, farm cash halved (rounded), visual expires two waves later, debuff released three game seconds after that. Overlapping owned orbs share one original cash snapshot and release only after the last owner. Sold towers release references. |
| Merchant global cash loss | Every 15 real seconds while a live positive-DebuffPercent enemy is available and not busy: all players lose 1000; selected enemy plays CoinFlip with four game-second movement hold. Original fixed loss is retained, not multiplied by DebuffPercent. |
| Wave timer | No countdown changes after match end. New wave invalidates the previous countdown, preventing duplicate updates. Speed changes affect pending waits. Existing skip-time comparison/UI events retained. |
| Total-game timer | Actual elapsed seconds, independent of timescale. Starts counting at wave >=1, stops exactly with match state, resets and runs again for the next generation. |

For every feature, test death/removal, game over, immediate restart, pause/resume
and changing timescale. End a match mid-throw, mid-CoinFlip and while debuffs/auras
are active. No old match may spawn an orb, charge cash, reward cash or mutate its
timers afterward. Already spawned orb areas intentionally survive their caster's
death until wave expiry, but never survive the match.

Regression-check the previously tested enemies, especially Knight, NoobSoldier,
Executioner and Assassin (shared DirectTowerAttack), and reward listener teardown
(shared scheduler Attach/Cancel). Do not run old MerchantOrb/Inventor/RNG copies.

## Corrections and behavior changes to verify

- Inventor nil-Config bug, late-added Buffs detection, RNG caster handoff, orphan
  welds and deletion of pre-existing status/effect resources are addressed.
- Elm's previous global wall-time tick becomes a per-enemy game-time interval,
  starting four seconds after registration. This deliberately makes healing honor
  timescale and pause. Inspect the resulting balance at accelerated speed.
- Marauder's Instance arithmetic bug is fixed with EcoDebuff.Value. Multi-threshold
  payouts keep the same total, displayed as one combined cash popup. Tween baselines
  are retained so repeated rewards do not progressively shrink/move the label.
- Merchant has no per-orb Heartbeat, delayed task chain or infinite polling task.
  One economy manager owns areas and CoinFlip holds; thrown orb work cancels if
  caster/target disappears. No damage is added to its original non-damaging throw.
- Orb scans run at 10 Hz instead of every Heartbeat; entering the area may take
  up to about 0.1 seconds to apply a debuff. Cash drain remains on real time.
- Stale OriginalCash/EcoDebuff resources from other systems are not claimed or
  deleted. Farm upgrade/modifier writers still use legacy Value state: upgrade a
  debuffed farm and verify balance. Full modifier composition remains future work.
- Aura presentation remains server-created and target queries are still linear.
  Read studio-batch-04.md for aura details and limits. This is lifecycle and code
  organization work, not a validated thousands-of-enemies performance benchmark.
- Original animation/particle/UI assets are required. Cloud tests do not validate
  their structure, visual appearance or game balance.

Cloud verification: ten test files pass, all 123 game files compile. New tests
exercise aura handoff, owned-resource reference counting, reward thresholds and
idempotent scheduler attachment/cleanup. Actual Studio validation remains pending.
