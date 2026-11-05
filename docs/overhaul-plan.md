# Simulation and presentation overhaul

## Baseline and scope

Starting checkout: e575c688404eedb75c8ef7d6125f9b524cd539d9.
91 Luau files, 32,013 source lines including blanks/comments; 26,037 nonblank.
All source compiled with Luau 0.745 before changes. No Studio performance baseline exists.
Goals: organized code, hundreds of towers/units, thousands of enemies, configurable
behaviors and presentation, clear selection UI, and complete match shutdown.
These are workload targets, not verified performance claims.

## Follow-up repository update

The subsequent upstream update supplied Main, Mob, Mine, Round, Unit, TowerServer,
TowerDeath and the ability scripts. They are now organized under Main; the path
module name is reconciled. The missing-source findings below describe the initial
audit and are resolved for source inspection. Studio assets remain unavailable.
See removal-and-layout.md for the current deployment hierarchy and removals.

## Findings from initial source inspection

- EnemySystem/EnemyService already uses a shared Heartbeat, dense runtime storage,
  throttled position updates, BulkMoveTo and compressed sync. Preserve these useful
  foundations and measure them before replacing them.
- EnemyService waits for sibling EnemyPaths, but the exported file is EnemyPath.luau.
  Reconcile the actual Studio instance name before changing import conventions.
- ServerScriptService/Main is absent. Summon and many attack scripts require its
  Mob and TowerDeath modules. Full tower combat, unit server simulation, wave
  orchestration and their connection to match state cannot be established here.
- EnemyService.Spawn and Summon only check Message == "GAME OVER" after waits.
  ArrowSpawn lacks that check. Stop disconnects movement only: it does not cancel
  queued spawning, dispose active entities or stop independent attack scripts.
- EnemyService.Damage accepts damageType but does not pass it to EnemyDamage.Damage.
  Define damage semantics and preserve existing defense behavior before migration.
- Movement uses dt * gameSpeed; status effects use os.clock deadlines. Attack code
  uses independent loops and task.delay(duration / speed), which cannot adapt a
  pending delay to subsequent speed changes. A shared simulation clock is needed.
- EnemyAttacks contains independent tag registrations, Heartbeats, loops and delayed
  attacks. Convert attack execution and cancellation together; module extraction
  alone does not reduce work or ensure shutdown.
- TowerRuntime, TowerStats, TowerAppearance and Cleanup exist. Keep compatibility
  with model Config until all readers/writers have migrated. Removing Value objects
  now would break the UI and attack scripts.
- GameController mixes placement, hover, upgrade UI, abilities and voting. Its render
  callback contains scene traversal. Separate controllers and cache candidates before
  tuning hover behavior; use two reusable local Highlights for selection and hover.
- UnitReplicator handles movement/rotation on clients; the matching server unit
  implementation is missing, so unit behavior migration needs that source.
- Cleanup previously skipped table resources added after disposal, skipped destruction
  of unparented Instances, and could abort disposal on an Instance/connection error.
  First implementation fixes those ownership defects without changing combat rules.

## Target boundaries

Server Simulation owns a match generation, simulation time, one scheduler, entity
registries, spatial index and damage service. A match ends by invalidating its
scheduled work before destroying entities and releasing match resources. A later
match receives a new generation, preventing old callbacks from affecting it.

Enemy, tower and unit services own authoritative state and explicit lifecycle hooks.
Definitions select reusable targeting, attack, base-interaction and death behaviors.
Damage types: None, Bullet, Fire, Laser, Energy initially; existing attacks retain
legacy damage semantics until each definition is explicitly migrated.

Clients own visual projectiles, cosmetic rigs, animation blending, attack/death VFX
and UI. Server messages carry entity IDs, sequence/generation, timestamps and visual
parameters. Visual completion never authorizes damage. Give presentation effects
bounded lifetimes, quality budgets and cleanup on removal or match end.

## Migration sequence and acceptance

1. Resource ownership: harden existing Cleanup and test idempotence, reverse disposal,
   late resources and reentrancy. Then introduce shared match scope/clock, with tests
   for speed changes, pause, callback cancellation, end and restart.
2. Reconcile missing Main sources and Studio instance mapping. Integrate match scope
   at real wave entry points and all spawn/summon APIs, then migrate attacks in small
   groups. Test ending a match during waits, summons, projectiles and boss phases.
3. Add spatial queries and typed damage pipeline; migrate one representative enemy
   and tower with behavioral parity checks before broad conversion.
4. Convert remaining enemy/tower behaviors, then units using the same lifecycle.
   Keep balance, target priority, payout, upgrades, immunities and collision semantics.
5. Split presentation/animation and UI controllers; add hover/selected outlines,
   consistent input handling and cleanup. Verify mouse, touch and gamepad in Studio.
6. Remove legacy Value bridges only after auditing all readers and writers.

## Validation

Cloud: compile every Luau source; run standalone lifecycle/scheduler/data tests.
These do not verify Roblox services, Instances, visual quality or gameplay.

Studio: capture MicroProfiler/server script timing, client frame timing, memory,
instance/connection counts and network traffic. Test 100/300/500 towers,
500/1,000/2,000 enemies and 100/300 units separately and together, including worst
case attack/VFX density. Select final budgets against a named low-end device,
player count and production assets. Initial candidate: 60 FPS desktop, 30 FPS low-end
mobile, subject to baseline measurement and product agreement.

Repeat spawn/despawn and full match restart cycles; memory and owned resource counts
must return near the warmed baseline without steady growth. Verify no spawn, damage
or attack callback from the ended match executes after shutdown. Compare gameplay
outcomes and visually review animations and UI. Do not describe scale targets as
achieved until these checks run with the original place.
