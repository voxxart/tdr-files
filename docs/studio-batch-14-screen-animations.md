# Batch 14: screen-based enemy animation and pooled deaths

## Replace

- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EnemyData`
- [ ] **LocalScript** — `StarterPlayer.StarterPlayerScripts.Animations` (`Animations.client.luau`)
- [ ] **LocalScript** — `StarterPlayer.StarterPlayerScripts.EnemyDeath` (`EnemyDeath.client.luau`)

## Add

- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.ScreenVisibility`
- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EnemyAnimationBudget`
- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EnemyDeathPool`

Install all six together. No new events, folders, or enemy assets need manual setup. EnemyData only gains performance settings; preserve your balance edits when merging. Keep previous EnemyRenderer, EnemyService, behavior modules, and sync codec.

## Live enemy animations

Animation visibility uses the camera frustum and a conservative bounding sphere, not distance. A 48-pixel margin keeps enemies animating at screen edges and reduces toggling. Bounds overlapping the frustum remain active even if their root is outside the screen. This does not perform wall/occlusion raycasts; enemies behind scenery but within the screen frustum still animate.

Off-screen enemy tracks are stopped, rather than left playing at speed zero. Newly encountered off-screen enemies defer animation loading/playback. The budget remembers game-time progress and the latest animation request. When a model returns on screen, loops resume at their current phase, current one-shot attacks seek forward, and expired attacks fall back to Walk/Walk2. Explicit stop requests are not resurrected. Global pause and per-model pause are excluded from virtual progress. Missing or delayed assets still use the existing bounded retry logic.

One shared update checks up to 1,024 models per rendered frame in rotation. At 5,000 tracked enemies, a full visibility sweep takes five frames; edge margin helps hide that delay during ordinary camera motion. Very fast pans or low frame rates can still reveal the bounded check latency. Increase the check budget if needed after measuring cost.

The budget applies to normal live enemies in Workspace.Mobs, not towers or units. Existing distance-based movement update rates remain independent. Server movement, attacks, damage, and timers continue off screen. Cosmetic animation markers skipped off screen are not replayed as a burst. Animation speed is now applied after Play, avoiding Play's default speed overriding pause or timescale.

## Death presentation

Client death rigs and lightweight effect anchors are reused, with a global cap of 48 allocated resources and six accepted new presentations per frame. Off-screen deaths skip cosmetic presentation. Over-budget deaths also skip visuals; server death behaviors, damage, rewards, and counters are unaffected.

Resources are pooled by enemy template. If all cached capacity belongs to another template, an idle resource is evicted to make room. Reuse stops tracks/sounds, clears particles, restores captured Motor6D transforms, and repositions the rig. Gameplay stats, hitboxes, and embedded Script/LocalScript descendants are stripped from corpse clones. Corpse animation tracks are loaded once per pooled rig, rather than once per death.

DeathEffects retains its Animations, Sounds, Particles, and Duration setup. Up to eight assets per category are used, sorted by Name for deterministic variant selection. A single sound and animation variant are selected using the enemy ID. Particle requests are capped at 100 per emitter and 200 total per death by default. Low VFX reduces acceptance rate and total particles to 50 per effect. Complex assets can still be expensive within these limits.

Death lifetime uses game seconds, clamped to 0.05–15 seconds. Pause freezes expiration and track/sound playback. Corpse animation stops if it leaves the screen and seeks forward if it re-enters before expiry. Particle TimeScale follows game speed up to the engine's supported maximum of 1; cleanup still uses game time at faster speeds. Match end clears active presentation, and script destruction destroys cached resources and disconnects owned listeners.

Idle pooled resources stay unparented and retain some memory for reuse. An empty match can therefore retain up to 48 cached resources; a stable retained pool is different from memory growing on every spawn/death cycle. Restarting/replacing the LocalScript destroys the pool.

## Settings

In `EnemyData.Settings`:

| Setting | Default | Meaning |
| --- | --- | --- |
| AnimationVisibilityChecksPerFrame | 1024 | Maximum model visibility checks per frame |
| AnimationScreenMargin | 48 | Extra pixels around camera edges |
| MaxDeathPresentations | 48 | Maximum allocated rigs/anchors, including idle resources |
| DeathPresentationsPerFrame | 6 | Maximum newly accepted death presentations per frame |
| DeathParticlesPerEffect | 200 | Total emitted particles per accepted High VFX death |

## Studio tests

- [ ] Watch a walking wave and pan away/back. Verify on-screen animation is smooth and re-entry does not visibly restart every walk at frame zero.
- [ ] Check partial visibility at each screen edge, large enemies, near-camera enemies, and a fast camera pan. Tune margin/check budget if transitions are noticeable.
- [ ] Pan away during attacks, summons, transformations, and boss/Reaper abilities; return during and after the animation. Confirm current state is shown and expired attacks do not replay.
- [ ] Pause/resume and change speed while enemies are on/off screen. Test explicit animation pause/resume and stop events.
- [ ] Confirm off-screen enemies continue moving, attacking, damaging the base, and dying on the server.
- [ ] Kill enemies with custom death animations/sounds/particles. Repeat the same enemy type to verify reused rigs do not inherit a previous pose, sound, or particles.
- [ ] Kill a large group simultaneously. Confirm bounded visual work, no output errors, and correct server rewards/counts even when some effects are skipped.
- [ ] Pan away/back during a corpse animation. Pause during death; verify lifetime and animation resume consistently.
- [ ] End/restart matches repeatedly with live enemies and corpses. Track object counts and memory after cleanup; cached resources should stabilize within the cap.
- [ ] Test High/Low VFX, equipped enemy appearances/custom rigs, and templates with missing animation controllers or optional assets.
- [ ] Profile representative battles with 1,000–5,000 enemies while looking at the wave, looking away, and during mass deaths. Compare client frame time, animation cost, and memory. Test a lower-powered client too.

## Automated validation and limits

All 175 game Luau files compile. Twenty-one Luau tests and twelve Python fixtures pass. New checks execute the actual visibility/budget/pool modules and death presentation script with engine mocks, covering screen bounds, stopped off-screen tracks, loop/attack timing, pause, explicit stops, bounded allocation, 10,000 burst attempts, cross-template eviction, rig reuse, particle limits, script stripping, and cleanup.

These checks do not execute Roblox's Animator, Motor6Ds, animation markers, sound engine, or GPU. Actual animation blending, pose restoration, asset loading, and performance require the Studio tests above. Detailed live enemy models still replicate, and the full animation cache remains for enemies that have been visible. This is a client animation/effect budget batch, not the later lightweight server entity or network interest-management migration.
