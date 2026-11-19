# Batch 42: unit detection, Reaper soul accounting and tower AOE eligibility

Replace together:

- [ ] **ModuleScript** `ServerScriptService.UnitSystem.Targeting`.
- [ ] **ModuleScript** `ServerScriptService.UnitSystem.Combat`.
- [ ] **ModuleScript** `ServerScriptService.UnitSystem.Damage`.
- [ ] **ModuleScript** `ServerScriptService.UnitSystem.Death`.
- [ ] **ModuleScript** `ServerScriptService.Main.TowerServer`.

No new scripts or remotes. Restart the play session.

## Unit settings

Add optional **BoolValues** to each unit template's **Config**:

- `LeadDetection = true`: enables damage to lead enemies. Missing/false means the unit still targets and plays attacks against lead, but cannot damage it.
- `HiddenDetection = true`: enables targeting/damaging hidden enemies. Missing/false means hidden enemies are ignored.

These settings can also be authored under **EnemyStats** when Config has no value with that name; Config takes precedence, including explicit false. Unit settings are independent of the owner tower's detection. Apply them to Default and skin unit templates as needed.

Primary, secondary and unit AOE damage respect these rules. Death splash also respects detection. Ramming cannot select undetected hidden enemies or damage undetected lead enemies, though the existing physical ram health cost still applies when colliding with lead. Flying enemies remain excluded by the existing unit rules.

## Reaper

Unit damage still contributes to its exact owning tower's TotalDamage counter, including shield and death-splash damage. The counter's cumulative `UnitDamage` attribute records that origin before TotalDamage changes. Reaper soul tracking subtracts these increments, while preserving progress from the tower's own damage, soul caps and spending behavior. No extra polling is added. Damage already credited before this code is installed cannot be retroactively classified; restart the session.

## Tower AOE

AOE follow-up swings now require the tower's enabled LeadDetection, FlyingDetection and HiddenDetection for those enemy types. Dead/invincible enemies are excluded, and successful shield hits count toward MaxHits. This fixes splash-around-another-target bypasses without altering ordinary projectile splash rules.

## Test

Compare units with missing, false and true detection flags against lead/hidden enemies; verify lead attack animations still play without damage. Check secondary fire, unit AOE/death effects and skins. Compare Reaper's own hits versus summon hits: both increase TotalDamage, only tower hits advance souls. Test tower AOE with normal targets beside lead/flying/hidden enemies, with detection disabled and enabled. Automated checks exercise actual unit combat/targeting, source accounting and Reaper listeners, and tower AOE filtering.
