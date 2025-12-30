--[[
-- Kui_Nameplates_ChatBubble
-- By Kesava at curse.com
-- All rights reserved
-- Backported by: Kader at https://github.com/bkader
-- ChatBubble module for Kui_Nameplates core layout.
]]
local addon = LibStub("AceAddon-3.0"):GetAddon("KuiNameplates")
local kui = LibStub("Kui-1.0")
local mod = addon:NewModule("ChatBubble", addon.Prototype, "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("KuiNameplatesChatBubble")

local GetTime, floor, ceil, format = GetTime, floor, ceil, format
local UnitExists, UnitGUID, InCombatLockdown = UnitExists, UnitGUID, InCombatLockdown
local GetScreenWidth, GetScreenHeight = GetScreenWidth, GetScreenHeight
local strfind, strsplit, tinsert = strfind, strsplit, tinsert

-- store profiles to reduce lookup
local db_display

-- Chat type mappings
local CHAT_TYPES = {
	["CHAT_MSG_SAY"] = "SAY",
	["CHAT_MSG_YELL"] = "YELL",
	["CHAT_MSG_PARTY"] = "PARTY",
	["CHAT_MSG_GUILD"] = "GUILD",
	["CHAT_MSG_RAID"] = "RAID",
	["CHAT_MSG_MONSTER_SAY"] = "MONSTER_SAY",
	["CHAT_MSG_MONSTER_YELL"] = "MONSTER_YELL"
}

-- Chat colors by type
local CHAT_COLORS = {
	["SAY"] = {1, 1, 1, 1},
	["YELL"] = {1, 0.25, 0.25, 1},
	["PARTY"] = {0.67, 0.67, 1, 1},
	["GUILD"] = {0.25, 1, 0.25, 1},
	["RAID"] = {1, 0.5, 0, 1},
	["MONSTER_SAY"] = {1, 1, 0.62, 1},
	["MONSTER_YELL"] = {1, 0.25, 0.25, 1}
}

local function UpdateDisplay()
	-- Update stored profiles
	db_display = mod.db.profile.display
end

local function CreateChatBubble(f)
	-- Create chat bubble background if it doesn't exist
	if f.bubbleFrame then return end
	
	f.bubbleFrame = CreateFrame("Frame", nil, WorldFrame)
	f.bubbleFrame:SetFrameStrata("TOOLTIP")
	f.bubbleFrame:SetFrameLevel(98)
	
	-- Set proper chat bubble backdrop (like real WoW chat bubbles)
	f.bubbleFrame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\ChatBubble-Background",
		edgeFile = "Interface\\Tooltips\\ChatBubble-BackDrop",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 16, right = 16, top = 16, bottom = 16 }
	})
	f.bubbleFrame:SetBackdropColor(1, 1, 1, 1)
	
	-- Create fontstring directly on the chat bubble frame
	f.bubbleText = f.bubbleFrame:CreateFontString(nil, "OVERLAY")
	local fontSize = db_display.font_size or 12
	f.bubbleText:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
	f.bubbleText:SetJustifyH("CENTER")
	f.bubbleText:SetJustifyV("MIDDLE")
	f.bubbleText:SetWordWrap(true)
	f.bubbleText:SetNonSpaceWrap(true)
	
	-- Initially hide the bubble
	f.bubbleFrame:Hide()
	f.bubbleText:Hide()
end

local function ShowChatOnNameplate(senderName, message, msgType)
	-- Check if chat bubbles are enabled
	if not db_display.enable then
		return
	end
	
	-- Check chat type filters
	if msgType == "SAY" and not db_display.show_say then return end
	if msgType == "YELL" and not db_display.show_yell then return end
	if msgType == "PARTY" and not db_display.show_party then return end
	if msgType == "GUILD" and not db_display.show_guild then return end
	if msgType == "RAID" and not db_display.show_raid then return end
	if (msgType == "MONSTER_SAY" or msgType == "MONSTER_YELL") and not db_display.show_monster then return end
	
	-- Check if we should hide in combat
	if db_display.hide_in_combat and InCombatLockdown() then
		return
	end
	
	-- Check if we should hide in PvP
	if db_display.hide_in_pvp then
		local _, instanceType = IsInInstance()
		if instanceType == "pvp" or GetZonePVPInfo() == "combat" then
			return
		end
	end
	
	-- Find the nameplate frame for the sender
	local frame = nil
	
	if not addon.frameList or #addon.frameList == 0 then
		return
	end
	
	for _, nameplate in ipairs(addon.frameList) do
		if nameplate.kui and nameplate.kui.name and nameplate.kui.name.text then
			local plateName = nameplate.kui.name.text
			if plateName == senderName then
				frame = nameplate
				break
			end
		end
	end
	
	if not frame or not frame.kui then 
		return 
	end
	
	-- Ensure the frame is properly initialized and visible
	local parentFrame = frame.kui:GetParent()
	if not frame.kui.health or not (parentFrame and parentFrame:IsVisible()) then
		return
	end
	
	-- Check if frame is within screen boundaries
	local nameFrame = frame.kui.name
	local overlayFrame = frame.kui.overlay
	local targetFrame = nameFrame or overlayFrame
	local left, bottom, width, height = targetFrame:GetRect()
	local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
	local right, top = left + width, bottom + height
	
	-- Estimate chat bubble center position
	local bubbleCenterX = left + (width / 2)
	local bubbleCenterY = top + 50 + (db_display.y_offset or 0)
		
	-- Skip if chat bubble center would be outside screen boundaries
	if bubbleCenterX < 0 or bubbleCenterX > screenWidth or 
	   bubbleCenterY < 200 or bubbleCenterY > screenHeight then
		return
	end
	
	local f = frame.kui
	
	-- Create chat bubble if needed
	CreateChatBubble(f)
	
	-- Get chat color
	local chatColor = CHAT_COLORS[msgType] or {1, 1, 1, 1}
	
	-- Apply color to text
	f.bubbleText:SetTextColor(unpack(chatColor))
	
	-- Set text and calculate optimal width
	local maxWidth = db_display.max_width or 300
	
	-- Set text first without width constraint to get natural width
	f.bubbleText:SetText(message)
	f.bubbleText:SetWidth(0) -- Reset width to get natural text width
	local naturalWidth = f.bubbleText:GetStringWidth()
	
	-- Only apply width constraint if text is too wide, otherwise use natural width
	if naturalWidth > maxWidth then
		f.bubbleText:SetWidth(maxWidth) -- Apply constraint for long text
	else
		f.bubbleText:SetWidth(naturalWidth) -- Use natural width for short text
	end
	
	-- Get the final dimensions after width applied
	local textWidth = f.bubbleText:GetWidth()
	local textHeight = f.bubbleText:GetStringHeight()
	
	-- Calculate bubble size with padding
	local bubbleWidth = textWidth + 32 -- Padding for bubble edges
	local bubbleHeight = textHeight + 32 -- 16px top + 16px bottom padding
	
	-- Set border color by chat type
	f.bubbleFrame:SetBackdropBorderColor(unpack(chatColor))
	
	-- Position and size the chat bubble to match the text
	f.bubbleFrame:SetSize(bubbleWidth, bubbleHeight)
	f.bubbleFrame:ClearAllPoints()
	f.bubbleFrame:SetPoint("BOTTOM", f.health, "TOP", 0, 15 + (db_display.y_offset or 0))
	f.bubbleFrame:Show()
	
	-- Position text inside the chat bubble
	f.bubbleText:ClearAllPoints()
	f.bubbleText:SetPoint("CENTER", f.bubbleFrame, "CENTER", 0, 0)
	
	-- Show text
	f.bubbleText:Show()
	
	-- Hide after configured duration
	local duration = db_display.duration or 4
	C_Timer.After(duration, function()
		if f.bubbleText and f.bubbleFrame then
			f.bubbleText:Hide()
			f.bubbleFrame:Hide()
		end
	end)
end

-- Event handler
local function OnChatMessage(event, message, sender)
	if not message or not sender then return end
	
	local name = strsplit("-", sender)
	local msgType = CHAT_TYPES[event]
	
	if msgType then
		ShowChatOnNameplate(name, message, msgType)
	end
end

------------------------------------------------------------ Module functions --
function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			display = {
				enable = true,
				max_width = 300,
				duration = 4,
				font_size = 12,
				y_offset = 0,
				hide_in_combat = false,
				hide_in_pvp = false,
				show_say = true,
				show_yell = true,
				show_party = true,
				show_guild = true,
				show_raid = false,
				show_monster = true
			}
		}
	})
	
	UpdateDisplay()
end

function mod:OnEnable()
	self:RegisterEvent("CHAT_MSG_SAY", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_YELL", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_PARTY", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_GUILD", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_RAID", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_MONSTER_SAY", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_MONSTER_YELL", OnChatMessage)
end

function mod:OnDisable()
	self:UnregisterAllEvents()
end

-- Called when our configuration changes
function mod:ConfigChanged()
	UpdateDisplay()
end