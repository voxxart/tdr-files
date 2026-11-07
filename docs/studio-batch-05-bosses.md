# Studio batch 05: six boss/advanced enemy controllers

Prerequisite: working expanded batch 04 (55a2db6). Back up the place. Replace old
copies; do not leave two tag managers active for one enemy. No remote/event asset
additions are required. This batch changes server attack ownership and timing;
original animation, sound, projectile and particle assets are still required.

## Replace seven Scripts under ServerScriptService

| Location | Type |
| --- | --- |
| EnemyAttacks.Noobicus | Script |
| EnemyAttacks.NoobJuggernaut | Script |
| EnemyAttacks.Doombringer | Script |
| EnemyAttacks.Swordmaster | Script |
| EnemyAttacks.PlagueDoctor | Script |
| EnemyAttacks.Wizard | Script |
| Summon | Script |

Swordmaster and Wizard must be regular server Scripts. Their former source filenames
lacked .server even though their contents were automatic tag managers. This checkout
now has Swordmaster.server.luau and Wizard.server.luau. Remove former same-name
ModuleScripts if imported that way; no exported source requires those old modules.

## Add eight ModuleScripts

Create EnemyAttacks.Bosses as a Folder.

| Location under ServerScriptService | Type |
| --- | --- |
| EnemyAttacks.BossScope | ModuleScript |
| EnemyAttacks.Bosses.Noobicus | ModuleScript |
| EnemyAttacks.Bosses.NoobJuggernaut | ModuleScript |
| EnemyAttacks.Bosses.Doombringer | ModuleScript |
| EnemyAttacks.Bosses.Swordmaster | ModuleScript |
| EnemyAttacks.Bosses.PlagueDoctor | ModuleScript |
| EnemyAttacks.Bosses.Wizard | ModuleScript |
| Simulation.TaskScope | ModuleScript |

Retain the installed AttackService, AttackScheduler, MatchService, Main.TowerDeath,
EnemyService and earlier enemy behaviors. No changes to them are needed here.

## Architecture and intended behavior

The six adapters register factories with the tested AttackService. Each factory
isolates one boss's ability logic/state. There is no independent boss Heartbeat or
infinite manager task. The shared scheduler checks each active boss's decision tree
at 0.1 game-second intervals, retaining the original ability priority and constants.

This is the lifecycle stage of the boss migration: ability functions remain together
in each boss module, preserving their authored rules. It is not a finished generic
ability-definition system. Further decomposition can follow Studio parity testing.

BossScope owns cancellable asynchronous jobs, delayed callbacks, temporary objects,
server animation tracks, tween signal connections, ability sounds and transient
properties. TaskScope is engine-independent and tested separately. Its task API is
local to each factory, not a replacement for Roblox task globally. It uses the match
clock for delays and waits; death/tag removal/match end cancel suspended work and
remove owned resources. Completed one-shot signal connections and timed resources
are released while the boss remains alive, rather than only at match end.

Gameplay deadlines, DOT ticks, shield healing and attack delays now use game seconds.
Previously many mixed os.clock deadlines with durations divided by an earlier speed.
Client-facing durations and TweenInfo timings retain existing protocols. Server-side
ability animations/tweens and client effects do not automatically retime mid-play;
perfect presentation synchronization still needs the client animation/VFX migration.

Committed lethal tower cleanup is scoped to its match independently of caster life,
with duplicate pending teardown suppressed. Boss summons pass a cancellation predicate
through Summon into EnemyService.Summon, including between multiple summon groups.
Other existing Summon event callers remain compatible with the optional argument.

## One combined Studio test session

| Enemy/tag | Exercise |
| --- | --- |
| Noobicus | Airstrike primary/splash, shield, stomp, summons and rewards. End during the airstrike windup: no damage, SellLock is released. Remove tag during shield: no owned invincibility remains. |
| NoobJuggernaut | Minigun primary/front-cone splash, 5-second DOT channel, movement release and reward thresholds/UI. Kill during the channel: subsequent ticks stop. |
| Doombringer | Slam, stomp, minigun, railgun, summon, enrage and rewards. Verify original priority, damage, particles and movement reset; interrupt every windup/channel. |
| Swordmaster | Rocket storm, anti-air orbs, sword rain, summon, fire breath, EMP, block, enrage sequence and rewards. Kill mid-flight: delayed rocket/orb/EMP damage stops. Block must stop healing and release temporary invincibility; existing invincibility is restored. |
| PlagueDoctor | Three potion props, throw/landing/decay damage, barrier transitions, shield healing and reward thresholds. Remove it while fields are active: owned fields and ticks stop. |
| Wizard | Nearest tower and chain of up to three targets, stun, beam creation, delayed impact and movement restoration. Sell a selected tower during windup and interrupt the caster. |

For all six, test at 1x/2x, pause/resume and a mid-ability speed change. Test tag
removal, lethal damage, game over and immediate match restart. Inspect Output for
missing assets or behavior errors. Use two bosses of the same type to check isolated
cooldowns, rewards and teardown. Verify earlier summoners still work, since Summon
now accepts an optional predicate. Repeat spawn/remove cycles and inspect instances,
connections and memory; no production-scale stress benchmark has run in this cloud.

## Intentional corrections and remaining limits

- Wizard/NoobJuggernaut's broken tag-removal hookups are replaced by proper adapters.
- Server animation tracks, beam attachments, transient locks, cloned particles,
  fields, tween callbacks and sounds have an explicit cleanup owner.
- Swordmaster's Block does not destroy a pre-existing Invincible instance; an
  existing value is restored on completion/cancellation. This is still a legacy
  value bridge, not complete arbitration of concurrent status writers.
- PlagueDoctor decay fields and other boss-owned ongoing effects now stop when the
  caster is removed. Already applied stun/damage is not undone. Effects surviving
  caster death would require an explicit independent match scope.
- DOT intervals that previously ignored timescale now follow simulation time.
  Check balance and visual alignment at accelerated speeds.
- Server-created presentation is cleaned here. Client-only particles/projectiles
  still follow their existing bounded effect code; this batch adds no universal
  client cancellation protocol and does not claim that all client VFX instantly end.
- Fixed-duration facing, overlapping legacy speed/status writers, server-created
  VFX, linear targeting queries and some authored reward/UI edge cases remain
  later migration work. Compilation cannot establish asset correctness or parity.

## Cloud verification

All 131 game files compile and all 11 test files pass. Task-scope tests cover nested
delays, suspended coroutine cancellation, idempotent cleanup, late cleanup, completed
lease removal and cross-match invalidation. Static integration checks confirm six
adapters use their factory modules and those modules contain no old manager loops,
raw os.clock deadlines or ancestry registrations. These tests do not run Roblox
services or validate actual boss damage/animations. Studio validation is pending.
