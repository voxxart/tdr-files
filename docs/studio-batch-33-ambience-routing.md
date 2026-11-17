# Batch 33: ambience volume after map loading

Replace **ModuleScript** `ReplicatedStorage.GameModules.SettingsAudio`. No other script or UI replacement is needed. Restart the Studio play session.

Map loading reparents an existing ambience Sound into Workspace.Ambience. The original router watched only Workspace.DescendantAdded, which can miss a reparent between descendants already inside Workspace. The slider changed its channel volume while the playing Sound remained outside that channel.

The router now observes the audio category folders directly, recognizes map-local Ambience/Ambient folders, and reroutes a tracked Sound when its category changes. Small ambience/music source sets also watch SoundGroup so a later routing reset cannot silently bypass their slider. There is no per-tower sound listener or per-frame sound scan.

Folder listeners are removed when their roots leave Workspace or are destroyed. Sound listeners disconnect on removal, category change, and controller destruction. Original Sound.Volume values and authored SoundGroup mixing remain preserved; server boss-music fades are not overridden.

Tests simulate the map-loading move without firing Workspace.DescendantAdded, verify mute for moved/map-local sounds, check a later SoundGroup reset, and move a sound between ambience/music channels. In Studio, load a map, set ambience to 0%, then restore it and check music/tower sliders remain independent.
