# Batch 08: centralized units

Install the complete batch before pressing Play. Keep the previously installed enemy, tower, support, and Simulation modules. Existing unit models, stats, animation assets, and attack events remain in use.

## Replace existing scripts

- [ ] **ModuleScript** — `ServerScriptService.Main.Unit`
- [ ] **LocalScript** — `StarterPlayer.StarterPlayerScripts.UnitReplicator`
- [ ] **LocalScript** — `StarterPlayer.StarterPlayerScripts.UnitDeath`

`Main.Unit` is now a compatibility entry point. Replace its entire contents; do not leave the old movement, attack, or collision loops running elsewhere.

## Add new objects

- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.UnitDefinitions`
- [ ] **ModuleScript** — `ServerScriptService.Simulation.UnitMotion`
- [ ] **Folder** — `ServerScriptService.UnitSystem`
- [ ] **ModuleScript** — `ServerScriptService.UnitSystem.Runtime`
- [ ] **ModuleScript** — `ServerScriptService.UnitSystem.Paths`
- [ ] **ModuleScript** — `ServerScriptService.UnitSystem.Behaviors`
- [ ] **ModuleScript** — `ServerScriptService.UnitSystem.Targeting`
- [ ] **ModuleScript** — `ServerScriptService.UnitSystem.Damage`
- [ ] **ModuleScript** — `ServerScriptService.UnitSystem.Combat`
- [ ] **ModuleScript** — `ServerScriptService.UnitSystem.Death`
- [ ] **ModuleScript** — `ServerScriptService.UnitSystem.Service`
- [ ] **ModuleScript** — `ServerScriptService.UnitSystem.Spawner`
- [ ] **LocalScript** — `StarterPlayer.StarterPlayerScripts.UnitPresentation`

These are 11 new ModuleScripts, one new LocalScript, and one new Folder, plus the three replacements above. Repository filenames ending in `.client.luau` become LocalScripts with the extension removed in Studio. Other new `.luau` files become ModuleScripts.

`ReplicatedStorage.Events.UnitPresentation` (**RemoteEvent**) and `UnitSnapshot` (**RemoteFunction**) are created automatically. Do not create duplicate events. Keep the existing `ReplicateUnit`, `AnimateUnit`, `AnimateUnit2`, `UnitStopAttack`, `RotateUnit`, `RotateTorso`, and `UnitDeath` events.

## What changed

One server Heartbeat owns unit movement, combat, contact damage, and removal. Hitboxes move in batches at a default 30 Hz; legacy Alpha values mirror at 10 Hz. Units share sampled paths and use the existing enemy spatial index for targeting and collision candidates. Primary and secondary attacks use match time rather than separate unit attack coroutines. Pause freezes movement, attacks, contact damage, and corpse retention.

One client render loop interpolates live unit models and shares path samples. Startup snapshots register units already present when a client joins. Explosion models, tweens, particles, and sounds now run on clients. The server retains authority over damage and match state.

EnemyService owns enemy death and counting. Unit attacks no longer manually destroy enemies or decrement their counters; this also allows enemy death behaviors to run consistently. Unit removal updates its own counter once. Pending spawns cancel when their match ends, and live units and retained corpses are cleared. Selling a spawner prevents future spawns without removing units it already produced.

Existing reciprocal ram rules remain: enemy damage uses the unit's pre-impact HP and unit damage uses the enemy's pre-impact HP. Invincible enemies take no ram damage and cost the unit 5000 HP. Secondary attacks apply ExplosionDefense once. Damage credit and cash use actual damage, including shields. Existing model health and speed scaling is retained.

## Customization

`UnitDefinitions.Units` is keyed by the exact unit model name. Empty definitions preserve model Config/EnemyStats defaults. Supported overrides are:

| Setting | Purpose |
| --- | --- |
| `Attacks`, `NoStop` | Enable attacks and attack while moving |
| `DamageType`, `SecondaryDamageType`, `RamDamageType` | Damage classifications; this does not add elemental resistances |
| `RamRange` | Contact search radius |
| `EndBehavior` | `Despawn` (default), `Death`, `Loop`, or a registered custom behavior |
| `Primary.Damage`, `.Range`, `.Cooldown` | Primary attack overrides |
| `Primary.AOERadius`, `.PostAttackHold` | Splash radius and post-shot movement hold |
| `Death.Animation`, `.Duration`, `.Animate` | Death animation asset name, retention in game seconds, animation enablement |
| `Death.Explode`, `.ExplosionRadius` | Explosion enablement and visual size |
| `Death.SplashFraction`, `.SplashRadius`, `.SplashOnRamOnly` | Gameplay splash; defaults are 15% max HP, 3.5 studs, ram deaths only |
| `Death.Behavior` | Key in the server death-hook registry |

For example, add this inside `Units`, replacing the name with an existing model:

```luau
['Your Unit'] = {
    NoStop = true,
    DamageType = 'Bullet',
    EndBehavior = 'Despawn',
    Primary = {Range = 18, Cooldown = 0.5},
    Death = {Animation = 'Death', Duration = 4},
},
```

Animated corpses still require the model's existing `DeathEffects` Folder and animation assets. `Animate = false` skips corpse retention. Explosion visuals and gameplay splash are separate; `SplashOnRamOnly = false` enables splash on ordinary deaths too when explosions are enabled.

Register custom hooks in `UnitSystem.Behaviors`. Hooks must not yield. An end hook receives `Model`, `Map`, `Definition`, `Position`, `Finish(died)`, and `Reset(alpha)`. It must call Finish or Reset; otherwise the service despawns the unit. A death hook receives Model and Position and runs once before standard death handling. Use client presentation scripts for custom visual effects.

Existing model stat Value objects remain for compatibility. This batch does not require converting unit assets or deleting their flags. Paths are cached for each match generation; changing waypoint geometry during a match does not rebuild the cache.

## Bulk Studio test

- [ ] Spawn ordinary contact units; confirm lane selection, travel, reciprocal ram damage, and path-end removal.
- [ ] Spawn stopping ranged units and NoStop units; confirm firing, facing, torso return, and movement recovery.
- [ ] Test primary splash and secondary attacks against shielded, defended, flying, lead, and invincible enemies.
- [ ] Confirm owner tower damage credit, targeting modes, cash rewards, enemy death effects, and counters. Kill an enemy with a unit and verify its death/count occurs once.
- [ ] Test a unit with death animations and a unit with explosion effects. Confirm the corpse stays at the death location and only the intended deaths cause splash damage.
- [ ] Test pause, resume, and speed changes during firing, movement, and death animation. No damage or spawns should occur while paused.
- [ ] End a match with live units and pending spawns; confirm cleanup and no continued spawning. Start another match and check for stale units or paths.
- [ ] Sell a spawning tower during its spawn delay; confirm cancellation and survival of already spawned units.
- [ ] Join with a second client while units are already moving. Confirm snapshot registration and no duplicate movement or effects.
- [ ] Test optional Loop/Death path-end settings and a custom death animation using a copied unit definition.
- [ ] Profile 100 then 300 mixed units with enemies present, checking server frame time, client frame time, memory, and network traffic. Repeat spawn/death cycles to check that memory settles.

Streaming, actual Bezier/rig geometry, animation timing, custom assets, and device performance require Studio validation. The startup snapshot does not implement a general retry system for models streamed in later. Some cosmetic particle/audio lifetimes still use real time. No lag-free capacity claim has been measured.

## Automated validation

All 163 game Luau files compile. Sixteen Luau test files and four integration fixtures pass. Unit fixtures execute the actual service, combat, damage, death, and renderer code with mocked Roblox boundaries, covering movement, pause/speed, snapshots, cleanup, path endings, damage/shields, ram, ownership, and shared client path caching. These checks do not run the Roblox engine or benchmark frame rate.
