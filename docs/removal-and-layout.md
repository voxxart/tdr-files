# Script layout and removal record

## Main hierarchy

Main/init.server.luau is the existing bootstrap, moved from Main.server.luau.
It must map to a Roblox Script named Main directly under ServerScriptService,
with the following children (not a Folder containing an init Script):

- ModuleScripts: Mob, Mine, Round, Unit, TowerServer, TowerDeath.
- Scripts: EngineerAbilities, MEUHealthReduction.

This is the conventional init.server.luau filesystem layout. There is no Rojo
project in this export; manual Studio imports must reproduce the hierarchy above.
Delete the old loose copies after moving them; do not run duplicate bootstraps.
Keep EnemySystem, TowerSystem, EnemyAttacks and other service scripts alongside Main.
EnemySystem/EnemyPath was renamed EnemyPaths to match EnemyService's WaitForChild.

## Removed source

- NoobicusAbilities.server.luau: duplicate airstrike damage receiver. The active
  EnemyAttacks/Noobicus.server.luau already chooses targets and applies primary and
  splash damage on the server. Removed the matching AirStrikeServer request from
  NoobModeAbilitiesVFX. Client presentation still receives AirStrikeClient.
- NoPathMobs.luau: no callers in the exported source, superseded by Mob's
  EnemyService forwarding. It used a per-enemy movement loop and connected Health
  Changed on every iteration. Check scripts embedded in original place assets for
  additional callers before deploying this source removal to that place.
- Mob.SetEffects, Burning, Bleeding and Stunned: unused no-op compatibility methods.
  No source callers remain; effect handling remains in EnemyService/EnemyEffects.
- EngineerAbilities' unused Mob require: removed; build behavior otherwise retained.

## Roblox instance removal

ReplicatedStorage.Events.NoobicusEvents.AirStrike.AirStrikeServer is obsolete after
this migration. Remove it from the original place, along with any old copy of
NoobicusAbilities, when deploying these changes. Event instances are not exported
in this repository, so no actual event asset has been deleted here.

Keep AirStrikeClient, BuildServer, BuildClient, MEU.Server and MEU.Client: current
scripts still consume them. Do not remove other events solely because their names
appear unused in a source-only search; models and place assets may contain callers.
CorrectMob has no source consumer/producer here; inspect place assets before removal.

## Validation

99 game scripts compile with Luau 0.745 after this pass. Cleanup lifecycle checks
pass. Static checks confirm the Main children and EnemyPaths import exist, and no
AirStrikeServer, NoPathMobs or removed Mob method call remains in source.
Studio gameplay testing is still required: one airstrike should apply one primary
and splash damage pass regardless of client count; its plane/explosion visuals
should remain visible on every client. Test bootstrap, waves, mines, unit spawn,
engineer builds and tower death after moving the instances.
