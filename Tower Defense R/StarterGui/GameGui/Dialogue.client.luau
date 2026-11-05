local wave = workspace.Info.Wave
local gamemode = workspace.Info.Gamemode

local DF = script.Parent.DialogueFrame
local text = DF.Dialouge.Main
local narName = DF.Dialouge.NaratorName
local imageLabel = DF.Dialouge.ImageLabel

local player = game.Players.LocalPlayer

local dialogueQueue = {}


--==================================================
-- SETTINGS
--==================================================

local DIALOGUE_POSITION_IN = UDim2.new(0.311, 0, 0.669, 0)
local DIALOGUE_POSITION_OUT = UDim2.new(0.311, 0, 2, 0)

local TYPE_SPEED = 0.01
local DEFAULT_WAIT_TIME = 4.5


--==================================================
-- DIALOGUE ENABLED
--==================================================

local DialogueEnabled = player:GetAttribute("DialogueEnabled")

player:GetAttributeChangedSignal("DialogueEnabled"):Connect(function()
	DialogueEnabled = player:GetAttribute("DialogueEnabled")

	-- If dialogue gets disabled, immediately clear the queue
	if DialogueEnabled == false then
		table.clear(dialogueQueue)

		DF:TweenPosition(
			DIALOGUE_POSITION_OUT,
			Enum.EasingDirection.In,
			Enum.EasingStyle.Back,
			0.5,
			true
		)
	end
end)


--==================================================
-- DIALOGUE QUEUE
--==================================================

local dialoguePlaying = false

-- Used to identify which wave a queued dialogue belongs to
local currentDialogueWave = 0


--==================================================
-- TYPEWRITER
--==================================================

local function typeWrite(object, txt, length)

	object.Text = ""

	for i = 1, #txt do

		if player:GetAttribute("DialogueEnabled") == false then
			return false
		end

		object.Text = string.sub(txt, 1, i)

		task.wait(length)

		if script:FindFirstChild("Sound") then
			script.Sound:Play()
		end
	end

	return true
end


--==================================================
-- PLAY SINGLE DIALOGUE
--==================================================

local function playDialogue(entry)

	if player:GetAttribute("DialogueEnabled") == false then
		return false
	end


	--==================================================
	-- NAME
	--==================================================

	narName.Text = entry.name or ""


	--==================================================
	-- IMAGE
	--==================================================

	if entry.image then
		imageLabel.Image = "rbxassetid://" .. tostring(entry.image)
		imageLabel.Visible = true
	else
		imageLabel.Image = ""
		imageLabel.Visible = false
	end


	--==================================================
	-- SLIDE IN
	--==================================================

	DF:TweenPosition(
		DIALOGUE_POSITION_IN,
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Back,
		0.5,
		true
	)

	if script:FindFirstChild("Start") then
		script.Start:Play()
	end


	--==================================================
	-- TYPE TEXT
	--==================================================

	local completed = typeWrite(
		text,
		entry.dialogue,
		TYPE_SPEED
	)

	if not completed then
		return false
	end


	--==================================================
	-- WAIT
	--==================================================

	local gameSpeed = workspace.Info.GameSpeed.Value

	if gameSpeed <= 0 then
		gameSpeed = 1
	end

	local waitTime = entry.waitTime or DEFAULT_WAIT_TIME

	task.wait(waitTime / gameSpeed)


	--==================================================
	-- SLIDE OUT
	--==================================================

	DF:TweenPosition(
		DIALOGUE_POSITION_OUT,
		Enum.EasingDirection.In,
		Enum.EasingStyle.Back,
		0.5,
		true
	)

	task.wait(0.5)

	return true
end


--==================================================
-- PLAY DIALOGUE SEQUENCE
--==================================================

local function playSequence(entries, sequenceWave)

	for _, entry in ipairs(entries) do

		if player:GetAttribute("DialogueEnabled") == false then
			return
		end


		-- If a newer wave has happened, stop this sequence.
		--
		-- This DOES NOT interrupt the current dialogue.
		-- It only prevents the rest of an outdated sequence
		-- from playing after the wave has changed.
		if sequenceWave ~= wave.Value then
			return
		end


		--==================================================
		-- DELAY BEFORE
		--==================================================

		if entry.delayBefore then
			task.wait(entry.delayBefore)

			if player:GetAttribute("DialogueEnabled") == false then
				return
			end

			if sequenceWave ~= wave.Value then
				return
			end
		end


		--==================================================
		-- PLAY
		--==================================================

		local completed = playDialogue(entry)

		if not completed then
			return
		end
	end
end


--==================================================
-- QUEUE PROCESSOR
--==================================================

local function processDialogueQueue()

	if dialoguePlaying then
		return
	end

	dialoguePlaying = true


	while #dialogueQueue > 0 do

		if player:GetAttribute("DialogueEnabled") == false then
			table.clear(dialogueQueue)
			break
		end


		-- Get the newest queued dialogue
		local sequence = table.remove(dialogueQueue, 1)

		if sequence then
			playSequence(
				sequence.entries,
				sequence.wave
			)
		end
	end


	dialoguePlaying = false
end


--==================================================
-- QUEUE NEW DIALOGUE
--==================================================

local function queueDialogue(entries, dialogueWave)

	-- Remove any OLD queued dialogue.
	--
	-- The dialogue currently playing is allowed to finish,
	-- but anything waiting behind it is discarded.
	table.clear(dialogueQueue)


	table.insert(dialogueQueue, {
		entries = entries,
		wave = dialogueWave
	})


	task.spawn(processDialogueQueue)
end


--==================================================
-- DIALOGUE DEFINITIONS
--==================================================

local DIALOGUE_IMAGES = {
	LaraGeneral = 107590449532900,
	HardModeLara = 77091920063430,
	
	Director = 114233219844445,

	Swordmaster = 102630778377965, -- Replace with Swordmaster image ID
	CommanderPrime = 85330365221781, -- Replace with Commander Hughes image ID
	Player = 111530264575063, -- Replace with Player image ID
	Voidling = 109056694030941, -- Replace with Voidling image ID
}

local DIALOGUES = {
	Easy = {
		[1] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Welcome to the fight commander! Seems Noobicus and his army are marching towards our camps. Place defenses quick!"
		}},

		[2] = {{
			narrator = "LaraGeneral",
			image = DIALOGUE_IMAGES.LaraGeneral,
			name = "General Voss",
			dialogue = "Seems Noobicus and his army were pretty upgraded since our first fight with him. This wont be easy commander."
		}},

		[8] = {{
			narrator = "LaraGeneral",
			image = DIALOGUE_IMAGES.LaraGeneral,
			name = "General Voss",
			dialogue = "Looks like Noobicus is playing a little bit of defense too. Noob Soldier next wave. Careful, he will damage your towers!"
		}},

		[10] = {{
			narrator = "LaraGeneral",
			image = DIALOGUE_IMAGES.LaraGeneral,
			name = "General Voss",
			dialogue = "The skies are no longer safe! Make sure your Troopers can target air! Their aviators may be old but they are effective."
		}},

		[12] = {{
			narrator = "LaraGeneral",
			image = DIALOGUE_IMAGES.LaraGeneral,
			name = "General Voss",
			dialogue = "Shadow enemies detected! Make sure you've got towers with hidden detection ready, or you'll regret it."
		}},

		[13] = {{
			narrator = "LaraGeneral",
			image = DIALOGUE_IMAGES.LaraGeneral,
			name = "General Voss",
			dialogue = "Noob Doctor seems to be charging in. Looks like he's been heavily upgraded to heal his allies over time!"
		}},

		[15] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Noob Engineers are rolling up! Their spawners will spawn enemies until destroyed! Make sure to utilize your tower's targeting!"
		}},

		[17] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Noob Gaurdians! Careful, these tanky Noobs will push far!"
		}},

		[19] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Noobicus is clearly VERY angry! Noob Juggernaut is rolling in and will shred your towers! Eradicate him, NOW!"
		}},

		[20] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "General Noobicus is approaching! He is extreamely upgraded and this is no joke! Hit em with everything you've got!"
		}},
	},

	Normal = {
		[1] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Welcome to the battelfield commander! I guess you successfully defeated Noobicus, but trust me, this will be much harder than his army."
		}},

		[2] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "This may feel easier at first but Doombringer is much worse than Noobicus. Just hold him back so we don't have another Base V incident.."
		}},

		[7] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "An Executioner is inbound! Those sabers can damage your towers! Watch out!"
		}},

		[10] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Where.... Where are they?",
			waitTime = 3
		}},

		[12] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Flying enemies detected! These aren't your average Aviator Noobs: they're faster, deadlier, and relentless."
		}},

		[14] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Seems that Doombringer is using a new soldier called MEU next wave. From what our intel shows, these guys will use hellspawn energy to summon enemies, but, everytime they use the energy, it damages them. Don't let your gaurd down!",
			waitTime = 5
		}},

		[18] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Polycephaly units inbound! Careful, not only are these guys lead but they'll explode and stun nearby towers when killed!"
		}},

		[21] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Looks like they have similar healing tech to us! If not handled accordingly, this enemy can become a serious threat!"
		}},

		[22] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Nice takedown Commander! But don't celebrate just yet... Doombringer's strongest are still waiting."
		}},

		[24] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Resurrected Noob Gaurdian inbound! We have no idea how he does it but, as long as he is alive, every enemy on the map is invincible. Take him out Quick!"
		}},

		[25] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Good job Commander but this fight isnt over. Endbringers are here which means Doombringer will be here next wave! Prepare!"
		}},

		[26] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.LaraGeneral,
			dialogue = "Commander.. He's here.. Take him down quick or we are DOOMED!"
		}},
	},

	Hard = {
		[1] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.HardModeLara,
			dialogue = "Hey Commander.. Glad you finally made it.. This army makes doombringer's army look like childs play."
		}},

		[2] = {{
			narrator = "LaraGeneral",
			name = "General Voss",
			image = DIALOGUE_IMAGES.HardModeLara,
			dialogue = "I truly hope you came prepared, because I can't stay and help you. Hold off Swordmaster and his army, then return to base immediately. We have a problem."
		}},

		[5] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 2,
				dialogue = "Hello, " .. game.Players.LocalPlayer.Name .. ". So, you're the one they sent to stop me.. You and your feeble army have made a grave mistake. You will fall before my forces. Surrender while you still can.",
				waitTime = 5,
			},
		},

		[6] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "Defeating Noobicus was impressive. Defeating Doombringer? That crossed the line. I was sent by none other than Null himself, and I will reduce your planet to ash!",
				waitTime = 5,
			},
		},

		[7] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "I hope you understand commander, I don't plan to take it easy on you. I will make you suffer, and I don't care how many Knights I need to do it!",
				waitTime = 5,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 4,
				dialogue = "Before this is over, you'll wish you had surrendered to General Noobicus while you still had the chance.",
				waitTime = 5,
			},
		},

		[10] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "Enough games, good luck fighting my Marksman.",
				waitTime = 5,
			},
		},

		[11] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "You continue to surprise with your endurance and resilance, but just remember, it only gets harder from here... Have some of my finest and most reinforced lead enemies!",
				waitTime = 5,
			},
		},

		[12] = {
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 0,
				dialogue = "Sorry I'm late " .. game.Players.LocalPlayer.Name .. ". Lara told me you guys were actually taking on Swordmaster. I'll try to help you through this.",
				waitTime = 4.5,
			},
			{
				narrator = "Player",
				name = game.Players.LocalPlayer.Name,
				image = DIALOGUE_IMAGES.Player,
				delayBefore = 2,
				dialogue = "Why are you here? I thought you were working on Operation Doomsday?",
				waitTime = 4,
			},
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 1.5,
				dialogue = "Commander, I'm here so you survive. More soldiers we have, the higher chance we can find and eradicate Null.. I need you to ensure I dont repeat my past mistakes.",
				waitTime = 5,
			},
			{
				narrator = "Player",
				name = game.Players.LocalPlayer.Name,
				image = DIALOGUE_IMAGES.Player,
				delayBefore = 2,
				dialogue = "Past mistakes? What do you mean past mistakes? Have you fought Null before??",
				waitTime = 3.5,
			},
		},

		[13] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "Hate to interrupt this sentimental moment, but I suggest you open your eyes to what's right in front of you. My servants remain loyal to me even after death... a level of loyalty your people could never understand.",
				waitTime = 5,
			},
			{
				narrator = "Player",
				name = game.Players.LocalPlayer.Name,
				image = DIALOGUE_IMAGES.Player,
				delayBefore = 0,
				dialogue = "What? What do you mean? The TDR is the most unified army there has been throughout human history.",
				waitTime = 3.75,
			},
		},

		[14] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "Trust me, even while you're here fighting me, your army is facing a threat you can't even begin to comprehend. You're just too blind to see it!",
				waitTime = 5,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 4,
				dialogue = "If you humans would've just let Null have this universe, we could've prepared for whats coming. You could've all provided a place for us, to hide, to run, and to be safe from whats coming. Instead, the chaos you've caused by fighting us, has alert all of us, to him..",
				waitTime = 5,
			},
		},

		[15] = {
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 0,
				dialogue = "Don't listen to him commander. He's just trying to distract you from the flying enemies incoming!",
				waitTime = 5,
			},
		},

		[16] = {
			{
				narrator = "Player",
				name = game.Players.LocalPlayer.Name,
				image = DIALOGUE_IMAGES.Player,
				delayBefore = 0,
				dialogue = "Commander Hughes... who is Null? Swordmaster makes it sound like you know him.",
				waitTime = 3.75,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "Oh, he knows Null alright. He knows exactly what Null can do. And judging by that look on his face... he knows what's coming. You're all doomed.",
				waitTime = 5,
			},
		},

		[17] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "Commander, allow me to introduce Merchant. He is a loyal soldier of mine and is able to steal your resources. Not that they'll be much use to you anyways since you'll be ash soon.",
				waitTime = 5,
			},
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 1.5,
				dialogue = "You talk too much.",
				waitTime = 2,
			},
		},

		[18] = {
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 0,
				dialogue = "Commander stay vigilant, radar detects something big moving in..",
				waitTime = 5,
			},
			{
				narrator = "Player",
				name = game.Players.LocalPlayer.Name,
				image = DIALOGUE_IMAGES.Player,
				delayBefore = 2,
				dialogue = "Thanks... but why won’t you be honest about Null?",
				waitTime = 3.75,
			},
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 2,
				dialogue = "Just defend. Don't worry about it.",
				waitTime = 3,
			},
		},

		[19] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "You guys have put up a good fight but its all in vain. Soon, you'll meet one of my finest soldiers. He has experience in eradicating ants like you.",
				waitTime = 5,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "Don't worry though, his soldiers will make sure this battle isn't even close.",
				waitTime = 5,
			},
		},

		[20] = {
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 0,
				dialogue = game.Players.LocalPlayer.Name .. " , Swordmaster wasn't lying. We've got a Plague Doctor moving in!",
				waitTime = 5,
			},
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 2,
				dialogue = "Take him down quick and make your troops don't get infected!",
				waitTime = 5,
			},
		},

		[21] = {
			{
				narrator = "Player",
				name = game.Players.LocalPlayer.Name,
				image = DIALOGUE_IMAGES.Player,
				delayBefore = 0,
				dialogue = "What was that? That felt strangely strong...",
				waitTime = 3.5,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 2,
				dialogue = "Oh " .. game.Players.LocalPlayer.Name .. " .. If you think that was hard, Null will destroy you.",
				waitTime = 4,
			},
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 2,
				dialogue = "Don't listen to him, " .. game.Players.LocalPlayer.Name .. ".",
				waitTime = 3,
			},
		},

		[23] = {
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 0,
				dialogue = "Commander, we got a large horde of Marksmen and Dark Knights coming in! Eradicate them quickly before they shred your defenses!",
				waitTime = 5,
			},
		},

		[24] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "Good job surviving the oldest trick in the book. Your army looks more pathetic by the minute, suppressed by my Inventor’s signal disruptor and stripped of your ability to activate tower abilities!",
				waitTime = 5,
			},
			{
				narrator = "Player",
				name = game.Players.LocalPlayer.Name,
				image = DIALOGUE_IMAGES.Player,
				delayBefore = 5,
				dialogue = "You talk all high and mighty, but you don’t even have the guts to face us yourself!",
				waitTime = 3.5,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 2,
				dialogue = "Its a choice " .. game.Players.LocalPlayer.Name .. ".",
				waitTime = 5,
			},
		},

		[25] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "And because of that arrogant comment last wave, have a Volent. I think you’ll love them.",
				waitTime = 5,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 2,
				dialogue = "And the reason I don’t simply wipe out your army myself, is because I love the smell of your fear, the sound of your elevated heartbeat, the sweat on your palms. All of it makes you the perfect prey.",
				waitTime = 5,
			},
		},

		[26] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "Seems you’ve seriously improved your aerial defenses since your fight with Doombringer. Impressive.",
				waitTime = 5,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 2,
				dialogue = "Don't take pride however, that just is my sign to send out my Assassains.",
				waitTime = 5,
			},
		},

		[27] = {
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 0,
				dialogue = "Swordmaster, your end is near! " .. game.Players.LocalPlayer.Name .. " is holding your army back like its nothing, and quite honestly, you haven’t impressed me.",
				waitTime = 5,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 2,
				dialogue = "Commander Hughes, you know from experience it’s not wise to be arrogant before the end of a battle... just ask Lily.",
				waitTime = 5,
			},
			{
				narrator = "Player",
				name = game.Players.LocalPlayer.Name,
				image = DIALOGUE_IMAGES.Player,
				delayBefore = 0,
				dialogue = "Who's Lily?",
				waitTime = 2,
			},
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 0,
				dialogue = ".....",
				waitTime = 3,
			},
		},

		[28] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "Well, I guess you win..",
				waitTime = 2.8,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 1,
				dialogue = "Just kidding. I’m sending my Honor Guard. In his eyes, you’re no threat.",
				waitTime = 4,
			},
		},

		[29] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "You actually eliminated my Honorary...",
				waitTime = 4,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 2,
				dialogue = "That... will be your final mistake.",
				waitTime = 4,
			},
			{
				narrator = "Player",
				name = game.Players.LocalPlayer.Name,
				image = DIALOGUE_IMAGES.Player,
				delayBefore = 5,
				dialogue = "Commander Hughes, I’m sorry for asking about Lily, but I seriously need help here!",
				waitTime = 4,
			},
		},

		[30] = {
			{
				narrator = "Player",
				name = game.Players.LocalPlayer.Name,
				image = DIALOGUE_IMAGES.Player,
				delayBefore = 0,
				dialogue = "Are those... trees?",
				waitTime = 3,
			},
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 4,
				dialogue = "Whispering Elms. They passively heal themselves.",
				waitTime = 4,
			},
			{
				narrator = "Player",
				name = game.Players.LocalPlayer.Name,
				image = DIALOGUE_IMAGES.Player,
				delayBefore = 0,
				dialogue = "You okay, Commander?",
				waitTime = 2.5,
			},
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 5,
				dialogue = "Yeah, I'm... Fine..",
				waitTime = 4,
			},
		},

		[31] = {
			{
				narrator = "CommanderPrime",
				name = "Commander Hughes",
				image = DIALOGUE_IMAGES.CommanderPrime,
				delayBefore = 0,
				dialogue = "Radar detects Swordmaster approaching. Prep your defenses for the fight of your life, " .. game.Players.LocalPlayer.Name .. ".",
				waitTime = 4,
			},
			{
				narrator = "Voidling",
				name = "???",
				image = DIALOGUE_IMAGES.Voidling,
				delayBefore = 10,
				dialogue = "Can't beleive Swordmaster is being bested by some humans.. Null wont be happy about this..",
				waitTime = 4,
			},
		},

		[32] = {
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 0,
				dialogue = "Commander....",
				waitTime = 2,
			},
			{
				narrator = "Swordmaster",
				name = "Swordmaster",
				image = DIALOGUE_IMAGES.Swordmaster,
				delayBefore = 2,
				dialogue = "BOW TO YOUR DOOM!",
				waitTime = 4,
			},
		},
	},
}

--==================================================
-- WAVE LISTENER
--==================================================

wave:GetPropertyChangedSignal("Value"):Connect(function()

	local modeTable = DIALOGUES[gamemode.Value]

	if not modeTable then
		return
	end


	local entries = modeTable[wave.Value]

	if not entries then
		return
	end


	-- Queue this wave's dialogue
	queueDialogue(
		entries,
		wave.Value
	)
end)