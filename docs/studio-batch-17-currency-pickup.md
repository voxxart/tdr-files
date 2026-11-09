# Batch 17: resting currency, farm-style orbs, pickup sound and running total

## Replace

- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EventCurrencyConfig`
- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.EventCurrencyPool`
- [ ] **ModuleScript** — `ServerScriptService.EventCurrencySystem.Service`
- [ ] **LocalScript** — `StarterPlayer.StarterPlayerScripts.EventCurrency`
- [ ] **ModuleScript** — the existing **Orbs** module used by your farms. The current farm script requires `ReplicatedStorage.Orbs`. Its repository source is `Tower Defense R/ReplicatedStorage/GameModules/Orbs.luau`; copy that content into the existing Studio Orbs module rather than creating a second module.

No datastore, wallet, enemy-service, or remote changes are needed for this follow-up. Restart Play after replacing the modules so the cached old Orbs implementation is not reused. Existing farm calls keep the same Play API.

## Assets

Keep the ground currency asset at:

```text
ReplicatedStorage.Particle.EventCurrency.Current (Model or BasePart)
  PickupSound (Sound; recommended name, with your SoundId/Volume)
```

PickupSound may be nested anywhere in the ground asset. If no Sound named PickupSound exists, the first descendant Sound is used. One local sound copy is cached on the character's HumanoidRootPart and restarted on collection, avoiding overlapping piles of sounds. Source sound properties are preserved and Looped is forced off.

Add the orb asset and popup:

```text
ReplicatedStorage
  Particle
    Orb
      EventDrops (Folder)
        YourOrb (Model, MeshPart, or Part)
    EventCurrencyPickup (BillboardGui)
      Amount (TextLabel)
```

EventDrops can contain one or more Model/BasePart variants; a variant is selected for each Play call. A direct Model or BasePart named EventDrops also works. This is separate from Current: Current is the ground pile, EventDrops supplies the collection orb.

Style EventCurrencyPickup and Amount in Studio. The script clones the BillboardGui directly into the local player's HumanoidRootPart, sets Adornee to that root, and enables it. It does not create a new HUD layout or change the template's styling.

## Behavior

- Currency launches in its existing random direction, then makes **two or three distinct, decaying bounces**. The bounce count is rolled on the server and sent in the drop metadata. After the last bounce it remains still on the ground.
- Currency keeps its authored orientation; there is no launch/rest spin.
- No amount/value label is created above ground currency. The white AlwaysOnTop ground outline stays.
- Collection removes the ground pile and calls `Orbs.Play("EventDrops", duration, orbCount, position, player)`, just as farm presentation calls the shared orb API.
- Pickup also plays the sound from the ground currency asset and updates the player popup. The previous burst of Current models from the player is removed.
- **Only one EventCurrencyPickup BillboardGui is maintained on the HRP.** The first pickup starts a five-second real-time window. Additional pickups during that window add to the displayed total without resetting the timer: 3 then 4 displays +3 then +7.
- At the end of those five seconds the billboard is destroyed and its total resets. A later pickup starts a new window. Respawning or removing the script also cleans up its popup/sound.
- The popup timer runs during pause and can finish after the match ends. Ground motion/lifetime and server pickup still follow game time; farm-style orb flight/fading uses real seconds, as the shared orb API previously did.

Personal eligibility, chance, rolled reward amounts, server proximity validation, duplicate-claim prevention, and saving are unchanged. The popup is cosmetic; the server wallet remains authoritative. Even if a ground visual was skipped or expired locally, a valid server collection can still update the popup and sound. Repeated collection messages are deduplicated in a bounded recent-ID cache.

## Settings

In EventCurrencyConfig:

```luau
BounceDuration = 0.9,       -- total bounce time in game seconds
MinBounces = 2,
MaxBounces = 3,
BounceHeight = 0.8,
CollectionDuration = 0.4,   -- orb flight in real seconds
CollectionOrbs = 1,         -- cosmetic count, independent of credited amount
PickupDisplaySeconds = 5,   -- fixed accumulation window from the first pickup
```

CollectionBurst and MaxCollectionBurstsPerFrame are no longer used. The shared Orbs module caps active/allocated resources at 256, accepts up to 64 orbs per Heartbeat window, and limits an individual Play call to eight visuals. Edit Orbs.Settings if measured testing calls for different limits. These caps affect visuals, not credited money.

The updated Orbs module supports both the existing farm Part assets and folder/model EventDrops assets. It pools resources, follows the moving target root, fades in the shared update loop, and moves all orb parts in one BulkMoveTo batch. It no longer creates a tween and completion connection for each orb. Inactive resources stay cached within the cap, and released records drop their character references.

## Studio tests

- [ ] With DropChance=1, watch multiple drops make two/three bounces and stop moving completely. Verify no spin or ground amount label.
- [ ] Collect a pile and confirm your EventDrops asset flies to the character and your PickupSound plays. Move during collection to check target following.
- [ ] Collect amounts 3 then 4 within five seconds. Verify one HRP billboard reads +7, then disappears five seconds after the first pickup. Collect again afterward to verify a fresh total.
- [ ] Check two players: personal copies, sound, orbs, and popups should be local to the correct collector.
- [ ] Check existing farm Money orbs still look correct, and test Model and MeshPart EventDrops assets.
- [ ] Test rapid collections, respawn, pause, game end, and restarting Play. Confirm no accumulating billboard/sound copies and no stale character references.
- [ ] Profile a mass collection using your real orb asset. Resource caps bound counts; asset complexity and continuous particle/trail content still affect GPU cost.

Automated validation: all 184 game files compile; 22 Luau tests and 16 Python fixtures pass. Updated tests exercise three bounce peaks and stationary rest, no ground label, the Orbs call, sound reuse, one popup accumulating +3/+7, fixed five-second expiration, duplicate collection handling, and cleanup. The actual shared Orbs module is also tested for old farm calls, folder/model assets, batching, target movement, fade/reuse, resource caps, and removed-character cleanup. Engine appearance, sound assets and BillboardGui layout require Studio verification.
