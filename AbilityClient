--[[
	Slash Ability - Client Script (REFACTORED & OPTIMIZED)
	Place this in StarterPlayer > StarterCharacterScripts

	Features:
	- Smooth VFX emission with optimized particle handling
	- Proper error handling and validation
	- Modular architecture with reusable components
	- Movement locking during ability
	- Client-side prediction with server replication
	- Audio preloading for instant playback
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ============================================
-- MODULE IMPORTS
-- ============================================
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local VFXHandler = require(ReplicatedStorage:WaitForChild("VFXHandler"))
local HitFeedback = require(ReplicatedStorage:WaitForChild("HitFeedback"))

-- ============================================
-- SERVICES & REFERENCES
-- ============================================
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- ============================================
-- REMOTE EVENT
-- ============================================
local reFolder = ReplicatedStorage:WaitForChild("RE")
local slashAbilityEvent = reFolder:WaitForChild("SlashAbilityEvent")

-- ============================================
-- STATE VARIABLES
-- ============================================
local animationTrack = nil
local isPlaying = false
local lastUseTime = 0
local vfxHandler = nil

-- Movement lock instances and state
local DEFAULT_WALKSPEED = 16 -- Fallback if we can't get original
local DEFAULT_JUMPPOWER = 50 -- Fallback if we can't get original
local originalWalkSpeed = math.max(humanoid.WalkSpeed, DEFAULT_WALKSPEED) -- Never store 0
local originalJumpPower = math.max(humanoid.JumpPower, DEFAULT_JUMPPOWER) -- Never store 0
local bodyPosition = nil
local bodyGyro = nil
local movementLocked = false

-- ============================================
-- INITIALIZATION
-- ============================================
local function initialize()
	-- Create VFX handler
	vfxHandler = VFXHandler.new()
	local success = vfxHandler:Initialize(humanoidRootPart)

	if not success then
		warn("Failed to initialize VFX handler")
		return false
	end

	return true
end

-- ============================================
-- MOVEMENT LOCKING (SIMPLIFIED & RELIABLE)
-- ============================================
local function cleanupMovementLock()
	-- Clean up BodyPosition
	if bodyPosition and bodyPosition.Parent then
		bodyPosition:Destroy()
	end
	bodyPosition = nil

	-- Clean up BodyGyro
	if bodyGyro and bodyGyro.Parent then
		bodyGyro:Destroy()
	end
	bodyGyro = nil
end

local function setMovementLocked(locked)
	if locked then
		if movementLocked then
			return -- Already locked, skip
		end

		local success, err = pcall(function()
			movementLocked = true
			print("[MOVEMENT LOCK] Locking movement...")

			-- Store original values (NEVER store 0!)
			local currentWalkSpeed = humanoid.WalkSpeed
			local currentJumpPower = humanoid.JumpPower

			if currentWalkSpeed > 0 then
				originalWalkSpeed = currentWalkSpeed
			end
			if currentJumpPower > 0 then
				originalJumpPower = currentJumpPower
			end

			-- STEP 1: Disable movement-related humanoid states
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)

			-- STEP 2: Set movement properties to zero
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0

			-- STEP 3: Create BodyPosition to anchor player in place
			bodyPosition = Instance.new("BodyPosition")
			bodyPosition.Name = "MovementLock_Position"
			bodyPosition.Position = humanoidRootPart.Position
			bodyPosition.MaxForce = Vector3.new(400000, 400000, 400000)
			bodyPosition.P = 10000
			bodyPosition.D = 500
			bodyPosition.Parent = humanoidRootPart

			-- STEP 4: Create BodyGyro to allow rotation but lock position
			bodyGyro = Instance.new("BodyGyro")
			bodyGyro.Name = "MovementLock_Gyro"
			bodyGyro.MaxTorque = Vector3.new(0, 400000, 0) -- Only Y-axis (allow looking around)
			bodyGyro.P = 3000
			bodyGyro.CFrame = humanoidRootPart.CFrame
			bodyGyro.Parent = humanoidRootPart

			print("[MOVEMENT LOCK] Movement locked successfully")
		end)

		if not success then
			warn("[MOVEMENT LOCK] ERROR during lock:", err)
			movementLocked = false
			cleanupMovementLock()
		end
	else
		if not movementLocked then
			return -- Already unlocked, skip
		end

		local success, err = pcall(function()
			print("[MOVEMENT LOCK] Unlocking movement...")

			-- CRITICAL: Set flag FIRST to prevent any interference
			movementLocked = false

			-- STEP 1: Clean up physics constraints IMMEDIATELY
			cleanupMovementLock()

			-- STEP 2: Re-enable humanoid states
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)

			-- STEP 3: Restore movement properties (NO task.wait()!)
			humanoid.WalkSpeed = originalWalkSpeed
			humanoid.JumpPower = originalJumpPower
			humanoid.JumpHeight = 7.2

			-- STEP 4: Immediate verification (synchronous, no delays)
			if humanoid.WalkSpeed == 0 then
				warn("[MOVEMENT LOCK] WalkSpeed is 0! Using default:", DEFAULT_WALKSPEED)
				humanoid.WalkSpeed = DEFAULT_WALKSPEED
			end
			if humanoid.JumpPower == 0 then
				humanoid.JumpPower = DEFAULT_JUMPPOWER
			end

			print("[MOVEMENT LOCK] Movement unlocked - WalkSpeed:", humanoid.WalkSpeed, "JumpPower:", humanoid.JumpPower)
		end)

		if not success then
			warn("[MOVEMENT LOCK] ERROR during unlock:", err)
			-- Emergency restoration
			movementLocked = false
			cleanupMovementLock()
			humanoid.WalkSpeed = DEFAULT_WALKSPEED
			humanoid.JumpPower = DEFAULT_JUMPPOWER
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
	end
end

-- ============================================
-- VFX REPLICATION (for other players)
-- ============================================
local function playVFXForCharacter(targetCharacter, vfxType)
	if not targetCharacter or not targetCharacter.Parent then return end

	-- REMOVED CHECK: Allow VFX for own character when explicitly sent by server
	-- This is critical for Final hit VFX - victims need to see the effect!
	-- The server explicitly sends Final VFX to hit players, even if it's their own character

	local targetHumanoidRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetHumanoidRootPart then return end

	-- Create temporary VFX handler for this character
	local tempVFXHandler = VFXHandler.new()
	tempVFXHandler:Initialize(targetHumanoidRootPart)
	tempVFXHandler:PlayVFX(vfxType, targetHumanoidRootPart)

	-- Clean up after VFX finishes
	task.delay(Config.VFX.CleanupTime + 1, function()
		tempVFXHandler:Destroy()
	end)
end

-- ============================================
-- FAILSAFE SYSTEMS
-- ============================================
local function setupMovementLockFailsafes()
	-- Failsafe 1: Death detection
	local deathConnection = humanoid.Died:Connect(function()
		if movementLocked then
			warn("[FAILSAFE] Player died during ability - emergency cleanup!")
			movementLocked = false
			cleanupMovementLock()
			humanoid.WalkSpeed = DEFAULT_WALKSPEED
			humanoid.JumpPower = DEFAULT_JUMPPOWER
		end
	end)

	-- Failsafe 2: Maximum duration timeout (safety net)
	local timeoutConnection
	timeoutConnection = task.delay(8, function() -- 8 seconds max (abilities should be ~3-4s)
		if movementLocked then
			warn("[FAILSAFE] Ability exceeded max duration - forcing unlock!")
			setMovementLocked(false)
		end
	end)

	-- Return connections for cleanup
	return deathConnection, timeoutConnection
end

-- ============================================
-- ANIMATION PLAYBACK
-- ============================================
local function playAnimation()
	-- Check if already playing
	if isPlaying then
		return
	end

	-- Check cooldown
	local currentTime = tick()
	if currentTime - lastUseTime < Config.Cooldown.Duration then
		local remainingCooldown = Config.Cooldown.Duration - (currentTime - lastUseTime)
		warn(string.format("Ability on cooldown: %.1f seconds remaining", remainingCooldown))
		return
	end

	-- Validate animation ID
	if Config.Animation.ID == "" then
		warn("ANIMATION_ID is not set in Config!")
		return
	end

	local deathConnection = nil
	local timeoutConnection = nil
	local success, err = pcall(function()
		isPlaying = true
		-- DON'T set lastUseTime here - wait until ability ends!

		-- Clean up any active VFX
		vfxHandler:CleanupAllVFX()

		-- Setup failsafes BEFORE locking movement
		deathConnection, timeoutConnection = setupMovementLockFailsafes()

		-- Lock movement
		setMovementLocked(true)

		-- Notify server
		slashAbilityEvent:FireServer(Config.Network.Actions.AbilityStart, character)

		-- Create and load animation
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. Config.Animation.ID
		animationTrack = humanoid:LoadAnimation(animation)

		-- Connect animation markers to VFX
		animationTrack:GetMarkerReachedSignal("Slash1"):Connect(function()
			vfxHandler:PlayVFX("Stab")
			slashAbilityEvent:FireServer(Config.Network.Actions.Stab, character)
		end)

		animationTrack:GetMarkerReachedSignal("Slash2"):Connect(function()
			vfxHandler:PlayVFX("Slash1")
			slashAbilityEvent:FireServer(Config.Network.Actions.Slash1, character)
		end)

		animationTrack:GetMarkerReachedSignal("Slash3"):Connect(function()
			vfxHandler:PlayVFX("Slash3")
			slashAbilityEvent:FireServer(Config.Network.Actions.Slash3, character)
		end)

		animationTrack:GetMarkerReachedSignal("Slash4"):Connect(function()
			vfxHandler:PlayVFX("Slash4")
			slashAbilityEvent:FireServer(Config.Network.Actions.Slash4, character)
		end)

		animationTrack:GetMarkerReachedSignal("Final"):Connect(function()
			vfxHandler:PlayVFX("Final")
			slashAbilityEvent:FireServer(Config.Network.Actions.Final, character)
		end)

		-- Play animation
		animationTrack:Play()

		-- Wait for animation to end
		animationTrack.Ended:Wait()

		-- Notify server
		slashAbilityEvent:FireServer(Config.Network.Actions.AbilityEnd, character)

		-- SET COOLDOWN HERE (when ability ends, not when it starts!)
		lastUseTime = tick()

		-- Unlock movement
		setMovementLocked(false)

		-- Clean up animation
		if animationTrack then
			animationTrack:Stop()
			animationTrack:Destroy()
			animationTrack = nil
		end

		-- Clean up failsafe connections
		if deathConnection then
			deathConnection:Disconnect()
		end
		if timeoutConnection then
			task.cancel(timeoutConnection)
		end

		isPlaying = false
	end)

	if not success then
		warn("Error playing animation:", err)
		isPlaying = false

		-- CRITICAL: Emergency cleanup to restore movement
		if movementLocked then
			setMovementLocked(false)
		end

		if animationTrack then
			animationTrack:Stop()
			animationTrack:Destroy()
			animationTrack = nil
		end

		-- Clean up failsafe connections
		if deathConnection then
			deathConnection:Disconnect()
		end
		if timeoutConnection then
			task.cancel(timeoutConnection)
		end
	end
end

-- ============================================
-- INPUT HANDLING
-- ============================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Config.Input.ActivationKey then
		playAnimation()
	end
end)

-- ============================================
-- NETWORK EVENT HANDLING
-- ============================================
slashAbilityEvent.OnClientEvent:Connect(function(vfxType, targetCharacter)
	if vfxType and targetCharacter then
		playVFXForCharacter(targetCharacter, vfxType)
	end
end)

-- ============================================
-- CHARACTER RESPAWN HANDLING
-- ============================================
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
	humanoidRootPart = newCharacter:WaitForChild("HumanoidRootPart")

	-- Reset state with safe defaults
	originalWalkSpeed = math.max(humanoid.WalkSpeed, DEFAULT_WALKSPEED)
	originalJumpPower = math.max(humanoid.JumpPower, DEFAULT_JUMPPOWER)
	isPlaying = false
	lastUseTime = 0
	movementLocked = false

	-- Emergency cleanup of movement lock
	cleanupMovementLock()

	-- Ensure movement is enabled
	humanoid.WalkSpeed = originalWalkSpeed
	humanoid.JumpPower = originalJumpPower

	-- Clean up old VFX handler
	if vfxHandler then
		vfxHandler:Destroy()
	end

	-- Initialize new VFX handler
	vfxHandler = VFXHandler.new()
	vfxHandler:Initialize(humanoidRootPart)

	-- Clean up animation
	if animationTrack then
		animationTrack:Stop()
		animationTrack:Destroy()
		animationTrack = nil
	end

	print("[CHARACTER RESPAWN] Character respawned - WalkSpeed:", originalWalkSpeed)
end)

-- ============================================
-- STARTUP
-- ============================================
initialize()

print("✓ Slash Ability Client initialized successfully")
