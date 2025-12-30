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

-- Chat message queue (fallback when no visible frame found)
local chatQueue = {}
local QUEUE_TIMEOUT = 4 -- seconds to keep messages in queue

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

-- Add message to queue with timestamp
local function AddToQueue(senderName, message, msgType)
	local currentTime = GetTime()
	
	-- Clean old messages first
	for i = #chatQueue, 1, -1 do
		if currentTime - chatQueue[i].timestamp > QUEUE_TIMEOUT then
			table.remove(chatQueue, i)
		end
	end
	
	-- Add new message
	table.insert(chatQueue, {
		sender = senderName,
		message = message,
		msgType = msgType,
		timestamp = currentTime
	})
end

local function UpdateContainerSize(frame)
	-- Set size and position of the chat bubble container frame
	-- Following Auras addon pattern exactly
	local yOffset = db_display.y_offset or 0
	frame.chatBubbles:SetWidth(db_display.max_width or 300)
	frame.chatBubbles:ClearAllPoints()
	frame.chatBubbles:SetPoint("BOTTOM", frame.health, "TOP", 0, 15 + yOffset)
end

-- Display chat bubble directly on a kui frame (extracted logic)
local function DisplayChatBubbleOnFrame(f, message, msgType)
	-- Make sure the chat bubble was created (should be done in Create)
	if not f.chatBubbles then
		return
	end
	
	-- Update container positioning (in case nameplate moved)
	UpdateContainerSize(f)
	
	-- Get chat color
	local chatColor = CHAT_COLORS[msgType] or {1, 1, 1, 1}
	
	-- Apply color to text
	f.chatBubbles.text:SetTextColor(unpack(chatColor))
	
	-- Update font size
	local fontSize = db_display.font_size or 12
	f.chatBubbles.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
	
	-- Set text and calculate optimal width
	local maxWidth = db_display.max_width or 300
	
	-- Set text first without width constraint to get natural width
	f.chatBubbles.text:SetText(message)
	f.chatBubbles.text:SetWidth(0) -- Reset width to get natural text width
	local naturalWidth = f.chatBubbles.text:GetStringWidth()
	
	-- Only apply width constraint if text is too wide, otherwise use natural width
	if naturalWidth > maxWidth then
		f.chatBubbles.text:SetWidth(maxWidth) -- Apply constraint for long text
	else
		f.chatBubbles.text:SetWidth(naturalWidth) -- Use natural width for short text
	end
	
	-- Get the final dimensions after width applied
	local textWidth = f.chatBubbles.text:GetWidth()
	local textHeight = f.chatBubbles.text:GetStringHeight()
	
	-- Calculate bubble size with padding
	local bubbleWidth = textWidth + 32 -- Padding for bubble edges
	local bubbleHeight = textHeight + 32 -- 16px top + 16px bottom padding
	
	-- Set border color by chat type
	f.chatBubbles.bubbleFrame:SetBackdropBorderColor(unpack(chatColor))
	
	-- Position and size the chat bubble frame
	f.chatBubbles.bubbleFrame:SetSize(bubbleWidth, bubbleHeight)
	f.chatBubbles.bubbleFrame:ClearAllPoints()
	f.chatBubbles.bubbleFrame:SetPoint("CENTER", f.chatBubbles, "CENTER", 0, 0)
	
	-- Update container height to match bubble
	f.chatBubbles:SetHeight(bubbleHeight)
	
	-- Position text inside the chat bubble
	f.chatBubbles.text:ClearAllPoints()
	f.chatBubbles.text:SetPoint("CENTER", f.chatBubbles.bubbleFrame, "CENTER", 0, 0)
	
	-- Show everything at full opacity
	f.chatBubbles:Show()
	f.chatBubbles.bubbleFrame:Show()
	f.chatBubbles.bubbleFrame:SetAlpha(1) -- Ensure full opacity regardless of parent
	f.chatBubbles.text:Show()
	f.chatBubbles.text:SetAlpha(1) -- Ensure text is also fully visible
	
	-- Cancel any existing timer
	if f.chatBubbles.timer then
		f.chatBubbles.timer:SetScript("OnUpdate", nil)
		f.chatBubbles.timer = nil
	end
	
	-- Hide after configured duration using WotLK-compatible timer
	local duration = db_display.duration or 4
	f.chatBubbles.timer = CreateFrame("Frame")
	f.chatBubbles.timer.timeLeft = duration
	f.chatBubbles.timer.container = f.chatBubbles
	f.chatBubbles.timer:SetScript("OnUpdate", function(self, elapsed)
		self.timeLeft = self.timeLeft - elapsed
		if self.timeLeft <= 0 then
			if self.container then
				self.container:Hide()
			end
			self:SetScript("OnUpdate", nil)
		end
	end)
end

-- Process queued messages for a nameplate that just became available
local function ProcessQueueForNameplate(frame)
	if not frame or not frame.name or not frame.name.text then
		return
	end
	
	local frameName = frame.name.text
	local currentTime = GetTime()
	
	-- Look for matching messages in queue
	for i = #chatQueue, 1, -1 do
		local queuedMsg = chatQueue[i]
		
		-- Remove expired messages
		if currentTime - queuedMsg.timestamp > QUEUE_TIMEOUT then
			table.remove(chatQueue, i)
		-- Process matching messages
		elseif queuedMsg.sender == frameName then
			-- Found a match! Display the chat bubble directly (ensure we pass kui frame)
			-- frame parameter should already be the kui frame since it has frame.name.text
			DisplayChatBubbleOnFrame(frame, queuedMsg.message, queuedMsg.msgType)
			
			-- Don't remove from queue - let timeout handle it so message can redisplay if camera moves
			-- Only process one message per frame update to avoid spam
			break
		end
	end
end

local function ShowChatOnNameplate(senderName, message, msgType)
	-- Check if chat bubbles are enabled
	if not mod.db.profile.enabled then
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
	
	if addon.frameList and #addon.frameList > 0 then
		for _, nameplate in ipairs(addon.frameList) do
			if nameplate.kui and nameplate.kui.name and nameplate.kui.name.text then
				local plateName = nameplate.kui.name.text
				if plateName == senderName then
					-- Validate this is actually the correct frame by checking if it's actively displayed
					if nameplate:IsVisible() and nameplate.kui:GetAlpha() > 0 then
						frame = nameplate
						break
					end
				end
			end
		end
	end
	
	-- Always add to queue for potential redisplay when camera moves
	AddToQueue(senderName, message, msgType)
	
	-- Only display immediately if we found a visible frame
	if frame then
		local f = frame.kui
		DisplayChatBubbleOnFrame(f, message, msgType)
	end
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

----------------------------------------------------------------------- hooks --
function mod:Create(msg, frame)
	-- Create chat bubble container following Auras pattern exactly
	frame.chatBubbles = CreateFrame("Frame", nil, frame)
	frame.chatBubbles.frame = frame
	
	-- Position and size is set OnShow (below)
	frame.chatBubbles:SetHeight(10)
	frame.chatBubbles:Hide()
	
	-- Create the actual visible bubble frame as child of container
	frame.chatBubbles.bubbleFrame = CreateFrame("Frame", nil, frame.chatBubbles)
	frame.chatBubbles.bubbleFrame:SetFrameStrata("TOOLTIP")
	frame.chatBubbles.bubbleFrame:SetFrameLevel(3)
	
	-- Set proper chat bubble backdrop
	frame.chatBubbles.bubbleFrame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\ChatBubble-Background",
		edgeFile = "Interface\\Tooltips\\ChatBubble-BackDrop",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 16, right = 16, top = 16, bottom = 16 }
	})
	frame.chatBubbles.bubbleFrame:SetBackdropColor(1, 1, 1, 1)
	
	-- Create text
	frame.chatBubbles.text = frame.chatBubbles.bubbleFrame:CreateFontString(nil, "OVERLAY")
	frame.chatBubbles.text:SetJustifyH("CENTER")
	frame.chatBubbles.text:SetJustifyV("MIDDLE")
	frame.chatBubbles.text:SetWordWrap(true)
	frame.chatBubbles.text:SetNonSpaceWrap(true)
	
	-- Initially hide everything
	frame.chatBubbles.bubbleFrame:Hide()
	frame.chatBubbles.text:Hide()
	
	-- Store timer for cleanup
	frame.chatBubbles.timer = nil
	
	frame.chatBubbles:SetScript("OnHide", function(self)
		if self.frame.MOVING then
			return
		end
		
		-- Hide and cleanup bubble elements
		if self.bubbleFrame then
			self.bubbleFrame:Hide()
		end
		if self.text then
			self.text:Hide()
		end
		if self.timer then
			self.timer:SetScript("OnUpdate", nil)
			self.timer = nil
		end
	end)
end

function mod:PostShow(msg, frame)
	-- Process any queued messages for this nameplate (queue fallback)
	ProcessQueueForNameplate(frame)
end

function mod:Hide(msg, frame)
	if frame.chatBubbles then
		frame.chatBubbles:Hide()
	end
end

------------------------------------------------------------ Module functions --
function mod:GetOptions()
	return {
		enabled = {
			type = "toggle",
			name = L["Enable chat bubbles"],
			desc = L["Show chat bubbles above nameplates when units speak in chat"],
			order = 1,
			disabled = false
		},
		display = {
			type = "group",
			name = L["Display"],
			inline = true,
			disabled = function()
				return not self.db.profile.enabled
			end,
			order = 10,
			args = {
				max_width = {
					type = "range",
					name = L["Max width"],
					desc = L["Maximum width of chat bubbles before text wrapping occurs"],
					order = 10,
					step = 10,
					min = 100,
					max = 500,
					softMin = 200,
					softMax = 400
				},
				duration = {
					type = "range",
					name = L["Duration"],
					desc = L["How long chat bubbles stay visible (in seconds)"],
					order = 20,
					step = 0.5,
					min = 0.5,
					max = 10,
					softMin = 1,
					softMax = 8
				},
				y_offset = {
					type = "range",
					name = L["Y offset"],
					desc = L["Vertical position adjustment for chat bubbles"],
					order = 30,
					step = 1,
					min = -50,
					max = 50
				},
				font_size = {
					type = "range",
					name = L["Font size"],
					desc = L["Size of the chat bubble text"],
					order = 40,
					step = 1,
					min = 6,
					max = 24,
					softMin = 8,
					softMax = 20
				}
			}
		},
		combat = {
			type = "group",
			name = L["Combat"],
			inline = true,
			disabled = function()
				return not self.db.profile.enabled
			end,
			order = 20,
			args = {
				hide_in_combat = {
					type = "toggle",
					name = L["Hide in combat"],
					desc = L["Hide chat bubbles when in combat"],
					order = 10
				},
				hide_in_pvp = {
					type = "toggle",
					name = L["Hide in PvP"],
					desc = L["Hide chat bubbles when in PvP areas"],
					order = 20
				}
			}
		},
		chat_types = {
			type = "group",
			name = "Chat Types",
			inline = true,
			disabled = function()
				return not self.db.profile.enabled
			end,
			order = 30,
			args = {
				show_say = {
					type = "toggle",
					name = L["Show SAY"],
					desc = L["Show SAY messages in chat bubbles"],
					order = 10
				},
				show_yell = {
					type = "toggle",
					name = L["Show YELL"],
					desc = L["Show YELL messages in chat bubbles"],
					order = 20
				},
				show_party = {
					type = "toggle",
					name = L["Show PARTY"],
					desc = L["Show PARTY messages in chat bubbles"],
					order = 30
				},
				show_guild = {
					type = "toggle",
					name = L["Show GUILD"],
					desc = L["Show GUILD messages in chat bubbles"],
					order = 40
				},
				show_raid = {
					type = "toggle",
					name = L["Show RAID"],
					desc = L["Show RAID messages in chat bubbles"],
					order = 50
				},
				show_monster = {
					type = "toggle",
					name = L["Show monster messages"],
					desc = L["Show NPC say and yell messages in chat bubbles"],
					order = 60
				}
			}
		}
	}
end

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			enabled = true,
			display = {
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
	
	addon:InitModuleOptions(self)
	mod:SetEnabledState(self.db.profile.enabled)
	
	UpdateDisplay()
end

function mod:OnEnable()
	self:RegisterMessage("KuiNameplates_PostCreate", "Create")
	self:RegisterMessage("KuiNameplates_PostShow", "PostShow")
	self:RegisterMessage("KuiNameplates_PostHide", "Hide")
	
	self:RegisterEvent("CHAT_MSG_SAY", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_YELL", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_PARTY", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_GUILD", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_RAID", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_MONSTER_SAY", OnChatMessage)
	self:RegisterEvent("CHAT_MSG_MONSTER_YELL", OnChatMessage)
	
	-- Initialize chat bubbles for existing frames
	for _, frame in pairs(addon.frameList) do
		if not frame.kui.chatBubbles then
			self:Create(nil, frame.kui)
		end
	end
end

function mod:OnDisable()
	self:UnregisterMessage("KuiNameplates_PostCreate", "Create")
	self:UnregisterMessage("KuiNameplates_PostShow", "PostShow")
	self:UnregisterMessage("KuiNameplates_PostHide", "Hide")
	
	self:UnregisterAllEvents()
	
	-- Hide all active chat bubbles
	for _, frame in pairs(addon.frameList) do
		self:Hide(nil, frame.kui)
	end
end

-- Called when our configuration changes
function mod:ConfigChanged()
	UpdateDisplay()
end

-- Add config change listener like Auras addon
mod:AddConfigChanged("enabled", function(v) mod:Toggle(v) end)