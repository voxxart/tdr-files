# Batch 16: personal enemy event-currency drops

For the current two/three-bounce, stationary drop, shared EventDrops orb, sound, and player-total billboard behavior, also apply [Batch 17](studio-batch-17-currency-pickup.md). It replaces the initial value labels and player coin-burst presentation described in this original batch.


Each player has their own copy of a successful drop. Collecting yours does not remove another player's copy. Walk within pickup range to collect; no click is required.

## Replace

- [ ] **ModuleScript** — `ServerScriptService.EnemySystem.EnemyService`
- [ ] **Script** — `ServerScriptService.Datastore` (`Datastore.server.luau`)

If you customized Datastore, merge the EventWallet binding, load/publish, save-version, disconnect persistence, and shutdown-wait changes while keeping your existing profile/reward edits. The datastore name remains OfficialTDRGameData.

## Add

- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EventCurrencyConfig`
- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EventCurrencyAssets`
- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EventCurrencyPool`
- [ ] **Folder** — `ServerScriptService.EventCurrencySystem`
- [ ] **ModuleScript** — `ServerScriptService.EventCurrencySystem.DropStore`
- [ ] **ModuleScript** — `ServerScriptService.EventCurrencySystem.Wallet`
- [ ] **ModuleScript** — `ServerScriptService.EventCurrencySystem.Service`
- [ ] **LocalScript** — `StarterPlayer.StarterPlayerScripts.EventCurrency` (`EventCurrency.client.luau`)

Install the complete batch before Play, including the folder and modules required by Datastore. No changes to the previous enemy proxy/renderer/animation modules are needed.

These are created automatically under ReplicatedStorage.Events:

- **RemoteEvent** — `EventCurrency`
- **RemoteFunction** — `EventCurrencySnapshot`

Do not add duplicate events or a client pickup-request remote. Pickup and rewards are server controlled.

## Currency asset

Use the existing Particle folder and add:

```text
ReplicatedStorage
  Particle
    EventCurrency (Folder)
      Current (Model or MeshPart/Part)
```

Current can also be a Folder containing the active Model/BasePart, or an ObjectValue pointing to it. Keep one active asset in the container. Models must contain at least one BasePart; Archivable must be enabled. A PrimaryPart is optional and is assigned locally when absent. Use a small static cosmetic asset for best performance.

The same asset appears on the ground, travels to the player on collection, and bursts outward from the player afterward. Colors/materials are preserved. Automatic particle emitters, trails, beams, lights, sounds, and legacy fire/smoke/sparkles on the asset are disabled to avoid multiplying continuous effects across all drops. Scripts and authored Highlights are stripped from local copies; the system supplies the white outline. No currency model Instances are spawned on the server.

If the asset is missing or invalid, drops are skipped and the server warns once, rather than awarding invisible pickups.

## Easy settings

Edit only `ReplicatedStorage.GameModules.EventCurrencyConfig`:

```luau
Enabled = true,                 -- false switches drops off
CurrencyKey = "EventCurrency",  -- numeric field in saved player data
DropChance = 0.10,              -- 10%; 1 = every eligible kill, 0 = never
MinAmount = 1,
MaxAmount = 5,
Lifetime = 30,                  -- GAME seconds, including launch/bounce
PickupRadius = 6,               -- studs from character root to landing point
```

Older profiles without the selected field start from zero when credited. Existing non-numeric fields are not overwritten; choose a numeric currency field. The default EventCurrency field already exists in this game's profile schema. Changing the visual model does not change which profile field is credited.

The drop chance and integer amount are rolled once per killed enemy. Every player present at that kill receives a personal copy with that rolled amount. Players joining later do not gain old copies. A player whose data is still loading can collect once it becomes ready, provided the drop has not expired. The character must be alive and within range. Amount bounds are clamped to positive integers, with MaxAmount raised to MinAmount if necessary.

Each visual pile represents its entire amount; an amount of 100 does not create 100 physical coins. The ground amount label shows its value, and collection shows +amount. Collection-burst models are decorative and do not award additional currency.

Settings are read on startup; restart Play after editing settings or swapping templates for reliable testing.

## Motion and presentation settings

| Setting | Default | Meaning |
| --- | --- | --- |
| LaunchDuration | 0.65 | Initial arc in game seconds |
| ArcHeight | 5 | Additional arc height |
| ScatterMin / ScatterMax | 2 / 6 | Random landing distance, in a random 360-degree direction |
| BounceDuration | 0.4 | Time spent bouncing after landing |
| BounceHeight | 0.8 | Initial bounce height |
| GroundOffset | 0.1 | Offset above server raycast landing surface |
| CollectionDuration | 0.4 | Curved flight to the collector |
| CollectionBurst | 3 | Decorative currency models emitted from the player, capped at six |

Landing uses a server raycast restricted to the enemy's map. Pickup becomes available after launch and bounce. Ground models have a white Highlight with AlwaysOnTop and transparent fill. The outline is disabled during collection/burst. Currency parts do not collide, touch, query, cast shadows, or interfere with tower/enemy picking.

Pause freezes motion, lifetime, and pickup. Match end removes uncollected copies and active presentation; already credited balances remain. Enemies reaching the base or removed for cleanup do not count as killed drops. The hook runs through EnemyService.OnDeath once per normal authoritative kill.

## Persistence

The server mutates the loaded player profile through the shared Wallet module. No datastore calls occur per pickup. Normal save/exit saves include the earned balance. Dirty currency also saves on disconnect without rerunning match-reward calculations. Shutdown waits for saves, and currency has a raw-profile save fallback if the existing match-reward save errors. Save attempts are bounded; live DataStore availability still determines persistence success.

Wallet versions prevent a save that started before a later pickup from falsely marking that pickup saved. Leaving players stop accepting new credits, and profile/wallet references are released after disconnect handling. A late datastore load is ignored if its player already left.

For UI integration, the player gets server attributes **EventCurrencyKey** and **EventCurrencyBalance**. Existing GetData also returns the updated profile. No new permanent HUD layout is added by this batch.

## Performance limits

| Setting | Default | Meaning |
| --- | --- | --- |
| MaxActiveDrops | 128 | Maximum server drop records, including all personal claim state |
| PickupHz | 10 | Shared server pickup/expiry/message tick |
| MaxClientVisuals | 160 | Maximum pooled currency resources per client |
| ClientBuildsPerFrame | 8 | Maximum client acquisition/build attempts per frame |
| MaxCollectionBurstsPerFrame | 4 | Maximum completed pickups producing burst visuals per frame |

Excess new drops are skipped when the server cap is full; excess visual resources/bursts are skipped at client caps. These limits intentionally bound very large kill bursts and can affect how much currency drops during saturation. Tune them using measured battles rather than making them unlimited.

Server state uses dense records and per-player claim flags, not server currency Parts or per-drop connections. One shared server loop handles proximity and expiry, with player positions captured once per tick. Spawn/remove messages are batched; collection messages are private. The client uses one render loop and one BulkMoveTo batch for all currency parts, with cached local part offsets and pooled assets. There are no per-drop tweens, delay tasks, Touched connections, or physical bouncing. Idle pool memory is retained up to the cap for reuse.

## Studio tests

- [ ] Add Current and set DropChance=1 temporarily. Kill ordinary, lightweight, summoned, and boss enemies; verify kills produce drops and base entry/cleanup do not.
- [ ] Test two players. Each should see their own copy, collect it once, and receive the full rolled amount without removing the other's copy.
- [ ] Confirm an out-of-range or dead player cannot collect. Test walking across a drop before/during/after its launch and bounce.
- [ ] Verify random directions/amounts, ground landing on each map, white AlwaysOnTop outline, amount text, flight to character, and player burst using your actual asset.
- [ ] Pause/resume and test speed changes. Let drops expire, leave/rejoin mid-wave, and end/restart the match with drops present.
- [ ] Check the EventCurrencyBalance attribute and GetData value. Collect, leave, and rejoin a published test server to verify real persistence; Studio datastore tests require the appropriate API access setting.
- [ ] Disable Enabled and remove Current to test off/missing-asset behavior. Restore afterward.
- [ ] Test a large simultaneous kill burst and repeated fights. Inspect active records, client instance count, server/client frame time, and memory. The selected asset's geometry still matters.

Server diagnostics:

```luau
print(require(game.ServerScriptService.EventCurrencySystem.Service).GetDiagnostics())
```

## Automated validation

All 184 game Luau files compile. Twenty-two Luau tests and fifteen Python fixtures pass. New fixtures execute the actual drop service, wallet, datastore load/disconnect path, client effects, pool, and asset resolver against mocked engine boundaries. They cover personal copies, one credit per player, range/landing checks, caps, pause/expiry, cancellation, zero per-pickup writes, disconnect persistence without duplicate rewards, snapshot races, arc/collection motion, Highlights, pooled reuse, Model/BasePart assets, and cleanup.

Roblox rendering, real map raycasts, replication, DataStore networking, and your model's visual/performance behavior still need the Studio and published-server checks above. These fixtures do not establish a zero-lag guarantee.
