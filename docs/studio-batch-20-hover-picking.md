# Batch 20: consistent model hover and tower selection

Update together:

## Replace existing scripts

- [ ] **ModuleScript** `ReplicatedStorage.GameModules.TowerInteraction`
- [ ] **LocalScript** `StarterGui.GameGui.GameController`
- [ ] **LocalScript** `StarterPlayer.StarterPlayerScripts.EnemyRenderer`
- [ ] **LocalScript** `StarterPlayer.StarterPlayerScripts.UnitReplicator`

## Add new script

- [ ] **Script** `ServerScriptService.InteractionQuery`

No new events, assets, or GUI objects are required. Keep EnemyVisuals from the previous batches. Restart the Studio play session after updating.

## Behavior

All actor types now use the same exact screen-pointer ray. The remaining unit sphere assist is removed, so a nearby unit cannot win when the pointer misses its body. Nested accessories/weapons resolve to their owning model. Visible map geometry blocks targets behind it, and the first valid visible body under the cursor wins. This uses Roblox part/mesh query geometry, not pixel-perfect rendering or a screen-wide nearest-model search.

Transparent parts, locally hidden parts, Border/Hitbox/proxy helpers, actor Effects folders, and dead/inactive actors are skipped for enemies, units, and towers alike. Hover cards do not intercept their own hover. Transparent Active frame backgrounds no longer block the world by themselves; buttons, text inputs, scrolling areas, and visible Active panels still do.

A dedicated InteractionQuery collision group can query all registered collision groups. No physical parts are moved into it, and existing group-to-group physical collision rules are unchanged. Visible actor body parts authored with CanQuery false are made queryable locally when discovered. Three folder listeners cover new geometry; there are no per-model hover listeners or per-frame scans of every actor.

Enemy and unit root movement now use explicitly ordered render bindings (Camera + 10 / Camera + 11). GameController's hover/placement update runs at Last, after those movements and the standard camera update. Destruction unbinds those render callbacks. Hover outlines and tower selection continue to use the shared picker.

The picker reuses its RaycastParams and caps filtering at 32 ray hits per pick. It usually needs one cast; extra casts pass through ignored helpers. If the cap is reached, it returns no target rather than selecting something unrelated. No sticky target retention or enlarged helper volume is used.

## Studio tests

- Move the pointer across feet, torsos, heads, weapons, and accessories of each actor type. Confirm the hover follows the body, not its hidden root or border.
- Put units, towers, and enemies close together. Confirm crossing visible bodies changes the tooltip immediately and pointing into empty space clears it.
- Test a dense moving enemy wave with the camera panning; verify hover matches the current visual position.
- Place a tower near an enemy: confirm an invisible Border/Hitbox does not steal hover. Click a tower and confirm the upgrade selection and outlines still work.
- Test behind a solid wall, over tooltips, over a transparent full-screen UI frame, and over real UI buttons. Check that world hover is blocked only in the expected cases.
- Test placement, rotation, cancel, and aimed abilities, since GameController's shared update now runs after movement.
- Check moving units, pause, timescale, match end, and restart for movement or cleanup regressions.

Automated fixtures cover exact picking, no sphere assist, invisible/helper/dead filtering, collision-group setup, UI blocking, body queryability, and cleanup. Renderer fixtures exercise the new priority bindings and retain the existing movement checks. Actual Studio visuals and collision geometry still need play testing.
