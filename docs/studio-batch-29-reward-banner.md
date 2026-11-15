# Batch 29: reward-only message banner

Replace **LocalScript** `StarterGui.GameGui.GameController`, then restart the play session. No new modules, events, or UI assets are needed.

The `gui.Info.Messages` banner now displays only `Wave Reward: $...` messages. Victory/defeat and other server status messages do not appear there. The existing result screen still opens for VICTORY/GAME OVER; the server's gameplay status values are unchanged.

A reward stays visible for five real seconds after its 0.4-second entrance, then fades/slides out over 0.4 seconds. The server clearing Info.Message during the countdown no longer erases the reward immediately. A new reward replaces the old one and refreshes the hold. Versioned callbacks and cancelled tweens prevent earlier timers or outros from hiding the new message. Result-screen transitions hide the banner immediately.

This is presentation only: wave payouts, skip votes, spawn overlap, and the five-second game-time intermission are unchanged. At increased timescale, the reward can remain visible into the next wave intentionally.

Test an ordinary wave clear and a skip, including at increased timescale. Confirm the reward stays readable, only the newest reward is shown, and neither TRIUMPH nor YOU LOSE appears in the banner. Confirm the normal victory/defeat result screen still opens once.
