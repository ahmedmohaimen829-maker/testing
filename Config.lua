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
	HitReactionID = "", -- Set this to your hit reaction animation ID
	HitReactionSpeed = 1.5, -- Speed multiplier for hit reaction
	HitReactionFadeTime = 0.1, -- Fade out time for hit reaction
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
	-- Normal hit hitbox
	Size = Vector3.new(6, 6, 6),
	ForwardOffset = 3.2,
	Duration = 0.5,
	DebugVisualization = false, -- Set to true to see hitboxes
	DebugTransparency = 0.5,

	-- Final hit hitbox (YELLOW - Expanding)
	Final = {
		StartSize = Vector3.new(6, 6, 6),   -- Starting size
		EndSize = Vector3.new(6, 6, 11),    -- Ending size (expands forward)
		Duration = 0.8,                      -- Longer duration for Final hit
		DebugColor = Color3.fromRGB(255, 255, 0), -- Yellow for Final
	},
}

-- ============================================
-- COMBAT SETTINGS
-- ============================================
Config.Combat = {
	DamagePerHit = 5,

	-- Normal hit pushback (IMPROVED SMOOTHNESS)
	PushbackForce = 30,
	PushbackDuration = 0.2, -- Slightly longer for smoother feel
	PushbackEasingStyle = Enum.EasingStyle.Quad, -- Smooth easing
	PushbackEasingDirection = Enum.EasingDirection.Out, -- Ease out
	UseSmoothPushback = true, -- Use TweenService instead of frame-by-frame

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

	-- Ragdoll smoothness settings
	InstantRagdoll = true, -- Apply ragdoll immediately without delay
	SmoothRecovery = true, -- Smooth transition when getting up
	RecoveryTransitionTime = 0.2, -- Time to transition from ragdoll to normal
}

-- ============================================
-- HIGHLIGHT SETTINGS (Hit Feedback)
-- ============================================
Config.Highlight = {
	FillColor = Color3.fromRGB(255, 0, 0),
	OutlineColor = Color3.fromRGB(200, 0, 0),
	FillTransparency = 0.3,
	FlickerInTime = 0.025, -- Quick flash
	FlickerOutTime = 0.1,
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
