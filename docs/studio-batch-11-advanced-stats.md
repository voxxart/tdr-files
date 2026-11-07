# Batch 11: per-level advanced stat dropdowns

## Install

- [ ] Replace **LocalScript** — `StarterGui.GameGui.GameController`
- [ ] Replace **ModuleScript** — `ServerScriptService.TowerSystem.TowerStats`
- [ ] Add **ModuleScript** — `ReplicatedStorage.GameModules.AdvancedStatsData`
- [ ] Add **ModuleScript** — `ReplicatedStorage.GameModules.AdvancedStatsUI`
- [ ] Optionally update **ModuleScript** — `ReplicatedStorage.GameModules.TowerData`; its only repository change is a format comment. Keep your own data edits and add groups as below.

No new events or required manual UI objects. The host is the existing **ScrollingFrame** `StarterGui.GameGui.UpgradeUI.Stats.Main`. Its existing layout is retained; a UIListLayout is created only if absent. Main's AutomaticCanvasSize, CanvasSize, AutomaticSize, Size, and Position are left unchanged. Configure its scroll range yourself to accommodate expanded groups.

## TowerData format

Add up to ten independently titled tables directly inside the desired upgrade level. Each accepts up to nine strings, in One–Nine order:

```luau
Upgrades = {
    [2] = {
        UpgradeName = "Your existing upgrade",
        Cost = 1000,
        -- Your existing gameplay stats stay here.
        AdvancedStats1 = {
            Title = "Special Attack",
            One = "Describe the attack here.",
            Two = "Describe its cooldown or conditions here.",
            Three = "Another detail.",
        },
        AdvancedStats2 = {
            Title = "Passive Effects",
            One = "Describe the passive effect here.",
        },
    },
},
```

Names are `AdvancedStats1` through `AdvancedStats10`. Groups display in numeric order, including when numbers are skipped. Entry names are `One`, `Two`, `Three`, `Four`, `Five`, `Six`, `Seven`, `Eight`, `Nine`. Missing, empty, or non-string entries are hidden; groups with no valid entries are hidden. Ordered string arrays are also supported: `AdvancedStats1 = {Title = "Abilities", "First detail", "Second detail"}`.

These are Luau strings in tables, not StringValue instances. Text is informational and does not change damage, attacks, or other gameplay behavior. Do not put these groups inside `Config` or merged `Stats`.

A group in `Upgrades[2]` appears while inspecting a placed level 2 tower. It disappears at level 3 unless that level defines its own group. For level 0, put the groups directly on the tower definition alongside Cost, Stats, and Upgrades. They are not inherited and do not preview the next level.

## Generated UI and custom template

Closed groups retain the template's exact authored UDim2, including `{0.924, 0}, {0.095, 0}`. Generated instances are direct children of Main so the Y scale has the same reference as the template. Expansion preserves those scale components and adds only the measured text height plus 16 pixels to the Y offset; closing restores the original UDim2. The fallback template also uses `{0.924, 0}, {0.095, 0}`. Clicking its header toggles expansion with a 0.25-second easing animation and animated arrow. Height follows visible wrapped text and updates when content layout changes. Groups open independently. Switching towers or levels closes the groups; refreshing the same tower and level preserves open state. Up to ten group frames are pooled and reused instead of recreated on every selection.

To keep and customize the generated design:

1. Run Play in Studio, then locate your local player's `PlayerGui.GameGui.UpgradeUI.Stats.Main.AdvancedStatsTemplate`.
2. Copy that **Frame** while playing, stop Play, and paste it into `StarterGui.GameGui.UpgradeUI.Stats.Main`.
3. Keep its exact name `AdvancedStatsTemplate` and set Visible to false. Customize its colors, fonts, corners, strokes, and spacing. The renderer will clone this saved template instead of generating a default one.

Keep this required structure:

```text
AdvancedStatsTemplate (Frame; ClipsDescendants = true)
  Toggle (TextButton; Size = {1, 0}, {0, 55})
    Title (TextLabel)
    Arrow (TextLabel or ImageLabel; Rotation animated)
  Content (Frame; Position Y offset = 55; AutomaticSize = Y)
    UIListLayout
    One (TextLabel)
    Two (TextLabel)
    Three (TextLabel)
    Four (TextLabel)
    Five (TextLabel)
    Six (TextLabel)
    Seven (TextLabel)
    Eight (TextLabel)
    Nine (TextLabel)
```

Keep all nine labels, even for groups with fewer entries. Labels should use TextWrapped=true, AutomaticSize=Y, and a width filling Content. The default content has 14-pixel horizontal inset, 8-pixel row spacing, and 16 pixels below the last item. The live copy resolves Toggle height from its authored size at the closed height, so a full-size `{1, 0}, {1, 0}` Toggle stays confined to the header during expansion. Content keeps its authored X position, width, and anchor; its live Y position and height are calculated to fit below the header. A centered Content anchor of `0.5, 0.5` is supported. The saved template is not modified. The 16-pixel bottom spacing is configured in AdvancedStatsUI. Keep the template a direct child of Main; generated instances are named AdvancedStats1–10 directly under Main, after existing rows by LayoutOrder.

The saved template is used at startup; edit outside Play and restart to preview changes. The template is never edited or destroyed by normal selection changes. If no template is supplied, a default is generated once per controller lifetime.

## Test in Studio

- [ ] Add one group at one level; verify it appears only at that current level, including at max level.
- [ ] Test several groups, including AdvancedStats10, and all nine strings. Verify numeric group and One–Nine text order.
- [ ] Test missing entries and long wrapping text at different resolutions and UI scales. Confirm no clipped last row and sufficient manually configured scroll range. Confirm Main canvas settings remain unchanged.
- [ ] Open several groups independently, close them, and click repeatedly mid-animation.
- [ ] Upgrade, switch towers, sell, and remove the selected tower. Verify no stale groups and no accumulating frames/connections.
- [ ] Test mouse, touch, and gamepad activation of the header; clicking UI must not select towers behind it.
- [ ] Save and customize a generated template; restart and confirm its design is used.
- [ ] Check existing upgrade comparison rows, ability controls, placement animations, and combat stats remain correct.

## Validation

All 168 game scripts compile. Eighteen Luau test files and seven Python fixtures pass. New fixtures exercise actual data parsing, generated/custom templates, ordered labels, expansion heights, interrupted toggles, pooling, exact-level switching, cleanup, and server exclusion of display metadata. Actual text measurement, UI layout, scroll sizing, and animation appearance require Studio testing.
