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

-- Movement lock instances
local originalWalkSpeed = humanoid.WalkSpeed
local originalJumpPower = humanoid.JumpPower
local alignPositionInstance = nil
local alignAttachment = nil
local lockAttachment = nil

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
-- MOVEMENT LOCKING
-- ============================================
local function setMovementLocked(locked)
	local success, err = pcall(function()
		if locked then
			-- Store original values
			originalWalkSpeed = humanoid.WalkSpeed
			originalJumpPower = humanoid.JumpPower

			-- Lock movement
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0

			-- Create position lock
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
		else
			-- Clean up position lock
			if alignPositionInstance then
				alignPositionInstance:Destroy()
				alignPositionInstance = nil
			end

			if alignAttachment then
				alignAttachment:Destroy()
				alignAttachment = nil
			end

			if lockAttachment then
				lockAttachment:Destroy()
				lockAttachment = nil
			end

			-- Restore movement
			humanoid.WalkSpeed = originalWalkSpeed
			humanoid.JumpPower = originalJumpPower
		end
	end)

	if not success then
		warn("Error in setMovementLocked:", err)
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

	local success, err = pcall(function()
		isPlaying = true
		-- DON'T set lastUseTime here - wait until ability ends!

		-- Clean up any active VFX
		vfxHandler:CleanupAllVFX()

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

		isPlaying = false
	end)

	if not success then
		warn("Error playing animation:", err)
		isPlaying = false
		setMovementLocked(false)

		if animationTrack then
			animationTrack:Stop()
			animationTrack:Destroy()
			animationTrack = nil
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

	originalWalkSpeed = humanoid.WalkSpeed
	originalJumpPower = humanoid.JumpPower
	isPlaying = false
	lastUseTime = 0

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

	-- Ensure movement is unlocked
	setMovementLocked(false)
end)

-- ============================================
-- STARTUP
-- ============================================
initialize()

print("✓ Slash Ability Client initialized successfully")
