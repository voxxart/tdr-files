# Batch 37: max-level Railgunner photon shots

## Replace

- [ ] **ModuleScript** `ServerScriptService.Main.TowerServer` (`TowerServer.luau`).

## Add

- [ ] **ModuleScript** `ReplicatedStorage.GameModules.PhotonShots`.
- [ ] **LocalScript** `StarterPlayer.StarterPlayerScripts.Towers.Railgunner`.

Keep the latest shared **ModuleScript** `LightningBolt` and its existing PartCache dependencies, plus **ModuleScript** `ReplicatedStorage.GameModules.VFXPolicy`. No new RemoteEvents are needed.

## Skin setup

- [ ] Optionally add a **Color3Value** named `PhotonColor` directly inside each Railgunner skin model's **Config** container. Set its Value to that skin's desired beam color. This colors both the photon beam and its impact.
- [ ] Position an **Attachment** named `Barrel` inside `Weapon.Handle` to choose the muzzle. If missing, the effect starts at Handle's position.

The server supplies a missing `Config.PhotonColor` when Railgunner reaches its final upgrade, defaulting to RGB `(100, 210, 255)`. Existing authored colors are preserved. Set skin colors on the tower template's Config so they are cloned into placed towers. Clients read the value per shot, so changing it affects subsequent shots.

The client derives the max level from TowerData: currently level 4. Lower levels do not show photon shots. This is a cosmetic, instantaneous laser beam and small expanding impact flash; it does not delay damage or alter targeting. It uses one straight static lightning segment per shot, without electrical jitter or branches. Impacts are pooled, with at most 48 active shots (16 on Low VFX). Effects beyond 350 studs from the camera and invalid/oversized links are omitted. Match end clears active effects. Duration is 0.18 real seconds, so visual cleanup still completes during pause.

## Test

Compare levels 3 and 4, test two skins with different PhotonColor values, verify the muzzle attachment and target impact, and check repeated attacks and match end. Confirm the earlier screen rendering issue stays resolved. Automated checks cover level/identity gating, color, muzzle, invalid endpoints, caps, impact reuse and cleanup; appearance requires Studio testing.
