# Batch 46: direct tower damage credit must match actual damage

Replace both **ModuleScripts** together:

- [ ] `ServerScriptService.TowerSystem.DirectDamage`.
- [ ] `ServerScriptService.TowerSystem.PrimaryAttack`.

Restart the play session. No new objects or balance values.

Blocked direct hits against lead or invincible enemies now credit zero TotalDamage, so Reaper cannot earn souls from them. LeadDetection must be enabled, including honoring explicit false; merely having a false BoolValue no longer bypasses lead immunity. Units are unaffected by this change.

DirectDamage returns actual HP/shield damage removed as a second return value, preserving its existing first return value for reward logic. PrimaryAttack credits this amount instead of configured raw damage. Defense reductions, zero-damage hits and overkill are reflected correctly. Shield damage still counts, without overflowing into health. Blocked attacks still play their normal attack/lead-hit feedback. Existing splash and special-attack accounting are unchanged.

Test Reaper against lead without detection, with false detection, and with true detection; compare TotalDamage and soul progress. Also test invincible enemies, low-health enemies, shields and defense. Automated coverage executes the real direct damage and primary modules for those cases, and the existing Reaper accounting tests remain in the suite.
