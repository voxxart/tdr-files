# Batch 21: easier hover and tower clicks when zoomed out

## Replace

- [ ] **ModuleScript** `ReplicatedStorage.GameModules.TowerInteraction`

Keep the batch 20 scripts, including `ServerScriptService.InteractionQuery`, GameController, EnemyRenderer, and UnitReplicator. No new scripts, assets, or events are needed. Restart the play session after updating the module.

## How it works

The exact cursor ray still runs first and wins immediately when it hits a live visible actor. When it misses, the picker samples eight directions at 3 pixels, then eight at 6 pixels. This gives small distant models a consistent screen-space margin rather than an expanding world-sized hitbox.

The closer pixel ring wins; within that ring, the frontmost valid body wins. There is no sticky previous selection or preference for towers over units/enemies. All samples skip the same helpers/effects/dead actors and stop at visible map geometry. Candidates farther away than the center ray's map hit are rejected as an additional conservative wall check. A fallback hit must also lie within 1.25 studs of the center ray, preventing excessive reach at extreme distance.

Hover and tower clicks already use this shared picker, so both receive the same behavior. UI blocking and outlines remain. Tower placement helpers remain excluded from local queries.

## Tuning (top of TowerInteraction)

- `PixelTolerance = 6`: outer screen-pixel margin; the inner ring is half this. Set 0 for exact-only picking. Runtime clamp is 0–12 pixels.
- `MaxWorldTolerance = 1.25`: maximum lateral distance in studs from the center ray.
- `MaxQueriesPerPick = 48`: shared ray budget across direct picking and all samples, including skipped helpers.
- `MaxSkippedParts = 32`: per-ray helper skip limit within that shared budget.

A clean direct hit needs one ray. A complete miss normally uses 17 rays; helper filtering can add rays up to the fixed shared budget. There are no spherecasts, per-actor frame scans, new hitbox parts, or server hover requests.

## Studio checks

1. Test towers, enemies, and units at close, normal, and far zoom. Small visible bodies should be easier to acquire without zooming in.
2. Pack different actor types together. Directly pointing at a visible body must select that body before any tolerance is considered.
3. Move into gaps between grouped towers and across model edges. Confirm the small margin feels comfortable and does not reach unrelated towers.
4. Check tower clicking/upgrading matches the hover outline. Test tooltips and real UI buttons for blocking behavior.
5. Test solid walls, slopes, and map decoration. The depth check is deliberately conservative near occluding geometry; it can reject a fallback while direct visible body hits continue to work.
6. Check dense-wave performance, since a miss can issue more rays than exact-only picking. Tune PixelTolerance or disable it if desired; query count remains capped.

Automated tests cover near/far screen tolerance, direct-hit priority, candidate ordering, outside-margin rejection, wall depth rejection, world-distance cap, and the global query budget. Final feel and actual mesh geometry need Studio testing.
