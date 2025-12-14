--[[
	Slash Ability - Server Script (REFACTORED & SECURE)
	Place this in ServerScriptService

	Features:
	- Server-side validation and anti-exploit protection
	- Cooldown management
	- Optimized hitbox detection
	- Ragdoll system with smooth knockback
	- Hit feedback replication
	- Proper error handling
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- ============================================
-- MODULE IMPORTS
-- ============================================
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local HitFeedback = require(ReplicatedStorage:WaitForChild("HitFeedback"))

-- ============================================
-- REMOTE EVENT
-- ============================================
local reFolder = ReplicatedStorage:WaitForChild("RE")
local slashAbilityEvent = reFolder:WaitForChild("SlashAbilityEvent")

-- ============================================
-- STATE TRACKING
-- ============================================
local activeAbilities = {} -- {[player] = abilityData}
local playerCooldowns = {} -- {[player] = lastUseTime}
local ragdolledCharacters = {} -- {[character] = ragdollData}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local function getBaseWalkSpeed(humanoid)
	if not humanoid:GetAttribute("BaseWalkSpeed") then
		humanoid:SetAttribute("BaseWalkSpeed", humanoid.WalkSpeed)
	end
	return humanoid:GetAttribute("BaseWalkSpeed")
end

local function getBaseJumpPower(humanoid)
	if not humanoid:GetAttribute("BaseJumpPower") then
		humanoid:SetAttribute("BaseJumpPower", humanoid.JumpPower)
	end
	return humanoid:GetAttribute("BaseJumpPower")
end

-- ============================================
-- VALIDATION
-- ============================================
local function validateAbilityStart(player, character)
	-- Check cooldown
	local currentTime = tick()
	local lastUseTime = playerCooldowns[player] or 0

	if currentTime - lastUseTime < Config.Cooldown.Duration then
		warn(string.format("[ANTI-EXPLOIT] Player %s attempted to use ability during cooldown", player.Name))
		return false
	end

	-- Check if character belongs to player
	if Players:GetPlayerFromCharacter(character) ~= player then
		warn(string.format("[ANTI-EXPLOIT] Player %s sent invalid character", player.Name))
		return false
	end

	-- Check if already active
	if activeAbilities[player] then
		warn(string.format("[ANTI-EXPLOIT] Player %s attempted to use ability while already active", player.Name))
		return false
	end

	return true
end

local function validateHitEvent(player, action)
	local abilityData = activeAbilities[player]
	if not abilityData then
		warn(string.format("[ANTI-EXPLOIT] Player %s sent hit event without active ability", player.Name))
		return false
	end

	-- Check if ability has been active too long
	if tick() - abilityData.startTime > Config.Validation.MaxAbilityDuration then
		warn(string.format("[ANTI-EXPLOIT] Player %s ability exceeded max duration", player.Name))
		return false
	end

	-- Check timing between hits (anti-spam)
	if abilityData.lastHitTime then
		if tick() - abilityData.lastHitTime < Config.Validation.MinTimeBetweenHits then
			warn(string.format("[ANTI-EXPLOIT] Player %s hit events too frequent", player.Name))
			return false
		end
	end

	-- Check max hits
	if abilityData.hitCount >= Config.Validation.MaxHitsPerAbility then
		warn(string.format("[ANTI-EXPLOIT] Player %s exceeded max hits per ability", player.Name))
		return false
	end

	return true
end

-- ============================================
-- MOVEMENT LOCK/UNLOCK
-- ============================================
local function lockTargetMovement(targetCharacter, targetHumanoid)
	if not targetCharacter or not targetCharacter.Parent then return nil end
	if not targetHumanoid or targetHumanoid.Health <= 0 then return nil end

	local success, lockData = pcall(function()
		local baseWalkSpeed = getBaseWalkSpeed(targetHumanoid)
		local baseJumpPower = getBaseJumpPower(targetHumanoid)

		targetHumanoid.WalkSpeed = 0
		targetHumanoid.JumpPower = 0

		return {baseWalkSpeed, baseJumpPower}
	end)

	return success and lockData or nil
end

local function unlockTargetMovement(targetCharacter, lockData)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not lockData then return end

	pcall(function()
		local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")
		if targetHumanoid then
			targetHumanoid.WalkSpeed = lockData[1]
			targetHumanoid.JumpPower = lockData[2]
		end
	end)
end

-- ============================================
-- PUSHBACK SYSTEM
-- ============================================
local function applyPushback(targetCharacter, abilityOwnerRootPart)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not abilityOwnerRootPart or not abilityOwnerRootPart.Parent then return end

	pcall(function()
		local targetRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
		if not targetRootPart then return end

		-- Calculate push direction
		local direction = (targetRootPart.Position - abilityOwnerRootPart.Position)
		if direction.Magnitude < 0.1 then return end

		direction = (direction.Unit * Vector3.new(1, 0, 1)) -- Flatten Y

		-- Apply instant pushback
		local pushbackVelocity = direction * Config.Combat.PushbackForce
		local currentVelocity = targetRootPart.AssemblyLinearVelocity

		targetRootPart.AssemblyLinearVelocity = Vector3.new(
			pushbackVelocity.X,
			currentVelocity.Y,
			pushbackVelocity.Z
		)

		-- Decay pushback over time
		task.spawn(function()
			local startTime = tick()
			while tick() - startTime < Config.Combat.PushbackDuration do
				if not targetRootPart or not targetRootPart.Parent then break end

				local progress = (tick() - startTime) / Config.Combat.PushbackDuration
				local decayFactor = 1 - progress

				local currentVel = targetRootPart.AssemblyLinearVelocity
				targetRootPart.AssemblyLinearVelocity = Vector3.new(
					pushbackVelocity.X * decayFactor,
					currentVel.Y,
					pushbackVelocity.Z * decayFactor
				)

				task.wait()
			end

			-- Stop horizontal movement
			if targetRootPart and targetRootPart.Parent then
				local finalVel = targetRootPart.AssemblyLinearVelocity
				targetRootPart.AssemblyLinearVelocity = Vector3.new(0, finalVel.Y, 0)
			end
		end)
	end)
end

-- ============================================
-- RAGDOLL SYSTEM
-- ============================================
local function getMotor6Ds(character)
	local motors = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			table.insert(motors, descendant)
		end
	end
	return motors
end

local function createRagdollConstraint(motor)
	local socket = Instance.new("BallSocketConstraint")
	socket.Name = "RagdollSocket_" .. motor.Name
	socket.LimitsEnabled = true
	socket.TwistLimitsEnabled = true
	socket.UpperAngle = Config.Ragdoll.UpperAngle
	socket.TwistLowerAngle = Config.Ragdoll.TwistLowerAngle
	socket.TwistUpperAngle = Config.Ragdoll.TwistUpperAngle

	local att0 = Instance.new("Attachment")
	att0.Name = "RagdollAtt0"
	att0.CFrame = motor.C0
	att0.Parent = motor.Part0

	local att1 = Instance.new("Attachment")
	att1.Name = "RagdollAtt1"
	att1.CFrame = motor.C1
	att1.Parent = motor.Part1

	socket.Attachment0 = att0
	socket.Attachment1 = att1
	socket.Parent = motor.Part0

	return socket, att0, att1
end

local function enableRagdoll(character)
	if ragdolledCharacters[character] then return false end

	local success, ragdollData = pcall(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return nil end

		local data = {
			motors = {},
			sockets = {},
			attachments = {},
			constraints = {}
		}

		-- Disable humanoid states
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		humanoid.PlatformStand = true

		-- Process motors
		local motors = getMotor6Ds(character)
		for _, motor in ipairs(motors) do
			if motor.Name ~= "RootJoint" and motor.Name ~= "Root" then
				table.insert(data.motors, {
					motor = motor,
					enabled = motor.Enabled
				})

				local socket, att0, att1 = createRagdollConstraint(motor)
				table.insert(data.sockets, socket)
				table.insert(data.attachments, att0)
				table.insert(data.attachments, att1)

				motor.Enabled = false
			end
		end

		-- Enable collision
		if Config.Ragdoll.EnableCollisionOnParts then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end

		return data
	end)

	if success and ragdollData then
		ragdolledCharacters[character] = ragdollData
		return true
	end

	return false
end

local function disableRagdoll(character)
	local ragdollData = ragdolledCharacters[character]
	if not ragdollData then return end

	pcall(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")

		-- Clean up constraints
		for _, constraint in ipairs(ragdollData.constraints) do
			if constraint and constraint.Parent then
				constraint:Destroy()
			end
		end

		-- Stop all movement
		if rootPart then
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
		end

		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
			end
		end

		-- Disable collision
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.CanCollide = false
			end
		end

		-- Position character upright
		if rootPart then
			local currentPos = rootPart.Position

			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = {character}
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude

			local rayResult = workspace:Raycast(currentPos, Vector3.new(0, -10, 0), raycastParams)
			local groundY = rayResult and rayResult.Position.Y or (currentPos.Y - 3)

			local hipHeight = humanoid and humanoid.HipHeight or 2
			local newY = groundY + hipHeight + 1

			rootPart.CFrame = CFrame.new(currentPos.X, newY, currentPos.Z)
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
		end

		-- Clean up ragdoll components
		for _, socket in ipairs(ragdollData.sockets) do
			if socket and socket.Parent then
				socket:Destroy()
			end
		end

		for _, att in ipairs(ragdollData.attachments) do
			if att and att.Parent then
				att:Destroy()
			end
		end

		-- Re-enable motors
		for _, motorData in ipairs(ragdollData.motors) do
			if motorData.motor and motorData.motor.Parent then
				motorData.motor.Enabled = true
			end
		end

		-- Re-enable humanoid control
		if humanoid then
			humanoid.PlatformStand = false
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)

	ragdolledCharacters[character] = nil
end

-- ============================================
-- KNOCKBACK SYSTEM (Final Hit)
-- ============================================
local function applyFinalKnockback(character, hitPosition, ragdollData)
	pcall(function()
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		-- Calculate direction
		local direction = (rootPart.Position - hitPosition)
		direction = Vector3.new(direction.X, 0, direction.Z)

		if direction.Magnitude < 0.1 then
			local angle = math.random() * math.pi * 2
			direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		else
			direction = direction.Unit
		end

		-- Create knockback velocity
		local knockbackVelocity = Vector3.new(
			direction.X * Config.Combat.KnockbackBackVelocity,
			Config.Combat.KnockbackUpVelocity,
			direction.Z * Config.Combat.KnockbackBackVelocity
		)

		-- Create attachment
		local attachment = Instance.new("Attachment")
		attachment.Name = "KnockbackAttachment"
		attachment.Parent = rootPart

		-- Linear velocity for smooth knockback
		local linearVelocity = Instance.new("LinearVelocity")
		linearVelocity.Name = "KnockbackVelocity"
		linearVelocity.Attachment0 = attachment
		linearVelocity.MaxForce = math.huge
		linearVelocity.VectorVelocity = knockbackVelocity
		linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		linearVelocity.Parent = rootPart

		if ragdollData then
			table.insert(ragdollData.constraints, linearVelocity)
			table.insert(ragdollData.attachments, attachment)
		end

		-- Angular velocity for tumbling
		local angularVelocity = Instance.new("AngularVelocity")
		angularVelocity.Name = "KnockbackSpin"
		angularVelocity.Attachment0 = attachment
		angularVelocity.MaxTorque = math.huge
		angularVelocity.AngularVelocity = Vector3.new(
			math.random(Config.Combat.AngularVelocityRange.X.Min, Config.Combat.AngularVelocityRange.X.Max),
			math.random(Config.Combat.AngularVelocityRange.Y.Min, Config.Combat.AngularVelocityRange.Y.Max),
			math.random(Config.Combat.AngularVelocityRange.Z.Min, Config.Combat.AngularVelocityRange.Z.Max)
		)
		angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		angularVelocity.Parent = rootPart

		if ragdollData then
			table.insert(ragdollData.constraints, angularVelocity)
		end

		-- Decay knockback over time
		task.spawn(function()
			local duration = Config.Combat.KnockbackDecayTime
			local startTime = tick()
			local startVelocity = knockbackVelocity

			while tick() - startTime < duration do
				local alpha = (tick() - startTime) / duration
				local easedAlpha = 1 - math.pow(1 - alpha, 2)

				if linearVelocity and linearVelocity.Parent then
					local currentVelocity = startVelocity * (1 - easedAlpha)
					linearVelocity.VectorVelocity = currentVelocity
				else
					break
				end

				task.wait()
			end

			if linearVelocity and linearVelocity.Parent then
				linearVelocity.MaxForce = 0
			end

			task.delay(0.2, function()
				if angularVelocity and angularVelocity.Parent then
					angularVelocity.MaxTorque = 0
				end
			end)
		end)
	end)
end

local function knockbackAndRagdoll(character, hitPosition)
	if ragdolledCharacters[character] then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- Enable ragdoll
	local success = enableRagdoll(character)
	if not success then return end

	-- Apply knockback
	local ragdollData = ragdolledCharacters[character]
	applyFinalKnockback(character, hitPosition, ragdollData)

	-- Schedule recovery
	task.delay(Config.Combat.RagdollDuration, function()
		if character and character.Parent then
			disableRagdoll(character)
		end
	end)
end

-- ============================================
-- OPTIMIZED HITBOX SYSTEM
-- ============================================
local function createHitbox(abilityOwner, character, humanoidRootPart, vfxType)
	if not character or not character.Parent then return end
	if not humanoidRootPart or not humanoidRootPart.Parent then return end

	local abilityData = activeAbilities[abilityOwner]
	if not abilityData then return end

	pcall(function()
		-- Create hitbox part
		local hitbox = Instance.new("Part")
		hitbox.Name = "SlashAbilityHitbox"
		hitbox.Size = Config.Hitbox.Size
		hitbox.Anchored = true
		hitbox.CanCollide = false
		hitbox.CanTouch = false
		hitbox.CanQuery = false
		hitbox.Massless = true
		hitbox.Parent = workspace

		-- Debug visualization
		if Config.Hitbox.DebugVisualization then
			hitbox.Transparency = Config.Hitbox.DebugTransparency
			hitbox.Color = Color3.fromRGB(255, 0, 0)
			hitbox.Material = Enum.Material.ForceField
		else
			hitbox.Transparency = 1
		end

		-- Track hits for this specific hitbox
		local hitboxHitPlayers = {}

		-- Heartbeat connection for hitbox processing
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if not character or not character.Parent then
				connection:Disconnect()
				hitbox:Destroy()
				return
			end

			if not humanoidRootPart or not humanoidRootPart.Parent then
				connection:Disconnect()
				hitbox:Destroy()
				return
			end

			-- Update hitbox position
			local lookVector = humanoidRootPart.CFrame.LookVector
			local hitboxPosition = humanoidRootPart.Position + (lookVector * Config.Hitbox.ForwardOffset)
			hitbox.CFrame = CFrame.new(hitboxPosition, hitboxPosition + lookVector)

			-- Check for overlapping parts
			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Exclude
			overlapParams.FilterDescendantsInstances = {character, hitbox}

			local partsInBox = workspace:GetPartBoundsInBox(hitbox.CFrame, Config.Hitbox.Size, overlapParams)

			for _, part in ipairs(partsInBox) do
				local targetCharacter = part.Parent
				if targetCharacter and targetCharacter:FindFirstChild("Humanoid") then
					local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)

					if targetPlayer and targetPlayer ~= abilityOwner and not hitboxHitPlayers[targetPlayer] then
						local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")

						if targetHumanoid and targetHumanoid.Health > 0 then
							-- Mark as hit by this hitbox
							hitboxHitPlayers[targetPlayer] = true

							-- Apply damage
							targetHumanoid.Health = math.max(0, targetHumanoid.Health - Config.Combat.DamagePerHit)

							-- Special handling for Final hit
							if vfxType == Config.Network.Actions.Final then
								-- Unlock if previously locked
								if abilityData.hitPlayers[targetPlayer] then
									local hitData = abilityData.hitPlayers[targetPlayer]
									if hitData.lockData then
										unlockTargetMovement(targetCharacter, hitData.lockData)
									end
								end

								-- Apply ragdoll and knockback
								knockbackAndRagdoll(targetCharacter, humanoidRootPart.Position)

								-- Hit feedback
								HitFeedback.FlickerHighlight(targetCharacter)

								-- Mark as hit (no lock data, ragdoll handles movement)
								abilityData.hitPlayers[targetPlayer] = {
									character = targetCharacter,
									humanoid = targetHumanoid,
									lockData = nil
								}
							else
								-- Normal hits: lock movement on first hit
								if not abilityData.hitPlayers[targetPlayer] then
									local lockData = lockTargetMovement(targetCharacter, targetHumanoid)
									if lockData then
										abilityData.hitPlayers[targetPlayer] = {
											character = targetCharacter,
											humanoid = targetHumanoid,
											lockData = lockData
										}
									end
								end

								-- Apply pushback
								applyPushback(targetCharacter, humanoidRootPart)

								-- Hit feedback
								HitFeedback.FlickerHighlight(targetCharacter)
							end
						end
					end
				end
			end
		end)

		-- Clean up hitbox after duration
		task.delay(Config.Hitbox.Duration, function()
			connection:Disconnect()
			if hitbox and hitbox.Parent then
				hitbox:Destroy()
			end
		end)
	end)
end

-- ============================================
-- REMOTE EVENT HANDLER
-- ============================================
slashAbilityEvent.OnServerEvent:Connect(function(player, action, character)
	if not player or not character or not character.Parent then
		return
	end

	-- Verify character ownership
	if Players:GetPlayerFromCharacter(character) ~= player then
		warn(string.format("[ANTI-EXPLOIT] Player %s sent character that doesn't belong to them", player.Name))
		return
	end

	-- Handle ability start
	if action == Config.Network.Actions.AbilityStart then
		if not validateAbilityStart(player, character) then
			return
		end

		-- Record cooldown
		playerCooldowns[player] = tick()

		-- Create ability data
		activeAbilities[player] = {
			character = character,
			startTime = tick(),
			lastHitTime = nil,
			hitCount = 0,
			hitPlayers = {}
		}
		return
	end

	-- Handle ability end
	if action == Config.Network.Actions.AbilityEnd then
		local abilityData = activeAbilities[player]
		if abilityData then
			-- Unlock all hit players (except ragdolled)
			for targetPlayer, data in pairs(abilityData.hitPlayers) do
				if not ragdolledCharacters[data.character] then
					unlockTargetMovement(data.character, data.lockData)
				end
			end

			activeAbilities[player] = nil
		end
		return
	end

	-- Handle hit events (Stab, Slash1, Slash3, Slash4, Final)
	if not validateHitEvent(player, action) then
		return
	end

	local abilityData = activeAbilities[player]

	-- Update hit tracking
	abilityData.lastHitTime = tick()
	abilityData.hitCount = abilityData.hitCount + 1

	-- Create hitbox
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		createHitbox(player, character, humanoidRootPart, action)
	end

	-- Replicate to all other clients
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			slashAbilityEvent:FireClient(otherPlayer, action, character)
		end
	end
end)

-- ============================================
-- CLEANUP ON PLAYER LEAVE
-- ============================================
Players.PlayerRemoving:Connect(function(player)
	-- Clean up active ability
	if activeAbilities[player] then
		local abilityData = activeAbilities[player]

		for targetPlayer, data in pairs(abilityData.hitPlayers) do
			if not ragdolledCharacters[data.character] then
				unlockTargetMovement(data.character, data.lockData)
			end
		end

		activeAbilities[player] = nil
	end

	-- Clean up cooldown
	playerCooldowns[player] = nil

	-- Clean up ragdoll
	local character = player.Character
	if character and ragdolledCharacters[character] then
		disableRagdoll(character)
	end
end)

-- ============================================
-- CHARACTER CLEANUP
-- ============================================
Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function(character)
		if ragdolledCharacters[character] then
			disableRagdoll(character)
		end
	end)
end)

-- Existing players
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		player.CharacterRemoving:Connect(function(character)
			if ragdolledCharacters[character] then
				disableRagdoll(character)
			end
		end)
	end
end

print("✓ Slash Ability Server initialized successfully")
