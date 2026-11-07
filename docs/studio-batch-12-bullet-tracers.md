# Batch 12: pooled client bullet tracers

## Add in Studio

- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.BulletTracers`
- [ ] **LocalScript** — `StarterPlayer.StarterPlayerScripts.TowerBullets` (`TowerBullets.client.luau`)

No existing game scripts, remotes, tower templates, or damage logic need replacing. Keep the existing CombatProfiles module and AnimateTower event.

## Behavior

Primary Attack animation events produce a moving warm-white bullet for towers whose resolved damage type is `Bullet`. The source is `Weapon.Handle` (lowercase `weapon` also supported). If that Handle contains a **Barrel Attachment**, its WorldPosition is used instead. Otherwise the bullet starts at Handle.Position. Missing weapons/handles skip the cosmetic without affecting gameplay. Upgrades that replace Weapon/Handle invalidate the cached muzzle automatically.

Bullets travel toward the enemy's rendered HumanoidRootPart/PrimaryPart, with Hitbox as a fallback. The endpoint is captured when the event arrives. Tracers do not home, collide, raycast, or apply damage. Existing muzzle flashes, animations, and sounds continue. This batch adds bullets to primary Attack events, not secondary rocket attacks or unit attacks.

All cosmetics run locally using the existing attack event, with no additional network messages. One shared RenderStepped loop moves pooled anchored parts in one BulkMoveTo batch per frame. There are no per-bullet tasks, tweens, event connections, or server projectile instances. Parts are reused after flight and retained within a fixed allocation limit. They cannot collide, touch, query, or cast shadows.

GameSpeed controls flight and pause; match end clears active tracers. The Low VFX setting reduces the emission budget. Script removal disconnects listeners and destroys the local pool.

## Budgets and appearance

Edit `BulletTracers.Settings`:

| Setting | Default | Meaning |
| --- | --- | --- |
| MaxActive | 256 | Maximum allocated/live tracer parts per client |
| ShotsPerSecond | 1200 | Real-time emission budget, divided by four on Low VFX |
| Burst | 64 | Maximum stored emission tokens |
| Speed | 500 | Nominal flight speed in studs per game second |
| Length | 1.8 | Maximum visible bullet length |
| Width | 0.09 | Bullet thickness |
| MaxDistance | 350 | Maximum camera-to-muzzle distance for rendering |

Flight duration is clamped to 0.05–0.5 game seconds for visibility and bounded lifetime. Very high attack rates or a full pool skip extra visuals; authoritative attacks and damage continue normally. These are visual budgets, not a promise to display every shot under arbitrary load. Existing animation and sound systems still have their own costs.

## Test

- [ ] Trooper, Heavy, Marksman, and another Bullet tower emit moving bullets from their handles. Add a Barrel Attachment if the exact barrel tip needs adjustment.
- [ ] Fire, Laser, Energy, Melee, and Explosion towers produce no new bullet tracers unless explicitly assigned Bullet.
- [ ] Upgrade a firing tower and confirm its new weapon is used. Test equipped appearances with different weapon geometry.
- [ ] Confirm firing and damage remain correct when the target dies, a tower is sold, or a model lacks Handle.
- [ ] Pause/resume, change speed, and end/restart the match. No bullets should continue spawning after match end.
- [ ] Test High/Low VFX and distant towers. Verify reduced visuals do not reduce damage.
- [ ] Profile a dense fight with hundreds of towers on server and client. Check part count stays bounded, network traffic has no extra per-shot event, and repeated fights do not accumulate tracer parts or callbacks.

Automated checks execute the actual pool and client listener with engine mocks. They cover bounded allocation during 48,000 synthetic emissions, reuse, batch movement, pause, Low VFX, damage-type filtering, weapon replacement, distance culling, and cleanup. Actual rig geometry, visual appearance, and performance need Studio validation.
