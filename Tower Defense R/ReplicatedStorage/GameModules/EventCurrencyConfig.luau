-- Chance is 0..1. CurrencyKey is a numeric field in the player's saved data.
return {
 Enabled=true,
 CurrencyKey='EventCurrency',
 QuotasEnabled=true,
 ModeQuotas={Easy=145,Normal=315,Hard=650},
 CompleteQuotaOnVictory=true, -- credit the remaining amount on a successful run

 DropChance=0.10,
 MinAmount=1,
 MaxAmount=5,
 Lifetime=30, -- game seconds, including the launch
 PickupRadius=6,
 LaunchDuration=0.65,
 ArcHeight=5,
 ScatterMin=2,
 ScatterMax=6,
 BounceDuration=0.9,
 MinBounces=2,
 MaxBounces=3,
 BounceHeight=0.8,
 GroundOffset=0.1,
 MinFloorNormalY=0.75,
 MaxFloorRise=1.5,
 FloorSearchDepth=32,
 LandingAttempts=3,
 LandingChecksPerFrame=24,
 LandingClearanceRadius=0.35,
 LandingClearanceHeight=1.5,
 CollectionDuration=0.4,
 CollectionOrbs=1,
 PickupDisplaySeconds=5,
 PickupSoundMinInterval=0.08,
 -- Hard limits keep very large waves bounded. Excess drops/visuals are skipped.
 MaxActiveDrops=128,
 PickupHz=10,
 MaxClientVisuals=160,
 ClientBuildsPerFrame=8,
}
