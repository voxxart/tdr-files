# Batch 40: skin-specific tower-spawned units

## Scripts

- [ ] Add **ModuleScript** `ServerScriptService.UnitSystem.TemplateResolver`.
- [ ] Replace **ModuleScript** `ServerScriptService.UnitSystem.Spawner`.

Restart the play session after both are installed. No new remotes or client scripts are required.

## Unit model layout

Use **Folder** `ReplicatedStorage.Units`, with a **Folder** per canonical tower name, then a **Folder** per appearance name, containing the unit **Models**:

```text
ReplicatedStorage
└─ Units (Folder)
   ├─ Motor Pool (Folder)
   │  ├─ Default (Folder)
   │  │  └─ Tank1 (Model)
   │  └─ Golden (Folder)
   │     └─ Tank1 (Model)
   ├─ Barracks (Folder)
   │  └─ Default (Folder)
   │     └─ <configured unit name> (Model)
   └─ Reaper (Folder)
      ├─ Default (Folder)
      │  └─ <configured unit name> (Model)
      └─ Golden (Folder)
         └─ <same unit name> (Model)
```

Tower folders must match the placed tower's `TowerName` attribute, and skin folders must match its resolved `AppearanceName` attribute (the same attribute Scrambler uses). A skin folder can override only some units: each requested unit falls back independently to that tower's Default folder. Missing skin/default models fall back to the existing flat `ReplicatedStorage.Units.<unit name>` model, allowing gradual migration. Non-tower spawns retain the flat lookup.

Keep unit Model names identical to the configured spawn names across skins; unit behavior/death definitions also use these names. Each model must retain the existing unit rig, EnemyStats, Hitbox and PrimaryPart setup. Skin models carry their own stats, so preserve matching gameplay stats when making cosmetic variants. Do not delete flat models until every caller using them has a suitable tower/default setup.

This applies to all units using the shared UnitSystem spawner, including automatic spawner towers and tower abilities such as Reaper summons. Existing Scrambler coils continue using `ReplicatedStorage.TowerUnits.Scrambler.<skin>`; their separate stationary-coil system is unchanged. Enemy summons and mines are unchanged.

## Test

Place two skins of the same spawner and verify each spawns its own unit visuals. Check a Default skin, an ability spawn, a missing skin folder, and a skin folder missing one upgrade's unit. Verify damage credit, health/speed multipliers, movement and death effects. Automated checks exercise selected/default/legacy lookup, canonical tower names, isolation and non-model rejection.
