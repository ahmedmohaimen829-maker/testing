--[[
	Ability System Configuration Module
	Shared between Client and Server

	Place in ReplicatedStorage for access by both sides
]]

local Config = {}

-- ============================================
-- ANIMATION SETTINGS
-- ============================================
Config.Animation = {
	ID = "125104321474109",
}

-- ============================================
-- VFX SETTINGS
-- ============================================
Config.VFX = {
	FolderPath = "VFX/Ability", -- Path in ReplicatedStorage
	CleanupTime = 3,

	Effects = {
		Stab = {
			TemplateName = "Stab",
			Position = Vector3.new(1, 0, -3),
			Rotation = nil,
			AudioID = "101644004711755",
		},
		Slash1 = {
			TemplateName = "Slash1",
			Position = Vector3.new(0, 0, -0.1),
			Rotation = Vector3.new(0, 0, -127),
			AudioID = "101644004711755",
		},
		Slash3 = {
			TemplateName = "Slash3",
			Position = Vector3.new(0, 0, 0),
			Rotation = Vector3.new(0, 0, 80),
			AudioID = "101644004711755",
		},
		Slash4 = {
			TemplateName = "Slash4",
			Position = Vector3.new(0, 0, -3.5),
			Rotation = nil,
			AudioID = "101644004711755",
		},
		Final = {
			TemplateName = "Final",
			Position = Vector3.new(0, -3.5, -7),
			Rotation = Vector3.new(0, 0, 0),
			AudioID = "3359047385",
		},
	},
}

-- ============================================
-- AUDIO SETTINGS
-- ============================================
Config.Audio = {
	Volume = 0.5,
	PreloadOnStart = true,
}

-- ============================================
-- HITBOX SETTINGS
-- ============================================
Config.Hitbox = {
	Size = Vector3.new(6, 6, 6),
	ForwardOffset = 3.2,
	Duration = 0.5,
	DebugVisualization = false, -- Set to true to see hitboxes
	DebugTransparency = 0.5,
}

-- ============================================
-- COMBAT SETTINGS
-- ============================================
Config.Combat = {
	DamagePerHit = 5,

	-- Normal hit pushback
	PushbackForce = 35,
	PushbackDuration = 0.15,

	-- Final hit knockback & ragdoll
	KnockbackUpVelocity = 100,
	KnockbackBackVelocity = 120,
	RagdollDuration = 2,
	KnockbackDecayTime = 0.3,
	AngularVelocityRange = {
		X = {Min = -8, Max = 8},
		Y = {Min = -4, Max = 4},
		Z = {Min = -8, Max = 8},
	},
}

-- ============================================
-- HIGHLIGHT SETTINGS (Hit Feedback)
-- ============================================
Config.Highlight = {
	FillColor = Color3.fromRGB(255, 0, 0),
	OutlineColor = Color3.fromRGB(200, 0, 0),
	FillTransparency = 0.3,
	FlickerInTime = 0.025, -- Quick flash
	FlickerOutTime = 0.05,
	BrightColor = Color3.fromRGB(255, 50, 50),
	BrightOutlineColor = Color3.fromRGB(255, 0, 0),
}

-- ============================================
-- COOLDOWN SETTINGS
-- ============================================
Config.Cooldown = {
	Duration = 3, -- Seconds between uses
	ShowUI = true, -- Future: cooldown UI indicator
}

-- ============================================
-- RAGDOLL SETTINGS
-- ============================================
Config.Ragdoll = {
	UpperAngle = 50,
	TwistLowerAngle = -50,
	TwistUpperAngle = 50,
	EnableCollisionOnParts = true,
}

-- ============================================
-- NETWORK SETTINGS
-- ============================================
Config.Network = {
	RemoteEventName = "SlashAbilityEvent",
	RemoteFolderPath = "RE", -- Path in ReplicatedStorage

	-- Actions (for type safety)
	Actions = {
		AbilityStart = "AbilityStart",
		AbilityEnd = "AbilityEnd",
		Stab = "Stab",
		Slash1 = "Slash1",
		Slash3 = "Slash3",
		Slash4 = "Slash4",
		Final = "Final",
	},
}

-- ============================================
-- VALIDATION SETTINGS (Server-side)
-- ============================================
Config.Validation = {
	MaxAbilityDuration = 10, -- Max time ability should take
	MinTimeBetweenHits = 0.05, -- Minimum time between hit events
	MaxHitsPerAbility = 5, -- Maximum hits in one ability use
}

-- ============================================
-- INPUT SETTINGS
-- ============================================
Config.Input = {
	ActivationKey = Enum.KeyCode.R,
}

-- ============================================
-- MOVEMENT LOCK SETTINGS
-- ============================================
Config.MovementLock = {
	-- AlignPosition settings
	Responsiveness = 200,
	RigidityEnabled = true,
}

return Config
