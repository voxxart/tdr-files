local mobs = workspace.Mobs

-- Function to check if a mob or any of its descendants should be marked as a boss
local function checkForBoss(newMob)
	if newMob.Name == "Noob Soldier" and workspace.Info.Gamemode.Value == "Easy" and workspace.Info.Wave.Value == 8 then
		if not newMob:FindFirstChild("IsBoss") then
			local isBoss = Instance.new("BoolValue")
			isBoss.Name = "IsBoss"
			isBoss.Value = true
			isBoss.Parent = newMob
		end
	end
end

local function checkForBoss2(newMob)
	if newMob.Name == "Noob Doctor" and workspace.Info.Gamemode.Value == "Easy" and workspace.Info.Wave.Value == 13 then
		if not newMob:FindFirstChild("IsBoss") then
			local isBoss = Instance.new("BoolValue")
			isBoss.Name = "IsBoss"
			isBoss.Value = true
			isBoss.Parent = newMob
		end
	end
end

local function checkForBoss3(newMob)
	if newMob.Name == "Noob Juggernaut" and workspace.Info.Gamemode.Value == "Easy" and workspace.Info.Wave.Value == 17 then
		if not newMob:FindFirstChild("IsBoss") then
			local isBoss = Instance.new("BoolValue")
			isBoss.Name = "IsBoss"
			isBoss.Value = true
			isBoss.Parent = newMob
		end
	end
end

local musicPlayed = false

local function checkForFinalBoss(newMob)
	if workspace.Info.Gamemode.Value == "Easy" and workspace.Info.Wave.Value == 20 and not musicPlayed then
		workspace.Music.Noobicus:Play()
		musicPlayed = true
		local AMB = workspace.Ambience:FindFirstChildOfClass("Sound")
		local OriginalVol = AMB.Volume
		AMB.Volume = 0

		workspace.Info.Message:GetPropertyChangedSignal("Value"):Connect(function()
			if workspace.Info.Message.Value == "VICTORY" or workspace.Info.Message.Value == "GAME OVER" then
				if workspace.Music.Noobicus.IsPlaying then
					workspace.Music.Noobicus:Destroy()
					musicPlayed = false
					AMB.Volume = OriginalVol
				end
			end
		end)
	end
end

local function checkForNormalBoss1(newMob)
	if newMob.Name == "Executioner" and workspace.Info.Gamemode.Value == "Normal" and workspace.Info.Wave.Value == 7 then
		if not newMob:FindFirstChild("IsBoss") then
			local isBoss = Instance.new("BoolValue")
			isBoss.Name = "IsBoss"
			isBoss.Value = true
			isBoss.Parent = newMob
		end
	end
end

local function checkForNormalBoss2(newMob)
	if newMob.Name == "MEU" and workspace.Info.Gamemode.Value == "Normal" and workspace.Info.Wave.Value == 15 then
		if not newMob:FindFirstChild("IsBoss") then
			local isBoss = Instance.new("BoolValue")
			isBoss.Name = "IsBoss"
			isBoss.Value = true
			isBoss.Parent = newMob
		end
	end
end

local function checkForNormalBoss3(newMob)
	if newMob.Name == "Resurrected Noob Gaurdian" and workspace.Info.Gamemode.Value == "Normal" and workspace.Info.Wave.Value == 24 then
		if not newMob:FindFirstChild("IsBoss") then
			local isBoss = Instance.new("BoolValue")
			isBoss.Name = "IsBoss"
			isBoss.Value = true
			isBoss.Parent = newMob
		end
	end
end

local musicPlayedNormal = false

local function checkForFinalBossNormal(newMob)
	if workspace.Info.Gamemode.Value == "Normal" and workspace.Info.Wave.Value == 26 and not musicPlayedNormal then
		workspace.Music.Endbringer:Play()
		musicPlayedNormal = true
		local AMB = workspace.Ambience:FindFirstChildOfClass("Sound")
		local OriginalVol = AMB.Volume
		AMB.Volume = 0

		workspace.Info.Message:GetPropertyChangedSignal("Value"):Connect(function()
			if workspace.Info.Message.Value == "VICTORY" or workspace.Info.Message.Value == "GAME OVER" then
				if workspace.Music.Endbringer.IsPlaying then
					workspace.Music.Endbringer:Destroy()
					musicPlayedNormal = false
					AMB.Volume = OriginalVol
				end
			end
		end)
	end
end

local function checkForHardBoss(newMob)
	if newMob.Name == "Marksman" and workspace.Info.Gamemode.Value == "Hard" and workspace.Info.Wave.Value == 10 then
		if not newMob:FindFirstChild("IsBoss") then
			local isBoss = Instance.new("BoolValue")
			isBoss.Name = "IsBoss"
			isBoss.Value = true
			isBoss.Parent = newMob
		end
	end
end

local function checkForHardBoss2(newMob)
	if newMob.Name == "Merchant" and workspace.Info.Gamemode.Value == "Hard" and workspace.Info.Wave.Value == 17 then
		if not newMob:FindFirstChild("IsBoss") then
			local isBoss = Instance.new("BoolValue")
			isBoss.Name = "IsBoss"
			isBoss.Value = true
			isBoss.Parent = newMob
		end
	end
end

---------------------------------------------------------
-- PLAGUE DOCTOR MINIBOSS (Hard Wave 20)
---------------------------------------------------------
local plagueMusicActive = false
local FADE_DURATION = 4
local PLAGUE_MUSIC_VOLUME = 2 -- target volume when fully faded in; adjust to taste

local function fadeInPlagueMusic()
	local sound = workspace.Music.HardMode.Plague
	if not sound.IsPlaying then
		sound.Volume = 0
		sound:Play()
	end
	local elapsed = 0
	local startVol = sound.Volume
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		local alpha = math.clamp(elapsed / FADE_DURATION, 0, 1)
		sound.Volume = startVol + (PLAGUE_MUSIC_VOLUME - startVol) * alpha
		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

local function fadeOutPlagueMusic()
	local sound = workspace.Music.HardMode.Plague
	local elapsed = 0
	local startVol = sound.Volume
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		local alpha = math.clamp(elapsed / FADE_DURATION, 0, 1)
		sound.Volume = startVol * (1 - alpha)
		if alpha >= 1 then
			connection:Disconnect()
			sound:Stop()
			sound.Volume = PLAGUE_MUSIC_VOLUME -- reset for next time
		end
	end)
end

local HONORYMusicActive = false
local FADE_DURATION2 = 4
local HONORY_MUSIC_VOLUME = 2 -- target volume when fully faded in; adjust to taste

local function fadeInHonoryMusic()
	local sound = workspace.Music.HardMode.Valor
	if not sound.IsPlaying then
		sound.Volume = 0
		sound:Play()
	end
	local elapsed = 0
	local startVol = sound.Volume
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		local alpha = math.clamp(elapsed / FADE_DURATION, 0, 1)
		sound.Volume = startVol + (PLAGUE_MUSIC_VOLUME - startVol) * alpha
		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

local function fadeOutHonoryMusic()
	local sound = workspace.Music.HardMode.Valor
	local elapsed = 0
	local startVol = sound.Volume
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		local alpha = math.clamp(elapsed / FADE_DURATION, 0, 1)
		sound.Volume = startVol * (1 - alpha)
		if alpha >= 1 then
			connection:Disconnect()
			sound:Stop()
			sound.Volume = PLAGUE_MUSIC_VOLUME -- reset for next time
		end
	end)
end

local function checkForMiniboss1(newMob)
	if newMob.Name ~= "Plague Doctor" then return end
	if workspace.Info.Gamemode.Value ~= "Hard" then return end
	if plagueMusicActive then return end

	plagueMusicActive = true
	fadeInPlagueMusic()

	-- Watch for this specific Plague Doctor leaving workspace.Mobs
	newMob.AncestryChanged:Connect(function(_, parent)
		if parent then return end -- still somewhere, not removed yet

		-- Check if any other Plague Doctor is still alive in Mobs
		for _, mob in ipairs(mobs:GetChildren()) do
			if mob.Name == "Plague Doctor" and mob ~= newMob then
				return -- another one is still alive, don't fade out yet
			end
		end

		-- Last one gone — fade out
		plagueMusicActive = false
		fadeOutPlagueMusic()
	end)
end

local function checkForMiniboss2(newMob)
	if newMob.Name ~= "Honorary" then return end
	if workspace.Info.Gamemode.Value ~= "Hard" then return end
	if plagueMusicActive then return end

	HONORYMusicActive = true
	fadeInHonoryMusic()

	-- Watch for this specific Plague Doctor leaving workspace.Mobs
	newMob.AncestryChanged:Connect(function(_, parent)
		if parent then return end -- still somewhere, not removed yet

		-- Check if any other Plague Doctor is still alive in Mobs
		for _, mob in ipairs(mobs:GetChildren()) do
			if mob.Name == "Honorary" and mob ~= newMob then
				return -- another one is still alive, don't fade out yet
			end
		end

		-- Last one gone — fade out
		HONORYMusicActive = false
		fadeOutHonoryMusic()
	end)
end

local musicPlayedHard = false

local function checkForFinalBossHard(newMob)
	if workspace.Info.Gamemode.Value == "Hard" and workspace.Info.Wave.Value == 32 and not musicPlayedHard then
		workspace.Music.HardMode.DuelOfCalamity:Play()
		musicPlayedHard = true
		local AMB = workspace.Ambience:FindFirstChildOfClass("Sound")
		local OriginalVol = AMB.Volume
		AMB.Volume = 0

		workspace.Info.Message:GetPropertyChangedSignal("Value"):Connect(function()
			if workspace.Info.Message.Value == "VICTORY" or workspace.Info.Message.Value == "GAME OVER" then
				if workspace.Music.HardMode.DuelOfCalamity.IsPlaying then
					workspace.Music.HardMode.DuelOfCalamity:Destroy()
					musicPlayedHard = false
					AMB.Volume = OriginalVol
				end
			end
		end)
	end
end


-- Listen for new mobs being added to the workspace
mobs.ChildAdded:Connect(function(newMob)
	checkForBoss(newMob)
	checkForBoss2(newMob)
	checkForBoss3(newMob)
	checkForFinalBoss(newMob)
	checkForNormalBoss1(newMob)
	checkForNormalBoss2(newMob)
	checkForNormalBoss3(newMob)
	checkForFinalBossNormal(newMob)
	checkForHardBoss(newMob)
	checkForHardBoss2(newMob)
	checkForMiniboss1(newMob)
	checkForMiniboss2(newMob)
	checkForFinalBossHard(newMob)
	for _, descendant in ipairs(newMob:GetDescendants()) do
		checkForBoss(descendant)
		checkForBoss2(descendant)
		checkForBoss3(descendant)
		checkForFinalBoss(newMob)
		checkForNormalBoss1(descendant)
		checkForNormalBoss2(descendant)
		checkForNormalBoss3(descendant)
		checkForFinalBossNormal(descendant)
		checkForHardBoss(descendant)
		checkForHardBoss2(descendant)
		checkForFinalBossHard(descendant)
	end

	newMob.DescendantAdded:Connect(checkForBoss)
end)