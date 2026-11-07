# Batch 10: animated placement slots

Install together:

- [ ] Replace **LocalScript** — `StarterGui.GameGui.GameController` (`GameController.client.luau`)
- [ ] Add **ModuleScript** — `ReplicatedStorage.GameModules.PlacementSlotAnimator`

The selected slot also fades in a white outline with two faint wider strokes for a small border glow; these fade out when deselected. Existing rounded corners are copied from the slot or its Button.

No new UI objects or events need to be added manually. The animator creates a UIScale on each loadout slot if needed, preserving the baseline of an existing UIScale. Previous interaction modules remain required.

When a placement preview becomes active, its loadout slot grows to 112% over 0.24 seconds with Back/Out easing. Successful placement, cancellation, or match end returns it to its original scale over 0.2 seconds. Invalid placement attempts retain the active slot. Selecting another slot animates the old slot down and the new slot up. Hotkeys and button clicks pass the actual slot index through the same placement flow.

Growth begins after placement is approved and the preview is ready. Rejected requests keep the previous active preview/slot. Request serials prevent stale requests from activating a slot, and a delayed successful placement response cannot clear a newer preview. No animation completion callbacks are retained; switching cancels the current tween and starts from the current scale. Destroying the controller cancels tweens and restores owned state.

Change `PlacementSlotAnimator.SelectedScale = 1.12` to tune the enlargement. UIScale leaves authored Size and Position intact; verify your loadout layout has enough space and does not clip enlarged slots.

Studio checks:

- [ ] Select each slot by clicking and by keys 1–6; verify the matching slot enlarges.
- [ ] Place successfully and check the return animation.
- [ ] Try invalid ground or insufficient cash; the slot should remain enlarged if its preview remains active.
- [ ] Cancel using Q and the cancel button; verify normal size returns.
- [ ] Switch slots rapidly; verify one active slot and no accumulated scale changes.
- [ ] Simulate network latency; switch slots while a placement request is pending. Verify an old response cannot shrink the newly active slot or remove its preview.
- [ ] End the match during placement; verify cleanup and return to normal.
- [ ] Check touch, different resolutions, UI scale settings, and slot clipping/spacing, the white outline, and glow fading on deselection.

All 166 game scripts compile. A deterministic fixture executes the actual animator and checks baseline scaling, cancellation, rapid switching, repeated selection, late registration, and cleanup. Visual timing and full placement flow require Studio testing.
