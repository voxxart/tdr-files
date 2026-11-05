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
