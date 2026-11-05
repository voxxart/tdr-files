# Enemy attack migration: Necromancer

Necromancer.server is now a tag-registration adapter. AttackService owns one shared
Heartbeat for migrated enemies; Simulation/AttackScheduler owns cooldowns, busy
state and cancellation. Behaviors/Summon contains configurable summon execution.
Other enemy attack scripts have not been migrated and retain their existing loops.

Necromancer retains SummonMin/SummonMax overrides (defaults 12–13 game seconds),
four Undead Squires with 2x health and 1x speed, the Death sound, Summon animation
and existing MEU.Client visual event. Cooldowns now follow live game speed and
pause. Overlapping casts on one enemy are prohibited. Missed cooldowns do not
produce catch-up bursts.

Registration uses the authoritative EnemyRuntime generation. Every execution checks
runtime health, legacy HealthValue (to catch damage before the next movement tick),
match generation and registration identity. Removing the tag invalidates an
in-progress cast, including a tag removed/re-added before the old cast resumes.
No per-enemy ancestry connections are created.

EnemyService.Summon has an optional final canContinue callback. Existing callers
remain compatible. Migrated summon groups check it before starting and after each
wait, stopping additional summons when the caster dies, loses its tag or its match
ends. Already spawned children remain ordinary enemies until their own removal.
The short-lived cast coroutine can remain suspended until its next wait wakes;
its cancellation predicate prevents additional gameplay work.

Tests: tests/attack-scheduler.luau runs with the actual MatchClock and a deferred
execution queue, checking cooldown/pause/speed changes, duplicate registration,
overlap suppression, tag removal, death before dispatch and match restart.
All game sources compile. These checks do not execute Roblox APIs or presentation.

Studio validation: import AttackService and Behaviors/Summon as ModuleScripts,
replace the old Necromancer Script (do not keep a second copy), and keep the
Necromancer tag on templates. Spawn a tagged Necromancer through EnemyService;
verify four summons and matching effects. Kill it/remove its tag during the group
spawn and confirm remaining children are cancelled. End/restart mid-cast, change
game speed mid-cooldown, pause and resume, and check no stale cast fires. Verify
other attacks continue unchanged. Scale-test with production assets before claiming
any performance target.

## MEU and Spawner follow-up

MEU and Spawner now register with the same AttackService. Their individual
Heartbeats and per-entity ancestry connections are removed.

- MEU: 8–9 game-second cooldown (SummonMin/Max overrides retained), three Summoned
  Armored Zombies, 1.18x health, 1x speed, Summon sound and MEU.Client effects.
  No extra AnimateEnemy event is introduced.
- Spawner: original math.random() initial stagger, then live EnemyStats.Cooldown
  in game seconds; three Spawned Armored Noobs, 2x health, 1x speed. No additional
  animation, sound or client effect is introduced. The initial stagger now follows
  simulation time, including pause, consistent with subsequent cooldowns.
- Summon now accepts optional animation, sound, client effect, first-cast delay
  and cooldown provider settings. Necromancer explicitly selects its existing
  MEU.Client effect, preserving its Studio-verified presentation.
- The Spawner branch in Summon.server is removed because the behavior calls
  Mob.Summon directly with a cancellation predicate. Keep SummonEnemy and the
  other branches: existing enemies still use that event.
- AttackService warns for missing runtimes or inactive/missing generations,
  instead of silently failing. It briefly waits for delayed runtime registration
  and ignores tagged templates outside workspace.

Studio update set (existing lifecycle modules and updated EnemyService required):
replace EnemyAttacks/MEU, Spawner, Necromancer, AttackService, Behaviors/Summon,
Simulation/AttackScheduler, and ServerScriptService/Summon. Keep one copy of each.
No new modules or events are introduced in this follow-up.

Test MEU for three children, correct health/speed and original effects. Test Spawner
for its short first stagger, three children and model-authored subsequent cooldown.
Kill/remove the caster tag during each group and end/restart the match; remaining
summons must stop. Change speed mid-cooldown and pause/resume. Recheck Necromancer
because the shared behavior gained optional presentation settings. Scheduler tests
cover first-cast delay and live cooldown reads; actual summons/visuals still require
Studio validation. This migration does not yet change MEU.Server health reduction
or the remaining client/server ability flows.

## Marksman migration

Marksman now uses Behaviors/Marksman, Targeting/NearestTower and the engine-independent
Simulation/AttackSequence. Its adapter replaces its standalone Heartbeat and ancestry
connections. Initial delay remains 5–8 game seconds. Targeting retains strict planar
distance <25 studs and excludes Flying flags; dead/Dying towers are now excluded too.
Damage is rounded 40% max tower health, or 50% with Death Wish, captured at attack start.
Windup is 2 game seconds and recovery 2; cooldown starts after completion (22–23).
Existing Fire animation, facing, Attack sound, Arrow remote and weapon hiding remain.

MatchService.Wait now optionally accepts a cancellation predicate. Death/tag removal
interrupt the sequence, while scheduler removal immediately releases movement/arrow
ownership even during a pause. Cleanup is idempotent. Target loss before impact applies
no damage and retries instead of permanently locking the attacker at infinite cooldown.
Movement restores OrigSpeed only if its speed is still zero, preserving another writer's
nonzero change. Overlapping zero-speed ownership from unrelated legacy systems remains
a limitation until movement modifiers are centralized.

A lethal committed hit starts match-scoped tower cleanup: the existing 0.5-second
presentation delay and 2-second TowerDeath delay are retained and adapt to speed.
TowerDeath.KillTower's optional cancellation predicate preserves other callers' behavior.
A caster dying after damage does not undo a committed kill; match end stops its delayed
cleanup. Facing currently uses the existing fixed-duration client protocol; matching
mid-animation speed changes perfectly requires the later presentation migration.

Studio update set: replace EnemyAttacks/Marksman, Simulation/AttackScheduler,
Simulation/MatchService and Main/TowerDeath. Add ModuleScripts Behaviors/Marksman,
Targeting/NearestTower (under a new Targeting Folder in EnemyAttacks), and
Simulation/AttackSequence. Keep existing summoner modules/adapters.

Verify nearest ground-tower selection, no flying/dead targeting, first delay, damage
with/without Death Wish, animation/sound/projectile and lethal tower removal. Kill or
untag Marksman during windup, sell its target, pause/resume, change timescale, and end
or restart the match during windup/recovery/death cleanup. No cancelled windup should
hit; a lost target should not permanently stop future attacks. Recheck all three
summoners because scheduler/Wait are shared. Cloud sequence tests cover cancellation,
target loss, exactly one impact, error cleanup and completion-based cooldowns; Roblox
behavior remains pending Studio validation. No stress-test performance claim is made.
