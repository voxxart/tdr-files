# Batch 28: five-second countdown after skipping

Replace **ModuleScript** `ServerScriptService.Main.Round`. Keep the other wave-skip scripts installed. Restart the Studio play session.

A successful skip awards the existing wave reward once, then displays the existing 00:05–00:01 countdown before the next wave begins. It skips the separate two-second reward-message wait, so the intended delay is five game seconds. Existing reward modifiers still apply.

Pending enemies continue spawning throughout the countdown and into the following wave if needed. The countdown respects pause/timescale. Skip votes remain closed during intermission. The legacy ForceNextWaveInstant flag no longer bypasses a successful skip's countdown; its behavior for other transitions is retained.

Countdown arrow spawning runs separately so its own spawn delays do not extend the countdown. This also applies to the existing ordinary intermission countdown.

The round regression fixture verifies the countdown, reward before countdown and once only, pause during intermission, and continued overlapping spawns. In Studio, test a skip during a long spawn sequence, check the reward and five-second display, pause/resume during it, and confirm the next wave begins normally.
