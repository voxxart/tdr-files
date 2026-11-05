# Studio batch 03: Executioner, Assassin, Enforcer

Prerequisite: working batch 02 (1c2e751). Back up the place and replace contents,
keeping one instance of each script. No event additions/removals are required.

## Replace existing instances under ServerScriptService

| Location | Type |
| --- | --- |
| EnemyAttacks.Executioner | Script |
| EnemyAttacks.Assassin | Script |
| EnemyAttacks.Enforcer | Script |
| EnemyAttacks.Behaviors.DirectTowerAttack | ModuleScript |
| EnemyAttacks.Behaviors.TowerDamage | ModuleScript |

## Add new instances under ServerScriptService

| Location | Type |
| --- | --- |
| EnemyAttacks.Behaviors.Enforcer | ModuleScript |
| Simulation.DamageAmount | ModuleScript |

Other modules/adapters stay unchanged. In particular retain the previously installed
AttackSequence, MatchService, AttackScheduler and updated Main.TowerDeath.

## Behavior and combined test session

- Executioner: nearest non-flying, non-cliff tower within strict planar Range
  (attribute, default 8). AttackMin/AttackMax attributes (defaults 6/11) apply to
  initial and subsequent game-time cooldowns. Fire animation; 15% max-health damage
  or 20% Death Wish, using the original rounded remaining-health calculation.
  Lethal cleanup starts without the additional half-second presentation delay;
  TowerDeath retains its two-second delay. No movement hold added.
- Assassin: initial 5–6 game seconds, subsequent cooldowns 10–14 measured from cast
  attempt. Nearest ground, non-cliff target within 5 planar studs. Immediate 40%
  damage (50% Death Wish), AttackTower animation and 0.75-second movement hold.
  Attack sound at 0.5 game seconds; death/tag removal/match end cancels it.
- Enforcer: initial/subsequent 10–14 game seconds. Nearest ground, non-cliff tower
  within 8 planar studs. Attack animation and 1.67-second movement hold. Slam and
  stun at 1 second, then 0.67 recovery. No damage introduced. Stun is 10 seconds
  (13 Death Wish), bridged to existing Config.Stunned, preserving a longer stun.

For each: test normal/Death Wish, flying/cliff/dead targets, timescale changes,
pause/resume, death, tag removal, game over and restart. For Enforcer, sell the
chosen target during windup and kill the caster before impact: neither should
produce a stun or error. Once applied, stun survives caster death as before.
Assassin damage is immediate, so killing it later does not undo the hit.

Recheck Knight and NoobSoldier because DirectTowerAttack is shared; recheck lethal
Marksman hits because TowerDamage is shared. Summoner behavior is unchanged.

## Implementation notes and limits

Three independent attack Heartbeats and their per-enemy ancestry connections are
removed. Executioner's unused BurstShooter example is removed. Assassin's broken
GetInstanceRemovedSignal call is replaced with an actual connection.

Executioner's lethal cleanup is now match-scoped and detached from the attack;
it does not serialize unrelated enemies behind TowerDeath's yielding cleanup.
Enforcer reads Death Wish at impact instead of caching its setting at script load.
It never reduces a stronger existing stun. Target searches exclude dead/Dying towers.

Enforcer's previous local tower list is replaced by shared nearest-target code.
That code still scans towers at attack time; this is a scheduling/ownership migration,
not verified spatial-query optimization. Centralizing all tower stun expiry and
replacing legacy Value bridges remains part of the upcoming tower-system work.
Facing duration and overlapping legacy speed modifiers retain the limitations
listed in batch 02. No production-scale performance claims have been validated.

Cloud verification: all six test files pass, including rounding edge cases,
windup/recovery cancellation and targeting filters; all 112 game sources compile.
Actual Roblox attacks, sounds, animations and stun timing require Studio testing.
