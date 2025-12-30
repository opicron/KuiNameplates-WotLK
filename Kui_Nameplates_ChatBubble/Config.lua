--[[
-- Kui_Nameplates_ChatBubble Config
-- By Kesava at curse.com
-- All rights reserved
-- Backported by: Kader at https://github.com/bkader
]]
local addon, ns = ...
local KUI = LibStub("AceAddon-3.0"):GetAddon("KuiNameplates")
local mod = KUI:GetModule("ChatBubble")
local L = LibStub("AceLocale-3.0"):GetLocale("KuiNameplatesChatBubble")

local category = L["Chat Bubbles"]

KuiNameplatesChatBubbleCustom = {}

local f = CreateFrame("Frame")
f.UpdateDisplay = {}

-- Chat message filtering and customization
local messageFilters = {
	["blocked_words"] = {},
	["blocked_players"] = {},
	["custom_colors"] = {},
	["message_replacements"] = {}
}

------------------------------------------------------------- create category --
local opt = CreateFrame("Frame", "KuiNameplatesChatBubbleConfig", InterfaceOptionsFramePanelContainer)
opt:Hide()
opt.name = category

------------------------------------------------------------- create elements --
-- blocked words section
local blockedWordsTitle = opt:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
blockedWordsTitle:SetText("Message Filtering")
blockedWordsTitle:SetPoint("TOPLEFT", 20, -20)

local blockedWordsDesc = opt:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
blockedWordsDesc:SetText("Block chat bubbles containing specific words or from specific players")
blockedWordsDesc:SetPoint("TOPLEFT", blockedWordsTitle, "BOTTOMLEFT", 0, -5)
blockedWordsDesc:SetPoint("RIGHT", -20, 0)
blockedWordsDesc:SetWordWrap(true)

-- blocked words list frame
local blockedWordsFrame = CreateFrame("Frame", "KuiNameplatesChatBubbleBlockedWordsFrame", opt)
blockedWordsFrame:SetSize(300, 150)
blockedWordsFrame:SetPoint("TOPLEFT", blockedWordsDesc, "BOTTOMLEFT", 0, -10)

local blockedWordsScroll = CreateFrame("ScrollFrame", "KuiNameplatesChatBubbleBlockedWordsScrollFrame", opt, "UIPanelScrollFrameTemplate")
blockedWordsScroll:SetSize(300, 150)
blockedWordsScroll:SetScrollChild(blockedWordsFrame)
blockedWordsScroll:SetPoint("TOPLEFT", blockedWordsDesc, "BOTTOMLEFT", 0, -10)

local blockedWordsBg = CreateFrame("Frame", nil, opt)
blockedWordsBg:SetBackdrop({
	bgFile = "Interface/ChatFrame/ChatFrameBackground",
	edgeFile = "Interface/Tooltips/UI-Tooltip-border",
	edgeSize = 16,
	insets = {left = 4, right = 4, top = 4, bottom = 4}
})
blockedWordsBg:SetBackdropColor(.1, .1, .1, .3)
blockedWordsBg:SetBackdropBorderColor(.5, .5, .5)
blockedWordsBg:SetPoint("TOPLEFT", blockedWordsScroll, -10, 10)
blockedWordsBg:SetPoint("BOTTOMRIGHT", blockedWordsScroll, 30, -10)

-- word entry text box
local wordEntryBox = CreateFrame("EditBox", "KuiNameplatesChatBubbleWordEntryBox", opt, "InputBoxTemplate")
wordEntryBox:SetAutoFocus(false)
wordEntryBox:EnableMouse(true)
wordEntryBox:SetMaxLetters(50)
wordEntryBox:SetPoint("TOPLEFT", blockedWordsScroll, "BOTTOMLEFT", 0, -10)
wordEntryBox:SetSize(200, 25)

-- add word button
local addWordButton = CreateFrame("Button", "KuiNameplatesChatBubbleAddWordButton", opt, "UIPanelButtonTemplate")
addWordButton:SetText("Add Word")
addWordButton:SetPoint("LEFT", wordEntryBox, "RIGHT", 5, 0)
addWordButton:SetSize(80, 25)

-- player name entry
local playerEntryBox = CreateFrame("EditBox", "KuiNameplatesChatBubblePlayerEntryBox", opt, "InputBoxTemplate")
playerEntryBox:SetAutoFocus(false)
playerEntryBox:EnableMouse(true)
playerEntryBox:SetMaxLetters(50)
playerEntryBox:SetPoint("TOPLEFT", wordEntryBox, "BOTTOMLEFT", 0, -10)
playerEntryBox:SetSize(200, 25)

-- add player button
local addPlayerButton = CreateFrame("Button", "KuiNameplatesChatBubbleAddPlayerButton", opt, "UIPanelButtonTemplate")
addPlayerButton:SetText("Block Player")
addPlayerButton:SetPoint("LEFT", playerEntryBox, "RIGHT", 5, 0)
addPlayerButton:SetSize(80, 25)

-- custom colors section
local customColorsTitle = opt:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
customColorsTitle:SetText("Custom Colors")
customColorsTitle:SetPoint("TOPLEFT", playerEntryBox, "BOTTOMLEFT", 0, -30)

local customColorsDesc = opt:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
customColorsDesc:SetText("Set custom colors for specific players or words")
customColorsDesc:SetPoint("TOPLEFT", customColorsTitle, "BOTTOMLEFT", 0, -5)
customColorsDesc:SetPoint("RIGHT", -20, 0)
customColorsDesc:SetWordWrap(true)

-- color target entry
local colorTargetBox = CreateFrame("EditBox", "KuiNameplatesChatBubbleColorTargetBox", opt, "InputBoxTemplate")
colorTargetBox:SetAutoFocus(false)
colorTargetBox:EnableMouse(true)
colorTargetBox:SetMaxLetters(50)
colorTargetBox:SetPoint("TOPLEFT", customColorsDesc, "BOTTOMLEFT", 0, -10)
colorTargetBox:SetSize(150, 25)

-- color picker button
local colorPickerButton = CreateFrame("Button", "KuiNameplatesChatBubbleColorPickerButton", opt, "UIPanelButtonTemplate")
colorPickerButton:SetText("Pick Color")
colorPickerButton:SetPoint("LEFT", colorTargetBox, "RIGHT", 5, 0)
colorPickerButton:SetSize(80, 25)

-- reset button
local resetButton = CreateFrame("Button", "KuiNameplatesChatBubbleResetButton", opt, "UIPanelButtonTemplate")
resetButton:SetText("Reset All")
resetButton:SetPoint("TOPRIGHT", -20, -20)
resetButton:SetSize(100, 25)

-- help text
local helpText = opt:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
helpText:SetText([[
• Use 'Add Word' to block messages containing specific words
• Use 'Block Player' to block all messages from a player
• Right-click items in the blocked words list to remove them
• Custom colors override default chat type colors
• All settings are saved per character]])
helpText:SetPoint("BOTTOMLEFT", 20, 50)
helpText:SetPoint("BOTTOMRIGHT", -20, 50)
helpText:SetWordWrap(true)
helpText:SetJustifyH("LEFT")
helpText:SetJustifyV("TOP")

------------------------------------------------------------- script handlers --
local function AddBlockedWord(word)
	if word and word ~= "" then
		word = strlower(strtrim(word))
		if not KuiNameplatesChatBubbleCustom.blocked_words then
			KuiNameplatesChatBubbleCustom.blocked_words = {}
		end
		KuiNameplatesChatBubbleCustom.blocked_words[word] = true
		f.UpdateDisplay()
	end
end

local function AddBlockedPlayer(player)
	if player and player ~= "" then
		player = strtrim(player)
		if not KuiNameplatesChatBubbleCustom.blocked_players then
			KuiNameplatesChatBubbleCustom.blocked_players = {}
		end
		KuiNameplatesChatBubbleCustom.blocked_players[player] = true
		f.UpdateDisplay()
	end
end

local function RemoveBlockedWord(word)
	if KuiNameplatesChatBubbleCustom.blocked_words then
		KuiNameplatesChatBubbleCustom.blocked_words[word] = nil
	end
	f.UpdateDisplay()
end

local function RemoveBlockedPlayer(player)
	if KuiNameplatesChatBubbleCustom.blocked_players then
		KuiNameplatesChatBubbleCustom.blocked_players[player] = nil
	end
	f.UpdateDisplay()
end

local function SetCustomColor(target, r, g, b)
	if target and target ~= "" then
		target = strtrim(target)
		if not KuiNameplatesChatBubbleCustom.custom_colors then
			KuiNameplatesChatBubbleCustom.custom_colors = {}
		end
		KuiNameplatesChatBubbleCustom.custom_colors[target] = {r, g, b, 1}
		f.UpdateDisplay()
	end
end

local function ClearWordEntryBox()
	wordEntryBox:SetText("")
	wordEntryBox:SetFocus()
end

local function ClearPlayerEntryBox()
	playerEntryBox:SetText("")
	playerEntryBox:SetFocus()
end

local function ClearColorTargetBox()
	colorTargetBox:SetText("")
	colorTargetBox:SetFocus()
end

-- button handlers
local function AddWordButtonOnClick()
	AddBlockedWord(wordEntryBox:GetText())
	ClearWordEntryBox()
end

local function AddPlayerButtonOnClick()
	AddBlockedPlayer(playerEntryBox:GetText())
	ClearPlayerEntryBox()
end

local function ColorPickerButtonOnClick()
	local target = colorTargetBox:GetText()
	if target == "" then
		return
	end
	
	-- Show color picker
	ColorPickerFrame:SetColorRGB(1, 1, 1)
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.func = function()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		SetCustomColor(target, r, g, b)
	end
	ColorPickerFrame:Show()
	ClearColorTargetBox()
end

local function ResetButtonOnClick()
	KuiNameplatesChatBubbleCustom = {}
	f.UpdateDisplay()
end

-- entry box handlers
local function WordEntryBoxOnEnterPressed()
	addWordButton:Click()
end

local function PlayerEntryBoxOnEnterPressed()
	addPlayerButton:Click()
end

local function ColorTargetBoxOnEnterPressed()
	colorPickerButton:Click()
end

-- update display function
f.UpdateDisplay = function()
	-- This would update the blocked words list display
	-- For now, just a placeholder since we'd need more complex UI
	-- to show the actual lists
end

------------------------------------------------------------- event handlers --
local function OnEvent(self, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...
		if addonName == "Kui_Nameplates_ChatBubble" then
			self:UnregisterEvent("ADDON_LOADED")
			
			KuiNameplatesChatBubbleCustom = KuiNameplatesChatBubbleCustom or {}
			KuiNameplatesChatBubbleCustom.blocked_words = KuiNameplatesChatBubbleCustom.blocked_words or {}
			KuiNameplatesChatBubbleCustom.blocked_players = KuiNameplatesChatBubbleCustom.blocked_players or {}
			KuiNameplatesChatBubbleCustom.custom_colors = KuiNameplatesChatBubbleCustom.custom_colors or {}
			
			f.UpdateDisplay()
		end
	end
end

-------------------------------------------------------------------- finalize --
-- Set up event handling
f:SetScript("OnEvent", OnEvent)
f:RegisterEvent("ADDON_LOADED")

-- Set up button scripts
addWordButton:SetScript("OnClick", AddWordButtonOnClick)
addPlayerButton:SetScript("OnClick", AddPlayerButtonOnClick)
colorPickerButton:SetScript("OnClick", ColorPickerButtonOnClick)
resetButton:SetScript("OnClick", ResetButtonOnClick)

-- Set up entry box scripts
wordEntryBox:SetScript("OnEnterPressed", WordEntryBoxOnEnterPressed)
wordEntryBox:SetScript("OnEscapePressed", ClearWordEntryBox)
playerEntryBox:SetScript("OnEnterPressed", PlayerEntryBoxOnEnterPressed)
playerEntryBox:SetScript("OnEscapePressed", ClearPlayerEntryBox)
colorTargetBox:SetScript("OnEnterPressed", ColorTargetBoxOnEnterPressed)
colorTargetBox:SetScript("OnEscapePressed", ClearColorTargetBox)

-- Add to interface options
InterfaceOptions_AddCategory(opt)

--------------------------------------------------------------- slash command --
_G.SLASH_KUICHATBUBBLE1 = "/kuicb"
_G.SLASH_KUICHATBUBBLE2 = "/kcb"

function SlashCmdList.KUICHATBUBBLE(msg)
	KUI:CloseConfig()
	InterfaceOptionsFrame_OpenToCategory(category)
	InterfaceOptionsFrame_OpenToCategory(category)
end

-- Export functions for use by Core.lua
_G.KuiNameplatesChatBubbleConfig = {
	IsWordBlocked = function(message)
		if not KuiNameplatesChatBubbleCustom.blocked_words then
			return false
		end
		message = strlower(message)
		for word, _ in pairs(KuiNameplatesChatBubbleCustom.blocked_words) do
			if strfind(message, word, 1, true) then
				return true
			end
		end
		return false
	end,
	
	IsPlayerBlocked = function(playerName)
		if not KuiNameplatesChatBubbleCustom.blocked_players then
			return false
		end
		return KuiNameplatesChatBubbleCustom.blocked_players[playerName] ~= nil
	end,
	
	GetCustomColor = function(target)
		if KuiNameplatesChatBubbleCustom.custom_colors and KuiNameplatesChatBubbleCustom.custom_colors[target] then
			return KuiNameplatesChatBubbleCustom.custom_colors[target]
		end
		return nil
	end
}