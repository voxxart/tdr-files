# Batch 23: tower idle recovery and mortar flights

Install all four scripts together.

## Replace

- [ ] **LocalScript** `StarterPlayer.StarterPlayerScripts.Animations`

## Add

- [ ] **ModuleScript** `ReplicatedStorage.GameModules.TowerIdleRecovery`
- [ ] **ModuleScript** `ReplicatedStorage.GameModules.ProjectileArc`
- [ ] **ModuleScript** `ReplicatedStorage.GameModules.MortarFlights`

No new events or assets are required. Existing Rocket, Explosion, and tower animation assets remain in use.

## Idle reliability

The existing latest-request retry slot could let an early attack replace a pending Idle request. It also stopped retrying a missing Idle after five seconds. Idle recovery is now independent: a shared round-robin worker checks at most 16 towers per frame, at most once every half second per tower. It keeps trying while a tower remains registered, without creating per-tower threads or connections.

Tower Idle tracks are explicitly looped at Idle priority. Tower attacks authored at Core priority are promoted to Action, so the base idle does not cover the attack. Higher authored priorities are preserved. Existing playing idle tracks are not restarted by the worker. Reaper summon locks and dead/removed towers are respected. Folder/controller replacement and level/source changes continue to use the existing track invalidation. AnimationController and Humanoid rigs are supported.

This addresses timing/retry failures; it cannot make a missing, invalid, or unauthorized Roblox animation asset playable. Check Client Output for asset-load errors if a specific tower still fails.

## Mortar presentation

Mortars use the existing Rocket template. Launch starts at `Weapon.Handle.Barrel` when it is an Attachment, otherwise at Handle. Arc height now scales with horizontal distance and elevation difference rather than always being six studs with a ten-stud ceiling.

A 64-segment arc-length table maps elapsed flight progress to distance along the curve. Analytic tangents and a stable trajectory-plane up vector keep the nose aligned through the apex and steep descents. Nearly vertical/zero-distance paths get a small lateral bend scaled to the trajectory, avoiding a stationary flip at the apex. Arbitrary random roll is removed.

Optional overrides:

- **NumberValue** `tower.Config.Projectile.ArcHeight`, or a numeric **attribute** `ArcHeight` on the Rocket template: additive arc height in studs above the straight launch-to-target interpolation. There is no old ten-stud clamp.
- **CFrame attribute** `FrontOffset` on the Rocket template: correct its authored forward axis if the tip does not point along local -Z. Default is identity.

A single shared frame update batches all rocket part transforms with BulkMoveTo. Limits are 128 active flights and 16 rocket builds between frames; excess visual launches are skipped, while server damage still resolves. Both BasePart and Model rocket templates work, and cloned scripts are stripped. Rocket geometry is anchored/noncolliding/nonqueryable/nontouching.

The server-provided launch duration is converted back to game seconds at receipt; subsequent pause and timescale changes affect flight progress. Impact presentation occurs when the shared flight reaches its endpoint, replacing the mortar's separate real-time task.delay. Match end clears flights without impact effects. Script destruction disconnects the shared update and clears flights. Server targeting, damage, and travel-duration calculation are unchanged. Normal non-mortar splash grenades retain their existing presentation.

## Studio tests

1. Place towers immediately before wave one and during an active wave. Confirm Idle starts, including towers that attack immediately.
2. Place many towers rapidly and upgrade in place. Confirm correct per-level Idle, no repeated frame-zero resets, and attacks still override the base idle.
3. Test Reaper summon abilities and their return to idle. Check pause, game-speed changes, selling, death, and match end.
4. Test mortar shots at short/long range and at targets well above/below launch height. Watch the rocket nose at the apex and landing.
5. Pause or change game speed during a flight. Check that the rocket and impact presentation track the expected travel time.
6. Check the Rocket template's forward axis; set FrontOffset if needed. Test both a Part rocket and a multi-part Model if your installation uses them.
7. End the match during a volley. Confirm no rockets or deferred mortar impacts remain. Stress-test many mortars for client frame cost and visual caps.

Automated fixtures cover late/interrupted idle recovery, cast guards, bounded checking, trajectory endpoints/orientation/near-uniform step distances across near/far/steep/vertical paths, flight pause, active/build limits, impact-once, and clearing. Final rig animation blending, model axes, game-speed/network timing, and visual tuning require Studio testing.
