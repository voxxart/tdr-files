# Batch 45: secondary-only unit lead detection

Replace both existing **ModuleScripts**:

- [ ] `ServerScriptService.UnitSystem.Targeting`.
- [ ] `ServerScriptService.UnitSystem.Combat`.

To let only the secondary attack damage lead, use these **BoolValues** in each unit template (including skin variants):

```text
Config
├─ LeadDetection = false
└─ SecondaryAttack
   └─ LeadDetection = true
```

SecondaryAttack.LeadDetection overrides the main setting only for secondary damage, including every enemy hit by its splash. Explicit false disables secondary lead damage even when the main setting is true. If the secondary value is absent, it inherits the existing Config/EnemyStats LeadDetection behavior. Primary, ram, death splash and hidden detection are unchanged. Units still attempt attacks against lead without detection, but deal no damage.

Restart the play session. Automated integration checks cover secondary-only detection, explicit false, and both enabled/disabled inheritance cases with the actual combat and detection modules.
