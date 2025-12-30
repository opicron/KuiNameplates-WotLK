local addon = LibStub("AceAddon-3.0"):GetAddon("KuiNameplates")
local mod = addon:NewModule("Elite", addon.Prototype, "AceEvent-3.0")

-- Skull icon texture path
local SKULL_ICON = "Interface\\AddOns\\Kui_Nameplates_Elite\\SkullIcon.tga"

function mod:Create(msg, frame)
	-- Create skull icon during frame creation
	frame.skull = CreateFrame("Frame", nil, frame)
	frame.skull:SetWidth(16)
	frame.skull:SetHeight(16)
	frame.skull:Hide()
	
	-- Create the skull texture
	frame.skull.icon = frame.skull:CreateTexture(nil, "OVERLAY")
	frame.skull.icon:SetAllPoints()
	frame.skull.icon:SetTexture(SKULL_ICON)
	frame.skull.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	
	-- Position next to level text
	frame.skull:SetPoint("LEFT", frame.level, "LEFT", -20, 4)
	frame.skull:Hide()
end

local function UpdateSkullVisibility(frame)
	-- Only show skull if: (friendly AND targeted) OR hostile
	local levelText = frame.level:GetText() or ""
	local isEliteOrRare = levelText:find("Elite") or levelText:find("Rare") or levelText:find("Boss")
	
	if isEliteOrRare then
		if (frame.friend and frame.target) or (not frame.friend) then
			frame.skull:Show()
		else
			frame.skull:Hide()
		end
	else
		frame.skull:Hide()
	end
end

function mod:PostShow(msg, frame)
	-- Update elite text (this happens after Kui's OnFrameShow)
	local levelText = frame.level:GetText() or ""

	if levelText:sub(-1) == "+" then
		frame.level:SetText(levelText:sub(1, -2) .. ' Elite')
	elseif levelText:sub(-2) == "r+" then
		frame.level:SetText(levelText:sub(1, -3) .. ' Rare Elite')
	elseif levelText:sub(-1) == "r" then
		frame.level:SetText(levelText:sub(1, -2) .. ' Rare')
	elseif levelText:sub(-1) == "b" then
		frame.level:SetText(levelText:sub(1, -2) .. ' Boss')
	end
	
	-- Update skull visibility based on conditions
	UpdateSkullVisibility(frame)
end

function mod:PostTarget(msg, frame, is_target)
	-- Update skull when targeting changes
	UpdateSkullVisibility(frame)
end

function mod:OnEnable()
	self:RegisterMessage("KuiNameplates_PostCreate", "Create")
	self:RegisterMessage("KuiNameplates_PostShow", "PostShow")
	self:RegisterMessage("KuiNameplates_PostTarget", "PostTarget")
	
	-- Create elements for existing frames
	for _, frame in pairs(addon.frameList) do
		if frame.kui and not frame.kui.skull then
			self:Create(nil, frame.kui)
		end
	end
end

function mod:OnDisable()
	-- Hide all skull icons
	for _, frame in pairs(addon.frameList) do
		if frame.kui and frame.kui.skull then
			frame.kui.skull:Hide()
		end
	end
end