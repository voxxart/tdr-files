# Batch 32: synchronize the volume slider fill

Replace **LocalScript** `StarterGui.GameGui.SettingsController`. No new modules or UI assets are required. Restart the play session.

For the provided `VolumeBar.Slider.End.Button` hierarchy, VolumeBar now remains the full-width input track while Slider's width reflects the current percentage. End stays at the fill edge with its original knob width; the Button's position inside End is preserved. The knob remains visible and inside the full bar at 0% and 100%.

Taps/drags still work across the whole bar, including its empty portion when the fill is zero. Drag input never uses the shrinking fill width. Fill and knob geometry respect UI scaling, and cached authored dimensions prevent fill widths from compounding when controls rebind. Legacy layouts without End retain their earlier optional Fill behavior.

Server settings, audio, saves, and remote behavior are unchanged. Tests cover partial/zero/full fill, unchanged knob width, full-bar interaction after emptying, and rebind stability.

In Studio, check each volume slider at 0%, 50%, and 100%, click the unfilled portion on mobile/mouse, and test the UI size preferences.
