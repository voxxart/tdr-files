# Batch 30: responsive event currency collection

## Replace

- [ ] **ModuleScript** `ReplicatedStorage.GameModules.EventCurrencyConfig`
- [ ] **ModuleScript** `ServerScriptService.EventCurrencySystem.Service`

Keep the existing EventCurrency LocalScript, shared Orbs, Wallet, quota, balance HUD, and pickup assets. No new scripts or remotes are needed. Restart the play session.

## Changes

- `PickupRadius = 10`: horizontal ground-level range in studs, increased from six. The character's HumanoidRootPart height no longer subtracts from that range.
- `PickupMaxHeight = 8`: separate vertical separation limit. Drops farther above or below the root cannot be collected.
- `PickupDelay = 0.15`: short grace in game seconds instead of waiting for the entire launch plus bounce duration (previously about 1.55 seconds). Nearby drops can be collected during the arc/bounces.
- `PickupHz = 20`: one proximity pass per 0.05 real seconds, retaining fractional elapsed time to avoid drift. At most one pass runs per Heartbeat; there is no catch-up loop.
- `CollectionDuration = 0.45`: shorter shared-Orbs flight, down from 0.65 seconds.

All checks and awards remain server-authoritative. No client pickup request or client balance mutation is added. Personal claims, loaded-wallet validation, quotas, expiry, duplicate prevention, pause behavior, and persistence remain. The existing bounded active drop count is unchanged. Proximity checks use squared horizontal distance plus a vertical comparison; there are no new rays or per-drop connections.

## Studio checks

Walk/jog past drops at normal speed and check that collection begins around ten ground-level studs without stopping beside them. Check drops near the player during their initial bounce, the Orbs flight, sounds, and accumulating popup. Test stairs/elevated platforms to tune PickupMaxHeight for your map geometry. Confirm pause, personal drops with multiple players, quota limits, and balance saving still work.

Automated server tests cover the initial grace, collection before the bounce finishes, horizontal boundary entry with a raised HRP, rejection outside the radius/height limit, and next-check collection. Existing personal accounting/persistence and client presentation tests remain.
