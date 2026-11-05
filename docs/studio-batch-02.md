# Studio batch 02: four enemy behaviors

Starting point: Studio has the working Necromancer/MEU/Spawner update (45b246a).
Back up the place. Replace contents in existing instances, keeping one copy.

## Replace existing instances

| Under ServerScriptService | Type |
| --- | --- |
| EnemyAttacks.Marksman | Script |
| EnemyAttacks.Knight | Script |
| EnemyAttacks.NoobSoldier | Script |
| EnemyAttacks.BreadBearer | Script |
| Simulation.AttackScheduler | ModuleScript |
| Simulation.MatchService | ModuleScript |
| Main.TowerDeath | ModuleScript |

## Add new instances

| Under ServerScriptService | Type |
| --- | --- |
| EnemyAttacks.Targeting | Folder |
| EnemyAttacks.Targeting.NearestTower | ModuleScript |
| EnemyAttacks.Behaviors.Marksman | ModuleScript |
| EnemyAttacks.Behaviors.DirectTowerAttack | ModuleScript |
| EnemyAttacks.Behaviors.TowerDamage | ModuleScript |
| EnemyAttacks.Behaviors.BreadDrops | ModuleScript |
| Simulation.AttackSequence | ModuleScript |

No events are added or removed. No other scripts need updating from 45b246a.
MatchClock, EnemyService, Round, AttackService and summoner adapters remain in place.
Script filenames in the checkout correspond to these instance names without .luau
or .server suffixes.

## One combined test session

| Enemy/tag | Expected behavior |
| --- | --- |
| Marksman | First attack after 5–8 game seconds; nearest non-flying tower strictly within 25 planar studs. 2-second windup, 40% max-health damage (50% Death Wish), 2-second recovery, then 22–23-second cooldown. Existing Fire/sound/arrow effects. |
| Knight | Every 3–5 game seconds, nearest ground tower strictly within 8 planar studs; excludes CliffTower. Immediate 25% damage (30% Death Wish), original facing and Fire animation. |
| NoobSoldier | Every 10–14 game seconds, nearest non-flying tower strictly within 25 planar studs. Immediate 12.5% damage (20% Death Wish), one-second movement hold, existing facing/Fire/Attack sound. |
| BreadBearer | First drop after 5–8 game seconds, second after 3–5 more. Bread1 then Bread2, one each, 2.5x health and 1x speed. Corresponding carried model disappears; no third drop. |

For all four: test death/tag removal/game over/restart, timescale change and pause.
Marksman must not damage after cancellation during windup, and must recover if its
target is sold. Soldier must release its movement hold after cancellation. Knight
and Soldier already apply damage immediately; later cancellation does not undo it.
Lethal tower hits should animate once and use match-scoped cleanup. Check targeting
against flying, cliff, dead and already-Dying towers. Recheck the three summoners.

## Known limits and behavior corrections

- No performance claim until production-asset Studio profiling. Target search is
  still a linear scan at attack time; shared spatial indexing is a later step.
- The former Knight/Soldier removal-signal calls never connected their callbacks;
  the adapters now connect correctly and create no per-enemy ancestry connection.
- Dead/Dying towers are no longer valid targets. Lost Marksman targets no longer
  lock the attacker at infinite cooldown.
- Bread attempts now validate the map/path before consuming one of the two drops.
  Invalid attempts can retry. Exhausted BreadBearer entries leave the scheduler.
- Bread initialization retains the original visible carried models. Remove/re-add
  of its tag resets its two-drop behavior, matching the original registration model.
- Existing client facing-duration protocol and legacy zero-speed ownership remain
  limitations; see enemy-attacks.md. Damage balance and normal cast effects are
  preserved, while timescale and shutdown handling are centralized.
- Cloud tests validate scheduler/sequence/targeting logic and source compilation;
  actual Instances, effects and gameplay remain pending this Studio test.
