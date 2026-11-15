# Batch 27: fix missing timing locals in wave definitions

## Replace

- [ ] **ModuleScript** `ServerScriptService.Main.Round`
- [ ] **ModuleScript** `ServerScriptService.Simulation.WaveService`

Keep Timer, WaveState, and GameController from batch 26. Restart the Studio play session after both replacements.

Batch 26 removed the old m/s/st locals, but the actual Easy/Normal/Hard wave definitions still referenced them inline. This raised a nil-value error before the first enemy spawned; the new error handler then forced GAME OVER. The earlier overlap fixture exercised the round controller with stub definitions and missed the authored inline writes.

All 78 authored timing entries now live in a local waveTiming table in Main.Round. The controller supplies the current wave's duration and skip threshold to WaveService.Begin before starting its asynchronous spawn job. The actual enemy group definitions no longer write to global timer values. This also prevents a previous wave's delayed job from changing the current wave's timer.

Original durations, skip thresholds, enemy groups, and wave events are preserved. A numeric workspace.Info.WaveDurationSeconds attribute still explicitly overrides duration if you set one; otherwise the original per-wave duration is used. Info.SkipTime mirrors the current wave's authored skip threshold in the original MMSS format.

A spawn-job failure now interrupts wave progression and shows "Wave spawning interrupted" rather than automatically setting GAME OVER. The server still logs the traceback. This avoids both forced defeat and awarding an incomplete wave; a broken definition still needs correction and a new play session.

Verification includes execution of every real Easy, Normal, and Hard definition: 78 waves, 319 enemy groups, and 2,017 authored enemies before map multipliers. Regression tests also cover the real Round.StartGame overlap flow, authored timing application, and spawn-error behavior. The enemy group/event source was compared with the prior version to confirm only inline timing writes were removed.

In Studio, start each difficulty and confirm the first enemies spawn without warnings. Check a later wave with a different authored duration, then skip during spawning and confirm earlier groups continue without resetting the new wave's timer.
