# Batch 43: purchase timescale for 500 gems in a match

## Replace

- [ ] **Script** `ServerScriptService.Datastore`.
- [ ] **ModuleScript** `ServerScriptService.Main.Round`.

## Add

- [ ] **Folder** `ServerScriptService.TimescaleSystem`.
- [ ] **ModuleScript** `ServerScriptService.TimescaleSystem.Purchase`.
- [ ] **LocalScript** `StarterGui.GameGui.TimescaleController`.

## Remove

- [ ] **Script** `ServerScriptService.TimescaleNotify` (the old "Unlock Timescale In Lobby To Use!" notification).

The new TimescaleController owns the button binding. The repository's GameController has no Timescale button handler, so no GameController replacement is required. If an older local handler exists only in your Studio place, remove that handler to avoid two scripts handling the same click. Existing TimescaleVote/TimescaleVoteNo endpoints are unrelated and remain unchanged.

## Existing UI

```text
GameGui (ScreenGui)
├─ Misc
│  └─ Timescale
│     └─ Button (GuiButton)
└─ PurchaseTimescale (Frame)
   ├─ Actions
   │  └─ Purchase (Frame; legacy spelling Puchase is also supported)
   │     └─ Button (GuiButton)
   ├─ Gems
   │  └─ Amount (TextLabel)
   ├─ Message (Frame, optionally containing a TextLabel)
   └─ Close (GuiButton)
```

The menu starts hidden. For nonowners the main button opens it; Close dismisses it. Gems.Amount displays the server-loaded playerData.Gems and updates on load, purchase, reward changes and status refresh. Message is visible only when loaded gems are below 500. Purchase remains clickable with insufficient gems so it can show the exact error through the existing Info.Errors.Error.Message template and Sounds.Error. The error is `You need <missing amount> gems to purchase this!`. Purchase and Close use Activated for mouse/touch/controller support.

On success the server subtracts exactly 500 gems, sets playerData.UnlockedTimescale to numeric 1, updates the read-only client mirrors and closes the menu. Duplicate requests for an owned unlock do not charge. The same loaded profile is saved immediately without awarding match rewards; dirty versions also participate in existing disconnect/shutdown saves and retries. A failed profile load cannot purchase or overwrite data.

The existing Functions.SpeedUp1 / SpeedUp2 remain the 1x / 1.5x controls for owners. They now validate loaded ownership server-side and share a one-second change cooldown. Ownership updates immediately after buying; no rejoin is needed. No speed change is applied automatically by purchasing.

**RemoteFunction** `ReplicatedStorage.Functions.PurchaseTimescale` is created automatically by Datastore. It accepts only `Status` and `Purchase`; clients never supply price, balance or unlock value. No new DataStore is introduced. Keep existing datastore/API settings and test persistence with API access enabled as usual.

## Test

Test 0, 499, exactly 500 and more than 500 gems. Verify Message visibility, exact shortage errors, Close, one deduction on rapid clicks, saved numeric ownership, and immediate owner controls. Rejoin to confirm persistence and test existing owners are never charged. Test a player whose data is not yet loaded. Automated checks execute the actual purchase policy, controller UI, datastore save path and existing currency regressions. Studio verification is still required for actual GUI behavior and persistence.
