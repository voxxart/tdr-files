# Batch 09: tower hover, selection, and upgrade actions

Install all three files together. Keep existing UI objects, tower assets, events, and server scripts.

## Replace

- [ ] **LocalScript** — `StarterGui.GameGui.GameController` (`GameController.client.luau` in the repository)

## Add

- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.TowerInteraction`
- [ ] **ModuleScript** — `ReplicatedStorage.GameModules.TowerActionGate`

No new Folder, RemoteEvent, RemoteFunction, or manually configured Highlight is required. The client creates a local `Workspace.TowerInteractionVisuals` Folder containing two reusable Highlights and removes it when GameController is destroyed.

## Behavior

- White outline on hovered towers; cyan outline on the selected tower. Selection takes priority when hovering the same tower. Outlines respect scenery occlusion.
- Picking uses the current screen pointer directly. Click/tap selection performs a fresh pick instead of using the previous frame's smoothed hover result. Nested upgrade model parts resolve to their containing tower.
- A 0.75-stud assisted cast helps with narrow parts. Exact hits take priority. Assisted targets must pass a visibility ray and cannot be selected through scenery. Change `TowerInteraction.AssistRadius` to tune assistance.
- Hovering buttons, text boxes, or Active UI containers suppresses world picking. Processed input remains ignored. Hover cards are passive; panels that should block world interaction must have their container's Active property enabled.
- Upgrade, sell, and target-mode buttons share the same handlers as E, X, and Z. Each tower permits one outstanding action across all three operations. Ownership, health, and upgrade eligibility are checked before requesting the server; server validation remains authoritative.
- Server responses retain the tower that initiated the action. A response for tower A cannot close or repaint tower B's panel after the player changes selection. Upgrade particles are removed after five seconds.
- Dead, sold, or removed towers lose selection and close the panel. Clicking empty space deselects. Escape deselects when Roblox has not consumed the input. Placement suppresses hover cards and hover outlines.
- Selected range circles are explicitly owned and destroyed when selection changes. Destroying a range model disconnects its Heartbeat, preventing accumulated range update connections. Selection no longer deletes every child of the camera.

This batch retains the existing UI layout and tower-specific ability controls. It does not redesign UI assets or change placement and missile-aim rules. Those flows still require regression testing.

## Studio checks

- [ ] Hover and click Trooper/Heavy and a tower with nested upgrade models. Check white hover and cyan selection outlines, then upgrade without losing the selected outline.
- [ ] Move the pointer quickly between adjacent towers and click; confirm the tower under the click is selected. Test narrow tower parts at different zoom levels.
- [ ] Place a tower behind map scenery; confirm assistance does not select it through a wall. Confirm exact enemy/unit hits still show their existing hover cards.
- [ ] Hover and click upgrade, sell, target mode, loadout buttons, and open menus. Confirm these do not select towers behind the UI. Check panel Active settings if a custom menu permits click-through.
- [ ] Repeatedly press Upgrade/E while a request is pending; confirm only one outstanding request for that tower. Repeat for sell and target mode.
- [ ] With simulated network latency, upgrade tower A and select tower B before the reply. Confirm B's panel stays selected. Repeat with selling A.
- [ ] Select another player's tower; confirm inspection works and mutation buttons/hotkeys cannot alter it.
- [ ] Kill or externally remove a selected tower; confirm its panel, range, and outline clear. End a match while a tower is selected.
- [ ] Switch selection and open/close the panel repeatedly. Check that selected range models and range Heartbeat connections do not accumulate.
- [ ] Test touch selection using actual tap positions and UI controls. Test with the top bar inset and different resolutions/UI scales.
- [ ] Recheck tower placement/rotation/cancellation, unit range hover, special tower range rings, missile aiming, and tower abilities.

## Validation

All 165 game Luau scripts compile. Seventeen Luau test files and five integration/renderer fixtures pass. New checks execute actual picking/outline code against mocked engine boundaries and test pending-action rejection, captured targets, independent towers, and recovery after remote errors. Actual ray geometry, UI hit testing, Highlight appearance, and network ordering in the full controller still need Studio validation.
