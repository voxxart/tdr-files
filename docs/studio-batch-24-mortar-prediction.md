# Batch 24: path-predictive mortar aiming

## Replace

- [ ] **ModuleScript** `ServerScriptService.TowerSystem.ProjectileService`

## Add

- [ ] **ModuleScript** `ServerScriptService.TowerSystem.ProjectilePrediction`

Keep all batch 23 client mortar/animation modules. No client update, new asset, event, or EnemyService replacement is needed.

## Behavior

CliffTower splash-projectile towers (the existing mortar branch) now lead their selected target along its actual cached path. The predictor snapshots authoritative EnemyRuntime Alpha, Speed, path, height, and lane offsets once per shot. It accounts for remaining spawn-emergence delay and known stun duration. Curves and reverse movement follow the path rather than a straight velocity extrapolation. Alpha is clamped at path endpoints.

It starts from the mortar's Barrel Attachment if present, otherwise Handle/root. Up to eight travel-time refinements account for the predicted point changing projectile travel distance. There are at most ten cached path samples per predicted shot, with early exit when the duration change is small. The fixed iteration limit keeps work bounded; extreme speeds or complicated paths are an approximation rather than a guaranteed intercept.

The chosen aim point and final duration are used for both the existing client rocket event and the scheduled server splash damage. The shot remains ballistic after launch: later speed changes, stuns, death, or path changes can still make it miss. Enemies reaching the base before impact may also evade the shot. Tower cancellation and match-end cancellation remain.

No enemy scans, per-frame prediction updates, new raycasts, or additional network messages are added. Existing server position mirrors do not limit prediction precision because it reads runtime progress directly. Unsupported targets without a usable path/runtime fall back to their current hitbox position.

## Toggle

`ProjectilePrediction.Enabled = true` at the top of the new module enables this feature. Set false before starting a new Studio play session for a global A/B comparison.

Optional **boolean attribute** `PredictProjectileTarget` on a tower's runtime `Config` overrides its default opt-in: false disables prediction for that tower, true enables it for another splash-projectile tower. The global module toggle still takes precedence. This uses an attribute, not a new BoolValue instance. Non-mortar splash towers otherwise retain their previous aiming and timing.

## Studio checks

1. Test fast enemies on straight segments and around tight corners at short and long mortar ranges. Compare hit rate with the global toggle on/off.
2. Watch the rocket endpoint and damage/explosion location; both must agree on the predicted point.
3. Test enemies stopped by stuns and newly emerging enemies. Test speed changes after launch and accept that a committed ballistic shot can miss them.
4. Change timescale and pause during flight. Keep the batch 23 client scripts installed so the visuals follow game-time flight progress.
5. Test an enemy near the base, a killed target, selling/upgrading the mortar, and match end while rockets are active. Confirm existing cancellation/reward behavior.
6. Test an ordinary non-mortar splash tower to confirm its existing aiming remains.

Automated tests cover curved/reverse paths, offsets, stale hitbox independence, stationary/stunned/emerging targets, endpoint clamping, bounded iterations, muzzle origin, shared visual/impact aim, game-time duration, opt-out, compatibility, and cancellation. Actual hit-rate improvement and network/visual alignment still require Studio testing.
