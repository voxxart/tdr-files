# Batch 22: correct hover/click cursor alignment

## Replace

- [ ] **ModuleScript** `ReplicatedStorage.GameModules.TowerInteraction`

Keep the other batch 20 scripts. No new scripts or assets are needed. Restart the Studio play session after replacing the module.

## Fix

GameController supplies raw `UserInputService:GetMouseLocation()` coordinates (or raw touch InputObject.Position). The picker previously used `Camera:ScreenPointToRay`, which interprets coordinates relative to the GUI inset. This displaced the query from the actual pointer. Close-up models could cover the displaced ray, while small models at far zoom became difficult or inconsistent to hover and click.

The picker now uses `Camera:ViewportPointToRay` for both the exact ray and any optional sample rays, matching the raw input and the existing placement projection. No GUI inset is subtracted or added. IgnoreGuiInset settings on the GUI do not change how the world pointer is projected.

`PixelTolerance` now defaults to **0**. Exact visible body geometry is the default again. The previous bounded fallback remains available as an explicit optional setting, but it is no longer used to compensate for cursor drift. Existing helper filtering, collision query group, render ordering, UI blocking, and outlines remain.

## Verification

The regression fixture now distinguishes ViewportPointToRay from ScreenPointToRay instead of treating them as interchangeable. It tests a grid of points across a small visible model at 128 studs under 36- and 58-pixel GUI insets. Each must resolve with one exact ray and zero pixel tolerance. Existing geometry, helper, wall, UI, death, query-budget, and optional tolerance tests remain.

In Studio, test enemies, units, and towers at 128 studs: head, torso, legs, and visible accessories. Check grouped towers, hover outlines, tower clicks, and touch if available. Hover should align with the cursor at all zoom levels; actual model mesh/query geometry still requires Studio testing.
