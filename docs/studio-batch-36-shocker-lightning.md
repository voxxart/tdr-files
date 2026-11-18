# Batch 36: Shocker lightning

- [ ] Replace **LocalScript** `StarterPlayer.StarterPlayerScripts.Towers.Shocker`.

Keep the existing shared **ModuleScript** `LightningBolt` and its PartCache dependencies in their current location. Shocker uses `ReplicatedStorage.LightningBolt` when present, otherwise `ReplicatedStorage.GameModules.LightningBolt`. Keep **ModuleScript** `ReplicatedStorage.GameModules.VFXPolicy` from the settings batch. No new events or tower attachments are required: the origin remains `Weapon.Handle.Lightning` (**Attachment**).

The existing server chain determines targets and damage. Client bolts have electric-blue coloring, static noise and thickness, and a short final fade. All chain links are supported, replacing the previous five-target visual cap. Endpoints are snapshots of each hit, matching the old effect. Geometry uses the shared part cache, 5–12 parts per link (up to 8 on Low VFX), with a 768-part Shocker budget. Excess visual links are omitted under load without changing damage. One cleanup loop returns expired bolts to the cache.

Test a single target and a fully upgraded chain, High/Low VFX, repeated attacks, and many Shockers. Verify the blue lightning starts at the weapon attachment, follows the chain, fades without pulsing, and disappears after each hit. Automated coverage checks full chains, static settings, fade, budget recovery and destruction cleanup; appearance still needs Studio verification.
