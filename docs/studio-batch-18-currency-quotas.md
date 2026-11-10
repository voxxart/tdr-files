# Batch 18: personal event currency quotas and cleaner pickups

Install these together. Existing assets, Wallet, DropStore, Orbs, and Datastore scripts from batches 16–17 remain required.

## Replace existing scripts

- [ ] **ModuleScript** `ReplicatedStorage.GameModules.EventCurrencyConfig`
- [ ] **ModuleScript** `ReplicatedStorage.GameModules.EventCurrencyPool`
- [ ] **ModuleScript** `ServerScriptService.EventCurrencySystem.Service`
- [ ] **ModuleScript** `ServerScriptService.Main.Round`
- [ ] **LocalScript** `StarterPlayer.StarterPlayerScripts.EventCurrency`

## Add new scripts

- [ ] **ModuleScript** `ServerScriptService.EventCurrencySystem.Quota`
- [ ] **ModuleScript** `ServerScriptService.EventCurrencySystem.Ground`
- [ ] **LocalScript** `StarterGui.GameGui.EventCurrencyBalance`

The HUD script uses the existing **TextLabel** `GameGui.Settings.EventCurrency.Amount`. No GameController replacement is needed. No manual remote creation is needed.

## Settings and reward rules

`EventCurrencyConfig.ModeQuotas` sets Easy = 145, Normal = 315, Hard = 650. These are per-player totals earned in one match, independent of the player's saved currency balance. Add an entry for any custom mode; unlisted modes have a zero quota. Set `QuotasEnabled = false` to restore unrestricted random drops.

Drop chance and amount remain random. Unclaimed piles reserve budget for their eligible players. The final pile can be smaller than `MinAmount` to reach the cap exactly. Expiration releases the reservation for later drops. Players stop receiving new piles once their collected currency plus outstanding piles reaches the quota. Leaving and rejoining the same match does not reset collected progress; starting another match does.

`CompleteQuotaOnVictory = true` guarantees the quota on a successful run: before victory is announced, outstanding piles are removed and the server awards each present player's remaining shortfall. This includes currency lost to expired or uncollected drops, low drop chance, or visual/drop limits. The existing pickup presentation displays this final award. Defeats retain only currency actually collected. Set the option false to keep the cap without a guaranteed victory award. `Enabled = false` disables both drops and victory awards.

Balances are credited through the existing server Wallet into loaded profile data and the normal save flow. The HUD reads the server-owned `EventCurrencyBalance` attribute initially and when it changes, with thousands separators. It sends no reward requests and makes no datastore calls. It also handles a late-created label.

## Landing and pickup presentation

Ground models stay anchored and noncolliding. Landing rays reject steep surfaces, excessive elevation changes, and blocked space beside walls, with a bounded number of retries and a shared `LandingChecksPerFrame` budget. If no clear floor is found, that attempted drop is skipped. For maps with complicated decoration, an optional Folder/Model named `EventCurrencyFloor` directly under the map can contain the intended collidable landing surfaces; clearance checks still consider the rest of the map.

Asset bottom placement now accounts for off-center pivots, rather than assuming the pivot is at the visual center. Pickup sound restarts are rate limited with `PickupSoundMinInterval`, preventing many simultaneous pickups from repeatedly interrupting the sound. The existing two-to-three bounces, stationary rest, Orbs collection, and accumulating five-second popup remain.

## Studio checks

1. Start each difficulty and verify its quota. For a quick test, temporarily raise drop chance, shorten lifetime, and lower the quotas.
2. Collect a nearly complete quota: the last pile should award only the remaining amount and further drops should stop for that player. A second player should retain independent progress.
3. Let a pile expire; later enemies should be able to replace that reserved amount. Rejoin the same match and verify collected progress does not reset.
4. Win with a shortfall: total earnings should equal the quota once. Lose with a shortfall: there should be no completion award.
5. Check `Settings.EventCurrency.Amount` updates on load and pickup, including balances above 999. Verify saved currency survives rejoining.
6. Test slopes, walls, stairs, and models with off-center pivots. Drops should settle on a clear floor without catching on walls. Confirm Orbs, sounds, and the single accumulating popup still work.

Automated fixtures cover quota accounting, victory completion, defeat behavior, rejoin accounting, floor selection, asset bottom placement, personal amounts, and HUD updates/cleanup. Actual map geometry, live saving, sound, and visual quality still need Studio testing.
