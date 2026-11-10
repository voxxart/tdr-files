# Batch 19: pickup presentation and saved balance

Install together after batch 18.

## Replace existing scripts

- [ ] **ModuleScript** `ReplicatedStorage.GameModules.EventCurrencyConfig`
- [ ] **ModuleScript** `ServerScriptService.EventCurrencySystem.Service`
- [ ] **LocalScript** `StarterPlayer.StarterPlayerScripts.EventCurrency`
- [ ] **LocalScript** `StarterGui.GameGui.EventCurrencyBalance`

## Remove obsolete script

- [ ] **ModuleScript** `ServerScriptService.EventCurrencySystem.Ground`

Keep Quota, Wallet, DropStore, EventCurrencyPool, EventCurrencyAssets, shared Orbs, Main.Round, and Datastore from previous batches. No new scripts, events, or UI objects need to be installed.

Ground pickups remain: random scatter, arc, two-to-three bounces, stationary rest, white AlwaysOnTop highlight, personal proximity pickup, and expiry. The restrictive floor-normal, overlap-clearance, and retry checks from batch 18 are removed. The earlier single downward ray and fallback landing position are restored, with a bounded shared ray budget. Assets remain anchored and noncolliding. The optional EventCurrencyFloor group and removed floor settings are no longer used.

## Pickup presentation

The existing `ReplicatedStorage.Particle.EventCurrencyPickup` BillboardGui and its `Amount` label remain the customizable template. Only one is attached to the HumanoidRootPart. Amounts count smoothly toward the accumulated total, the label bounces on each pickup, and text/strokes fade near expiration. Each new pickup refreshes the five-second timer. Existing text/stroke transparency and label scale are preserved as animation baselines.

`ReplicatedStorage.Particle.Orb.EventDrops` remains the shared Orbs source, now with three orbs and a 0.65-second flight by default. Sound still comes from the Current currency asset, with a small pitch variation and restart throttling.

A reusable Attachment on the HumanoidRootPart emits a short burst. Up to four ParticleEmitters from Current are used if provided; otherwise a neutral default burst is generated. Particle lifetime/count and emission frequency are bounded. Attachment, sound, popup, and listeners are cleaned up on character changes or script destruction. There are no per-pickup delayed tasks or animation connections; popup animation uses the existing frame loop.

Settings: `CollectionOrbs`, `CollectionDuration`, `PickupDisplaySeconds`, `PickupCountDuration`, `PickupBounceDuration`, `PickupFadeDuration`, `PickupBurstCount` (0 disables), `PickupBurstLifetime`, and `PickupSoundMinInterval`.

## Currency display

Set `EventCurrencyConfig.CurrencyKey` to the numeric field in the player's saved profile (for example `Pumpkins` or `EventCurrency`). The existing server Wallet credits `playerData[CurrencyKey]` and replicates that saved total via `EventCurrencyKey` and `EventCurrencyBalance`. The HUD checks the matching key and shows that balance at `GameGui.Settings.EventCurrency.Amount`, including prior savings, with thousands separators. It does not display the per-match quota counter or fetch the full profile every pickup. CurrencyKey is an installation setting; keep the same config on server and client.

Easy 145, Normal 315, Hard 650 quotas, per-player claims, expiration reservation release, victory completion, duplicate protection, and persistence are unchanged. Do not install the supplied standalone Pumpkin example scripts alongside this system: they would create a second reward flow.

## Studio checks

- Set CurrencyKey to your actual saved field and join with a known existing balance. Confirm the Settings label shows that total and increments by each awarded amount.
- Pick up several piles close together: one popup should smoothly accumulate, bounce again, reset its timer, and fade five seconds after the last pickup. Confirm the Orbs, sound, and root burst.
- Respawn during the popup and after a burst. Confirm old effects disappear and new pickups work.
- Confirm drops still bounce and wait for proximity pickup. Test map edges and geometry with the restored landing behavior.
- With two players, confirm personal drops and quota limits remain independent. Verify victory fills only the remaining quota and defeat does not.

Automated tests cover the presentation lifecycle and accounting; final visual tuning and live persistence require Studio testing.
