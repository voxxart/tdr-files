# Studio batch 06: tower combat core

Prerequisite: working boss batch plus Noobicus correction (7d1de9a), with the existing
TowerRuntime, Cleanup, EnemyRuntime and match lifecycle modules installed. Back up
Studio first. This is the core combat stage; support abilities and special tower
systems remain compatibility helpers, not a completed rewrite of every tower.

## Replace two ModuleScripts

| Location | Type |
| --- | --- |
| ServerScriptService.Main.TowerServer | ModuleScript |
| ServerScriptService.TowerSystem.TowerStats | ModuleScript |

## Add ten ModuleScripts and one LocalScript

| Location | Type |
| --- | --- |
| ReplicatedStorage.GameModules.CombatProfiles | ModuleScript |
| ServerScriptService.Simulation.SpatialIndex | ModuleScript |
| ServerScriptService.Simulation.TargetPolicy | ModuleScript |
| ServerScriptService.TowerSystem.Targeting | ModuleScript |
| ServerScriptService.TowerSystem.CombatScheduler | ModuleScript |
| ServerScriptService.TowerSystem.PrimaryAttack | ModuleScript |
| ServerScriptService.TowerSystem.SecondaryAttack | ModuleScript |
| ServerScriptService.TowerSystem.BurstAttack | ModuleScript |
| ServerScriptService.TowerSystem.DirectDamage | ModuleScript |
| ServerScriptService.TowerSystem.ProjectileService | ModuleScript |
| StarterPlayer.StarterPlayerScripts.TowerPresentation | LocalScript |

No new folders are required. TowerPresentation RemoteEvent is created automatically
inside ReplicatedStorage.Events by SecondaryAttack. Do not manually add another event
with that name, and do not remove existing animation/projectile events.

## What changed

- TowerServer delegates targeting, primary/secondary combat, bursts, projectile
  impacts and the shared scheduler through module interfaces. Its specialized
  functions, placement/upgrade/sell handlers and existing remote APIs are retained.
- A planar spatial index updates once per Heartbeat when queried, shared by all
  towers. In-cell movement reuses records; despawned entries are released. Infinite
  or extremely large queries fall back to scanning registered candidates. Only
  authoritative EnemyRuntime models directly under Mobs are indexed; preview
  arrows under Arrows are excluded as before.
- First/Last use authoritative runtime Alpha rather than throttled legacy Alpha.
  Near/Strong/Weak, hidden/flying detection and Beamer minimum health filters remain.
  Aggro presence still has priority. Aviators prioritize flying enemies after
  aggro; this resolves an earlier iteration-order ambiguity. Equal-priority ties
  remain unspecified. Dead enemies cannot be selected for new shots.
- Normal and burst cooldowns, secondary burst waits and splash projectile travel
  use the match clock. Ended generations cannot continue these attack paths.
  Pause blocks new combat; sale, tower death or teardown cancels owned projectiles.
- Each primary/secondary/burst path has a busy guard and error reporting so a
  yielding helper cannot start an overlapping duplicate or silently lock a burst.
- Basic direct hits use DirectDamage for defense and shield/health writes. Health
  and shields clamp at zero; shield-breaking damage does not spill into health.
  Cash/TotalDamage counter conventions are preserved rather than rebalanced.
- Secondary laser Part creation moves to the client. The server still commits
  damage and broadcasts the short presentation event. Laser visuals remain 0.08s.

## Customization

CombatProfiles contains defaults by canonical tower name and valid damage type
names (None, Bullet, Fire, Laser, Energy, Melee, Explosion). Unknown/support towers
use None. TowerData Stats.DamageType and upgrade DamageType fields override defaults
through the existing TowerStats config application; Config.DamageType is a StringValue.
These are classifications, not newly invented elemental resistance rules. Ordinary
DirectDamage hits record LastDamageType in EnemyRuntime. Specialized splash/DOT/
ability paths have not yet been unified into this damage service.

Existing ProjectileSpeed continues to work. Optional TowerData Stats fields:

```luau
DamageType = "Explosion",
Projectile = {
    Speed = 60,          -- studs per game second; overrides ProjectileSpeed
    MinTravelTime = 0.05,
},
```

Splash shots retain a fixed aim point and current-at-impact tower damage stats,
matching the previous behavior. They can miss a moving enemy; the original projectile
VFX event remains. Its supplied duration is estimated using launch-time speed:
server impact deadlines adapt to subsequent speed changes, but existing clients
still use fixed-duration presentation. Full adaptive projectile visuals/death
animation definitions are separate upcoming presentation work.

## Combined Studio validation

1. Normal shooter (Trooper/Marksman): placement, five target modes, detection,
   shields, defense, cash rewards, ammo/reload, upgrades, sale and tower death.
2. Burst shooter: one burst at a time, shot spacing and post-burst delay; upgrade,
   stun, sale and game over during a burst. Busy state must always release.
3. Splash tower (Demolitionist/Mortar): fixed aim point, travel time with distance,
   splash radius, moving-enemy misses, speed change mid-flight and cancellation
   after sale/death/game over. Check optional projectile profile settings.
4. Secondary Rocket/Laser/AOE and in-place upgrade unlocking Secondary: targeting,
   delay/burst count, damage and effects. Use a multiplayer test for client lasers.
5. Aviator/Helicopter: movement, flying priority and secondary attacks; pause/resume.
6. Beamer/Phaser, Flamethrower, Shocker, shotgun, Cowboy/reward towers, corruption,
   Reaper summoning and active abilities: parity smoke test of retained helpers.
7. Support/farm/tree/medic/spawner/mine/scrambler: placement/upgrades/sale still work.
   Their independent loops are not yet migrated by this batch.
8. End/restart while combat and projectiles run. No migrated old-generation attacks
   should damage enemies in a new match. Check Output for module wiring errors.
9. Stress test with production assets and compare server time, client frame time,
   network traffic and memory to baseline; cloud density tests are not Studio FPS.

## Remaining scope and verification limits

Support loops, Phaser phase deadlines, legacy stun timing, some DOT and ability
callbacks still use existing wall-time/Value bridges. This batch does not claim
complete match shutdown or timescale consistency for those paths. Specialized
helpers retain some scans and server effects. All tower damage/resistance rules,
client projectile/animation retiming, custom death presentation and support-system
ownership need subsequent migration. It is not yet a demonstrated hundreds-of-towers
performance result, and the unit-system overhaul has not begun.

Cloud: 14 Luau test files pass plus the Python-run tower integration fixture.
All 142 game files compile. Spatial queries match a brute-force oracle, including
negative cells, boundaries, removal and unbounded range. A 5,000-entry density
fixture yields 29 local candidates for its representative query. The integration
fixture executes actual primary/secondary/burst/scheduler/projectile modules with
simulated dependencies to check damage/cash/shields, overlap, pause, cancellation
and bounded projectile cleanup. It does not simulate Roblox physics, replication,
models, animation or UI, and Studio parity validation remains required.

## Pregame placement correction

Towers placed during preparation (generation zero) now stay registered without
executing combat. When the first match begins they bind once to its generation.
Ended-match towers still deregister and cannot attach to a later match. Update
Main.TowerServer and TowerSystem.CombatScheduler for this correction. Integration
checks cover preparation, enrollment, match end and prevention of later re-enrollment.
Fresh placement also initializes HealthValue from module MaxHealth rather than
copying a potentially zero template health value.
