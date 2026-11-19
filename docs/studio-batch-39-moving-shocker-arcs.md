# Batch 39: animated Shocker electrical arcs

Replace together:

- [ ] **ModuleScript** `LightningBolt` — update the existing shared copy your game uses, using `ReplicatedStorage/GameModules/LightningBolt.luau` from this repository. Keep its PartCache dependencies in place.
- [ ] **LocalScript** `StarterPlayer.StarterPlayerScripts.Towers.Shocker`.

No new instances, events or assets need to be added manually. Restart the play session.

High VFX draws two independently seeded strands per chain link: electric blue and a thinner pale-blue strand. Sharper, larger bends change shape at up to 18 Hz, with continuous visibility between updates and a final fade. Low VFX uses a single strand with shape updates capped at 12 Hz. Endpoints remain at the shot's captured muzzle and enemy Hitbox positions. Server damage and chain targets are unchanged.

The shared lightning module adds opt-in `ShapeRefreshHz` (clamped to 24). Existing static effects such as Railgunner still default to zero refresh; ordinary animated lightning such as Reaper retains its behavior. Shocker retains its 768-part global client budget, endpoint validation and single cleanup loop. Refresh updates existing geometry, without recreating parts or bolts. Cached parts stay outside Workspace, retaining the rendering fixes.

Test chains on High/Low VFX, many simultaneous Shockers, and camera movement. Confirm the arcs shift without blinking, cleanup completes after each shot, and the earlier rendering issue stays resolved. Also verify Railgunner remains straight and Reaper retains its effect. Automated checks cover refresh rate limiting, geometry reuse, both strands and full-chain endpoints, part budgets, expiry and cleanup; the reference image's appearance requires Studio testing.
