# Match lifecycle foundation

Simulation/MatchClock is engine-independent. Begin returns a new generation;
Stop invalidates work and releases pending callback captures. Advance integrates
real dt * current speed, so existing deadlines adapt to speed changes and pause.
After returns a cancellation function. Callbacks must not yield; callbacks added
while dispatching are processed on a later tick. This initial delayed-job queue is
for match-level jobs, not one recurring job per entity; attacks will use a shared
entity scheduler in the next migration.

Simulation/MatchService binds the clock to Info.GameRunning, GameSpeed and terminal
Message values. Round begins explicitly; clients do not control the clock.
Capture the generation at the start of any yielding workflow, then use
Wait(generation, gameSeconds) and check its boolean result before performing work.
Never capture a fresh generation after a yield to revive an old workflow.

Migrated: round countdown/inter-wave waits, normal enemy spawning, arrow spawning
and summoned enemy group waits. Victory now clears GameRunning. Enemy runtimes
carry a generation and are removed without kill rewards on the next enemy tick
when that generation ends. Deferred Roblox signal handling is supplemented by
explicit Begin and direct terminal-state checks.

Not yet migrated: independent enemy attack timers, tower/unit combat, mines,
boss callbacks, status-effect timing, UI timers and existing wall-clock delays.
Those still require their own generation guards and scheduler integration. Do not
claim complete match shutdown or timescale consistency for the whole game yet.
EnemyService.Stop still only disconnects its own scheduler; match shutdown is
controlled through GameRunning/terminal message, not that low-level method.

Cloud checks: tests/match-clock.luau exercises speed changes, pause, cancellation,
stop during callback dispatch, restart invalidation and release of pending work.
tests/cleanup.luau covers resource ownership. Compile all game sources with Luau.

Studio checks still required: end during normal spawn cooldown, arrow countdown
and summon emergence; no later clone should register. Restart immediately while
an old spawn waits; it must not join the new match. Change speed during a spawn
wait, pause/resume and confirm game-time duration. Verify no kill rewards on
match cleanup, enemy count returns to zero, and victory rewards/badges still run.
Import Simulation as a Folder beside Main, EnemySystem and TowerSystem.
