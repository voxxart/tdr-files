# Batch 41: AntiLagUnits support for skin folders

- [ ] Replace **Script** `ServerScriptService.AntiLagUnits`.
- [ ] Replace **ModuleScript** `ServerScriptService.UnitSystem.Spawner`.
- [ ] Add **ModuleScript** `ServerScriptService.UnitSystem.TemplatePreparation`.

Keep **ModuleScript** `UnitSystem.TemplateResolver` from batch 40. Restart the play session.

AntiLagUnits now traverses organizational Folders beneath ReplicatedStorage.Units, preparing both nested tower/skin templates and legacy flat models. It does not traverse submodels inside unit rigs. Existing authored hitboxes remain unchanged. Missing hitboxes are cloned from HumanoidRootPart, stripped of child objects, hidden, anchored and made non-colliding, retaining the previous CanTouch setting. Malformed roots/hitboxes produce a warning and cannot be spawned.

Spawner also invokes the same idempotent preparation immediately after resolving its template, before cloning it. This covers startup ordering and templates added after startup without additional per-template connections or frame loops.

Test a skin unit with no Hitbox, a unit with an authored Hitbox, and existing default units. Check movement, combat and death behavior. Automated checks execute the startup script against nested folders and exercise repeated/on-demand preparation and invalid templates.
