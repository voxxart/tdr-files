return {
	Settings = {
		SellPercent = 0.5,
	},

	Towers = {
		Trooper = {
			Cost = 500,

			Stats = {
				Damage = 1,
				Firerate = 0.25,
				Range = 12,

				MaxHealth = 100,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Gloves",
					Cost = 370,

					Damage = 1,
					Firerate = 0.2,
					Range = 13,
					MaxHealth = 120,
				},

				[2] = {
					UpgradeName = "Heat Vision",
					Cost = 875,

					HiddenDetection = true,
					Damage = 2,
					Firerate = 0.18,
					MaxHealth = 145,
				},
				[3] = {
					UpgradeName = "Upgraded Weaponry",
					Cost = 3185,

					FlyingDetection = true,
					Damage = 4,
					Firerate = 0.15,
					Range = 16,
					MaxHealth = 180,
				},
				[4] = {
					UpgradeName = "Terminator",
					Cost = 9500,

					Damage = 6,
					Firerate = 0.14,
					Range = 17,
					MaxHealth = 285,
				},
			},
		},
		Marksman = {
			Cost = 725,

			Stats = {
				Damage = 5,
				Firerate = 1.86,
				Range = 18,

				MaxHealth = 50,
				FlyingDetection = true,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Hired Assassin",
					Cost = 325,

					Damage = 6,
					Range = 23,
					MaxHealth = 55,
				},

				[2] = {
					UpgradeName = "Perfect Accuracy",
					Cost = 840,

					HiddenDetection = true,
					Damage = 12,
					Firerate = 1.46,
					MaxHealth = 69,
					Range = 24,
				},
				[3] = {
					UpgradeName = "Geared for War",
					Cost = 2750,

					LeadDetection = true,
					Damage = 20,
					MaxHealth = 90,
				},
				[4] = {
					UpgradeName = "Deadeye",
					Cost = 8000,

					Damage = 65,
					Firerate = 1.25,
					Range = 28,
					MaxHealth = 100,
				},
			},
		},
		
		["Mob Farm"] = {
			Cost = 250,

			Stats = {
				Farm = true,
				Cash = 75,
				Damage = 0,
				Firerate = 0,
				Range = 3,

				MaxHealth = 150,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "City Street",
					Cost = 215,

					Cash = 120,
					MaxHealth = 120,
				},

				[2] = {
					UpgradeName = "Stronger Foes",
					Cost = 550,

					Cash = 270,
					MaxHealth = 225,
				},

				[3] = {
					UpgradeName = "Crowd Control",
					Cost = 1550,

					Cash = 600,
					MaxHealth = 300,
				},

				[4] = {
					UpgradeName = "Challenging Fight",
					Cost = 4000,

					Cash = 1200,
					MaxHealth = 375,
				},

				[5] = {
					UpgradeName = "Raze the Void",
					Cost = 6250,

					Cash = 1800,
					MaxHealth = 500,
				},
			},
		},
		
		["Knifer"] = {
			Cost = 300,

			Stats = {
				Damage = 15,
				Firerate = 1.85,
				Range = 5,

				AOE = true,
				MaxHits = 2,

				MaxHealth = 100,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Strong Gloves",
					Cost = 375,

					Damage = 20,
					Firerate = 1.65,
					Range = 5.5,
					MaxHits = 2,
					MaxHealth = 110,
				},

				[2] = {
					UpgradeName = "Adrenaline Rush",
					Cost = 800,

					Damage = 25,
					Range = 5.5,
					MaxHits = 3,
					
					MaxHealth = 125,
					
					LeadDetection = true,
				},
				[3] = {
					UpgradeName = "Trained Operative",
					Cost = 2750,

					Damage = 32,
					Range = 6,
					MaxHits = 3,
					Firerate = 1.5,

					MaxHealth = 150,
				},
				[4] = {
					UpgradeName = "The Negotiator",
					Cost = 5800,

					Damage = 50,
					Range = 7,
					MaxHits = 4,

					MaxHealth = 225,
				},
			},
		},
		
		["Reaper"] = {
			Cost = 2500,

			Stats = {
				Damage = 40,
				Firerate = 1.5,
				Range = 5,

				AOE = true,
				MaxHits = 4,

				MaxHealth = 600,
				
				Config = {
					["Reaper.HallowGaurd"] = false,
					["Reaper.Giant Skeleton"] = false,
					["Reaper.Sluagh"] = false,
					["Reaper.ForgottenKnight"] = false,
					["Reaper.Skeleton"] = true,
					["Reaper.MaxSouls"] = 200,
					["Reaper.SoulRequirements.Giant Skeleton"] = 450,
					["Reaper.SoulRequirements.Sluagh"] = 285,
					["Reaper.SoulRequirements.ForgottenKnight"] = 490,
					["Reaper.SoulCollectionRate"] = 3,
				},
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Stronger Swings",
					Cost = 950,

					Damage = 45,
					Range = 5.25,
					MaxHits = 4,
					MaxHealth = 645,
					
					Config = {
						["Reaper.MaxSouls"] = 285,
						["Reaper.SoulCollectionRate"] = 3,
					},
				},

				[2] = {
					UpgradeName = "Heavy Armor",
					Cost = 4850,

					Damage = 60,
					Range = 5.5,
					Firerate = 1.42,
					MaxHits = 6,

					MaxHealth = 720,

					Config = {
						["Reaper.Giant Skeleton"] = true,
						["Reaper.MaxSouls"] = 420,
						["Reaper.SoulCollectionRate"] = 3,
					},
				},
				[3] = {
					UpgradeName = "Dark Necromancy",
					Cost = 9500,

					Damage = 100,
					Range = 6,
					Firerate = 1.4,

					MaxHealth = 945,
					
					HiddenDetection = true,
					
					Config = {
						["Reaper.Slaugh"] = true,
						["Reaper.MaxSouls"] = 750,
						["Reaper.SoulCollectionRate"] = 2,
					},
				},
				[4] = {
					UpgradeName = "Soul Stealer",
					Cost = 15250,

					Damage = 125,
					MaxHits = 10,

					MaxHealth = 1200,
					
					Config = {
						["Reaper.ForgottenKnight"] = true,
						["Reaper.MaxSouls"] = 1400,
						["Reaper.SoulCollectionRate"] = 2,
					},
				},
				[5] = {
					UpgradeName = "Emperor of the Dead",
					Cost = 30000,

					Damage = 180,
					Range = 7,
					MaxHits = 10,
					Firerate = 1.38,
					
					Config = {
						["Reaper.HallowGaurd"] = true,
						["Reaper.MaxSouls"] = 3000,
						["Reaper.SoulRequirements.Giant Skeleton"] = 500,
						["Reaper.SoulRequirements.Sluagh"] = 350,
						["Reaper.SoulRequirements.ForgottenKnight"] = 600,
						["Reaper.SoulCollectionRate"] = 2,
					},

					MaxHealth = 1750,
				},
			},
		},
		
		["Mine Layer"] = {
			Cost = 325,

			Stats = {
				Damage = 12,
				Firerate = 5.85,
				Range = 5,
				MaxHealth = 285,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Improved Payload",
					Cost = 400,

					Firerate = 5.85,

					Config = {
						["MineStats.MaxMines"] = 4,
					},
				},
				
				MaxHealth = 300,

				[2] = {
					UpgradeName = "Expanded Minefield",
					Cost = 1500,
					Damage = 18,
					Firerate = 5.65,

					Config = {
						["MineStats.SelectedMine"] = "Mine2",
					},
					
					MaxHealth = 325,
				},

				[3] = {
					UpgradeName = "Military Explosives",
					Cost = 4650,

					Firerate = 5.35,
					Damage = 27,
					Range = 5.5,

					Config = {
						["MineStats.MaxMines"] = 6,
						["MineStats.SelectedMine"] = "Mine3",
					},
					MaxHealth = 380,
				},

				[4] = {
					UpgradeName = "Bunker Buster Mines",
					Cost = 9450,

					Damage = 40,
					Firerate = 5.25,
					Range = 6,

					Config = {
						["MineStats.MaxMines"] = 8,
						["MineStats.SelectedMine"] = "Mine4",

						-- Unlock Boss Shredder mines.
						["MineStats.BossBusterMines.MaxMines"] = 1,
						["MineStats.BossBusterMines.SelectedMine"] = "BossShredder",
						["MineStats.BossBusterMines.TravelTime"] = 1.5,
					},
					MaxHealth = 450,
				},
			},
		},
		
		["Demolitionist"] = {
			Cost = 800,

			Stats = {
				Damage = 12,
				Firerate = 2.25,
				Range = 10,

				Splash = true,
				SplashRadius = 2.25,
				ProjectileSpeed = 15,

				MaxHealth = 145,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Faster Throwing",
					Cost = 450,

					SplashRadius = 2.4,
					Firerate = 2.12,
					MaxHealth = 160,
				},

				[2] = {
					UpgradeName = "More Explosives",
					Cost = 1200,

					Damage = 18,
					SplashRadius = 2.45,
					Firerate = 2.05,
					Range = 12,
					MaxHealth = 180,
				},

				[3] = {
					UpgradeName = "Deadly Frags",
					Cost = 3000,

					Damage = 18,

					-- BURST UNLOCKS HERE
					Burst = true,
					MaxBurst = 6,
					Range = 13,
					SplashRadius = 2.65,

					-- Time BETWEEN complete bursts.
					Delay = 4,
					Firerate = 0.5,
					MaxHealth = 200,
					
					HiddenDetection = true,
				},

				[4] = {
					UpgradeName = "Crowd Control Professional",
					Cost = 7700,

					Damage = 22,
					SplashRadius = 3,
					Range = 14.5,

					MaxBurst = 6,
					OGCooldown = 0.25,
					Firerate = 0.25,
					Delay = 3.4,
					MaxHealth = 250,
				},
			},
		},
		
		["Shocker"] = {
			Cost = 600,

			Stats = {
				Damage = 10,
				Firerate = 2.3,
				Range = 10,

				Shocker = true,

				MaxHealth = 125,
				
				LeadDetection = true,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Shock Proof Gloves",
					Cost = 325,

					Damage = 12,
					Firerate = 2.25,
					Range = 11,

					Config = {
						["Shocker.ChainCount"] = 4,
						["Shocker.StunTime"] = 0.2,
					},
					MaxHealth = 132,
				},

				[2] = {
					UpgradeName = "Shocking Blasts",
					Cost = 900,

					Damage = 14,
					Firerate = 2.15,
					Range = 11,

					Config = {
						["Shocker.ChainCount"] = 5,
						["Shocker.StunTime"] = 0.3,
					},
					MaxHealth = 145,
				},
				[3] = {
					UpgradeName = "Battery Pack",
					Cost = 4350,

					Damage = 28,
					Firerate = 2.15,
					Range = 13,
					
					FlyingDetection = true,

					Config = {
						["Shocker.ChainCount"] = 5,
						["Shocker.StunTime"] = 0.45,
					},
					MaxHealth = 180,
				},
				[4] = {
					UpgradeName = "Shock Trooper",
					Cost = 7900,

					Damage = 40,
					Firerate = 2,
					Range = 14,

					Config = {
						["Shocker.ChainCount"] = 8,
						["Shocker.StunTime"] = 0.65,
					},
					MaxHealth = 200,
				},
			},
		},
		
		["Motor Pool"] = {
			Cost = 500,

			Stats = {
				Damage = 0,
				Firerate = 40,
				Range = 3,
				MaxHealth = 600,

				-- Spawner
				Unit = "Humvee",
				SpawnCooldown = 40,
				PlacementCooldown = 10,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Faster Spawn Time",
					Cost = 400,

					SpawnCooldown = 35,
					Firerate = 35,
					MaxHealth = 615,
				},

				[2] = {
					UpgradeName = "Expanded Motor Pool",
					Cost = 750,

					Unit = "Humvee2",
					SpawnCooldown = 35,
					MaxHealth = 625,
				},

				[3] = {
					UpgradeName = "Heavy Vehicle Production",
					Cost = 3500,
					
					UnitIcon = "102891463329792",
					DPS = 25,
					Unit = "Humvee3",
				},

				[4] = {
					UpgradeName = "Basic Tank",
					Cost = 11000,
					
					UnitIcon = "132801871318609",
					DPS = 68,

					Unit = "Tank1",
					SpawnCooldown = 32,
					Firerate = 32,
				},

				[5] = {
					UpgradeName = "Upgraded Tanks & Calvary",
					Cost = 23800,
					
					DPS = 95,

					Unit = "Tank2",
					SpawnCooldown = 30,

					-- Ability unlocks HERE
					CavlryAbility = true,
					CanBuff = "Yes",
					ABILITYACTIVE = false,

					AbilityCost = 2250,
					BuffCooldown = 90,
					BuffLegnth = 0,
					
					MaxHealth = 1000,
				},
			},
		},
		
		["Flamethrower"] = {
			Cost = 800,

			Stats = {
				Damage = 2,
				Firerate = 0.2,
				Range = 8,

				Flamethrower = true,

				MaxHealth = 200,
				
				BurnTime = 6,
				FireDamage = 1,
				
				LeadDetection = true,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Heat Proof Gloves",
					Cost = 500,

					Firerate = 0.18,

					
					MaxHealth = 215,
					
					BurnTime = 7,
					FireDamage = 2,
					
					Config = {
						["DefenseMelt.MeltAmount"] = 0.05,
						["DefenseMelt.MeltPerTick"] = 0.01,
						["DefenseMelt.MeltPerTickPercent"] = 1,
						["DefenseMelt.MeltPercentAmount"] = 5,
					},
				},

				[2] = {
					UpgradeName = "Face Protection",
					Cost = 1750,

					Damage = 2,
					Firerate = 0.15,
					Range = 9,
					
					BurnTime = 10,
					FireDamage = 3,

					Config = {
						["DefenseMelt.MeltAmount"] = 0.1,
						["DefenseMelt.MeltPerTick"] = 0.02,
						["DefenseMelt.MeltPerTickPercent"] = 2,
						["DefenseMelt.MeltPercentAmount"] = 10,
						["SlowDown.SlowAmount"] = 0.02,
					},
					MaxHealth = 245,
				},
				[3] = {
					UpgradeName = "Hotter Flames",
					Cost = 4500,

					Damage = 3,
					Firerate = 0.12,
					
					BurnTime = 15,
					FireDamage = 7,

					Config = {
						["DefenseMelt.MeltAmount"] = 0.15,
						["DefenseMelt.MeltPerTick"] = 0.05,
						["DefenseMelt.MeltPerTickPercent"] = 5,
						["DefenseMelt.MeltPercentAmount"] = 15,
						["SlowDown.SlowAmount"] = 0.05,
					},
					MaxHealth = 280,
					
					HiddenDetection = true,
				},
				
				[4] = {
					UpgradeName = "Flame Crazed",
					Cost = 10000,

					Damage = 5,
					Firerate = 0.1,
					Range = 11,

					Config = {
						["DefenseMelt.MeltAmount"] = 0.25,
						["DefenseMelt.MeltPerTick"] = 0.08,
						["DefenseMelt.MeltPerTickPercent"] = 8,
						["DefenseMelt.MeltPercentAmount"] = 25,
						["SlowDown.SlowAmount"] = 0.08,
					},
					MaxHealth = 350,
				},
			},
		},
		
		["Operator"] = {
			Cost = 485,

			Stats = {
				Damage = 6,
				Firerate = 0.13,
				Range = 13,

				Burst = true,
				MaxBurst = 4,
				Delay = 1.18,

				MaxHealth = 285,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "No Evidence",
					Cost = 285,

					Firerate = 0.125,
					MaxHealth = 300,
				},

				[2] = {
					UpgradeName = "Concealed Identity",
					Cost = 860,

					MaxBurst = 6,
					Delay = 1.15,
					Range = 14,
					
					FlyingDetection = true,
					MaxHealth = 310,
				},

				[3] = {
					UpgradeName = "Solo Operator",
					Cost = 3000,

					Damage = 8,
					MaxBurst = 15,

					-- Time BETWEEN complete bursts.
					Delay = 1.1,
					Firerate = 0.12,
					MaxHealth = 365,
				},

				[4] = {
					UpgradeName = "Stealth Ops",
					Cost = 8000,

					Range = 15,
					Firerate = 0.125,
					
					Burst = false,
					HiddenDetection = true,
					
					MaxHealth = 450,
				},
			},
		},
		
		["Machine Gunner"] = {
			Cost = 2000,

			Stats = {
				Damage = 3,
				Firerate = 0.125,
				Range = 15,
				
				MaxAmmo = 50,
				ReloadCooldown = 4,

				MaxHealth = 325,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Military Experience",
					Cost = 500,
					
					MaxAmmo = 65,
					
					Damage = 4,
					MaxHealth = 350,
				},

				[2] = {
					UpgradeName = "Concealed Identity",
					Cost = 860,

					Firerate = 0.1,
					Range = 16,

					MaxAmmo = 80,
					ReloadCooldown = 3.5,

					MaxHealth = 415,
				},

				[3] = {
					UpgradeName = "Solo Operator",
					Cost = 5350,
					
					MaxAmmo = 125,
					ReloadCooldown = 3,

					Damage = 6,
					MaxHealth = 480,
				},

				[4] = {
					UpgradeName = "Stealth Ops",
					Cost = 8000,

					Damage = 9,
					Range = 18,
					Firerate = 0.08,
					LeadDetection = true,
					
					MaxAmmo = 200,
					ReloadCooldown = 2.75,

					MaxHealth = 575,
				},
			},
		},
		["Aviator"] = {
			Cost = 700,

			Stats = {
				Damage = 5,
				Firerate = 0.15,
				Range = 7.5,
				MaxHealth = 525,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Cleaner Barrels",
					Cost = 575,

					Firerate = 0.125,
					MaxHealth = 545,
				},

				[2] = {
					UpgradeName = "Bombs Away!",
					Cost = 1325,
					
					RocketDPS = 6,

					Secondary = {
						Type = "Rocket",

						Damage = 14,
						Range = 7.5,

						Cooldown = 0.1,
						Delay = 1.875,
						MaxBurst = 1,

						Splash = true,
						SplashRadius = 2,
					},
					MaxHealth = 585,
				},

				[3] = {
					UpgradeName = "Better Aerodynamics",
					Cost = 3750,
					
					Damage = 8,
					Range = 8,
					Firerate = 0.1,
					
					RocketDPS = 8,

					Secondary = {
						Damage = 14,
						Range = 8,
						MaxBurst = 1,
						SplashRadius = 2.25,
					},
					MaxHealth = 685,
					HiddenDetection = true,
				},
				[4] = {
					UpgradeName = "New Gen Plane",
					Cost = 3750,

					Damage = 8,
					Range = 8,
					Firerate = 0.1,

					RocketDPS = 8,

					Secondary = {
						Damage = 30,
						Range = 8,
						Cooldown = 0.25,
						MaxBurst = 2,
						Delay = 1.5,
						SplashRadius = 2.5,
					},
					MaxHealth = 815,
				},
			},
		},
		
		["Tree"] = {
			Cost = 800,

			Stats = {
				Damage = 0,
				Firerate = 0,
				Range = 3,

				Tree = true,

				MaxHealth = 130,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Branch Growth",
					Cost = 200,
					Range = 4,

					Config = {
						["AOEHeal.HealAmount"] = 25,
						["AOEHeal.HealRange"] = 5,
						["AOEHeal.HealCooldown"] = 4.5,
					},
					MaxHealth = 135,
				},

				[2] = {
					UpgradeName = "Leaves",
					Cost = 900,


					Config = {
						["AOEHeal.HealAmount"] = 35,
						["AOEHeal.HealRange"] = 5,
						["AOEHeal.HealCooldown"] = 4,
					},
					MaxHealth = 160,
				},
				[3] = {
					UpgradeName = "Healing Folliage",
					Cost = 3600,

					Range = 5,

					Config = {
						["AOEHeal.HealAmount"] = 80,
						["AOEHeal.HealRange"] = 6,
						["AOEHeal.HealCooldown"] = 4,
					},
					MaxHealth = 180,
				},
				[4] = {
					UpgradeName = "Void Tree",
					Cost = 7500,
					Range = 5.5,

					Config = {
						["StunShields.Enabled"] = true,
						["AOEHeal.HealAmount"] = 120,
						["AOEHeal.HealRange"] = 7,
						["AOEHeal.HealCooldown"] = 4,
						["StunShields.ShieldRegenTime"] = 40,
						["StunShields.ShieldRange"] = 7,
					},
					MaxHealth = 285,
				},
			},
		},
		
		["Shotgunner"] = {
			Cost = 300,

			Stats = {
				Damage = 2,
				Firerate = 2.45,
				Range = 7,

				SpreadAngle = 80,
				PelletCount = 8,

				MaxHealth = 150,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Mild Armor",
					Cost = 200,

					Firerate = 2.08,
					MaxHealth = 155,
				},

				[2] = {
					UpgradeName = "Extra Shells",
					Cost = 800,

					Range = 7.5,
					Damage = 3,

					SpreadAngle = 60,
					PelletCount = 10,

					MaxHealth = 245,
				},

				[3] = {
					UpgradeName = "Extreame Armor",
					Cost = 2800,
					
					Damage = 4,

					PelletCount = 13,

					HiddenDetection = true,
					MaxHealth = 500,
				},

				[4] = {
					UpgradeName = "Healthy Upgrade",
					Cost = 7000,

					Damage = 7,
					Firerate = 2,
					Range = 8,

					SpreadAngle = 50,
					PelletCount = 16,

					MaxHealth = 525,
				},
			},
		},
		
		["Commander"] = {
			Cost = 1650,

			Stats = {
				Commander = true,
				NoAttack = true,

				Range = 8,
				MaxHealth = 450,
				
				ABILITYACTIVE = false,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Radio Training",
					Cost = 1000,

					Range = 10,

					Config = {
						["Buffs.FirerateBuff"] = 1.1,
						["Buffs.FirerateBuffPercentage"] = 10,

						["Buffs.RangeBuff"] = 1.05,
						["Buffs.RangeBuffPercentage"] = 5,
					},
					
					MaxHealth = 475,
				},

				[2] = {
					UpgradeName = "Field Command",
					Cost = 2750,

					Config = {
						["Buffs.FirerateBuff"] = 1.15,
						["Buffs.FirerateBuffPercentage"] = 15,

						["Buffs.RangeBuff"] = 1.1,
						["Buffs.RangeBuffPercentage"] = 10,
					},
					MaxHealth = 525,
					
					VisualElevation = 0.56,
				},

				[3] = {
					UpgradeName = "Advanced Command",
					Cost = 6000,

					Config = {
						["Buffs.FirerateBuff"] = 1.18,
						["Buffs.FirerateBuffPercentage"] = 18,

						["Buffs.RangeBuff"] = 1.11,
						["Buffs.RangeBuffPercentage"] = 11,
					},
					MaxHealth = 600,
					VisualElevation = 0.56,
				},

				[4] = {
					UpgradeName = "Call To Arms",
					Cost = 12000,

					Range = 15,

					-- THIS unlocks the CTA button.
					CTA = true,

					CanBuff = "Yes",
					BuffCooldown = 30,
					BuffLegnth = 10,
					
					Ability = true,

					Config = {
						["Buffs.FirerateBuff"] = 1.225,
						["Buffs.FirerateBuffPercentage"] = 22.5,

						["Buffs.RangeBuff"] = 1.125,
						["Buffs.RangeBuffPercentage"] = 12.5,
					},
					VisualElevation = 0.56,
				},
			},
		},
		
		["Sergeant"] = {
			Cost = 650,

			Stats = {
				Damage = 10,
				Firerate = 0.75,
				Range = 10,

				MaxHealth = 350,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Tactical Gloves",
					Cost = 400,

					Range = 12,
					Firerate = 0.68,
					MaxHealth = 375,
				},

				[2] = {
					UpgradeName = "Night Vision",
					Cost = 1050,

					Damage = 12,
					Firerate = 0.6,
					
					
					MaxHealth = 400,
					
					HiddenDetection = true,
				},

				[3] = {
					UpgradeName = "Supressive Fire",
					Cost = 3750,

					Range = 14,
					Firerate = 0.3,
					MaxHealth = 445,

					FlyingDetection = true,
				},

				[4] = {
					UpgradeName = "War Born",
					Cost = 6000,

					Damage = 15,
					Range = 15,
					Firerate = 0.18,
					MaxHealth = 480,

				},
				
				[5] = {
					UpgradeName = "Heart of a Leader",
					Cost = 14500,
					
					Damage = 23,
					Range = 19,
					Firerate = 0.15,
					MaxHealth = 600,

					SergeantRage = true,
					Ability = true,
					CanBuff = "Yes",
					BuffCooldown = 60,
					BuffLegnth = 10,

					Config = {
						["DamageBuffs.DamageBuff"] = 1,
					},
				},
			},
		},
		
		["Scrambler"] = {
			Cost = 800,

			Stats = {
				Damage = 5,
				Firerate = 0.5,
				Range = 12,

				MaxHealth = 480,
				
				TUnit = "Coil",
				RebuildTime = 50,
				TimeUntilRebuild = 50,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Slight Armor",
					Cost = 675,

					Range = 13,
					Damage = 6,
					
					TUnit = "Coil2",
					
					
					MaxHealth = 500,
				},

				[2] = {
					UpgradeName = "Dead Eye",
					Cost = 1050,

					Damage = 8,
					TUnit = "Coil3",

					MaxHealth = 500,
				},

				[3] = {
					UpgradeName = "Upgraded Coil",
					Cost = 4950,
					
					TUnit = "Coil4",
					RebuildTime = 55,

					Damage = 12,
					Range = 15,
					MaxHealth = 600,
					
					HiddenDetection = true,
				},

				[4] = {
					UpgradeName = "Shadow Engineer",
					Cost = 15250,
					
					TUnit = "Coil5",
					RebuildTime = 60,

					Damage = 18,
					Range = 16,
					MaxHealth = 780,
				},
			},
		},
		
		["Railgunner"] = {
			Cost = 4500,

			Stats = {
				Damage = 70,
				Firerate = 5,
				Range = 24,

				MaxHealth = 425,
				
				FlyingDetection = true,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Smoother Handling",
					Cost = 900,

					Range = 26,
					Firerate = 4.8,
					MaxHealth = 450,
					
					LeadDetection = true,
				},

				[2] = {
					UpgradeName = "Headshots Only",
					Cost = 3200,

					Damage = 110,
					Firerate = 4.7,


					MaxHealth = 500,
				},

				[3] = {
					UpgradeName = "Supressive Fire",
					Cost = 7500,

					Damage = 185,
					Range = 32,
					Firerate = 4.65,
					MaxHealth = 650,
				},

				[4] = {
					UpgradeName = "Deadshot",
					Cost = 19850,

					Damage = 400,
					Range = 35,
					Firerate = 4.5,
					MaxHealth = 820,
				},
			},
		},
		
		["Heavy"] = {
			Cost = 4000,

			Stats = {
				Damage = 4,
				Firerate = 0.13,
				Range = 15,

				MaxHealth = 625,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Heavy Gear",
					Cost = 700,

					Range = 16,
					Damage = 5,
					MaxHealth = 700,
				},

				[2] = {
					UpgradeName = "Heat Vision",
					Cost = 2250,

					Damage = 6,
					Firerate = 0.125,
					Range = 17,
					
					MaxHealth = 750,

					HiddenDetection = true,
				},

				[3] = {
					UpgradeName = "Barrage of Bullets",
					Cost = 7000,

					Damage = 9,
					Range = 18,
					Firerate = 0.08,
					MaxHealth = 900,
					
				},

				[4] = {
					UpgradeName = "Heavy Weapons Guy",
					Cost = 14800,

					Damage = 12,
					Range = 19,
					MaxHealth = 1350,
					
				},
			},
		},
		
		["Mortar"] = {
			Cost = 1800,

			Stats = {
				Damage = 12,
				Firerate = 4,
				Range = 20,

				Splash = true,
				SplashRadius = 3,
				ProjectileSpeed = 30,
				
				LeadDetection = true,
				FlyingDetection = true,

				MaxHealth = 480,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Explosive Protection",
					Cost = 550,

					Damage = 20,
					Firerate = 3.75,
					Range = 22,
					MaxHealth = 540,
				},

				[2] = {
					UpgradeName = "More Explosives",
					Cost = 2150,

					Damage = 35,
					SplashRadius = 3.5,
					Firerate = 3.5,
					Range = 25,
					MaxHealth = 600,
				},

				[3] = {
					UpgradeName = "Deadly Frags",
					Cost = 5900,

					Damage = 90,

					Range = 28,
			
					MaxHealth = 650,
				},

				[4] = {
					UpgradeName = "Crowd Control Professional",
					Cost = 17500,

					Damage = 72,
					SplashRadius = 4.2,
					Range = 35,
					
					Burst = true,

					MaxBurst = 3,
					OGCooldown = 0.2,
					Firerate = 0.2,
					Delay = 3.2,
					MaxHealth = 900,
				},
			},
		},
		
		["Helicopter"] = {
			Cost = 4850,

			Stats = {
				Damage = 5,
				Firerate = 0.15,
				Range = 8,
				
				MovementSpeed = 125, 
				DPS = 33,
				
				FlyingDetection = true,
				
				MaxHealth = 500,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Faster Reloading",
					Cost = 1275,

					Firerate = 0.125,
					
					MovementSpeed = 130, 
					
					DPS = 40,
					MaxHealth = 525,
				},

				[2] = {
					UpgradeName = "Rockets",
					Cost = 3200,

					DPS = 48,

					Secondary = {
						Type = "Rocket",

						Damage = 10,
						Range = 8,

						Cooldown = 0.2,
						Delay = 4.5,
						MaxBurst = 4,

						Splash = true,
						SplashRadius = 2,
					},
					MaxHealth = 525,
				},

				[3] = {
					UpgradeName = "Aerial Patrol",
					Cost = 7890,

					Damage = 7,
					Range = 10,
					Firerate = 0.1,

					DPS = 75,
					
					MovementSpeed = 140, 
					
					Config = {
						["PossibleModes.Pursuit"] = true,
					},

					Secondary = {
						Damage = 17,
						Range = 10,
						Delay = 4,
					},
					MaxHealth = 900,
				},
				[4] = {
					UpgradeName = "Rocket Storm",
					Cost = 16870,

					Damage = 9,

					DPS = 114,
					
					MovementSpeed = 145, 

					Secondary = {
						Damage = 20,
						MaxBurst = 6,
					},
					MaxHealth = 900,
				},
				[5] = {
					UpgradeName = "Angel of Death",
					Cost = 27500,

					Damage = 15,
					Range = 12,

					DPS = 245,
					
					MovementSpeed = 165, 

					Secondary = {
						Type = "Rocket",

						Damage = 45,
						Range = 12,
						Delay = 3.55,
						MaxBurst = 12,

						SplashRadius = 2.25,
					},
					LeadDetection = true,
					
					MaxHealth = 2400,
				},
			},
		},
		
		["Outlaw"] = {
			Cost = 550,

			Stats = {
				Damage = 3,
				Firerate = 0.33,
				Range = 13,
				
				BountyPerHealth = 20,
				HealthPerBounty = 8,
				MaxBounty = 252,

				MaxHealth = 90,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Quickdraw",
					Cost = 275,
					
					BountyPerHealth = 25,
					MaxBounty = 270,

					Range = 14,
					Firerate = 0.26,
					MaxHealth = 105,
				},

				[2] = {
					UpgradeName = "Just Buisness",
					Cost = 925,
					
					BountyPerHealth = 60,
					HealthPerBounty = 15,
					MaxBounty = 450,

					Damage = 4,
					Firerate = 0.22,

					MaxHealth = 130,

					HiddenDetection = true,
				},

				[3] = {
					UpgradeName = "Cowboy of the West",
					Cost = 3800,
					
					BountyPerHealth = 75,
					HealthPerBounty = 50,
					MaxBounty = 1125,

					Damage = 7,
					Range = 15,
					MaxHealth = 130,

				},

				[4] = {
					UpgradeName = "Fastest Draw in the West",
					Cost = 8900,
					
					BountyPerHealth = 140,
					HealthPerBounty = 100,
					MaxBounty = 3600,

					Damage = 9,
					Firerate = 0.15,
					Range = 16,
					MaxHealth = 200,

				},
			},
		},
		
		["Medic"] = {
			Cost = 1250,

			Stats = {
				Damage = 2,
				Firerate = 0.25,
				Range = 10,

				HealAmount = 1,

				MaxHealth = 200,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Sterile Work",
					Cost = 425,

					BountyPerHealth = 25,
					MaxBounty = 270,

					Damage = 3,
					Firerate = 0.2,
					MaxHealth = 250,
				},

				[2] = {
					UpgradeName = "Dangerous Chemestry",
					Cost = 800,

					Range = 12,
					Damage = 5,

					MaxHealth = 400,
				},

				[3] = {
					UpgradeName = "Battlefield Medic",
					Cost = 3520,
					
					HealAmount = 2,

					Damage = 12,
					Firerate = 0.15,
					Range = 14,
					MaxHealth = 530,

				},

				[4] = {
					UpgradeName = "Doctor's Orders",
					Cost = 8900,

					BaseHeal = 10,
					HealBase = true,

					Damage = 13,
					Firerate = 0.1,
					Range = 15,
					MaxHealth = 800,

				},
			},
		},
		
		["Beamer"] = {
			Cost = 5000,

			Stats = {
				Damage = 2,
				Firerate = 0.25,
				Range = 18,
				
				BaseDamage = 2, 

				Config = {
					["BeamerSettings.ChargeCooldown"] = 6.5,
					["BeamerSettings.IncreaseTick"] = 1.5,
					["BeamerSettings.IncreaseVal"] = 1,
					["BeamerSettings.MaxDamage"] = 14,
					["BeamerSettings.OverHeatCooldown"] = 4,
				},
				
				LeadDetection = true,

				MaxHealth = 1000,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Sterile Work",
					Cost = 1800,

					Config = {
						["BeamerSettings.IncreaseTick"] = 1.25,
						["BeamerSettings.MaxDamage"] = 17,
					},
					Damage = 3,
					BaseDamage = 3, 
					MaxHealth = 1050,
				},

				[2] = {
					UpgradeName = "Dangerous Chemestry",
					Cost = 5900,
					
					HiddenDetection = true,
					Damage = 5,
					BaseDamage = 5,
					Range = 19,
					
					Config = {
						["BeamerSettings.ChargeCooldown"] = 6.25,
						["BeamerSettings.IncreaseTick"] = 1.15,
						["BeamerSettings.IncreaseVal"] = 1,
						["BeamerSettings.MaxDamage"] = 20,
						["BeamerSettings.OverHeatCooldown"] = 3.75,
					},

					MaxHealth = 1300,
				},

				[3] = {
					UpgradeName = "Battlefield Medic",
					Cost = 9250,
					
					BaseDamage = 8,
					Damage = 8,
					Range = 22,
					
					Config = {
						["BeamerSettings.ChargeCooldown"] = 6,
						["BeamerSettings.IncreaseTick"] = 0.8,
						["BeamerSettings.IncreaseVal"] = 2,
						["BeamerSettings.MaxDamage"] = 32,
					},
					
					MaxHealth = 1575,

				},

				[4] = {
					UpgradeName = "Doctor's Orders",
					Cost = 16750,
					
					BaseDamage = 12,
					Damage = 12,

					Config = {
						["BeamerSettings.ChargeCooldown"] = 5.5,
						["BeamerSettings.MaxDamage"] = 46,
						["BeamerSettings.OverHeatCooldown"] = 3.5,
					},
					
					
					MaxHealth = 2150,

				},
				
				[5] = {
					UpgradeName = "Doctor's Orders",
					Cost = 25000,

					BaseDamage = 16,
					Damage = 16,
					Range = 25,

					Config = {
						["BeamerSettings.ChargeCooldown"] = 4,
						["BeamerSettings.IncreaseTick"] = 1,
						["BeamerSettings.IncreaseVal"] = 4,
						["BeamerSettings.MaxDamage"] = 65,
						["BeamerSettings.OverHeatCooldown"] = 2,
					},
					
					MultiPhaser = true,

					MaxHealth = 3000,

				},
			},
		},
		
		["Golden Heavy"] = {
			Cost = 6000,

			Stats = {
				Damage = 7,
				Firerate = 0.125,
				Range = 15,

				MaxHealth = 600,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Gilded Armor",
					Cost = 2100,

					Range = 16,
					Damage = 8,
					Firerate = 0.11,
					MaxHealth = 675,
				},

				[2] = {
					UpgradeName = "Golden Vision",
					Cost = 7200,

					Damage = 10,
					Firerate = 0.1,
					Range = 17,

					MaxHealth = 800,

					HiddenDetection = true,
				},

				[3] = {
					UpgradeName = "Much More Ammo",
					Cost = 16000,

					Damage = 16,
					Range = 19,
					MaxHealth = 1200,

				},

				[4] = {
					UpgradeName = "Gilded Juggernaut",
					Cost = 25000,

					Damage = 22,
					Range = 22,
					MaxHealth = 2850,
					
					VisualElevation = 0.85,

				},
			},
		},
		["Golden Outlaw"] = {
			Cost = 750,

			Stats = {
				Damage = 5,
				Firerate = 0.28,
				Range = 13,

				BountyPerHealth = 25,
				HealthPerBounty = 8,
				MaxBounty = 500,
				
				CashReward = 30,
				KillCount = 18,

				MaxHealth = 90,
			},

			Upgrades = {
				[1] = {
					UpgradeName = "Practice Draw",
					Cost = 450,

					Firerate = 0.22,
					Range = 14,

					BountyPerHealth = 32,
					MaxBounty = 550,

					CashReward = 32,

					MaxHealth = 105,
				},

				[2] = {
					UpgradeName = "Professional Hitman",
					Cost = 1500,

					BountyPerHealth = 75,
					HealthPerBounty = 20,
					MaxBounty = 750,

					CashReward = 40,

					Damage = 6,
					Firerate = 0.18,

					MaxHealth = 130,

					HiddenDetection = true,
				},

				[3] = {
					UpgradeName = "Cowboy of the West",
					Cost = 5350,

					BountyPerHealth = 100,
					HealthPerBounty = 65,
					MaxBounty = 2000,
					
					CashReward = 50,

					Damage = 10,
					Range = 15,

				},

				[4] = {
					UpgradeName = "Most Wanted",
					Cost = 16400,

					BountyPerHealth = 175,
					HealthPerBounty = 75,
					MaxBounty = 12000,

					CashReward = 125,
					KillCount = 36,

					Damage = 18,
					Firerate = 0.15,
					Range = 16,
					MaxHealth = 700,

				},
			},
		},
	},
}