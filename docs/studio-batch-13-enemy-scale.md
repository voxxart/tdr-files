# Batch 13: enemy scale foundations

Install this entire batch together before Play. The EnemySync wire format changes, so old and new server/client files must not be mixed.

## Replace

- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EnemyData`
- [ ] **ModuleScript** — `ServerScriptService.EnemySystem.EnemyService`
- [ ] **ModuleScript** — `ServerScriptService.EnemySystem.EnemyEffects`
- [ ] **ModuleScript** — `ServerScriptService.TowerSystem.Targeting`
- [ ] **LocalScript** — `StarterPlayer.StarterPlayerScripts.EnemyRenderer` (`EnemyRenderer.client.luau`)

## Add

- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EnemySyncCodec`
- [ ] **ModuleScript** — `ServerScriptService.EnemySystem.LegacyEffects`

No new RemoteEvent, RemoteFunction, Folder, or model asset is required. Existing ReplicateMob, RotateMob, and EnemySync events stay. Existing enemy behavior/attack modules stay. EnemyData changes only add performance settings and update a comment; preserve your own enemy balance edits when merging it.

## Findings and changes

The existing system already had sampled paths, a dense runtime array, a shared server scheduler, compressed sync, and batched hitbox movement. This batch builds on those pieces.

### Bounded sync

The previous system put every enemy in one unreliable packet. It now splits records into buffers of at most 900 bytes, with sequence and server timestamp headers. Five thousand enemies produce 46 packets per sync interval. Records are still eight bytes each. Per-enemy sequence checks reject duplicate/older corrections, including sequence wrap, and clients use bounded latency compensation. Truncated or malformed packets are ignored.

This fixes oversized unreliable packets; it does not eliminate bandwidth cost. At 5,000 enemies, one full sync contains 40,644 bytes per client; at 5 Hz that is about 203 KB/s before transport overhead and ordinary Instance replication. This is a measurement target for the next Studio profile, not a guarantee of acceptable network usage.

### Spawn budget

Waves, arrows, and summons share a budget of 32 rig clones per server Heartbeat. Waiting happens before cloning. Work over the limit resumes on later frames; budget waits also respect pause, match cancellation, and summon cancellation predicates. Large groups may take longer to appear rather than cloning thousands of rigs in one frame.

### Effect timing and connection cleanup

The former three duration-change connections per enemy are replaced with cached references polled in the shared simulation pass. This removes 15,000 such connections at 5,000 enemies. Existing Effects folders and Value objects stay for compatibility. Legacy duration requests are consumed on the next server simulation pass rather than synchronously in a Value signal.

Movement, spawn delays, burn, bleed, and stun use game time. GameSpeed 0 now freezes them instead of being treated as 1. The delayed tower teardown caused by enemy explosions also uses match-scoped game time. A lethal burn cannot continue into a bleed callback on the removed enemy in the same update. The effect damage callback is shared instead of allocated for each enemy each frame.

The targeting grid now releases enemy/model references immediately on folder removal, even if there are no later tower queries to trigger a refresh.

### Renderer

Enemies still advance numerically in the shared loop, but expensive path CFrame sampling and root movement run at distance-dependent rates: nearby 60 Hz, middle distance 30 Hz, and far/behind-camera 10 Hz by default. Distant ticks are staggered. Emerging enemies and enemies facing an attack target use the nearby rate. Visible enemies remain rendered; this is update throttling, not disappearing models or reducing damage accuracy on the server.

Duplicate registration is idempotent. Invalid/removed roots are reclaimed during rendering instead of being skipped forever. Existing enemies at client startup, missed spawn events, and late metadata can recover through one bounded shared retry queue. Spawn attributes supply lane, height, and offsets. Late recovery does not replay emergence particles or sounds. Missing waypoint geometry is retried at a shared 0.5-second interval. Root recovery is retried for up to ten seconds; this is not a general guarantee for every streaming/custom rig scenario.

Match end clears renderer records, registration retries, movement arrays, and path caches. Facing durations freeze with game time. Optional summon particle/sound bursts are limited to eight per frame; emergence movement remains available when cosmetic bursts are skipped.

## EnemyData.Settings

| Setting | Default | Purpose |
| --- | --- | --- |
| SyncPacketBytes | 900 | Packet cap; codec enforces a maximum of 900 |
| SpawnBudgetPerFrame | 32 | Shared rig clone budget |
| NearRenderDistance | 120 | Near/middle distance boundary in studs |
| FarRenderDistance | 260 | Middle/far boundary |
| NearRenderHz | 60 | Nearby/emergence/attack-facing visual update rate |
| MidRenderHz | 30 | Middle-distance visual update rate |
| FarRenderHz | 10 | Far/behind-camera visual update rate |
| RegistrationBudget | 64 | Retry attempts per rendered frame |
| RegistrationTimeout | 10 | Retry lifetime in real seconds |
| SummonEffectsPerFrame | 8 | Optional summon cosmetic bursts per frame |

Existing ServerPositionHz=10, ClientSyncHz=5, and AlphaMirrorHz=5 remain unchanged. Far rendering can make client hover/tracer endpoints up to roughly one far update interval behind. Authoritative hitboxes, tower targeting, damage, and attack scheduling do not use those client visual rates.

## Diagnostics

In the **server** Studio command bar while playing:

```luau
print(require(game.ServerScriptService.EnemySystem.EnemyService).GetDiagnostics())
```

The result reports ActiveEnemies, LastSyncPackets, LastSyncBytesPerClient, LastMovedHitboxes, and LegacyEffectConnectionsPerEnemy. Sync fields describe the most recent full sync interval, not per-second throughput or total network traffic. Collect actual bandwidth, frame time, and memory in Studio's performance tools.

## Studio regression and scale tests

- [ ] Ordinary waves follow every lane; authoritative targeting, damage, health, and base damage remain correct.
- [ ] Necromancer/General Noobicus summons appear on the correct lane with emergence movement and expected behavior. Check large spawn groups spread across frames rather than freeze a frame.
- [ ] Burn, bleed, stun, slowdown, and overlapping effects behave correctly at 0.5x, 1x, and 2x. Pause during movement/effects/emergence; no movement, effect ticks, new rigs, or base damage should advance while paused.
- [ ] Kill enemies through tower damage, units, burn, and bleed. Check each death behavior, explosion, reward, and enemy counter occurs once.
- [ ] Join with another client mid-wave. Test delayed model/path replication and StreamingEnabled if used. Check no static enemies, duplicate movement, or replayed summon bursts.
- [ ] Simulate latency and packet loss. Check correction is smooth and old packets do not rewind enemies.
- [ ] Zoom/move the camera between near, middle, far, and behind-camera enemies. Check appearance, attack facing, hover, and bullet endpoints. Tune render rates if needed.
- [ ] End a match with live enemies and pending spawns. Check all runtimes/counters clear, effects stop, and another match starts without old state.
- [ ] Run 250, 1,000, 2,500, then 5,000 simple enemies, first without towers and then with a representative tower/unit mix. Record server frame time, client frame time, received data, physics/network cost, and memory at each step.
- [ ] Repeat spawn/kill/end cycles several times. Allow deferred cleanup/GC to settle, and compare memory and object/connection counts at the same empty-match point. Distinguish retained pools/assets from growing references.

## Validation and remaining limits

All 172 game files compile. Nineteen Luau tests and ten Python fixtures pass. New fixtures execute the actual service, effects, runtime, codec, targeting index, and renderer against mocked Roblox boundaries. They cover 5,000 runtimes, bounded packets, zero legacy effect connections, pause/speed, effects, death/counting, external removal, budgeted/cancelled spawning, initial and delayed registration, duplicate/stale sync, distance throttling, and restart cleanup.

These are logic tests, not Roblox benchmarks or proof that memory never leaks. The game still replicates full enemy model Instances and hitboxes, maintains compatibility Values, and runs the existing animation, attack, and death-effect systems. Detailed rigs, mass simultaneous deaths, particles, animations, and network replication may remain the dominant costs. Studio profiling should determine the next batch, especially client rig/animation budgets, death-effect budgets, replication interest management, and any remaining expensive attack queries. No claim of lag-free thousands is made from these fixtures.
