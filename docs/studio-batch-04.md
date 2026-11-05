# Studio batch 04: Inventor and RNG global auras

This two-aura checklist is superseded by studio-batch-04-expanded.md, which
includes five enemies and both match timers. Use the expanded installation list.

Prerequisite: working batch 03 (d948768), including updated EnemyService and match
lifecycle. Back up the place; replace contents rather than running duplicate scripts.

Replace two Scripts under ServerScriptService:
- EnemyAttacks.Inventor
- EnemyAttacks.RNG

Add these four ModuleScripts:
- EnemyAttacks.AuraService
- EnemyAttacks.Auras.Inventor
- EnemyAttacks.Auras.RNG
- Simulation.AuraController

Create EnemyAttacks.Auras as a Folder. No event changes. No updates to the tested
attack adapters, AttackService, EnemyService or simulation clock are needed.

## Behavior and validation

Inventor: any tagged live caster above 400 health disables towers with a Folder
named Buffs or DamageBuffs in Config. New eligible towers are picked up at the next
0.2-second update, including folders added after the tower was parented. No Config
must produce no error. At 400 or below, on death/tag removal, or match end, its
owned DISABLED value is removed; a pre-existing value is restored rather than deleted.
Multiple casters keep the aura active until no eligible caster remains.

RNG: any tagged live caster above 500 health grants non-RNG models under Mobs the
existing Invincible compatibility value, shield scaled by HipHeight, and template
beam from caster Core.Neon.Attachment to target Torso.Center. All tagged RNG models
remain excluded as aura targets. Verify new enemies gain the aura, target removal
releases resources, and caster handoff binds beams to the replacement caster.
At 500 or below, death/tag removal, or match end, owned effects and values disappear.
Pre-existing Shield and Invincible instances must survive cleanup.

Both auras share a single 0.2 real-second reconciliation loop, matching the previous
wall-time aura checks (not attack cooldowns). Terminal match state clears effects
on the next Heartbeat, including while simulation time is paused. New matches
cannot reuse the previous generation's effects. Use several casters and repeated
spawn/remove cycles; inspect instance counts for accumulation of beams and welds.

## Corrections and limits

- Fixed Inventor's nil Config fallback and its failure to notice later Buffs folders.
- RNG rebinds resources when caster identity changes, even while aura stays enabled.
- Welds are owned by the shield, and target teardown explicitly destroys them;
  no per-target ancestry connections are created.
- Cleanup only removes created status values. Existing values are restored, and
  pre-existing shields are not destroyed. This still uses legacy Value bridges;
  competing writes to the same BoolValue are not fully distinguishable until all
  status producers migrate to a central modifier registry.
- This update preserves the existing legacy Invincible mechanism. Full authoritative
  damage/immunity unification remains part of the damage/tower-system migration.
- Shield/beam presentation remains server-created in this batch. Moving it to a
  client effect controller requires a separate synchronized presentation migration.
- Missing optional presentation assets skip that effect. Shield Break still follows
  the old Play-then-Destroy behavior; dedicated one-shot audio is future work.
- Reconciliation still scans aura targets at 5 Hz; profile production assets before
  claiming performance at thousands of enemies. No scale benchmark has run here.

Cloud: seven test files pass, including aura deduplication, target removal, caster
handoff, stop cleanup and incomplete-target retry; all 116 game files compile.
Studio tests of actual effects, values, immunities and match cleanup are pending.
