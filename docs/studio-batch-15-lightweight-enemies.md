# Batch 15: lightweight ordinary enemies and local rigs

This is the first representation migration: ordinary enemies use small server proxies and client-created visuals while existing combat APIs stay compatible. It is not a full conversion to table-only entities.

## Replace

- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EnemyData`
- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EnemyAnimationBudget`
- [ ] **ModuleScript** — `ServerScriptService.EnemySystem.EnemyService`
- [ ] **ModuleScript** — `ServerScriptService.EnemyAttacks.Auras.RNG`
- [ ] **LocalScript** — `StarterPlayer.StarterPlayerScripts.EnemyRenderer` (`EnemyRenderer.client.luau`)

## Add

- [ ] **ModuleScript** — `ServerScriptService.EnemySystem.EnemyProxyFactory`
- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EnemyVisuals`

Install all seven together. **A new server with the old renderer will produce invisible lightweight enemies.** Keep the previous sync codec, Animations script, death-presentation modules, templates, and behavior systems. No new events or manually created folders are needed. Merge EnemyData's new settings while preserving your balance edits.

## Representation

For eligible enemies, the server creates an invisible HumanoidRootPart, an invisible Hitbox, a cloned EnemyStats folder, and existing top-level Value objects. The service adds its existing runtime metadata and compatibility Effects. It no longer clones their visible body parts, meshes, animation controllers, animation assets, accessories, or death-presentation assets into Workspace on the server.

Authoritative movement, health, targeting, damage, effects, base hits, IDs, and enemy counters continue through the existing runtime/proxy model. The same reliable spawn and bounded sync events are used, with no new per-shot messages.

Each client clones the visual rig from ReplicatedStorage.Mobs and attaches its visual children to the same proxy Model. The server root is renamed locally to EnemyProxyRoot; the local visual root becomes HumanoidRootPart/PrimaryPart for existing client animation, hover, sound, targeting presentation, and bullet-effect code. EnemyStats, Effects, Alpha, and Hitbox are retained from the server proxy rather than replaced with client copies. Original template assets are not modified.

Client construction has a shared budget of sixteen rigs per rendered frame. Excess work enters the renderer's existing retry queue. Waiting on that budget refreshes the retry deadline, while genuinely missing assets can still time out. A large late join fills in over several frames; at 5,000 rigs and 60 FPS the theoretical clone-budget minimum alone is about 5.2 seconds. Actual loading and frame time can make it longer. Existing sync corrects recovered movement; inspect first appearance/corrections under latency in Studio.

Duplicate registration does not clone another rig. Removal and match-end cleanup destroy locally attached children explicitly. Rebuilding restores the replicated root and attaches a fresh visual rig. The animation budget updates its bounds when the visual becomes ready and can start Walk after the initial animation-asset retry has expired.

## Initial eligibility and fallback

`EnemyData.Settings.LightweightEnemies` initially opts in these exact template names:

```luau
LightweightEnemies = {
    Noob = true,
    Zombie = true,
    ["Armored Noob"] = true,
    ["Armored Zombie"] = true,
},
ClientRigBuildsPerFrame = 16,
```

A template must have EnemyStats, a distinct BasePart Hitbox, and a BasePart HumanoidRootPart as its primary root. Any CollectionService tag on the model or descendants, embedded Script/LocalScript, ObjectValue reference, or IsFinalBoss marker causes full-model fallback. Template checks are cached for the running session; restart Play after structural asset edits.

This keeps tagged attacks, boss code, transformations, and unsupported custom references on their existing full-model path. Unlisted enemy names also retain their full models. Do not opt arbitrary bosses or custom attack rigs into the list without auditing their server-side body/attachment dependencies. If all opted-in templates carry excluded tags/scripts, diagnostics will correctly report zero proxies; inspect those assets before assuming the new mode is active.

The RNG aura now creates a temporary attachment on a proxy's authoritative Hitbox when Torso.Center is unavailable. Its beam and invincibility effect still function, and the temporary attachment is cleaned up. That proxy beam endpoint follows the existing coarse server hitbox updates; check its appearance in Studio.

## Diagnostics and rollback

In the server command bar during Play:

```luau
print(require(game.ServerScriptService.EnemySystem.EnemyService).GetDiagnostics())
```

`LightweightEnemies` reports how many live runtimes actually use proxies. Compare it with ActiveEnemies and inspect a Noob in the **server** explorer: it should have two physical parts and gameplay metadata, while the **client** explorer shows its local visual children too.

Disable an entry or set `LightweightEnemies = {}` to restore full models for newly spawned enemies. Already spawned proxies retain their local visuals until removal. The client renderer supports a mixture of full and lightweight enemies. To remove this migration entirely, revert the complete batch together.

## Studio test

- [ ] Spawn all four opted-in types. Verify server proxy count and reduced descendant count, and confirm each client still sees the complete, correctly positioned rig.
- [ ] Confirm health/armor/shields, hidden/flying/lead filters where applicable, tower targeting, unit ramming, mines, explosions, slows, burn, bleed, base damage, and rewards work against proxies.
- [ ] Check enemy hover cards, bullet endpoints, beams, sounds, walking/attack animation setup, and screen-visibility budgeting. Test equipped/customized template geometry and pivots.
- [ ] Apply RNG protection to a lightweight enemy and confirm its shield, beam, invincibility, and cleanup.
- [ ] Test Necromancer summons and a representative boss/attacker/aura mix. Verify tagged/scripted enemies retain full models and their custom behaviors.
- [ ] Join a second client mid-wave, add network latency, and test StreamingEnabled if used. Look for invisible enemies, missing animations, duplicated visual children, and large first-position corrections.
- [ ] Spawn a large burst. Confirm rig construction is spread across frames and budgeted proxies eventually become visible rather than expiring from the queue.
- [ ] End/restart matches repeatedly and compare server/client instance counts and memory after cleanup.
- [ ] A/B test the four names enabled versus disabled at 250, 1,000, and higher ordinary-enemy counts. Compare server spawn time, server memory, replicated instance traffic, and client frame time. Record client rig-creation spikes and steady-state costs separately.

## Validation and remaining work

All 177 game Luau files compile. Twenty-one Luau tests and thirteen Python fixtures pass. Tests execute the proxy factory and visual attachment code, plus the actual enemy service with 5,000 synthetic proxies, covering reduced topology, preserved stats, fallback, rig attachment/detachment, construction budget, aura attachment cleanup, damage/effects, targeting, and match cleanup against mocked engine boundaries.

Actual engine replication order, rig welding, Motor6Ds, UI hooks, asset pivots, and appearance require Studio testing. Templates remain in ReplicatedStorage; clients still hold full visible rigs, and server proxies still replicate compatibility Values, roots, and hitboxes. The existing full-enemy sync volume is unchanged. This batch reduces live server rig representation for the safe initial set; table-only entities, broader behavior migration, and selective network updates remain separate work. It does not establish a lag-free capacity guarantee.
