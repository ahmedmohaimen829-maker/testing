--[[
	Hit Feedback Module
	Handles smooth visual feedback for hits (highlights, etc.)

	Place in ReplicatedStorage for shared use
]]

local TweenService = game:GetService("TweenService")
local Config = require(script.Parent.Config)

local HitFeedback = {}

-- ============================================
-- SMOOTH HIGHLIGHT FLICKER (IMPROVED)
-- ============================================
function HitFeedback.FlickerHighlight(character)
	if not character or not character.Parent then return end

	local success, err = pcall(function()
		-- Create highlight
		local highlight = Instance.new("Highlight")
		highlight.Name = "SlashHitFlicker"
		highlight.FillColor = Config.Highlight.FillColor
		highlight.OutlineColor = Config.Highlight.OutlineColor
		highlight.FillTransparency = Config.Highlight.FillTransparency
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Enabled = true
		highlight.Parent = character

		-- Smooth flash to bright red
		local flashTween = TweenService:Create(
			highlight,
			TweenInfo.new(
				Config.Highlight.FlickerInTime,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				FillColor = Config.Highlight.BrightColor,
				OutlineColor = Config.Highlight.BrightOutlineColor,
			}
		)

		-- Smooth fade out
		local fadeTween = TweenService:Create(
			highlight,
			TweenInfo.new(
				Config.Highlight.FlickerOutTime,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.In
			),
			{
				FillTransparency = 1,
				OutlineTransparency = 1,
			}
		)

		-- Play flash, then fade
		flashTween:Play()
		flashTween.Completed:Connect(function()
			if highlight and highlight.Parent then
				fadeTween:Play()
				fadeTween.Completed:Connect(function()
					if highlight and highlight.Parent then
						highlight:Destroy()
					end
				end)
			end
		end)
	end)

	if not success then
		warn("Failed to create hit feedback:", err)
	end
end

-- ============================================
-- SCREEN SHAKE (OPTIONAL - Future Enhancement)
-- ============================================
function HitFeedback.ScreenShake(camera, intensity, duration)
	-- Future: Implement camera shake for local player when hit
	-- This would be called from the client script
end

return HitFeedback
