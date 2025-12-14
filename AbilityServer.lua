--[[
	Slash Ability - Server Script (ULTRA SMOOTH & OPTIMIZED)
	Place this in ServerScriptService

	Features:
	- Smooth pushback with TweenService (no stuttering!)
	- Hit reaction animations
	- Fixed Final hit ragdoll consistency
	- Instant ragdoll response with smooth recovery
	- Server-side validation and anti-exploit protection
	- Proper error handling
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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
local activePushbacks = {} -- {[character] = {tweens, connections}}
local activeHitAnimations = {} -- {[character] = animationTrack}

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
	local currentTime = tick()
	local lastUseTime = playerCooldowns[player] or 0

	if currentTime - lastUseTime < Config.Cooldown.Duration then
		warn(string.format("[ANTI-EXPLOIT] Player %s attempted to use ability during cooldown", player.Name))
		return false
	end

	if Players:GetPlayerFromCharacter(character) ~= player then
		warn(string.format("[ANTI-EXPLOIT] Player %s sent invalid character", player.Name))
		return false
	end

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

	if tick() - abilityData.startTime > Config.Validation.MaxAbilityDuration then
		warn(string.format("[ANTI-EXPLOIT] Player %s ability exceeded max duration", player.Name))
		return false
	end

	if abilityData.lastHitTime then
		if tick() - abilityData.lastHitTime < Config.Validation.MinTimeBetweenHits then
			warn(string.format("[ANTI-EXPLOIT] Player %s hit events too frequent", player.Name))
			return false
		end
	end

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
-- HIT REACTION ANIMATION SYSTEM
-- ============================================
local function playHitReactionAnimation(targetCharacter)
	if not targetCharacter or not targetCharacter.Parent then return end
	if Config.Animation.HitReactionID == "" then return end

	pcall(function()
		local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		-- Stop any existing hit animation
		if activeHitAnimations[targetCharacter] then
			activeHitAnimations[targetCharacter]:Stop(Config.Animation.HitReactionFadeTime)
			activeHitAnimations[targetCharacter] = nil
		end

		-- Create and play hit reaction animation
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. Config.Animation.HitReactionID

		local animTrack = humanoid:LoadAnimation(animation)
		animTrack:Play(Config.Animation.HitReactionFadeTime, 1, Config.Animation.HitReactionSpeed)

		activeHitAnimations[targetCharacter] = animTrack

		-- Clean up after animation
		task.delay(animTrack.Length / Config.Animation.HitReactionSpeed + 0.1, function()
			if activeHitAnimations[targetCharacter] == animTrack then
				activeHitAnimations[targetCharacter] = nil
			end
		end)
	end)
end

-- ============================================
-- SMOOTH PUSHBACK SYSTEM (FIXED STUTTERING!)
-- ============================================
local function cleanupPushback(targetCharacter)
	local pushbackData = activePushbacks[targetCharacter]
	if not pushbackData then return end

	-- Stop all tweens
	for _, tween in ipairs(pushbackData.tweens or {}) do
		if tween then
			tween:Cancel()
		end
	end

	-- Disconnect connections
	for _, connection in ipairs(pushbackData.connections or {}) do
		if connection then
			connection:Disconnect()
		end
	end

	-- Destroy velocity object
	if pushbackData.bodyVelocity and pushbackData.bodyVelocity.Parent then
		pushbackData.bodyVelocity:Destroy()
	end

	activePushbacks[targetCharacter] = nil
end

local function applyPushback(targetCharacter, abilityOwnerRootPart)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not abilityOwnerRootPart or not abilityOwnerRootPart.Parent then return end

	pcall(function()
		local targetRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
		if not targetRootPart then return end

		-- Clean up any existing pushback
		cleanupPushback(targetCharacter)

		-- Calculate push direction
		local direction = (targetRootPart.Position - abilityOwnerRootPart.Position)
		if direction.Magnitude < 0.1 then return end

		direction = (direction.Unit * Vector3.new(1, 0, 1)) -- Flatten Y

		local pushbackVelocity = direction * Config.Combat.PushbackForce

		if Config.Combat.UseSmoothPushback then
			-- SMOOTH METHOD: Using BodyVelocity with TweenService (BUTTER SMOOTH!)
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge) -- Only horizontal
			bodyVelocity.Velocity = pushbackVelocity
			bodyVelocity.P = 10000
			bodyVelocity.Parent = targetRootPart

			-- Tween velocity to zero smoothly
			local tweenInfo = TweenInfo.new(
				Config.Combat.PushbackDuration,
				Config.Combat.PushbackEasingStyle,
				Config.Combat.PushbackEasingDirection
			)

			local tween = TweenService:Create(bodyVelocity, tweenInfo, {
				Velocity = Vector3.zero
			})

			-- Store for cleanup
			activePushbacks[targetCharacter] = {
				bodyVelocity = bodyVelocity,
				tweens = {tween},
				connections = {}
			}

			tween:Play()

			-- Clean up after tween completes
			tween.Completed:Connect(function()
				cleanupPushback(targetCharacter)
			end)
		else
			-- LEGACY METHOD: Direct velocity manipulation (kept as fallback)
			local currentVelocity = targetRootPart.AssemblyLinearVelocity
			targetRootPart.AssemblyLinearVelocity = Vector3.new(
				pushbackVelocity.X,
				currentVelocity.Y,
				pushbackVelocity.Z
			)

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

				if targetRootPart and targetRootPart.Parent then
					local finalVel = targetRootPart.AssemblyLinearVelocity
					targetRootPart.AssemblyLinearVelocity = Vector3.new(0, finalVel.Y, 0)
				end
			end)
		end

		-- Play hit reaction animation
		playHitReactionAnimation(targetCharacter)
	end)
end

-- ============================================
-- RAGDOLL SYSTEM (IMPROVED CONSISTENCY)
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
	-- FIX #3: Check moved to caller, but keep as safety (return true if already exists)
	if ragdolledCharacters[character] then
		print("Ragdoll already active for", character.Name, "- returning true")
		return true -- Return true because ragdoll IS active, just already exists
	end

	local success, ragdollData = pcall(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			print("Invalid humanoid for ragdoll")
			return nil
		end

		local data = {
			motors = {},
			sockets = {},
			attachments = {},
			constraints = {},
			humanoid = humanoid
		}

		-- FIX #2: FORCE HUMANOID STATE MORE AGGRESSIVELY
		-- Disable ALL states that could interfere
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)

		-- Force physics state TWICE (Roblox sometimes ignores the first)
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		task.wait() -- Single frame yield to let state propagate
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		humanoid.PlatformStand = true -- Set again after state change

		-- Process motors INSTANTLY
		local motors = getMotor6Ds(character)
		for _, motor in ipairs(motors) do
			-- Don't disable RootJoint for better stability
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

		-- Enable collision for physics
		if Config.Ragdoll.EnableCollisionOnParts then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.CanCollide = true
				end
			end
		end

		print("Ragdoll enabled successfully for", character.Name)
		return data
	end)

	if success and ragdollData then
		ragdolledCharacters[character] = ragdollData
		return true
	else
		warn("Failed to enable ragdoll:", ragdollData)
	end

	return false
end

local function disableRagdoll(character)
	local ragdollData = ragdolledCharacters[character]
	if not ragdollData then return end

	pcall(function()
		local humanoid = ragdollData.humanoid or character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")

		-- Clean up constraints FIRST
		for _, constraint in ipairs(ragdollData.constraints) do
			if constraint and constraint.Parent then
				constraint:Destroy()
			end
		end

		-- SMOOTH RECOVERY: Gradual velocity reduction
		if Config.Combat.SmoothRecovery and rootPart then
			local currentVel = rootPart.AssemblyLinearVelocity
			local currentAngVel = rootPart.AssemblyAngularVelocity

			-- Tween to zero velocity
			local tweenInfo = TweenInfo.new(
				Config.Combat.RecoveryTransitionTime,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)

			-- Create temporary part to tween (we'll manually apply values)
			task.spawn(function()
				local startTime = tick()
				while tick() - startTime < Config.Combat.RecoveryTransitionTime do
					if not rootPart or not rootPart.Parent then break end

					local alpha = (tick() - startTime) / Config.Combat.RecoveryTransitionTime
					local smoothAlpha = 1 - math.pow(1 - alpha, 2) -- Ease out

					rootPart.AssemblyLinearVelocity = currentVel * (1 - smoothAlpha)
					rootPart.AssemblyAngularVelocity = currentAngVel * (1 - smoothAlpha)

					task.wait()
				end

				if rootPart and rootPart.Parent then
					rootPart.AssemblyLinearVelocity = Vector3.zero
					rootPart.AssemblyAngularVelocity = Vector3.zero
				end
			end)
		else
			-- Stop all movement instantly
			if rootPart then
				rootPart.AssemblyLinearVelocity = Vector3.zero
				rootPart.AssemblyAngularVelocity = Vector3.zero
			end
		end

		-- Stop velocity on all parts
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
			humanoid.AutoRotate = true
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end

		print("Ragdoll disabled for", character.Name)
	end)

	ragdolledCharacters[character] = nil
end

-- ============================================
-- FINAL KNOCKBACK (IMPROVED CONSISTENCY)
-- ============================================
local function applyFinalKnockback(character, hitPosition, ragdollData)
	pcall(function()
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			warn("No HumanoidRootPart for final knockback")
			return
		end

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

		print("Applied final knockback to", character.Name)

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
	-- Prevent duplicate ragdolls
	if ragdolledCharacters[character] then
		print("Character already ragdolled, skipping")
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		print("Invalid humanoid, skipping ragdoll")
		return
	end

	print("Attempting to ragdoll and knockback:", character.Name)

	-- Clean up any active pushback first
	cleanupPushback(character)

	-- Enable ragdoll INSTANTLY
	local success = enableRagdoll(character)
	if not success then
		warn("Failed to enable ragdoll for", character.Name)
		return
	end

	-- Apply knockback IMMEDIATELY after ragdoll
	local ragdollData = ragdolledCharacters[character]
	if ragdollData then
		applyFinalKnockback(character, hitPosition, ragdollData)
	else
		warn("Ragdoll data not found after enabling ragdoll")
	end

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
local function createHitbox(abilityOwner, character, humanoidRootPart, vfxType, customDuration)
	if not character or not character.Parent then return end
	if not humanoidRootPart or not humanoidRootPart.Parent then return end

	local abilityData = activeAbilities[abilityOwner]
	if not abilityData then return end

	pcall(function()
		-- Determine if this is Final hit for special handling
		local isFinalHit = (vfxType == Config.Network.Actions.Final)

		-- Create hitbox part with dynamic size for Final hit
		local hitbox = Instance.new("Part")
		hitbox.Name = "SlashAbilityHitbox"
		hitbox.Size = Config.Hitbox.Size -- Start at 6,6,6
		hitbox.Anchored = true
		hitbox.CanCollide = false
		hitbox.CanTouch = false
		hitbox.CanQuery = false
		hitbox.Massless = true
		hitbox.Parent = workspace

		-- Debug visualization
		if Config.Hitbox.DebugVisualization then
			hitbox.Transparency = Config.Hitbox.DebugTransparency
			hitbox.Color = isFinalHit and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 0, 0)
			hitbox.Material = Enum.Material.ForceField
		else
			hitbox.Transparency = 1
		end

		-- Track hits for this specific hitbox
		local hitboxHitPlayers = {}
		local hitboxStartTime = tick()

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

			-- FINAL HIT: Expand hitbox size over time (6,6,6 → 6,6,11)
			if isFinalHit then
				local elapsed = tick() - hitboxStartTime
				local duration = customDuration or Config.Hitbox.Duration
				local progress = math.min(elapsed / duration, 1)

				-- Expand Z dimension from 6 to 11
				local startZ = 6
				local endZ = 11
				local currentZ = startZ + (endZ - startZ) * progress

				hitbox.Size = Vector3.new(6, 6, currentZ)
			end

			-- Update hitbox position
			local lookVector = humanoidRootPart.CFrame.LookVector
			local hitboxPosition = humanoidRootPart.Position + (lookVector * Config.Hitbox.ForwardOffset)
			hitbox.CFrame = CFrame.new(hitboxPosition, hitboxPosition + lookVector)

			-- Check for overlapping parts
			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Exclude
			overlapParams.FilterDescendantsInstances = {character, hitbox}

			local partsInBox = workspace:GetPartBoundsInBox(hitbox.CFrame, hitbox.Size, overlapParams)

			-- FIX #1: DEDUPLICATE TO ONE PART PER CHARACTER BEFORE PROCESSING
			local charactersHit = {}
			for _, part in ipairs(partsInBox) do
				local targetCharacter = part.Parent
				if targetCharacter and targetCharacter:FindFirstChild("Humanoid") and not charactersHit[targetCharacter] then
					charactersHit[targetCharacter] = part
				end
			end

			-- Process each unique character hit
			for targetCharacter, part in pairs(charactersHit) do
				local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)

				if targetPlayer and targetPlayer ~= abilityOwner and not hitboxHitPlayers[targetPlayer] then
					local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")

					if targetHumanoid and targetHumanoid.Health > 0 then
						-- Mark as hit by this hitbox IMMEDIATELY
						hitboxHitPlayers[targetPlayer] = true

						-- Apply damage
						targetHumanoid.Health = math.max(0, targetHumanoid.Health - Config.Combat.DamagePerHit)

						-- SPECIAL HANDLING FOR FINAL HIT (FIXED CONSISTENCY)
						if isFinalHit then
							-- FIX #5: Detailed debug logging
							print("=== FINAL HIT DEBUG ===")
							print("Target:", targetPlayer.Name)
							print("Already ragdolled?:", ragdolledCharacters[targetCharacter] ~= nil)
							print("Humanoid health:", targetHumanoid.Health)
							print("Humanoid state:", targetHumanoid:GetState().Name)
							print("Hitbox size at hit:", hitbox.Size)

							-- Unlock if previously locked
							if abilityData.hitPlayers[targetPlayer] then
								local hitData = abilityData.hitPlayers[targetPlayer]
								if hitData.lockData then
									unlockTargetMovement(targetCharacter, hitData.lockData)
								end
							end

							-- Apply ragdoll and knockback (INSTANT, NO DELAY)
							knockbackAndRagdoll(targetCharacter, humanoidRootPart.Position)

							-- Hit feedback
							HitFeedback.FlickerHighlight(targetCharacter)

							-- CRITICAL: Explicitly send Final VFX to the hit player so they see the effect!
							slashAbilityEvent:FireClient(targetPlayer, vfxType, character)
							print("Sent Final VFX to hit player:", targetPlayer.Name)

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

							-- Apply smooth pushback
							applyPushback(targetCharacter, humanoidRootPart)

							-- Hit feedback
							HitFeedback.FlickerHighlight(targetCharacter)
						end
					end
				end
			end
		end)

		-- Clean up hitbox after duration (longer for Final hit)
		task.delay(customDuration or Config.Hitbox.Duration, function()
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

		-- DON'T set cooldown here - wait until ability ends!

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

			-- SET COOLDOWN HERE (when ability ends, not when it starts!)
			playerCooldowns[player] = tick()
			print(string.format("[COOLDOWN] %s ability ended, cooldown set for %d seconds", player.Name, Config.Cooldown.Duration))
		end
		return
	end

	-- Handle hit events
	if not validateHitEvent(player, action) then
		return
	end

	local abilityData = activeAbilities[player]

	-- Update hit tracking
	abilityData.lastHitTime = tick()
	abilityData.hitCount = abilityData.hitCount + 1

	-- Create hitbox (with extended duration for Final hit)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		-- FIX #4: Extend duration for Final hit to ensure it connects
		local duration = (action == Config.Network.Actions.Final) and 0.8 or nil
		createHitbox(player, character, humanoidRootPart, action, duration)
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
	if activeAbilities[player] then
		local abilityData = activeAbilities[player]

		for targetPlayer, data in pairs(abilityData.hitPlayers) do
			if not ragdolledCharacters[data.character] then
				unlockTargetMovement(data.character, data.lockData)
			end
		end

		activeAbilities[player] = nil
	end

	playerCooldowns[player] = nil

	local character = player.Character
	if character then
		if ragdolledCharacters[character] then
			disableRagdoll(character)
		end
		cleanupPushback(character)
	end
end)

-- ============================================
-- CHARACTER CLEANUP
-- ============================================
local function setupCharacterCleanup(player)
	player.CharacterRemoving:Connect(function(character)
		if ragdolledCharacters[character] then
			disableRagdoll(character)
		end
		cleanupPushback(character)
		if activeHitAnimations[character] then
			activeHitAnimations[character]:Stop()
			activeHitAnimations[character] = nil
		end
	end)
end

Players.PlayerAdded:Connect(setupCharacterCleanup)

for _, player in ipairs(Players:GetPlayers()) do
	setupCharacterCleanup(player)
end

print("✓ Slash Ability Server initialized successfully (ULTRA SMOOTH)")
