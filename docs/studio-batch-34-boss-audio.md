# Batch 34: per-player boss music and ambience transitions

Install all six scripts together, replace the old BossSetups rather than adding another copy, and restart the Studio play session.

## Replace

- [ ] **Script** `ServerScriptService.BossSetups`
- [ ] **ModuleScript** `ServerScriptService.Simulation.WaveService`
- [ ] **ModuleScript** `ReplicatedStorage.GameModules.SettingsAudio`
- [ ] **LocalScript** `StarterGui.GameGui.SettingsController`

## Add

- [ ] **ModuleScript** `ReplicatedStorage.GameModules.BossMusicConfig`
- [ ] **ModuleScript** `ReplicatedStorage.GameModules.BossMusicMixer`

Keep the unified settings server and other settings modules from previous batches. No new RemoteEvents, UI objects, or sound assets are required. The server publishes one atomic JSON attribute, `workspace.Info.BossAudioSnapshot`, for late-client recovery and scene changes. WaveService also publishes `WaveActive` so intermission closes a boss-music scene without waiting for the next wave number.

## Existing music covered

Sound paths are relative to Workspace.Music:

| Mode / boss | Sound path | Behavior |
| --- | --- | --- |
| Easy final wave 20 / General Noobicus | Noobicus | Final ambience lock |
| Normal final wave 26 / Doombringer | Endbringer | Final ambience lock |
| Hard / Plague Doctor | HardMode.Plague | Non-final boss scene |
| Hard / Honorary | HardMode.Valor | Non-final boss scene |
| Hard final wave 32 / Swordmaster | HardMode.DuelOfCalamity | Final ambience lock |

Final themes retain the wave-start behavior rather than waiting for the final boss to finish its spawn delay. The configured final boss ending stops its theme; the ambience lock remains. A non-final scene ends when its boss dies/leaves or the wave closes, including a skip with the boss still alive.

## Mixing and fades

Actual theme output combines the Sound's base volume, the player's Music slider, and a separate 0–1 fade gain. Ambience similarly combines its authored mix, the player's Ambience slider, and a separate scene-suppression gain. Changing a preference updates only the user channel, so even a 100% ambience setting cannot bypass a scene gain of zero.

Default fades last four real seconds and use smooth easing. They are independent of game timescale. Music fades in as ambience fades out. When a non-final boss scene ends during a continuing match, the music fades out and ambience fades back toward the player's current setting, including changes made while it was muted. Muting Music does not release the ambience lock while the boss scene is active.

A final-wave ambience lock persists after the final boss dies and throughout victory/defeat. Defeat in a non-final wave also keeps ambience suppressed. Music fades out on results; there is no scheduled delayed callback that can revive ambience afterward. Terminal/final controller cleanup stops remaining ambience sounds before removing local groups, preventing cleanup from making them audible again.

Themes loop while active and stop without destroying their assets. Original looping/volume properties are restored when a theme finishes or the controller is destroyed. Plague and Valor retain the old base-volume target of 2 via TrackVolumes; other themes use their authored Sound.Volume. User volume remains a separate multiplier in all cases. Late clients immediately honor an existing ambience lock and seek a loaded theme using its server start timestamp.

## Multiple bosses and lifecycle

All live instances sharing a theme are tracked; killing one does not end the theme if another remains. If different non-final music bosses overlap, the most recently added active theme takes priority; a surviving earlier theme can return when the newer boss ends. The final-wave theme takes priority over miniboss music.

The Honorary handler no longer uses the Plague Doctor's flag. Death attributes, health reaching zero, removal, wave end, and match end release the corresponding boss records and their connections. Server tracking is limited to music bosses, with no full-mob scan each frame. Client fades run through the existing unified SettingsController frame update; there is no separate music LocalScript or per-boss Heartbeat fade worker.

Existing milestone IsBoss markers are retained. Boss targeting, attacks, rewards, and player preference persistence are unchanged. Existing server modifier ambience playback/fades retain their own Sound.Volume behavior; the personal slider and boss scene gain multiply that authored behavior.

## Configuration

`BossMusicConfig.FadeSeconds` controls the transition length. Modes contains final wave/boss/track names and miniboss music mappings. TrackVolumes optionally supplies a base-volume target for a sound path.

A non-final boss model may have a **string attribute** BossMusicPath pointing to another existing Sound beneath Workspace.Music (dot-separated path). It uses the same current-wave lifecycle and mixing. Missing paths warn server-side rather than throwing. Actual asset loading/permissions still need Studio verification.

## Studio tests

1. Set Music to a low percentage before spawning each music boss. Verify its fade-in never jumps to full volume. Change Music during the fade and at full playback, including 0%.
2. Check ambience fades out as the theme begins. Move Ambience between 0% and 100% while the boss is alive; it must remain silent once the fade completes. Add/move a new ambience Sound during the lock too.
3. Kill the last non-final music boss and verify ambience fades to the latest slider setting. Test two instances of the same boss and overlapping Plague/Honorary bosses.
4. Skip/end the non-final wave while its boss survives. Verify the theme ends and ambience can return during intermission.
5. Test Easy 20, Normal 26, and Hard 32. Kill the final boss while other enemies remain: music may fade out, but ambience must not return. Verify victory and defeat stay silent on the ambience channel.
6. Lose during a non-final theme/fade-back and verify no later fade-in starts. Check result-screen sounds still play normally.
7. Rejoin or rebuild the settings GUI during an active boss. Confirm personal settings still apply, the theme can recover, and ambience does not blip at full volume. Restart another match and ensure themes are reusable.

The automated integration fixture runs the actual server boss lifecycle, audio routing, and client mixer together. It covers user-volume multiplication during fades, suppressed slider changes, moved/new ambience sounds, shared/different bosses, wave-end release, every configured final mode, defeat, late callbacks/clients, property restoration, asset reuse, and cleanup. The complete regression suite also retains the existing settings, wave, animation, and currency checks.
