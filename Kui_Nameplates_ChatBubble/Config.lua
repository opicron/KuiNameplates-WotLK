--[[
-- Kui_Nameplates_ChatBubble Config
-- By Kesava at curse.com
-- All rights reserved
-- Backported by: Kader at https://github.com/bkader
-- Configuration module for ChatBubble addon integrated into KUI system
]]
local addon, ns = ...
local KUI = LibStub("AceAddon-3.0"):GetAddon("KuiNameplates")
local mod = KUI:GetModule("ChatBubble")
local L = LibStub("AceLocale-3.0"):GetLocale("KuiNameplatesChatBubble")

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
		},
		filtering = {
			type = "group",
			name = "Message Filtering",
			inline = true,
			disabled = function()
				return not self.db.profile.enabled
			end,
			order = 40,
			args = {
				enabled = {
					type = "toggle",
					name = "Enable filtering",
					desc = "Enable word and player filtering for chat bubbles",
					order = 10
				},
				blocked_words_input = {
					type = "input",
					name = "Block word",
					desc = "Add a word to block (press Enter to add)",
					order = 20,
					disabled = function()
						return not self.db.profile.filtering.enabled
					end,
					get = function() return "" end,
					set = function(info, value)
						if value and value ~= "" then
							local word = strtrim(strlower(value))
							if not self.db.profile.filtering.blocked_words then
								self.db.profile.filtering.blocked_words = {}
							end
							self.db.profile.filtering.blocked_words[word] = true
						end
					end
				},
				blocked_words_list = {
					type = "description",
					name = function()
						if not self.db.profile.filtering.blocked_words then
							return "Blocked words: (none)"
						end
						local words = {}
						for word, _ in pairs(self.db.profile.filtering.blocked_words) do
							table.insert(words, word)
						end
						if #words == 0 then
							return "Blocked words: (none)"
						end
						table.sort(words)
						return "Blocked words: " .. table.concat(words, ", ")
					end,
					order = 25,
					disabled = function()
						return not self.db.profile.filtering.enabled
					end
				},
				clear_blocked_words = {
					type = "execute",
					name = "Clear blocked words",
					desc = "Remove all blocked words",
					order = 27,
					disabled = function()
						return not self.db.profile.filtering.enabled
					end,
					func = function()
						self.db.profile.filtering.blocked_words = {}
					end
				},
				blocked_players_input = {
					type = "input",
					name = "Block player",
					desc = "Add a player name to block (press Enter to add)",
					order = 30,
					disabled = function()
						return not self.db.profile.filtering.enabled
					end,
					get = function() return "" end,
					set = function(info, value)
						if value and value ~= "" then
							local player = strtrim(value)
							if not self.db.profile.filtering.blocked_players then
								self.db.profile.filtering.blocked_players = {}
							end
							self.db.profile.filtering.blocked_players[player] = true
						end
					end
				},
				blocked_players_list = {
					type = "description",
					name = function()
						if not self.db.profile.filtering.blocked_players then
							return "Blocked players: (none)"
						end
						local players = {}
						for player, _ in pairs(self.db.profile.filtering.blocked_players) do
							table.insert(players, player)
						end
						if #players == 0 then
							return "Blocked players: (none)"
						end
						table.sort(players)
						return "Blocked players: " .. table.concat(players, ", ")
					end,
					order = 35,
					disabled = function()
						return not self.db.profile.filtering.enabled
					end
				},
				clear_blocked_players = {
					type = "execute",
					name = "Clear blocked players",
					desc = "Remove all blocked players",
					order = 37,
					disabled = function()
						return not self.db.profile.filtering.enabled
					end,
					func = function()
						self.db.profile.filtering.blocked_players = {}
					end
				},
				custom_color_player = {
					type = "input",
					name = "Player for custom color",
					desc = "Enter player name then set color below",
					order = 40,
					disabled = function()
						return not self.db.profile.filtering.enabled
					end,
					get = function() return self.db.profile.filtering.color_target or "" end,
					set = function(info, value)
						self.db.profile.filtering.color_target = strtrim(value or "")
					end
				},
				custom_color = {
					type = "color",
					name = "Custom color",
					desc = "Set custom color for the player specified above",
					order = 50,
					disabled = function()
						return not self.db.profile.filtering.enabled or not self.db.profile.filtering.color_target or self.db.profile.filtering.color_target == ""
					end,
					get = function()
						local target = self.db.profile.filtering.color_target
						if target and self.db.profile.filtering.custom_colors and self.db.profile.filtering.custom_colors[target] then
							local c = self.db.profile.filtering.custom_colors[target]
							return c[1], c[2], c[3], c[4]
						else
							return 1, 1, 1, 1
						end
					end,
					set = function(info, r, g, b, a)
						local target = self.db.profile.filtering.color_target
						if target and target ~= "" then
							if not self.db.profile.filtering.custom_colors then
								self.db.profile.filtering.custom_colors = {}
							end
							self.db.profile.filtering.custom_colors[target] = {r, g, b, a or 1}
						end
					end
				},
				custom_colors_list = {
					type = "description",
					name = function()
						if not self.db.profile.filtering.custom_colors then
							return "Custom colors: (none)"
						end
						local colors = {}
						for player, color in pairs(self.db.profile.filtering.custom_colors) do
							local colorStr = string.format("|cff%02x%02x%02x%s|r", 
								math.floor(color[1] * 255), 
								math.floor(color[2] * 255), 
								math.floor(color[3] * 255), 
								player)
							table.insert(colors, colorStr)
						end
						if #colors == 0 then
							return "Custom colors: (none)"
						end
						table.sort(colors)
						return "Custom colors: " .. table.concat(colors, ", ")
					end,
					order = 55,
					disabled = function()
						return not self.db.profile.filtering.enabled
					end
				},
				clear_custom_colors = {
					type = "execute",
					name = "Clear custom colors",
					desc = "Remove all custom color settings",
					order = 57,
					disabled = function()
						return not self.db.profile.filtering.enabled
					end,
					func = function()
						self.db.profile.filtering.custom_colors = {}
						self.db.profile.filtering.color_target = ""
					end
				},
				clear_filters = {
					type = "execute",
					name = "Clear ALL filters",
					desc = "Remove all blocked words, players, and custom colors",
					order = 70,
					disabled = function()
						return not self.db.profile.filtering.enabled
					end,
					func = function()
						self.db.profile.filtering.blocked_words = {}
						self.db.profile.filtering.blocked_players = {}
						self.db.profile.filtering.custom_colors = {}
						self.db.profile.filtering.color_target = ""
					end
				}
			}
		}
	}
end

-- Expose filtering functions for backwards compatibility and external use
_G.KuiNameplatesChatBubbleConfig = {
	IsWordBlocked = function(message)
		if not mod.db or not mod.db.profile.filtering or not mod.db.profile.filtering.enabled then
			return false
		end
		if not mod.db.profile.filtering.blocked_words then
			return false
		end
		local lowerMessage = strlower(message)
		for word, _ in pairs(mod.db.profile.filtering.blocked_words) do
			if strfind(lowerMessage, strlower(word), 1, true) then
				return true
			end
		end
		return false
	end,
	
	IsPlayerBlocked = function(playerName)
		if not mod.db or not mod.db.profile.filtering or not mod.db.profile.filtering.enabled then
			return false
		end
		if not mod.db.profile.filtering.blocked_players then
			return false
		end
		return mod.db.profile.filtering.blocked_players[playerName] ~= nil
	end,
	
	GetCustomColor = function(target)
		if mod.db and mod.db.profile.filtering and mod.db.profile.filtering.custom_colors and mod.db.profile.filtering.custom_colors[target] then
			return mod.db.profile.filtering.custom_colors[target]
		end
		return nil
	end
}