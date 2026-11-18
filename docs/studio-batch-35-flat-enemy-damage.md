# Batch 35: flat enemy damage to towers

Replace these existing scripts together and restart the play session. No new instances or events are needed.

- [ ] **ModuleScript** `ServerScriptService.Simulation.DamageAmount`
- [ ] **ModuleScript** `ServerScriptService.EnemyAttacks.Behaviors.DirectTowerAttack`
- [ ] **ModuleScript** `ServerScriptService.EnemyAttacks.Behaviors.Marksman`
- [ ] **Script** `ServerScriptService.EnemyAttacks.NoobSoldier`
- [ ] **Script** `ServerScriptService.EnemyAttacks.Knight`
- [ ] **Script** `ServerScriptService.EnemyAttacks.Executioner`
- [ ] **Script** `ServerScriptService.EnemyAttacks.Assassin`
- [ ] **Script** `ServerScriptService.EnemyAttacks.Honorary`
- [ ] **ModuleScript** `ServerScriptService.EnemyAttacks.Bosses.Noobicus`
- [ ] **ModuleScript** `ServerScriptService.EnemyAttacks.Bosses.NoobJuggernaut`
- [ ] **ModuleScript** `ServerScriptService.EnemyAttacks.Bosses.Doombringer`
- [ ] **ModuleScript** `ServerScriptService.EnemySystem.EnemyService`

## Damage values

Former percentages use a 100-HP reference. Values now subtract HP directly, including decimals, regardless of tower maximum health.

| Attack | Normal HP damage | Death Wish HP damage |
| --- | --- | --- |
| Noob Soldier | 12.5 | 20 |
| Knight | 25 | 30 |
| Executioner | 15 | 20 |
| Assassin / Marksman | 40 | 50 |
| Doombringer minigun | 2.5 | 3.13 |

Noobicus airstrike primary deals 90 (77 against flying towers); splash deals 30 (8 against flying towers); stomp deals 10. Juggernaut hits deal 2.5, with 5 per DOT tick. Doombringer DOT deals 5 per tick and stomp deals 10. Honorary slam deals 100 and stomp deals 10. Enemy death explosions deal 12.5 to eligible ground towers.

Already-flat attacks retain their damage. Explicit execution/instant-kill abilities remain lethal. Enemy/unit health scaling and unit death damage against enemies are unchanged.

## Studio checks

Compare the same attacker against towers with different maximum HP: each hit should remove the same amount. Check Death Wish damage, boss DOT/splash, tower death cleanup, and enemy death explosion flyer exclusions. Automated checks compile all game scripts and run the direct-attack behavior across 100-HP and 1,000-HP targets; Studio is needed to verify the full engine effects.
