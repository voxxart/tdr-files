"""Run the direct attack behavior with real enemy definitions and differing tower HP."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
base = root / 'Tower Defense R/ServerScriptService'
source = (base / 'EnemyAttacks/Behaviors/DirectTowerAttack.luau').read_text()
# Substitute engine imports while executing the production attack body unchanged.
source = source[source.index('local Attack = {}'):]
code = '''local target
local workspace = {Info={Modifiers={['Death Wish']={Value=false}},GameSpeed={Value=1}}}
local Amount = {Flat=function(n) return math.max(0,n or 0) end}
local Match = {Capture=function() return 1 end, Wait=function() return true end}
local Targeting = {Find=function() return target end}
local Damage = {Apply=function(t,n) t.Config.Health.HealthValue.Value=math.max(0,t.Config.Health.HealthValue.Value-n) end}
local Mob = {FacePart=function() end}
local Rep = {Events={AnimateEnemy={FireAllClients=function() end}}}
local Random = {new=function() return {} end}
local Towers = {}
local enemy = {Parent=true,FindFirstChild=function() return nil end,GetAttribute=function() return nil end}
local Attack = (function()
''' + source + '\nend)()\n'
for name, normal, death in [('NoobSoldier',12.5,20),('Knight',25,30),('Executioner',15,20),('Assassin',40,50),('Marauder',None,None)]:
    text = (base / f'EnemyAttacks/{name}.server.luau').read_text()
    definition = ('local definition = ' + text.split('Direct.new(enemy, ',1)[1].split(')',1)[0].strip() if name == 'Marauder' else next(line for line in text.splitlines() if line.startswith('local definition =')))
    code += definition + '\n'
    for hp in [100,1000]:
        for wish, amount in [(False, normal),(True,death)]:
            expected = 0 if amount is None else hp-amount
            code += f'''workspace.Info.Modifiers['Death Wish'].Value={str(wish).lower()}
-- No MaxHealth property: damage must never depend on it.
target={{Config={{Health={{HealthValue={{Value={hp}}}}}}},PrimaryPart={{}}}}
Attack.new(enemy,definition).Run(function() return true end)
assert(target.Config.Health.HealthValue.Value == {expected}, '{name}: wrong flat damage')
'''
code += "print('Direct attacks deal identical HP damage across tower health totals; Marauder remains lethal')\n"
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau') as f:
    f.write(code); f.flush()
    subprocess.run(['/workspace/tools/luau-0.745/luau',f.name],check=True)
