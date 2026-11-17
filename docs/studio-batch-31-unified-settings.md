# Batch 31: unified settings, sliders, fitted UI scale, and VFX quality

Install the whole batch together, remove the old handlers, then start a fresh Studio play session. Settings have one client entry script and one server entry script. The ModuleScripts below are their reusable implementation, not additional independently running handlers.

## Add entry scripts

- [ ] **LocalScript** `StarterGui.GameGui.SettingsController`
- [ ] **Script** `ServerScriptService.PlayerSettings.Controller`

## Add modules

All six are **ModuleScripts** directly under `ReplicatedStorage.GameModules`:

- [ ] `SettingsSchema`
- [ ] `SettingsMath`
- [ ] `SettingsAudio`
- [ ] `SettingsScale`
- [ ] `SettingsEffects`
- [ ] `VFXPolicy`

## Replace existing scripts

- [ ] **LocalScript** `StarterGui.GameGui.GameController`
- [ ] **LocalScript** `StarterPlayer.StarterPlayerScripts.Animations`
- [ ] **LocalScript** `StarterPlayer.StarterPlayerScripts.EnemyExplosion`
- [ ] **LocalScript** `StarterPlayer.StarterPlayerScripts.EventCurrency`

GameController no longer binds any obsolete FullSettings tab or Timescale-page paths. The timescale system and its global notification are retained, but the supplied new layout has no Timescale page to bind. Its old missing controls no longer stop GameController initialization.

## Delete old client handlers

Remove these **LocalScripts**, wherever their copies currently sit inside the Studio settings UI. Their repository sources were grouped under StarterGui/PlayerSettings, but their old code used script.Parent as an individual section, so actual Studio placement may differ.

- [ ] `TowerSounds`
- [ ] `AmbientSounds`
- [ ] `MusicSounds`
- [ ] `DialogueSettings`
- [ ] `UIScale`
- [ ] `VFXSettings`

## Delete old server handlers

Remove these six **Scripts** from `ServerScriptService.PlayerSettings`:

- [ ] `VolumeTowers`
- [ ] `VolumeAmbience`
- [ ] `VolumeMusic`
- [ ] `Dialogue`
- [ ] `UIScale`
- [ ] `VFX`

Only the new Controller Script should run in that folder. Do not keep old handlers enabled: they would race the new owner, restore old defaults, and apply volume twice.

## Retired settings remotes

These have no remaining repository consumers after the old handlers are removed. Delete their settings-only instances in `ReplicatedStorage.Events`:

- [ ] **RemoteEvent** `VolumeChange`
- [ ] **RemoteEvent** `VolumeChangeAmbience`
- [ ] **RemoteEvent** `VolumeChangeMusic`
- [ ] **RemoteEvents** `VFX.High`, `VFX.Low`
- [ ] **RemoteEvents** `Dialogue.On`, `Dialogue.Off`
- [ ] **RemoteEvents** `UiScale.Small`, `UiScale.Default`, `UiScale.Large`, `UiScale.ExtraLarge`

Empty VFX/Dialogue/UiScale folders can also be removed; retain unrelated events if your Studio project has additional scripts not in the repository. Keep all existing gameplay timescale remotes. The new server creates **RemoteEvent** `Events.PlayerSettingChange` automatically.

## New layout bindings

The controller lives directly under GameGui and expects the provided hierarchy:

```text
GameGui
  Misc.Settings.Button               (current open control)
  FullSettings
    Frame                            (decorative line; unchanged)
    Close                            (ImageButton or wrapper containing a button)
    SettingsArea
      SoundSettings
        Towers.VolumeBar.Slider.End.Button
        Ambience.VolumeBar.Slider.End.Button
        Music.VolumeBar.Slider.End.Button
      GeneralSettings
        Dialogue.ButtonSection.Default.Button
        Dialogue.ButtonSection.Off.Button
        VFX.ButtonSection.High.Button
        VFX.ButtonSection.Low.Button
        UIScale.ButtonSection.Small.Button
        UIScale.ButtonSection.Default.Button
        UIScale.ButtonSection.Large.Button
```

The old Settings.OpenSettings.Button opener is also accepted as a fallback. The current Misc.Settings.Button opener and updated SkipFrame.ButtonArea paths from the latest GitHub edits are preserved, along with the edited three-second reward banner hold.

Direct ImageButton/TextButton options and wrappers with Button/Upgrade children are supported. A sound section named Volume is accepted as an alias for Music. Both SoundSettings and GeneralSettings stay visible; there are no obsolete category-tab handlers. Frame, SettingsName, aspect ratio, corners, strokes, layout constraints, and authored sizes/vertical positions remain customizable.

Each VolumeBar.SectionTitle text label is used for the percentage. An existing Frame named Fill under the track is updated if present; none is generated. VolumeBar is the fixed interaction track, Slider is the green fill, End is the moving knob wrapper, and End.Button is its interactive ImageButton (batch 32). The Slider width follows the percentage without shrinking the knob. The entire VolumeBar and Slider track accept taps/clicks/drags, so grabbing the small knob is unnecessary. End moves as a unit; its inner Button keeps its authored position. Legacy layouts without End are also supported: a wide Slider frame is treated as the track; a narrow Slider frame is treated as a moving knob wrapper inside VolumeBar. For a legacy layout without End, if your custom dimensions make that heuristic wrong, set a **boolean attribute** `SettingsSliderTrack` on Slider: true means Slider is the full track; false means it is the moving wrapper.

## Sound sliders

Mouse click/drag and touch work continuously between 0 and 100 percent (saved with 0.1-percent precision). Knobs remain inside their track and use scale-relative X positioning so UI scaling does not distort the endpoints. Focused sliders support keyboard left/right (1%), Home/End, and gamepad D-pad left/right (5%); D-pad up/down remains available for navigation. Mouse/touch changes commit once at release; keyboard changes are debounced. Focus loss and closing the menu finish the active drag. Additional touches do not hijack it.

Three local SoundGroup channels change volume immediately without rescanning sounds for each slider movement. Authored Sound.Volume values are preserved; 100% means the authored mix, rather than the old blanket 0.1/0.5/2 assignments. Existing SoundGroup volumes/effects are routed through bounded cached copies, and dynamic sounds are handled as they appear. Clones of already-routed sounds do not get attenuated twice.

- Music: workspace.Music descendants.
- Ambience: workspace.Ambience descendants.
- Towers: workspace.Towers, Mobs, Units, and Visual descendants (combat audio).
- Optional **string attribute** SettingsCategory on a workspace Sound selects Towers/Music/Ambience explicitly.

UI sounds and unrelated workspace sounds retain their authored mix unless explicitly categorized. Music and ambience now use separate saved attributes; the old server scripts incorrectly shared MusicVolumePercent.

## UI scaling

Small = 0.9, Default = 1, Large = 1.1 preferred panel scale. Top-level panels are fitted around their authored anchors to their parent's available screen area. Full-screen layout containers are left alone and their direct panels are considered instead. Actual panel scale is capped by available space, so Large may match Default on a constrained display rather than overflow the screen.

The controller changes a panel's root UIScale only. It does not overwrite every nested UIScale or compound the preference through nested descendants. Camera viewport changes trigger a fit pass; panel size/visibility changes are handled without a permanent full-UI scan every frame. Authored anchor points should be inside the screen; intentionally offscreen positions are not pulled back during animation.

Transient Cash, Messages, and hover-card roots are excluded by default to avoid fighting their animation/positioning logic. Optional **boolean attribute** SettingsScalable=true opts a specific GuiObject into management; SettingsScaleIgnore=true opts it out. New ScreenGuis and explicitly opted-in UI objects are supported. Existing scales are restored if the controller is destroyed.

## VFX and dialogue

The server owns the existing Player.VFX and Player.Dialogue StringValues for compatibility. The new client does not create competing duplicate values or blindly reset saved choices. Clicked choices apply locally immediately, then synchronize through the validated settings event. Existing gradient styles EnabledVFX/Disabled are used when present; Selected attributes are also updated on the choice wrapper/button.

Low quality reduces continuous emitter Rate to 25%, including newly created emitters, without enabling emitters authored as disabled. High restores the original rates and the authored Lighting.GlobalShadows state rather than unconditionally forcing shadows on. Existing particles finish naturally; emitters are not globally destroyed. Weak emitter tracking and shared descendant listeners replace the old unused all-workspace particle cache.

110 burst emission sites in Animations, enemy explosion bursts, and event-currency pickup bursts now use VFXPolicy. Low uses quarter-count bursts capped at 24 particles each and 96 per approximately 1/60-second time slice; High caps individual bursts at 120 and the shared slice at 512. A VFXEssential boolean attribute preserves at least one particle for a nonzero small Low request while budget remains. Heavy simultaneous effects degrade within fixed limits instead of emitting an unbounded burst. Existing Low-aware bullet/death presentation also receives the correct Player.VFX value. Gameplay, damage, projectile geometry, and essential target interaction are unchanged.

## Persistence

Settings are validated on the server and stored together in UnifiedPlayerSettingsV1. A missing unified record is migrated from the six original preference stores and keys; old stores are read but not modified/deleted. Saved ExtraLarge UI scale maps to Large because the new layout has three choices.

Changes update the loaded settings record and replicated attributes. They do not make per-drag datastore calls. Dirty saves are coalesced, with at least 30 seconds between autosaves after a short quiet period; leave/shutdown flush the latest values. Invalid/non-finite values and unknown keys are rejected. The remote uses a token budget to limit spam. If saved data cannot be read, session settings remain usable but are not written over unknown saved preferences. These failures are logged server-side.

The new store is separate from OfficialTDRGameData; gameplay currency, rewards, and the core Datastore script are unchanged.

## Studio testing

1. Remove the old handlers, install all additions/replacements, and restart. Confirm the menu opens/closes with the new layout and no missing-path warnings.
2. Drag each slider to 0%, a middle value, and 100%. Check click-to-seek, dragging outside the track, touch, focused keyboard/D-pad input, focus loss, and closing while dragging.
3. Verify music and ambience remain independent. Test existing and newly spawned tower/ability sounds, and confirm 0% stays muted for new sounds.
4. Rejoin with known old preferences, change them, then rejoin again. Confirm migration, separate channel values, Low/Off state, and retained UI-size preference.
5. Test Small/Default/Large on desktop and phone-sized viewports, including portrait/landscape and resizing while the menu is open. Check settings, upgrade panel, HUD panels, selected tower slot animations, hover cards, and wave reward animation.
6. Toggle Low/High during combat. Check particle reduction, disabled template emitters staying disabled, restoration of the map's original shadows, and new effects respecting the chosen quality.
7. Respawn/reopen/rebuild the settings GUI and test for duplicate handlers, muted sounds unexpectedly returning, or stale slider drags.

Automated fixtures execute the real unified server/controller/modules using deterministic engine boundaries. They cover preference migration and failed-load protection, validation/rate limits/coalesced saving, the supplied hierarchy, mouse/touch/keyboard sliders, release-only commits, audio independence/authored mixing/dynamic clones, VFX budgets/restoration, viewport fitting, nested animation scales, and cleanup. Roblox Studio remains necessary to validate the actual UI assets, SoundGroup mix, touch/gamepad feel, and live datastore behavior.
