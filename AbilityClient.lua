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
local originalWalkSpeed = humanoid.WalkSpeed
local originalJumpPower = humanoid.JumpPower
local alignPositionInstance = nil
local alignAttachment = nil
local lockAttachment = nil
local lockConnection = nil
local lockedCFrame = nil
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
-- MOVEMENT LOCKING (ROBUST SYSTEM)
-- ============================================
local function cleanupMovementLock()
	-- Disconnect continuous enforcement
	if lockConnection then
		lockConnection:Disconnect()
		lockConnection = nil
	end

	-- Clean up position lock instances
	if alignPositionInstance and alignPositionInstance.Parent then
		alignPositionInstance:Destroy()
	end
	alignPositionInstance = nil

	if alignAttachment and alignAttachment.Parent then
		alignAttachment:Destroy()
	end
	alignAttachment = nil

	if lockAttachment and lockAttachment.Parent then
		lockAttachment:Destroy()
	end
	lockAttachment = nil

	lockedCFrame = nil
end

local function setMovementLocked(locked)
	local success, err = pcall(function()
		if locked then
			if movementLocked then
				warn("Movement already locked!")
				return
			end

			movementLocked = true
			print("[MOVEMENT LOCK] Locking movement...")

			-- Store original values
			originalWalkSpeed = humanoid.WalkSpeed
			originalJumpPower = humanoid.JumpPower

			-- Store current position/rotation for enforcement
			lockedCFrame = humanoidRootPart.CFrame

			-- STEP 1: Disable all movement-related humanoid states
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)

			-- STEP 2: Set movement properties to zero
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0

			-- STEP 3: Create AlignPosition for position locking
			local lockPosition = humanoidRootPart.Position

			lockAttachment = Instance.new("Attachment")
			lockAttachment.Name = "LockAttachment"
			lockAttachment.WorldPosition = lockPosition
			lockAttachment.Parent = workspace.Terrain

			alignAttachment = Instance.new("Attachment")
			alignAttachment.Name = "MovementLockAttachment"
			alignAttachment.Parent = humanoidRootPart

			alignPositionInstance = Instance.new("AlignPosition")
			alignPositionInstance.Name = "MovementLock"
			alignPositionInstance.Mode = Enum.PositionAlignmentMode.TwoAttachment
			alignPositionInstance.Attachment0 = alignAttachment
			alignPositionInstance.Attachment1 = lockAttachment
			alignPositionInstance.RigidityEnabled = Config.MovementLock.RigidityEnabled
			alignPositionInstance.MaxForce = math.huge
			alignPositionInstance.Responsiveness = Config.MovementLock.Responsiveness
			alignPositionInstance.Parent = humanoidRootPart

			-- STEP 4: Continuous enforcement - force position every frame
			lockConnection = RunService.Heartbeat:Connect(function()
				if not movementLocked then
					if lockConnection then
						lockConnection:Disconnect()
						lockConnection = nil
					end
					return
				end

				-- Enforce movement properties
				if humanoid.WalkSpeed ~= 0 then
					humanoid.WalkSpeed = 0
				end
				if humanoid.JumpPower ~= 0 then
					humanoid.JumpPower = 0
				end

				-- Enforce position (keep rotation but lock position)
				if lockedCFrame and humanoidRootPart then
					local currentRotation = humanoidRootPart.CFrame - humanoidRootPart.CFrame.Position
					humanoidRootPart.CFrame = CFrame.new(lockedCFrame.Position) * currentRotation

					-- Zero out velocity to prevent drift
					humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
						0,
						humanoidRootPart.AssemblyLinearVelocity.Y, -- Keep Y velocity for animations
						0
					)
				end
			end)

			print("[MOVEMENT LOCK] Movement locked successfully")
		else
			if not movementLocked then
				warn("Movement already unlocked!")
				return
			end

			movementLocked = false
			print("[MOVEMENT LOCK] Unlocking movement...")

			-- Clean up enforcement and instances
			cleanupMovementLock()

			-- Re-enable all humanoid states
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)

			-- Restore movement properties
			humanoid.WalkSpeed = originalWalkSpeed
			humanoid.JumpPower = originalJumpPower
			if humanoid.JumpHeight == 0 then
				humanoid.JumpHeight = 7.2 -- Default Roblox value
			end

			-- Verify restoration worked
			task.wait()
			if humanoid.WalkSpeed == 0 then
				warn("[MOVEMENT LOCK] WalkSpeed still 0 after unlock! Force restoring...")
				humanoid.WalkSpeed = originalWalkSpeed or 16
			end

			print("[MOVEMENT LOCK] Movement unlocked successfully - WalkSpeed:", humanoid.WalkSpeed)
		end
	end)

	if not success then
		warn("[MOVEMENT LOCK] ERROR:", err)
		-- Emergency cleanup
		movementLocked = false
		cleanupMovementLock()
		humanoid.WalkSpeed = originalWalkSpeed or 16
		humanoid.JumpPower = originalJumpPower or 50
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
			warn("[MOVEMENT LOCK] Player died while locked - emergency cleanup!")
			movementLocked = false
			cleanupMovementLock()
		end
	end)

	-- Failsafe 2: Maximum duration timeout (safety net)
	task.delay(10, function() -- 10 seconds max for any ability
		if movementLocked then
			warn("[MOVEMENT LOCK] Movement lock exceeded max duration - emergency unlock!")
			setMovementLocked(false)
		end
	end)

	-- Return death connection so it can be cleaned up
	return deathConnection
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
	local success, err = pcall(function()
		isPlaying = true
		-- DON'T set lastUseTime here - wait until ability ends!

		-- Clean up any active VFX
		vfxHandler:CleanupAllVFX()

		-- Setup failsafes BEFORE locking movement
		deathConnection = setupMovementLockFailsafes()

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

		-- Clean up death connection
		if deathConnection then
			deathConnection:Disconnect()
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

		if deathConnection then
			deathConnection:Disconnect()
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

	-- Reset state
	originalWalkSpeed = humanoid.WalkSpeed
	originalJumpPower = humanoid.JumpPower
	isPlaying = false
	lastUseTime = 0
	movementLocked = false

	-- Emergency cleanup of movement lock
	cleanupMovementLock()

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

	print("[CHARACTER RESPAWN] Character respawned, all state reset")
end)

-- ============================================
-- STARTUP
-- ============================================
initialize()

print("✓ Slash Ability Client initialized successfully")
