-- ReplicatedStorage/GameModules/EnemyData.lua
-- Shared static enemy data + performance settings.
-- Server runtime state remains authoritative.

local Flags = {
	Hidden     = 1,
	Flying     = 2,
	Invincible = 4,
	NoCash     = 8,
	Aggro      = 16,
	Lead       = 32,
	NoStun     = 64,
	InstaKill  = 128,
	FinalBoss  = 256,
}

return {
	Settings = {
		-- Paths are sampled ONCE, then enemies only do table lookups + CFrame:Lerp.
		PathSampleCount = 512,

		-- Server only needs coarse authoritative hitboxes.
		ServerPositionHz = 10,

		-- Alpha exists only for compatibility with current tower targeting.
		-- Set to 0 after tower targeting is migrated to EnemyRuntime.
		AlphaMirrorHz = 5,

		-- Bounded compressed sync packets at this rate.
		ClientSyncHz = 5,
		SyncPacketBytes = 900,
		SpawnBudgetPerFrame = 32,
		-- Visual rates only; authoritative movement/attacks are unchanged.
		NearRenderDistance = 120,
		FarRenderDistance = 260,
		NearRenderHz = 60,
		MidRenderHz = 30,
		FarRenderHz = 10,
		RegistrationBudget = 64,
		RegistrationTimeout = 10,
		SummonEffectsPerFrame = 8,
		AnimationVisibilityChecksPerFrame = 1024,
		AnimationScreenMargin = 48,
		MaxDeathPresentations = 48,
		DeathPresentationsPerFrame = 6,
		DeathParticlesPerEffect = 200,

		BurnTick = 1,
		BleedTick = 1,

		PathCurveResolution = 1.2,
	},

	Flags = Flags,

	Enemies = {
		Arrow = {
			MaxHealth = 10,
			Speed = 15,
			HipHeight = 0.25,
			Flags = 0,
		},

		["Armored Noob"] = {
			MaxHealth = 30,
			Speed = 1.95,
			HipHeight = 0.4,
			Flags = 0,
		},
		
		["Armored Zombie"] = {
			MaxHealth = 16,
			Speed = 2.25,
			HipHeight = 0.4,
			Flags = 0,
		},
		
		["Assassin"] = {
			MaxHealth = 400,
			Speed = 5.1,
			HipHeight = 0.25,
			Flags = 1,
		},
		
		["Aviator Noob"] = {
			MaxHealth = 60,
			Speed = 5,
			HipHeight = 0.25,
			Flags = 2,
		},
		
		["Bread Bearer"] = {
			MaxHealth = 35,
			Speed = 2,
			HipHeight = 0.25,
			Flags = 0,
		},
		
		["Bread1"] = {
			MaxHealth = 50,
			Speed = 0.001,
			HipHeight = 0.25,
			Flags = 16,
		},
		
		["Bread2"] = {
			MaxHealth = 40,
			Speed = 0.01,
			HipHeight = 0.25,
			Flags = 16,
		},
		
		["Bronze"] = {
			MaxHealth = 70,
			Speed = 2.35,
			HipHeight = 0.25,
			Flags = 32,
		},
		
		["Brute"] = {
			MaxHealth = 2250,
			Speed = 2,
			HipHeight = 1.025,
			Flags = 0,
		},
		
		["Dark Knight"] = {
			MaxHealth = 4250,
			Speed = 1.5,
			HipHeight = 1.025,
			Flags = 0,
		},
		
		["Doombringer"] = {
			MaxHealth = 52500,
			Speed = 0.75,
			HipHeight = 1.45,
			Flags = 256,
		},
		
		["Endbringer"] = {
			MaxHealth = 10000,
			Speed = 1,
			HipHeight = 1.2,
			Flags = 0,
		},
		
		["Endergetic Noob"] = {
			MaxHealth = 10,
			Speed = 4,
			HipHeight = 0.25,
			Flags = 0,
		},
		
		["Enforcer"] = {
			MaxHealth = 10000,
			Speed = 1.5,
			HipHeight = 1.35,
			Flags = 32,
		},
		
		["Executioner"] = {
			MaxHealth = 375,
			Speed = 2.35,
			HipHeight = 0.6,
			Flags = 0,
		},
		
		["General Noobicus"] = {
			MaxHealth = 20000,
			Speed = 0.5,
			HipHeight = 1.2,
			Flags = 256,
		},
		
		["Glider"] = {
			MaxHealth = 350,
			Speed = 2.8,
			HipHeight = 0.25,
			Flags = 2,
		},
		
		["Heavy"] = {
			MaxHealth = 27,
			Speed = 2,
			HipHeight = 0.25,
			Flags = 0,
		},
		
		["Honorary"] = {
			MaxHealth = 52500,
			Speed = 0.62,
			HipHeight = 1.6,
			Flags = 256,
		},
		
		["Infected Medic"] = {
			MaxHealth = 800,
			Speed = 2,
			HipHeight = 0.3,
			Flags = 0,
		},
		
		["Inventor"] = {
			MaxHealth = 6000,
			Speed = 1.5,
			HipHeight = 1.025,
			Flags = 0,
		},
		
		["Knight"] = {
			MaxHealth = 125,
			Speed = 2.35,
			HipHeight = 0.25,
			Flags = 0,
		},
		
		["MEU"] = {
			MaxHealth = 500,
			Speed = 2.5,
			HipHeight = 0.6,
			Flags = 0,
			
			Duration      = 0.8,
			Depth         = 4,
			HoardDuration = 0.2,
			Spread        = 1.5
		},
		
		["Marauder"] = {
			MaxHealth = 29750,
			Speed = 1.2,
			HipHeight = 1.2,
			Flags = 0,
		},
		
		["Marksman"] = {
			MaxHealth = 2075,
			Speed = 1,
			HipHeight = 0.84,
			Flags = 0,
		},
		
		["Merchant"] = {
			MaxHealth = 2350,
			Speed = 2.3,
			HipHeight = 0.6,
			Flags = 0,
		},
		
		["Noob"] = {
			MaxHealth = 8,
			Speed = 2.7,
			HipHeight = 0.25,
			Flags = 0,
		},
		
		["Noob Doctor"] = {
			MaxHealth = 2000,
			Speed = 2.25,
			HipHeight = 0.45,
			Flags = 0,
		},
		
		["Noob Engineer"] = {
			MaxHealth = 375,
			Speed = 2.35,
			HipHeight = 0.6,
			Flags = 0,
			
			Duration      = 0.8,
			Depth         = 4,
			HoardDuration = 0.2,
			Spread        = 1.5
		},
		
		["Noob Gaurdian"] = {
			MaxHealth = 3450,
			Speed = 1.45,
			HipHeight = 1.1,
			Flags = 0,
		},
		
		["Noob Juggernaut"] = {
			MaxHealth = 19250,
			Speed = 1.25,
			HipHeight = 1,
			Flags = 0,
		},
		
		["Noob Soldier"] = {
			MaxHealth = 275,
			Speed = 1.5,
			HipHeight = 0.25,
			Flags = 0,
		},
		
		["Peasant"] = {
			MaxHealth = 16,
			Speed = 3.1,
			HipHeight = 0.25,
			Flags = 0,
		},
		
		["Pilot"] = {
			MaxHealth = 125,
			Speed = 7,
			HipHeight = 0.25,
			Flags = 2,
		},
		
		["Plague Doctor"] = {
			MaxHealth = 12000,
			Speed = 0.75,
			HipHeight = 1.3,
			Flags = 0,
		},
		
		["Plagued"] = {
			MaxHealth = 400,
			Speed = 1.8,
			HipHeight = 0.55,
			Flags = 0,
		},
		
		["Polycephaly"] = {
			MaxHealth = 100,
			Speed = 5,
			HipHeight = 0.4,
			Flags = 32,
		},
		
		["Reaper"] = {
			MaxHealth = 450000,
			Speed = 0.7,
			HipHeight = 2.1,
			Flags = 256,
		},
		
		["Resurrected Noob Gaurdian"] = {
			MaxHealth = 3000,
			Speed = 2,
			HipHeight = 1.1,
			Flags = 0,
		},
		
		["Ripped Noob"] = {
			MaxHealth = 320,
			Speed = 1.75,
			HipHeight = 0.75,
			Flags = 0,
		},
		
		["Shadow Noob"] = {
			MaxHealth = 14,
			Speed = 2,
			HipHeight = 0.25,
			Flags = 1,
		},
		
		["Skeleton"] = {
			MaxHealth = 45,
			Speed = 2.25,
			HipHeight = 0.28,
			Flags = 0,
		},
		
		["Spawned Armored Noob"] = {
			MaxHealth = 75,
			Speed = 1.95,
			HipHeight = 0.25,
			Flags = 0,
		},
		
		["Spawner"] = {
			MaxHealth = 500,
			Speed = 0.01,
			HipHeight = 0.25,
			Flags = 0,
			
			Duration      = 0.8,
			Depth         = 4,
			HoardDuration = 0.2,
			Spread        = 1.5
		},
		
		["Speedy"] = {
			MaxHealth = 10,
			Speed = 5.5,
			HipHeight = 0.25,
			Flags = 0,
		},
		
		["Spy"] = {
			MaxHealth = 15,
			Speed = 4.75,
			HipHeight = 0.25,
			Flags = 1,
		},
		
		["Summoned Armored Zombie"] = {
			MaxHealth = 144,
			Speed = 2.6,
			HipHeight = 0.4,
			Flags = 0,
		},
		
		["Swordmaster"] = {
			MaxHealth = 160000,
			Speed = 0.55,
			HipHeight = 1.6,
			Flags = 256,
		},
		
		["Undead Squire"] = {
			MaxHealth = 80,
			Speed = 3.1,
			HipHeight = 0.25,
			Flags = 8,
		},
		
		["Volent"] = {
			MaxHealth = 5000,
			Speed = 1.25,
			HipHeight = 1.025,
			Flags = 2,
		},
		
		["Whispering Elm"] = {
			MaxHealth = 7000,
			Speed = 1.3,
			HipHeight = 2,
			Flags = 0,
		},
		
		["Wizard"] = {
			MaxHealth = 450,
			Speed = 2,
			HipHeight = 0.25,
			Flags = 0,
		},
		
		["Worker"] = {
			MaxHealth = 26,
			Speed = 2.8,
			HipHeight = 2.8,
			Flags = 8,
		},
		
		["Wraith"] = {
			MaxHealth = 35,
			Speed = 2,
			HipHeight = 0.25,
			Flags = 1,
		},
		
		["Zombie"] = {
			MaxHealth = 12,
			Speed = 2.7,
			HipHeight = 0.25,
			Flags = 0,
		},
		
		
		Necromancer = {
			MaxHealth = 600,
			Speed = 2,
			HipHeight = 0,
			Flags = 0,
			Duration      = 0.8,
			Depth         = 4,
			HoardDuration = 0.2,
			Spread        = 1.5
		},
	},
}
