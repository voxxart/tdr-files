# Batch 36: Shocker lightning

- [ ] Replace **LocalScript** `StarterPlayer.StarterPlayerScripts.Towers.Shocker`.

Keep the existing shared **ModuleScript** `LightningBolt` and its PartCache dependencies in their current location. Shocker uses `ReplicatedStorage.LightningBolt` when present, otherwise `ReplicatedStorage.GameModules.LightningBolt`. Keep **ModuleScript** `ReplicatedStorage.GameModules.VFXPolicy` from the settings batch. No new events or tower attachments are required: the origin remains `Weapon.Handle.Lightning` (**Attachment**).

The existing server chain determines targets and damage. Client bolts have electric-blue coloring, static noise and thickness, and a short final fade. All chain links are supported, replacing the previous five-target visual cap. Endpoints are snapshots of each hit, matching the old effect. Geometry uses the shared part cache, 5–12 parts per link (up to 8 on Low VFX), with a 768-part Shocker budget. Excess visual links are omitted under load without changing damage. One cleanup loop returns expired bolts to the cache.

Test a single target and a fully upgraded chain, High/Low VFX, repeated attacks, and many Shockers. Verify the blue lightning starts at the weapon attachment, follows the chain, fades without pulsing, and disappears after each hit. Automated coverage checks full chains, static settings, fade, budget recovery and destruction cleanup; appearance still needs Studio verification.

## Graphics glitch fix

- [ ] Replace the shared **ModuleScript** `LightningBolt` too, using `ReplicatedStorage/GameModules/LightningBolt.luau` from this repository. Replace the copy your game currently uses (`ReplicatedStorage.LightningBolt` takes precedence); keep its existing PartCache dependency alongside it.

The shared module now hides parts before returning them to distant cache storage, tracks active bolts by identity instead of sparse-array length, makes destruction safe to repeat, and hides zero-length or fully faded segments before computing their orientation. These fixes also apply to other effects using that same module. Test Shocker and Reaper together in Studio, including repeated hits and effect expiry.

### Follow-up for recurring graphics glitches

Replace both **ModuleScript** `LightningBolt` (the copy used by your game) and **LocalScript** `StarterPlayer.StarterPlayerScripts.Towers.Shocker`, then restart the play session. Cached lightning parts now stay in an unparented folder outside Workspace. Checkout resets their transform while hidden before attaching them to Terrain; return removes them from Workspace before the cache teleports them. Shocker also rejects nonfinite/out-of-world endpoints and links longer than 512 studs. This bounds visual geometry without affecting damage. Automated checks cover cache isolation and invalid/oversized links; the reported graphics glitch needs Studio reproduction to confirm resolution.

Shocker now opts into static geometry: the module calculates its segment shapes and colors only on the first update, then updates transparency until expiry. Other towers keep the existing animated behavior. This reduces repeated geometry work, but does not establish the cause of the reported temporary scene-quality drop. Replace both scripts listed above for this change.

### Electrical appearance

Replace both **ModuleScript** `LightningBolt` and **LocalScript** `Towers.Shocker`. Shocker opts into a jagged three-dimensional shape with stronger irregular corners and a thinner, uneven electric-blue filament. Offsets are bounded by segment length, endpoints stay exact, and geometry remains static for each shot. Other lightning users keep their existing shape. There are no extra segments or branches; cache isolation, the geometry budget and fade remain in place. Verify appearance and the earlier graphics issue in Studio.
