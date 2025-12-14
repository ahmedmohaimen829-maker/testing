--[[
	VFX Handler Module
	Handles smooth VFX emission and audio playback

	Place in ReplicatedStorage for client-side use
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local Config = require(script.Parent.Config)

local VFXHandler = {}
VFXHandler.__index = VFXHandler

-- ============================================
-- CONSTRUCTOR
-- ============================================
function VFXHandler.new()
	local self = setmetatable({}, VFXHandler)

	self.vfxTemplates = {}
	self.preloadedSounds = {}
	self.activeVFXParts = {}

	return self
end

-- ============================================
-- INITIALIZATION
-- ============================================
function VFXHandler:Initialize(humanoidRootPart)
	self.humanoidRootPart = humanoidRootPart

	-- Load VFX templates
	local success, err = pcall(function()
		local vfxFolder = ReplicatedStorage:WaitForChild("VFX", 5):WaitForChild("Ability", 5)

		for effectName, effectData in pairs(Config.VFX.Effects) do
			local template = vfxFolder:FindFirstChild(effectData.TemplateName)
			if template then
				self.vfxTemplates[effectName] = template
			else
				warn(string.format("VFX template '%s' not found for effect '%s'", effectData.TemplateName, effectName))
			end
		end
	end)

	if not success then
		warn("Failed to load VFX templates:", err)
		return false
	end

	-- Preload audio
	self:PreloadAudio()

	return true
end

-- ============================================
-- AUDIO PRELOADING
-- ============================================
function VFXHandler:PreloadAudio()
	-- Clear existing sounds
	for _, sound in pairs(self.preloadedSounds) do
		if sound and sound.Parent then
			sound:Destroy()
		end
	end
	self.preloadedSounds = {}

	local soundsToPreload = {}

	-- Create sound instances
	for effectName, effectData in pairs(Config.VFX.Effects) do
		if effectData.AudioID and effectData.AudioID ~= "" then
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxassetid://" .. effectData.AudioID
			sound.Volume = Config.Audio.Volume
			sound.RollOffMaxDistance = 100
			sound.RollOffMinDistance = 10
			sound.Parent = self.humanoidRootPart

			self.preloadedSounds[effectName] = sound
			table.insert(soundsToPreload, sound.SoundId)
		end
	end

	-- Preload all sounds
	if #soundsToPreload > 0 then
		task.spawn(function()
			local success, err = pcall(function()
				ContentProvider:PreloadAsync(soundsToPreload)
			end)
			if not success then
				warn("Failed to preload audio:", err)
			end
		end)
	end
end

-- ============================================
-- VFX PLAYBACK (IMPROVED & OPTIMIZED)
-- ============================================
function VFXHandler:PlayVFX(effectName, targetRootPart)
	targetRootPart = targetRootPart or self.humanoidRootPart

	if not targetRootPart or not targetRootPart.Parent then
		warn("Invalid target for VFX:", effectName)
		return
	end

	local effectData = Config.VFX.Effects[effectName]
	local vfxTemplate = self.vfxTemplates[effectName]

	if not effectData then
		warn("Effect data not found:", effectName)
		return
	end

	if not vfxTemplate then
		warn("VFX template not found:", effectName)
		return
	end

	-- Play audio
	self:PlayAudio(effectName, targetRootPart)

	-- Create VFX
	task.spawn(function()
		self:CreateVFXAtPosition(
			vfxTemplate,
			effectData.Position,
			effectData.Rotation,
			targetRootPart
		)
	end)
end

-- ============================================
-- CREATE VFX AT POSITION (OPTIMIZED)
-- ============================================
function VFXHandler:CreateVFXAtPosition(vfxTemplate, relativePosition, rotation, targetRootPart)
	if not vfxTemplate then return end

	local success, err = pcall(function()
		-- Calculate rotation
		local rotationCFrame = CFrame.new()
		local useWorldRotation = false

		if rotation then
			if rotation.X == 0 and rotation.Y == 0 and rotation.Z == 0 then
				useWorldRotation = true
			else
				rotationCFrame = CFrame.Angles(
					math.rad(rotation.X),
					math.rad(rotation.Y),
					math.rad(rotation.Z)
				)
			end
		end

		-- Create invisible container
		local container = Instance.new("Part")
		container.Name = "VFXContainer"
		container.Size = Vector3.new(0.1, 0.1, 0.1)
		container.Transparency = 1
		container.CanCollide = false
		container.Anchored = true
		container.CanTouch = false
		container.CanQuery = false

		-- Position container
		local worldPosition = (targetRootPart.CFrame * CFrame.new(relativePosition)).Position

		if useWorldRotation then
			container.CFrame = CFrame.new(worldPosition)
		else
			container.CFrame = targetRootPart.CFrame * CFrame.new(relativePosition) * rotationCFrame
		end

		container.Parent = workspace

		-- Track for cleanup
		table.insert(self.activeVFXParts, container)

		-- Clone and emit VFX (optimized recursive function)
		self:ProcessVFXRecursive(vfxTemplate, container, container)

		-- Schedule cleanup
		Debris:AddItem(container, Config.VFX.CleanupTime)
	end)

	if not success then
		warn("Failed to create VFX:", err)
	end
end

-- ============================================
-- RECURSIVE VFX PROCESSING (OPTIMIZED)
-- ============================================
function VFXHandler:ProcessVFXRecursive(obj, container, parent)
	for _, child in ipairs(obj:GetChildren()) do
		if child:IsA("Attachment") then
			-- Clone attachment
			local attachmentClone = child:Clone()
			attachmentClone.Parent = container

			-- Emit all particle emitters in attachment
			for _, emitter in ipairs(attachmentClone:GetChildren()) do
				if emitter:IsA("ParticleEmitter") then
					local emitCount = emitter:GetAttribute("EmitCount") or 20
					emitter:Emit(emitCount)

					-- Optional: Smoother emission by spreading over time
					if emitCount > 50 then
						task.spawn(function()
							local burstCount = math.ceil(emitCount / 3)
							for i = 1, 3 do
								if emitter and emitter.Parent then
									emitter:Emit(burstCount)
									task.wait(0.016) -- ~1 frame
								end
							end
						end)
					end
				end
			end

		elseif child:IsA("BasePart") then
			-- Clone part
			local partClone = child:Clone()
			partClone.CFrame = container.CFrame * child.CFrame
			partClone.Anchored = true
			partClone.CanCollide = false
			partClone.CanTouch = false
			partClone.CanQuery = false
			partClone.Parent = container

			table.insert(self.activeVFXParts, partClone)

			-- Process children of part
			self:ProcessVFXRecursive(child, container, partClone)

		elseif child:IsA("ParticleEmitter") then
			-- Clone emitter directly attached to parent
			local emitterClone = child:Clone()
			emitterClone.Parent = container

			local emitCount = emitterClone:GetAttribute("EmitCount") or 20
			emitterClone:Emit(emitCount)

		else
			-- Process other children recursively
			self:ProcessVFXRecursive(child, container, parent)
		end
	end
end

-- ============================================
-- AUDIO PLAYBACK
-- ============================================
function VFXHandler:PlayAudio(effectName, targetRootPart)
	targetRootPart = targetRootPart or self.humanoidRootPart

	local sound = self.preloadedSounds[effectName]
	if not sound then return end

	local success, err = pcall(function()
		local soundToPlay = sound

		-- Clone sound for other characters
		if targetRootPart ~= self.humanoidRootPart then
			soundToPlay = sound:Clone()
			soundToPlay.Parent = targetRootPart
		else
			-- Stop if already playing to allow immediate replay
			if sound.IsPlaying then
				sound:Stop()
			end
		end

		soundToPlay:Play()

		-- Clean up cloned sounds
		if soundToPlay ~= sound then
			soundToPlay.Ended:Connect(function()
				soundToPlay:Destroy()
			end)
			Debris:AddItem(soundToPlay, 10)
		end
	end)

	if not success then
		warn("Failed to play audio:", effectName, err)
	end
end

-- ============================================
-- CLEANUP
-- ============================================
function VFXHandler:CleanupAllVFX()
	for _, part in ipairs(self.activeVFXParts) do
		if part and part.Parent then
			part:Destroy()
		end
	end
	self.activeVFXParts = {}
end

function VFXHandler:Destroy()
	self:CleanupAllVFX()

	for _, sound in pairs(self.preloadedSounds) do
		if sound and sound.Parent then
			sound:Destroy()
		end
	end
	self.preloadedSounds = {}
end

return VFXHandler
