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
