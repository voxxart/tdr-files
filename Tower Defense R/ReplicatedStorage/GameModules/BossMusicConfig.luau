-- Sound paths are relative to Workspace.Music. Fade values are real seconds.
return {
 FadeSeconds=4,
 -- Preserve the old Plague/Valor authored fade targets; others use Sound.Volume.
 TrackVolumes={['HardMode.Plague']=2,['HardMode.Valor']=2},
 Modes={
  Easy={FinalWave=20,FinalBoss='General Noobicus',FinalTrack='Noobicus',Bosses={[8]='Noob Soldier',[13]='Noob Doctor',[17]='Noob Juggernaut'}},
  Normal={FinalWave=26,FinalBoss='Doombringer',FinalTrack='Endbringer',Bosses={[7]='Executioner',[15]='MEU',[24]='Resurrected Noob Gaurdian'}},
  Hard={FinalWave=32,FinalBoss='Swordmaster',FinalTrack='HardMode.DuelOfCalamity',Bosses={[10]='Marksman',[17]='Merchant'},
   Music={['Plague Doctor']='HardMode.Plague',Honorary='HardMode.Valor'}},
 },
}
