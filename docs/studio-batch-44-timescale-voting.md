# Batch 44: timescale votes and mode-dependent cooldowns

## Replace

- [ ] **ModuleScript** `ServerScriptService.Main.Round`.
- [ ] **LocalScript** `StarterGui.GameGui.TimescaleController`.

## Add

- [ ] **ModuleScript** `ServerScriptService.TimescaleSystem.VoteState`.
- [ ] **ModuleScript** `ServerScriptService.TimescaleSystem.Controller`.
- [ ] **LocalScript** `StarterGui.GameGui.TimescaleVoting`.

Keep the TimescaleSystem Folder and Purchase module from batch 43. Keep the purchase UI and server data scripts. No GameController update is needed. Restart the play session.

## Existing vote UI

```text
GameGui
└─ TimescaleVote (Frame)
   ├─ ButtonArea
   │  ├─ Yes
   │  │  └─ Button (GuiButton)
   │  └─ No
   │     └─ Button (GuiButton)
   └─ Title (TextLabel)
```

The Title becomes `Increase Timescale to 1.5x (yes/players)` or `Decrease Timescale to 1x (yes/players)`. If you add an optional TextLabel named Timer or Countdown directly inside TimescaleVote, it displays seconds left. Without it, the 15-second deadline still works. The frame exposes SecondsRemaining and VoteFailed attributes; Misc.Timescale exposes CooldownRemaining for custom visual styling. No authored Message text in the purchase menu is modified.

## Rules

All deadlines use real server seconds, independent of game speed.

- Solo: an owner changes speed immediately; a server-wide 15-second cooldown starts at that change.
- Multiplayer: an owner starts a 15-second vote. Every current player, including nonowners and the requester, must explicitly vote Yes. The requester is not automatically counted. All Yes applies the requested speed immediately, closes the vote and starts a 60-second cooldown.
- One No permanently vetoes that vote and starts its 60-second cooldown immediately. The panel stays visible until the original 15-second deadline; other players can still submit their choices, but cannot undo the veto. The cooldown does not restart when the panel closes.
- If time expires without unanimity, speed stays unchanged and the 60-second cooldown starts at the deadline.
- Each player can submit one choice per vote. Stale vote IDs, duplicate/outsider votes and concurrent requests cannot change speed. A vote already in progress prevents another request. Membership changes update the required count; leavers are excluded and new arrivals join the electorate. A veto remains final even if its voter leaves.
- Match end closes an active panel. Purchasing the unlock still only unlocks access; it does not change speed or bypass cooldowns.

The server creates RemoteFunctions `ReplicatedStorage.Functions.RequestTimescale` and `VoteTimescale`. Existing SpeedUp1/SpeedUp2 and TimescaleVote/TimescaleVoteNo endpoints route through the same controller, preventing old calls from bypassing the new rules. Round no longer uses the legacy vote counters to determine results. Info.TimescaleState is a server-owned JSON attribute for client UI recovery.

## Test

Test solo changes at 0/14/15 seconds; two-player unanimous votes in both directions; a No followed by Yes from everyone else; no response timeout; duplicate/stale votes; new arrivals and departures; and match-end cleanup. Verify the failed panel stays visible until the deadline and the cooldown starts only once. Automated state/service/UI tests cover these transitions; Studio is required for multiplayer UI verification.
