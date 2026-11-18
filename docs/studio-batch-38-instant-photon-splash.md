# Batch 38: instant Railgunner splash with matching impact size

Replace these existing scripts together:

- [ ] **ModuleScript** `ReplicatedStorage.GameModules.TowerData`.
- [ ] **ModuleScript** `ServerScriptService.TowerSystem.PrimaryAttack`.
- [ ] **LocalScript** `StarterPlayer.StarterPlayerScripts.Towers.Railgunner`.

Keep the latest **ModuleScript** `ReplicatedStorage.GameModules.PhotonShots` from the 1.75-stud impact update. No new objects, modules or RemoteEvents are needed. Restart the play session after updating.

Railgunner's final upgrade (level 4) now specifies `Splash = true`, `InstantSplash = true`, and `SplashRadius = 0.875`. The damage area therefore has a 1.75-stud diameter, matching the visual impact's final diameter. Lower levels remain direct attacks. Damage is applied immediately using the existing splash handler, including its defense, shield, cash and damage-tracking rules. There is no projectile travel delay or extra splash-projectile effect. The normal Attack event still drives the photon beam, and the client now aims at Hitbox first so the beam/impact center matches the server splash center.

`InstantSplash` is an opt-in Boolean setting for splash attacks. Missing or false preserves the ordinary projectile path; do not change projectile speed to simulate instant shots. Splash damage and the photon impact remain separately authored sizes: if changing them later, set the PhotonShots impact diameter to twice SplashRadius.

Test final-level Railgunner with enemies inside/outside 0.875 studs of the target Hitbox, including shields/invincibility, and check that damage occurs at the shot rather than after travel. Verify lower levels and ordinary splash towers still behave as before. Automated coverage checks actual primary routing, final-level data, animation count, ammunition consumption and legacy projectile routing.
