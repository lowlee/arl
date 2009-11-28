-------------------------------------------------------------------------------
-- ARLFrame.lua		Frame functions for all of AckisRecipeList
-------------------------------------------------------------------------------
-- File date: @file-date-iso@
-- File revision: @file-revision@
-- Project revision: @project-revision@
-- Project version: @project-version@
-------------------------------------------------------------------------------
-- Please see http://www.wowace.com/projects/arl/for more information.
-------------------------------------------------------------------------------
-- License:
--	Please see LICENSE.txt

-- This source code is released under All Rights Reserved.
-------------------------------------------------------------------------------
--- **AckisRecipeList** provides an interface for scanning professions for missing recipes.
-- There are a set of functions which allow you make use of the ARL database outside of ARL.
-- ARL supports all professions currently in World of Warcraft 3.2
-- @class file
-- @name ARLFrame.lua
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Localized Lua globals.
-------------------------------------------------------------------------------
local _G = getfenv(0)

local string = _G.string
local sformat = string.format
local strlower = string.lower
local smatch = string.match

local select = _G.select
local type = _G.type

local table = _G.table
local twipe = table.wipe
local tinsert, tremove = table.insert, table.remove
local ipairs, pairs = _G.ipairs, _G.pairs

local math = _G.math
local floor = math.floor

local tonumber = _G.tonumber
local tostring = _G.tostring

-------------------------------------------------------------------------------
-- Localized Blizzard API.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- AddOn namespace.
-------------------------------------------------------------------------------
local LibStub = LibStub

local MODNAME		= "Ackis Recipe List"
local addon		= LibStub("AceAddon-3.0"):GetAddon(MODNAME)

local BFAC		= LibStub("LibBabble-Faction-3.0"):GetLookupTable()
local L			= LibStub("AceLocale-3.0"):GetLocale(MODNAME)
local QTip		= LibStub("LibQTip-1.0")

local Player		= addon.Player

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local SortedProfessions = {	-- To make tabbing between professions easier 
	{ name = GetSpellInfo(51304),	texture = "alchemy" },		-- 1 
	{ name = GetSpellInfo(51300),	texture = "blacksmith" },	-- 2 
	{ name = GetSpellInfo(51296),	texture = "cooking" },		-- 3 
	{ name = GetSpellInfo(51313),	texture = "enchant" },		-- 4 
	{ name = GetSpellInfo(51306),	texture = "engineer" },		-- 5 
	{ name = GetSpellInfo(45542),	texture = "firstaid" },		-- 6 
	{ name = GetSpellInfo(45363),	texture = "inscribe" },		-- 7 
	{ name = GetSpellInfo(51311),	texture = "jewel" },		-- 8 
	{ name = GetSpellInfo(51302),	texture = "leather" },		-- 9 
	{ name = GetSpellInfo(53428),	texture = "runeforge" },	-- 10 
	{ name = GetSpellInfo(32606),	texture = "smelting" },		-- 11 
	{ name = GetSpellInfo(51309),	texture = "tailor" },		-- 12 
} 

local ExpButtonText = {		-- Some variables I want to use in creating the GUI later... (ZJ 8/26/08)
	_G.GENERAL,		-- 1
	L["Obtain"],		-- 2
	L["Binding"],		-- 3
	L["Item"],		-- 4
	_G.ROLE,		-- 5
	_G.REPUTATION,		-- 6
	_G.MISCELLANEOUS
}

local NUM_PROFESSIONS		= 12
local NUM_RECIPE_LINES		= 24			-- Number of visible lines in the scrollframe.
local SEASONAL_CATEGORY		= GetCategoryInfo(155)	-- Localized string - "World Events"

local MAINPANEL_NORMAL_WIDTH	= 293
local MAINPANEL_EXPANDED_WIDTH	= 444

local FILTERMENU_SINGLE_WIDTH	= 136
local FILTERMENU_DOUBLE_WIDTH	= 300
local FILTERMENU_HEIGHT		= 312

local FILTERMENU_SMALL		= 112
local FILTERMENU_LARGE		= 210

local FACTION_HORDE		= BFAC["Horde"]
local FACTION_ALLIANCE		= BFAC["Alliance"]
local FACTION_NEUTRAL		= BFAC["Neutral"]

-------------------------------------------------------------------------------
-- Constants for acquire types.
-------------------------------------------------------------------------------
local A_TRAINER, A_VENDOR, A_MOB, A_QUEST, A_SEASONAL, A_REPUTATION, A_WORLD_DROP, A_CUSTOM, A_PVP, A_MAX = 1, 2, 3, 4, 5, 6, 7, 8, 9, 9

-------------------------------------------------------------------------------
-- Define the static popups we're going to call when people haven't scanned or
-- when current filters are blocking all recipes from being displayed.
-------------------------------------------------------------------------------
StaticPopupDialogs["ARL_NOTSCANNED"] = {
	text = L["NOTSCANNED"],
	button1 = _G.OKAY,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
}

StaticPopupDialogs["ARL_ALLFILTERED"] = {
	text = L["ALL_FILTERED"],
	button1 = _G.OKAY,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
}

StaticPopupDialogs["ARL_ALLKNOWN"] = {
	text = L["ARL_ALLKNOWN"],
	button1 = _G.OKAY,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
}

StaticPopupDialogs["ARL_ALLEXCLUDED"] = {
	text = L["ARL_ALLEXCLUDED"],
	button1 = _G.OKAY,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
}

StaticPopupDialogs["ARL_SEARCHFILTERED"] = {
	text = L["ARL_SEARCHFILTERED"],
	button1 = _G.OKAY,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
}

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------
local FilterValueMap		-- Assigned in addon:InitializeFrame()

local ARL_SearchText, ARL_LastSearchedText
local ARL_ExpGeneralOptCB, ARL_ExpObtainOptCB, ARL_ExpBindingOptCB, ARL_ExpItemOptCB, ARL_ExpPlayerOptCB, ARL_ExpRepOptCB, ARL_Rep_ClassicCB, ARL_Rep_BCCB, ARL_Rep_LKCB,ARL_ExpMiscOptCB

-------------------------------------------------------------------------------
-- Upvalues
-------------------------------------------------------------------------------
local ReDisplay

-------------------------------------------------------------------------------
-- Table cache mechanism
-------------------------------------------------------------------------------
local AcquireTable, ReleaseTable
do
	local table_cache = {}

	-- Returns a table
	function AcquireTable()
		local tbl = tremove(table_cache) or {}
		return tbl
	end

	-- Cleans the table and stores it in the cache
	function ReleaseTable(tbl)
		if not tbl then return end
		twipe(tbl)
		tinsert(table_cache, tbl)
	end
end	-- do block

-------------------------------------------------------------------------------
-- Close all possible pop-up windows
-------------------------------------------------------------------------------
function addon:ClosePopups()
	StaticPopup_Hide("ARL_NOTSCANNED")
	StaticPopup_Hide("ARL_ALLFILTERED")
	StaticPopup_Hide("ARL_ALLKNOWN")
	StaticPopup_Hide("ARL_ALLEXCLUDED")
	StaticPopup_Hide("ARL_SEARCHFILTERED")
end

-------------------------------------------------------------------------------
-- Colours a skill level based on whether or not the player has a high enough
-- skill level or faction to learn it.
-------------------------------------------------------------------------------
local function ColourSkillLevel(recipeEntry, hasFaction, recStr)
	local playerSkill = Player["ProfessionLevel"]
	local recipeSkill = recipeEntry["Level"]
	local recipeOrange = recipeEntry["Orange"]
	local recipeYellow = recipeEntry["Yellow"]
	local recipeGreen = recipeEntry["Green"]
	local recipeGrey = recipeEntry["Grey"]

	if recipeSkill > playerSkill or not hasFaction then
		return addon:Red(recStr)
	elseif playerSkill >= recipeGrey then
		return addon:MidGrey(recStr)
	elseif playerSkill >= recipeGreen then
		return addon:Green(recStr)
	elseif playerSkill >= recipeYellow then
		return addon:Yellow(recStr)
	elseif playerSkill >= recipeOrange then
		return addon:Orange(recStr)
	else
		--@alpha@
		addon:Print("DEBUG: ColourSkillLevel fallback: " .. recStr)
		--@end-alpha@
		return addon:MidGrey(recStr)
	end
end

-------------------------------------------------------------------------------
-- Sets show and hide scripts as well as text for a tooltip for the given frame.
-------------------------------------------------------------------------------
local SetTooltipScripts
do
	local function Show_Tooltip(frame, motion)
		GameTooltip_SetDefaultAnchor(GameTooltip, frame)
		GameTooltip:SetText(frame.tooltip_text, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		GameTooltip:Show()
	end

	local function Hide_Tooltip()
		GameTooltip:Hide()
	end

	function SetTooltipScripts(frame, textLabel)
		frame.tooltip_text = textLabel

		frame:SetScript("OnEnter", Show_Tooltip)
		frame:SetScript("OnLeave", Hide_Tooltip)
	end
end	-- do

-------------------------------------------------------------------------------
-- Generic function for creating buttons.
-------------------------------------------------------------------------------
local GenericCreateButton
do
	-- I hate stretchy buttons. Thanks very much to ckknight for this code
	-- (found in RockConfig)

	-- when pressed, the button should look pressed
	local function button_OnMouseDown(this)
		if this:IsEnabled() == 1 then
			this.left:SetTexture([[Interface\Buttons\UI-Panel-Button-Down]])
			this.middle:SetTexture([[Interface\Buttons\UI-Panel-Button-Down]])
			this.right:SetTexture([[Interface\Buttons\UI-Panel-Button-Down]])
		end
	end

	-- when depressed, return to normal
	local function button_OnMouseUp(this)
		if this:IsEnabled() == 1 then
			this.left:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
			this.middle:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
			this.right:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
		end
	end

	local function button_Disable(this)
		this.left:SetTexture([[Interface\Buttons\UI-Panel-Button-Disabled]])
		this.middle:SetTexture([[Interface\Buttons\UI-Panel-Button-Disabled]])
		this.right:SetTexture([[Interface\Buttons\UI-Panel-Button-Disabled]])
		this:__Disable()
		this:EnableMouse(false)
	end

	local function button_Enable(this)
		this.left:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
		this.middle:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
		this.right:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
		this:__Enable()
		this:EnableMouse(true)
	end

	function GenericCreateButton(bName, parentFrame, bHeight, bWidth, bNormFont, bHighFont, initText, tAlign, tooltipText, noTextures)
		local button = CreateFrame("Button", bName, parentFrame)

		button:SetWidth(bWidth)
		button:SetHeight(bHeight)

		if noTextures == 1 then
			local left = button:CreateTexture(nil, "BACKGROUND")
			button.left = left
			left:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])

			local middle = button:CreateTexture(nil, "BACKGROUND")
			button.middle = middle
			middle:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])

			local right = button:CreateTexture(nil, "BACKGROUND")
			button.right = right
			right:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])

			left:SetPoint("TOPLEFT")
			left:SetPoint("BOTTOMLEFT")
			left:SetWidth(12)
			left:SetTexCoord(0, 0.09375, 0, 0.6875)

			right:SetPoint("TOPRIGHT")
			right:SetPoint("BOTTOMRIGHT")
			right:SetWidth(12)
			right:SetTexCoord(0.53125, 0.625, 0, 0.6875)

			middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
			middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
			middle:SetTexCoord(0.09375, 0.53125, 0, 0.6875)

			button:SetScript("OnMouseDown", button_OnMouseDown)
			button:SetScript("OnMouseUp", button_OnMouseUp)

			button.__Enable = button.Enable
			button.__Disable = button.Disable
			button.Enable = button_Enable
			button.Disable = button_Disable

			local highlight = button:CreateTexture(nil, "OVERLAY", "UIPanelButtonHighlightTexture")
			button:SetHighlightTexture(highlight)
		elseif noTextures == 2 then
			button:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
			button:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
			button:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
			button:SetDisabledTexture("Interface\\Buttons\\UI-PlusButton-Disabled")
		elseif noTextures == 3 then
			button:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
			button:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
			button:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
			button:SetDisabledTexture("Interface\\Buttons\\UI-PlusButton-Disabled")
		end

		local text = button:CreateFontString(nil, "ARTWORK")
		button:SetFontString(text)
		button.text = text
		text:SetPoint("LEFT", button, "LEFT", 7, 0)
		text:SetPoint("RIGHT", button, "RIGHT", -7, 0)
		text:SetJustifyH(tAlign)

		text:SetFontObject(bNormFont)
		text:SetText(initText)

		if tooltipText and tooltipText ~= "" then
			SetTooltipScripts(button, tooltipText)
		end
		return button
	end
end	-- do

local function HideARL_ExpOptCB(ignorevalue)
	ARL_ExpGeneralOptCB.text:SetText(addon:Yellow(ExpButtonText[1]))
	ARL_ExpObtainOptCB.text:SetText(addon:Yellow(ExpButtonText[2]))
	ARL_ExpBindingOptCB.text:SetText(addon:Yellow(ExpButtonText[3]))
	ARL_ExpItemOptCB.text:SetText(addon:Yellow(ExpButtonText[4]))
	ARL_ExpPlayerOptCB.text:SetText(addon:Yellow(ExpButtonText[5]))
	ARL_ExpRepOptCB.text:SetText(addon:White(ExpButtonText[6]))
	ARL_ExpMiscOptCB.text:SetText(addon:Yellow(ExpButtonText[7]))

	if (ignorevalue ~= "general") then
		ARL_ExpGeneralOptCB:SetChecked(false)
		ARL_ExpGeneralOptCB.text:SetText(addon:Yellow(ExpButtonText[1]))
	else
		ARL_ExpGeneralOptCB.text:SetText(addon:White(ExpButtonText[1]))
	end

	if (ignorevalue ~= "obtain") then
		ARL_ExpObtainOptCB:SetChecked(false)
		ARL_ExpObtainOptCB.text:SetText(addon:Yellow(ExpButtonText[2])) 
	else
		ARL_ExpObtainOptCB.text:SetText(addon:White(ExpButtonText[2]))
	end

	if (ignorevalue ~= "binding") then
		ARL_ExpBindingOptCB:SetChecked(false)
		ARL_ExpBindingOptCB.text:SetText(addon:Yellow(ExpButtonText[3]))
	else
		ARL_ExpBindingOptCB.text:SetText(addon:White(ExpButtonText[3]))
	end

	if (ignorevalue ~= "item") then
		ARL_ExpItemOptCB:SetChecked(false)
		ARL_ExpItemOptCB.text:SetText(addon:Yellow(ExpButtonText[4]))
	else
		ARL_ExpItemOptCB.text:SetText(addon:White(ExpButtonText[4]))
	end

	if (ignorevalue ~= "player") then
		ARL_ExpPlayerOptCB:SetChecked(false)
		ARL_ExpPlayerOptCB.text:SetText(addon:Yellow(ExpButtonText[5]))
	else
		ARL_ExpPlayerOptCB.text:SetText(addon:White(ExpButtonText[5]))
	end

	if (ignorevalue ~= "rep") then
		ARL_ExpRepOptCB:SetChecked(false)
		ARL_ExpRepOptCB.text:SetText(addon:Yellow(ExpButtonText[6]))
	else
		ARL_ExpRepOptCB.text:SetText(addon:White(ExpButtonText[6]))
	end

	if (ignorevalue ~= "misc") then
		ARL_ExpMiscOptCB:SetChecked(false)
		ARL_ExpMiscOptCB.text:SetText(addon:Yellow(ExpButtonText[7]))
	else
		ARL_ExpMiscOptCB.text:SetText(addon:White(ExpButtonText[7]))
	end
end

-------------------------------------------------------------------------------
-- Sort functions
-------------------------------------------------------------------------------
local SortRecipeList
do
	addon.sorted_recipes = {}

	local recipe_list = addon.recipe_list

	local function Sort_SkillAsc(a, b)
		local reca, recb = recipe_list[a], recipe_list[b]

		if reca["Level"] == recb["Level"] then
			return reca["Name"] < recb["Name"]
		else
			return reca["Level"] < recb["Level"]
		end
	end

	local function Sort_SkillDesc(a, b)
		local reca, recb = recipe_list[a], recipe_list[b]

		if reca["Level"] == recb["Level"] then
			return reca["Name"] < recb["Name"]
		else
			return recb["Level"] < reca["Level"]
		end
	end

	local function Sort_Name(a, b)
		return recipe_list[a]["Name"] < recipe_list[b]["Name"]
	end

	-- Will only sort based off of the first acquire type
	local function Sort_Acquisition(a, b)
		local reca = recipe_list[a]["Acquire"][1]
		local recb = recipe_list[b]["Acquire"][1]

		if not reca or not recb then
			return not not reca
		end

		if reca["Type"] ~= recb["Type"] then
			return reca["Type"] < recb["Type"]
		end

		if reca["Type"] == A_CUSTOM then
			if reca["ID"] == recb["ID"] then
				return recipe_list[a]["Name"] < recipe_list[b]["Name"]
			else
				return reca["ID"] < recb["ID"]
			end
		else
			return recipe_list[a]["Name"] < recipe_list[b]["Name"]
		end
	end

	local function Sort_Location(a, b)
		-- We do the or "" because of nil's, I think this would be better if I just left it as a table which was returned
		local reca = recipe_list[a]["Locations"] or ""
		local recb = recipe_list[b]["Locations"] or ""

		reca = smatch(reca,"(%w+), ") or reca
		recb = smatch(recb,"(%w+), ") or recb

		if reca == recb then
			return Sort_Acquisition(a, b)
		else
			return reca < recb
		end
	end

	local sortFuncs = {
		["SkillAsc"]	= Sort_SkillAsc,
		["SkillDesc"]	= Sort_SkillDesc,
		["Name"]	= Sort_Name,
		["Acquisition"]	= Sort_Acquisition,
		["Location"]	= Sort_Location,
	}

	-- Sorts the recipe list according to configuration settings.
	function SortRecipeList()
		local sorted_recipes = addon.sorted_recipes
		twipe(sorted_recipes)

		for n, v in pairs(addon.recipe_list) do
			tinsert(sorted_recipes, n)
		end
		table.sort(sorted_recipes, sortFuncs[addon.db.profile.sorting])
	end
end	-- do

-------------------------------------------------------------------------------
-- Tooltip functions and data.
-------------------------------------------------------------------------------
local arlSpellTooltip = CreateFrame("GameTooltip", "arlSpellTooltip", UIParent, "GameTooltipTemplate")
local arlTooltip

-- Font Objects needed for arlTooltip
local narrowFont
local normalFont

local narrowFontObj = CreateFont(MODNAME.."narrowFontObj")
local normalFontObj = CreateFont(MODNAME.."normalFontObj")

-- Fallback in case the user doesn't have LSM-3.0 installed
if not LibStub:GetLibrary("LibSharedMedia-3.0", true) then

	local locale = GetLocale()
	-- Fix for font issues on koKR
	if locale == "koKR" then
		narrowFont = "Fonts\\2002.TTF"
		normalFont = "Fonts\\2002.TTF"
	else
		narrowFont = "Fonts\\ARIALN.TTF"
		normalFont = "Fonts\\FRIZQT__.TTF"
	end
else
	-- Register LSM 3.0
	local LSM3 = LibStub("LibSharedMedia-3.0")

	narrowFont = LSM3:Fetch(LSM3.MediaType.FONT, "Arial Narrow")
	normalFont = LSM3:Fetch(LSM3.MediaType.FONT, "Friz Quadrata TT")
end

-- I want to do a bit more comprehensive tooltip processing. Things like changing font sizes,
-- adding padding to the left hand side, and using better color handling. So... this function
-- will do that for me.
local function ttAdd(
	leftPad,		-- number of times to pad two spaces on left side
	textSize,		-- add to or subtract from addon.db.profile.frameopts.fontsize to get fontsize
	narrow,			-- if 1, use ARIALN instead of FRITZQ
	str1,			-- left-hand string
	hexcolor1,		-- hex color code for left-hand side
	str2,			-- if present, this is the right-hand string
	hexcolor2)		-- if present, hex color code for right-hand side

	-- are we changing fontsize or narrow?
	local fontSize
	if ((narrow == 1) or (textSize ~= 0)) then
		local font, fontObj = normalFont, normalFontObj
		if (narrow == 1) then
			font = narrowFont
			fontObj = narrowFontObj
		end

		fontSize = addon.db.profile.frameopts.fontsize + textSize

		fontObj:SetFont(font, fontSize)
		arlTooltip:SetFont(fontObj)
	end

	-- Add in our left hand padding
	local loopPad = leftPad
	local leftStr = str1

	while (loopPad > 0) do
		leftStr = "  " .. leftStr
		loopPad = loopPad - 1
	end
	local lineNum

	if (str2) then
		lineNum = arlTooltip:AddLine()
		arlTooltip:SetCell(lineNum, 1, "|cff"..hexcolor1..leftStr.."|r")
		arlTooltip:SetCell(lineNum, 2, "|cff"..hexcolor2..str2.."|r", "RIGHT")
	else
		-- Text spans both columns - set maximum width to match fontSize to maintain uniform tooltip size. -Torhal
		local width = math.ceil(fontSize * 37.5)
		lineNum = arlTooltip:AddLine()
		arlTooltip:SetCell(lineNum, 1, "|cff"..hexcolor1..leftStr.."|r", nil, "LEFT", 2, nil, 0, 0, width, width)
	end
end

local function SetSpellTooltip(owner, loc, link)
	arlSpellTooltip:SetOwner(owner, "ANCHOR_NONE")
	arlSpellTooltip:ClearAllPoints()

	if loc == "Top" then
		arlSpellTooltip:SetPoint("BOTTOMLEFT", owner, "TOPLEFT")
	elseif loc == "Bottom" then
		arlSpellTooltip:SetPoint("TOPLEFT", owner, "BOTTOMLEFT")
	elseif loc == "Left" then
		arlSpellTooltip:SetPoint("TOPRIGHT", owner, "TOPLEFT")
	elseif loc == "Right" then
		arlSpellTooltip:SetPoint("TOPLEFT", owner, "TOPRIGHT")
	end

	-- Add TipTac Support
	if TipTac and TipTac.AddModifiedTip and not arlSpellTooltip.tiptac then
		TipTac:AddModifiedTip(arlSpellTooltip)
		arlSpellTooltip.tiptac = true
	end

	-- Set the spell tooltip's scale, and copy its other values from GameTooltip so AddOns which modify it will work.
	arlSpellTooltip:SetBackdrop(GameTooltip:GetBackdrop())
	arlSpellTooltip:SetBackdropColor(GameTooltip:GetBackdropColor())
	arlSpellTooltip:SetBackdropBorderColor(GameTooltip:GetBackdropBorderColor())
	arlSpellTooltip:SetScale(addon.db.profile.frameopts.tooltipscale)

	arlSpellTooltip:SetHyperlink(link)
	arlSpellTooltip:Show()
end

local function GenerateTooltipContent(owner, rIndex)
	local spellTooltipLocation = addon.db.profile.spelltooltiplocation
	local acquireTooltipLocation = addon.db.profile.acquiretooltiplocation
	local recipe_entry = addon.recipe_list[rIndex]
	local spellLink = recipe_entry["RecipeLink"]
	local MainPanel = addon.Frame

	if acquireTooltipLocation == _G.OFF then
		QTip:Release(arlTooltip)

		-- If we have the spell link tooltip, anchor it to MainPanel instead so it shows
		if spellTooltipLocation ~= _G.OFF and spellLink then
			SetSpellTooltip(MainPanel, spellTooltipLocation, spellLink)
		else
			arlSpellTooltip:Hide()
		end
		return
	end
	arlTooltip = QTip:Acquire(MODNAME.." Tooltip", 2, "LEFT", "LEFT")
	arlTooltip:ClearAllPoints()

	if acquireTooltipLocation == "Right" then
		arlTooltip:SetPoint("TOPLEFT", MainPanel, "TOPRIGHT")
	elseif acquireTooltipLocation == "Left" then
		arlTooltip:SetPoint("TOPRIGHT", MainPanel, "TOPLEFT")
	elseif acquireTooltipLocation == "Top" then
		arlTooltip:SetPoint("BOTTOMLEFT", MainPanel, "TOPLEFT")
	elseif acquireTooltipLocation == "Bottom" then
		arlTooltip:SetPoint("TOPLEFT", MainPanel, "BOTTOMLEFT")
	elseif acquireTooltipLocation == "Mouse" then
		local x, y = GetCursorPosition()
		local uiscale = UIParent:GetEffectiveScale()

		arlTooltip:ClearAllPoints()
		arlTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / uiscale, y / uiscale)
	end

	if TipTac and TipTac.AddModifiedTip then
		-- Pass true as second parameter because hooking OnHide causes C stack overflows -Torhal
		TipTac:AddModifiedTip(arlTooltip, true)
	end
	local clr1, clr2 = "", ""

	arlTooltip:Clear()
	arlTooltip:SetScale(addon.db.profile.frameopts.tooltipscale)
	arlTooltip:AddHeader()
	arlTooltip:SetCell(1, 1, "|cff"..addon:hexcolor("HIGH")..recipe_entry["Name"], "CENTER", 2)

	-- check if the recipe is excluded
	local exclude = addon.db.profile.exclusionlist

	if exclude[rIndex] then
		ttAdd(0, -1, 1, L["RECIPE_EXCLUDED"], addon:hexcolor("RED"))
	end

	-- Add in skill level requirement, colored correctly
	clr1 = addon:hexcolor("NORMAL")

	local recipeSkill = recipe_entry["Level"]
	local playerSkill = Player["ProfessionLevel"]

	if recipeSkill > playerSkill then
		clr2 = addon:hexcolor("RED")
	elseif playerSkill - recipeSkill < 20 then
		clr2 = addon:hexcolor("ORANGE")
	elseif playerSkill - recipeSkill < 30 then
		clr2 = addon:hexcolor("YELLOW")
	elseif playerSkill - recipeSkill < 40 then
		clr2 = addon:hexcolor("GREEN") 
	else
		clr2 = addon:hexcolor("MIDGREY")
	end
	ttAdd(0, -1, 0, L["Required Skill"] .. " :", clr1, recipe_entry["Level"], clr2)
	arlTooltip:AddSeparator()
	-- Binding info
	clr1 = addon:hexcolor("NORMAL")

	if (recipe_entry["Flags"][36]) then
		ttAdd(0, -1, 1, L["BOEFilter"], clr1)
	end

	if (recipe_entry["Flags"][37]) then
		ttAdd(0, -1, 1, L["BOPFilter"], clr1)
	end

	if (recipe_entry["Flags"][38]) then
		ttAdd(0, -1, 1, L["BOAFilter"], clr1)
	end

	if (recipe_entry["Flags"][40]) then
		ttAdd(0, -1, 1, L["RecipeBOEFilter"], clr1)
	end

	if (recipe_entry["Flags"][41]) then
		ttAdd(0, -1, 1, L["RecipeBOPFilter"], clr1)
	end

	if (recipe_entry["Flags"][42]) then
		ttAdd(0, -1, 1, L["RecipeBOAFilter"], clr1)
	end
	arlTooltip:AddSeparator()

	-- obtain info
	ttAdd(0, -1, 0, L["Obtained From"] .. " : ", addon:hexcolor("NORMAL"))

	local playerFaction = Player["Faction"]
	local rep_list = addon.reputation_list

	-- loop through acquire methods, display each
	for k, v in pairs(recipe_entry["Acquire"]) do
		local acquire_type = v["Type"]

		if acquire_type == A_TRAINER then
			-- Trainer:			TrainerName
			-- TrainerZone			TrainerCoords
			local trnr = addon.trainer_list[v["ID"]]
			local cStr = ""

			clr1 = addon:hexcolor("TRAINER")
			-- Don't display trainers if it's opposite faction
			local displaytt = false

			if (trnr["Faction"] == FACTION_HORDE) then
				clr2 = addon:hexcolor("HORDE")

				if (playerFaction == FACTION_HORDE) then
					displaytt = true
				end
			elseif (trnr["Faction"] == FACTION_ALLIANCE) then
				clr2 = addon:hexcolor("ALLIANCE")

				if (playerFaction == FACTION_ALLIANCE) then
					displaytt = true
				end
			else
				clr2 = addon:hexcolor("NEUTRAL")
				displaytt = true
			end

			if (displaytt) then
				-- Add the trainer information to the tooltip
				ttAdd(0, -2, 0, L["Trainer"], clr1, trnr["Name"], clr2)
				-- If we have a coordinate, add the coordinates to the tooltop
				if (trnr["Coordx"] ~= 0) and (trnr["Coordy"] ~= 0) then
					cStr = "(" .. trnr["Coordx"] .. ", " .. trnr["Coordy"] .. ")"
				end
				clr1 = addon:hexcolor("NORMAL")
				clr2 = addon:hexcolor("HIGH")
				ttAdd(1, -2, 1, trnr["Location"], clr1, cStr, clr2)
			end
		elseif acquire_type == A_VENDOR then
			-- Vendor:					VendorName
			-- VendorZone				VendorCoords
			local vendor = addon.vendor_list[v["ID"]]
			local cStr = ""

			clr1 = addon:hexcolor("VENDOR")
			-- Don't display vendors of opposite faction
			local displaytt = false
			local faction

			if (vendor["Faction"] == FACTION_HORDE) then
				clr2 = addon:hexcolor("HORDE")
				if (playerFaction == FACTION_HORDE) then
					displaytt = true
				else
					faction = FACTION_HORDE
				end
			elseif (vendor["Faction"] == FACTION_ALLIANCE) then
				clr2 = addon:hexcolor("ALLIANCE")
				if (playerFaction == FACTION_ALLIANCE) then
					displaytt = true
				else
					faction = FACTION_ALLIANCE
				end
			else
				clr2 = addon:hexcolor("NEUTRAL")
				displaytt = true
			end

			if displaytt then
				if (vendor["Coordx"] ~= 0) and (vendor["Coordy"] ~= 0) then
					cStr = "(" .. vendor["Coordx"] .. ", " .. vendor["Coordy"] .. ")"
				end

				ttAdd(0, -1, 0, L["Vendor"], clr1, vendor["Name"], clr2)
				clr1 = addon:hexcolor("NORMAL")
				clr2 = addon:hexcolor("HIGH")
				ttAdd(1, -2, 1, vendor["Location"], clr1, cStr, clr2)
			elseif faction then
				ttAdd(0, -1, 0, faction.." "..L["Vendor"], clr1)
			end
		elseif acquire_type == A_MOB then
			-- Mob Drop:			Mob Name
			-- MoBZ				MobCoords
			local mob = addon.mob_list[v["ID"]]
			local cStr = ""

			if (mob["Coordx"] ~= 0) and (mob["Coordy"] ~= 0) then
				cStr = "(" .. mob["Coordx"] .. ", " .. mob["Coordy"] .. ")"
			end

			clr1 = addon:hexcolor("MOBDROP")
			clr2 = addon:hexcolor("HORDE")
			ttAdd(0, -1, 0, L["Mob Drop"], clr1, mob["Name"], clr2)
			clr1 = addon:hexcolor("NORMAL")
			clr2 = addon:hexcolor("HIGH")
			ttAdd(1, -2, 1, mob["Location"], clr1, cStr, clr2)
		elseif acquire_type == A_QUEST then
			-- Quest:				QuestName
			-- QuestZone				QuestCoords
			local quest = addon.quest_list[v["ID"]]

			if quest then
				clr1 = addon:hexcolor("QUEST")
				-- Don't display quests of opposite faction
				local displaytt = false
				local faction

				if (quest["Faction"] == FACTION_HORDE) then
					clr2 = addon:hexcolor("HORDE")
					if (playerFaction == FACTION_HORDE) then
						displaytt = true
					else
						faction = FACTION_HORDE
					end
				elseif (quest["Faction"] == FACTION_ALLIANCE) then
					clr2 = addon:hexcolor("ALLIANCE")
					if (playerFaction == FACTION_ALLIANCE) then
						displaytt = true
					else
						faction = FACTION_ALLIANCE
					end
				else
					clr2 = addon:hexcolor("NEUTRAL")
					displaytt = true
				end

				if displaytt then
					local cStr = ""

					if (quest["Coordx"] ~= 0) and (quest["Coordy"] ~= 0) then
						cStr = "(" .. quest["Coordx"] .. ", " .. quest["Coordy"] .. ")"
					end

					ttAdd(0, -1, 0, L["Quest"], clr1, quest["Name"], clr2)
					clr1 = addon:hexcolor("NORMAL")
					clr2 = addon:hexcolor("HIGH")
					ttAdd(1, -2, 1, quest["Location"], clr1, cStr, clr2)
				elseif faction then
					ttAdd(0, -1, 0, faction.." "..L["Quest"], clr1)
				end
			end
		elseif acquire_type == A_SEASONAL then
			-- Seasonal:				SeasonEventName
			clr1 = addon:hexcolor("SEASON")
			ttAdd(0, -1, 0, SEASONAL_CATEGORY, clr1, addon.seasonal_list[v["ID"]]["Name"], clr1)
		elseif acquire_type == A_REPUTATION then
			-- Reputation:				Faction
			-- RepLevel				RepVendor				
			-- RepVendorZone			RepVendorCoords

			local repfac = rep_list[v["ID"]]
			local repname = repfac["Name"] -- name
			local rplvl = v["RepLevel"]
			local repvendor = addon.vendor_list[v["RepVendor"]]
			local cStr = ""

			if (repvendor["Coordx"] ~= 0) and (repvendor["Coordy"] ~= 0) then
				cStr = "(" .. repvendor["Coordx"] .. ", " .. repvendor["Coordy"] .. ")"
			end
			clr1 = addon:hexcolor("REP")
			clr2 = addon:hexcolor("NORMAL")
			ttAdd(0, -1, 0, _G.REPUTATION, clr1, repname, clr2)

			local rStr = ""
			if (rplvl == 0) then
				rStr = FACTION_NEUTRAL
				clr1 = addon:hexcolor("NEUTRAL")
			elseif (rplvl == 1) then
				rStr = BFAC["Friendly"]
				clr1 = addon:hexcolor("FRIENDLY")
			elseif (rplvl == 2) then
				rStr = BFAC["Honored"]
				clr1 = addon:hexcolor("HONORED")
			elseif (rplvl == 3) then
				rStr = BFAC["Revered"]
				clr1 = addon:hexcolor("REVERED")
			else
				rStr = BFAC["Exalted"]
				clr1 = addon:hexcolor("EXALTED")
			end

			local displaytt = false
			if repvendor["Faction"] == FACTION_HORDE then
				clr2 = addon:hexcolor("HORDE")

				if playerFaction == FACTION_HORDE then
					displaytt = true
				end
			elseif repvendor["Faction"] == FACTION_ALLIANCE then
				clr2 = addon:hexcolor("ALLIANCE")

				if playerFaction == FACTION_ALLIANCE then
					displaytt = true
				end
			else
				clr2 = addon:hexcolor("NEUTRAL")
				displaytt = true
			end

			if displaytt then
				ttAdd(1, -2, 0, rStr, clr1, repvendor["Name"], clr2)
				clr1 = addon:hexcolor("NORMAL")
				clr2 = addon:hexcolor("HIGH")
				ttAdd(2, -2, 1, repvendor["Location"], clr1, cStr, clr2)
			end
		elseif acquire_type == A_WORLD_DROP then
			-- World Drop				RarityLevel
			if (v["ID"] == 1) then
				clr1 = addon:hexcolor("COMMON")
			elseif (v["ID"] == 2) then
				clr1 = addon:hexcolor("UNCOMMON")
			elseif (v["ID"] == 3) then
				clr1 = addon:hexcolor("RARE")
			elseif (v["ID"] == 4) then
				clr1 = addon:hexcolor("EPIC")
			else
				clr1 = addon:hexcolor("NORMAL")
			end
			ttAdd(0, -1, 0, L["World Drop"], clr1)
		elseif acquire_type == A_CUSTOM then
			local customname = addon.custom_list[v["ID"]]["Name"]

			ttAdd(0, -1, 0, customname, addon:hexcolor("NORMAL"))
		elseif acquire_type == A_PVP then
			-- Vendor:					VendorName
			-- VendorZone				VendorCoords
			local vendor = addon.vendor_list[v["ID"]]
			local cStr = ""

			clr1 = addon:hexcolor("VENDOR")
			-- Don't display vendors of opposite faction
			local displaytt = false
			local faction

			if (vendor["Faction"] == FACTION_HORDE) then
				clr2 = addon:hexcolor("HORDE")
				if (playerFaction == FACTION_HORDE) then
					displaytt = true
				else
					faction = FACTION_HORDE
				end
			elseif (vendor["Faction"] == FACTION_ALLIANCE) then
				clr2 = addon:hexcolor("ALLIANCE")
				if (playerFaction == FACTION_ALLIANCE) then
					displaytt = true
				else
					faction = FACTION_ALLIANCE
				end
			else
				clr2 = addon:hexcolor("NEUTRAL")
				displaytt = true
			end

			if displaytt then
				if vendor["Coordx"] ~= 0 and vendor["Coordy"] ~= 0 then
					cStr = "(" .. vendor["Coordx"] .. ", " .. vendor["Coordy"] .. ")"
				end
				ttAdd(0, -1, 0, L["Vendor"], clr1, vendor["Name"], clr2)
				clr1 = addon:hexcolor("NORMAL")
				clr2 = addon:hexcolor("HIGH")
				ttAdd(1, -2, 1, vendor["Location"], clr1, cStr, clr2)
			elseif faction then
				ttAdd(0, -1, 0, faction.." "..L["Vendor"], clr1)
			end
		--@alpha@
		else	-- Unhandled
			ttAdd(0, -1, 0, L["Unhandled Recipe"], addon:hexcolor("NORMAL"))
		--@end-alpha@
		end
	end
	arlTooltip:AddSeparator()
	arlTooltip:AddSeparator()

	clr1 = addon:hexcolor("NORMAL")

	ttAdd(0, -1, 0, L["ALT_CLICK"], clr1)
	ttAdd(0, -1, 0, L["CTRL_CLICK"], clr1)
	ttAdd(0, -1, 0, L["SHIFT_CLICK"], clr1)

	if addon.db.profile.worldmap or addon.db.profile.minimap then
		ttAdd(0, -1, 0, L["CTRL_SHIFT_CLICK"], clr1)
	end
	arlTooltip:Show()

	-- If we have the spell link tooltip, link it to the acquire tooltip.
	if spellTooltipLocation ~= _G.OFF and spellLink then
		SetSpellTooltip(arlTooltip, spellTooltipLocation, spellLink)
	else
		arlSpellTooltip:Hide()
	end
end

-------------------------------------------------------------------------------
-- Create the MainPanel and set its values
-------------------------------------------------------------------------------
local MainPanel = CreateFrame("Frame", "ARL_MainPanel", UIParent)
MainPanel:SetWidth(MAINPANEL_NORMAL_WIDTH)
MainPanel:SetHeight(447)
MainPanel:SetFrameStrata("DIALOG")
MainPanel:SetHitRectInsets(5, 5, 5, 5)

MainPanel:EnableMouse(true)
MainPanel:EnableKeyboard(true)
MainPanel:SetMovable(true)
MainPanel:SetClampedToScreen(true)
MainPanel:Show()

MainPanel.is_expanded = false

-- Let the user banish the MainPanel with the ESC key.
tinsert(UISpecialFrames, "ARL_MainPanel")

addon.Frame = MainPanel

MainPanel.backdrop = MainPanel:CreateTexture("AckisRecipeList.bgTexture", "ARTWORK")
MainPanel.backdrop:SetTexture("Interface\\Addons\\AckisRecipeList\\img\\main")
MainPanel.backdrop:SetAllPoints(MainPanel)
MainPanel.backdrop:SetTexCoord(0, (MAINPANEL_NORMAL_WIDTH/512), 0, (447/512))

MainPanel.title_bar = MainPanel:CreateFontString(nil, "ARTWORK")
MainPanel.title_bar:SetFontObject("GameFontHighlightSmall")
MainPanel.title_bar:ClearAllPoints()
MainPanel.title_bar:SetPoint("TOP", MainPanel, "TOP", 20, -16)
MainPanel.title_bar:SetJustifyH("CENTER")

-------------------------------------------------------------------------------
-- MainPanel scripts/functions.
-------------------------------------------------------------------------------
MainPanel:SetScript("OnHide",
		    function(self)
			    addon:ClosePopups()
		    end)

MainPanel:SetScript("OnMouseDown", MainPanel.StartMoving)

MainPanel:SetScript("OnMouseUp",
		    function(self, button)
			    self:StopMovingOrSizing()

			    local opts = addon.db.profile.frameopts
			    local from, _, to, x, y = self:GetPoint()

			    opts.anchorFrom = from
			    opts.anchorTo = to

			    if self.is_expanded then
				    if opts.anchorFrom == "TOPLEFT" or opts.anchorFrom == "LEFT" or opts.anchorFrom == "BOTTOMLEFT" then
					    opts.offsetx = x
				    elseif opts.anchorFrom == "TOP" or opts.anchorFrom == "CENTER" or opts.anchorFrom == "BOTTOM" then
					    opts.offsetx = x - 151/2
				    elseif opts.anchorFrom == "TOPRIGHT" or opts.anchorFrom == "RIGHT" or opts.anchorFrom == "BOTTOMRIGHT" then
					    opts.offsetx = x - 151
				    end
			    else
				    opts.offsetx = x
			    end
			    opts.offsety = y
		    end)

function MainPanel:ToggleState()
	if self.is_expanded then
		self:SetWidth(MAINPANEL_NORMAL_WIDTH)

		self.backdrop:SetTexture([[Interface\Addons\AckisRecipeList\img\main]])
		self.backdrop:SetAllPoints(self)
		self.backdrop:SetTexCoord(0, (MAINPANEL_NORMAL_WIDTH/512), 0, (447/512))

		self.progress_bar:SetWidth(195)
	else
		self:SetWidth(MAINPANEL_EXPANDED_WIDTH)

		self.backdrop:SetTexture([[Interface\Addons\AckisRecipeList\img\expanded]])
		self.backdrop:SetAllPoints(self)
		self.backdrop:SetTexCoord(0, (MAINPANEL_EXPANDED_WIDTH/512), 0, (447/512))

		self.progress_bar:SetWidth(345)
	end
	self.is_expanded = not self.is_expanded

	local x, y = self:GetLeft(), self:GetBottom()

	self:ClearAllPoints()
	self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
	self:UpdateTitle()
end

function MainPanel:SetProfession()
	for k, v in pairs(SortedProfessions) do
		if v.name == Player["Profession"] then
			self.profession = k
			break
		end
	end
	self.mode_button:ChangeTexture(SortedProfessions[self.profession].texture)
end

function MainPanel:SetPosition()
	self:ClearAllPoints()

	local opts = addon.db.profile.frameopts
	local FixedOffsetX = opts.offsetx

	if opts.anchorTo == "" then
		-- no values yet, clamp to whatever frame is appropriate
		if ATSWFrame then
			-- Anchor frame to ATSW
			self:SetPoint("CENTER", ATSWFrame, "CENTER", 490, 0)
		elseif CauldronFrame then
			-- Anchor frame to Cauldron
			self:SetPoint("CENTER", CauldronFrame, "CENTER", 490, 0)
		elseif Skillet then
			-- Anchor frame to Skillet
			self:SetPoint("CENTER", SkilletFrame, "CENTER", 468, 0)
		else
			-- Anchor to default tradeskill frame
			self:SetPoint("TOPLEFT", TradeSkillFrame, "TOPRIGHT", 10, 0)
		end
	else
		if self.is_expanded then
			if opts.anchorFrom == "TOPLEFT" or opts.anchorFrom == "LEFT" or opts.anchorFrom == "BOTTOMLEFT" then
				FixedOffsetX = opts.offsetx
			elseif opts.anchorFrom == "TOP" or opts.anchorFrom == "CENTER" or opts.anchorFrom == "BOTTOM" then
				FixedOffsetX = opts.offsetx + 151/2
			elseif opts.anchorFrom == "TOPRIGHT" or opts.anchorFrom == "RIGHT" or opts.anchorFrom == "BOTTOMRIGHT" then
				FixedOffsetX = opts.offsetx + 151
			end
		end
		self:SetPoint(opts.anchorFrom, UIParent, opts.anchorTo, FixedOffsetX, opts.offsety)
	end
end

function MainPanel:UpdateTitle()
	if self.is_expanded then
		local total, active = 0, 0

		for filter, info in pairs(FilterValueMap) do
			if info.svroot then
				if info.svroot[filter] == true then
					active = active + 1
				end
				total = total + 1
			end
		end
		self.title_bar:SetFormattedText(addon:Normal("ARL (v.%s) - %s (%d/%d %s)"), addon.version, Player["Profession"], active, total, _G.FILTERS)
	else
		self.title_bar:SetFormattedText(addon:Normal("ARL (v.%s) - %s"), addon.version, Player["Profession"])
	end
end

-------------------------------------------------------------------------------
-- Create the MainPanel.mode_button and assign its values.
-------------------------------------------------------------------------------
MainPanel.mode_button = CreateFrame("Button", nil, MainPanel, "UIPanelButtonTemplate")
MainPanel.mode_button:SetWidth(64)
MainPanel.mode_button:SetHeight(64)
MainPanel.mode_button:SetPoint("TOPLEFT", MainPanel, "TOPLEFT", 1, -2)
MainPanel.mode_button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

MainPanel.mode_button._normal = MainPanel.mode_button:CreateTexture(nil, "BACKGROUND")
MainPanel.mode_button._pushed = MainPanel.mode_button:CreateTexture(nil, "BACKGROUND")
MainPanel.mode_button._disabled = MainPanel.mode_button:CreateTexture(nil, "BACKGROUND")

-------------------------------------------------------------------------------
-- MainPanel.mode_button scripts/functions.
-------------------------------------------------------------------------------
MainPanel.mode_button:SetScript("OnClick",
				function(self, button, down)
					-- Known professions should be in Player["Professions"]

					-- This loop is gonna be weird. The reason is because we need to
					-- ensure that we cycle through all the known professions, but also
					-- that we do so in order. That means that if the currently displayed
					-- profession is the last one in the list, we're actually going to
					-- iterate completely once to get to the currently displayed profession
					-- and then iterate again to make sure we display the next one in line.
					-- Further, there is the nuance that the person may not know any
					-- professions yet at all. User are so annoying.
					local startLoop = 0
					local endLoop = 0
					local displayProf = 0

					-- ok, so first off, if we've never done this before, there is no "current"
					-- and a single iteration will do nicely, thank you
					if button == "LeftButton" then
						-- normal profession switch
						if MainPanel.profession == 0 then
							startLoop = 1
							endLoop = NUM_PROFESSIONS + 1
						else
							startLoop = MainPanel.profession + 1
							endLoop = MainPanel.profession
						end
						local index = startLoop
	
						while index ~= endLoop do
							if index > NUM_PROFESSIONS then
								index = 1
							elseif Player["Professions"][SortedProfessions[index].name] then
								displayProf = index
								MainPanel.profession = index
								break
							else
								index = index + 1
							end
						end
					elseif button == "RightButton" then
						-- reverse profession switch
						if MainPanel.profession == 0 then
							startLoop = NUM_PROFESSIONS + 1
							endLoop = 0
						else
							startLoop = MainPanel.profession - 1
							endLoop = MainPanel.profession
						end
						local index = startLoop

						while index ~= endLoop do
							if index < 1 then
								index = NUM_PROFESSIONS
							elseif Player["Professions"][SortedProfessions[index].name] then
								displayProf = index
								MainPanel.profession = index
								break
							else
								index = index - 1
							end
						end
					end
					local is_shown = TradeSkillFrame:IsVisible()

					CastSpellByName(SortedProfessions[MainPanel.profession].name)
					addon:Scan()

					if not is_shown then
						TradeSkillFrame:Hide()
					end
				end)

function MainPanel.mode_button:ChangeTexture(texture)
	local normal, pushed, disabled = self._normal, self._pushed, self._disabled

	normal:SetTexture([[Interface\Addons\AckisRecipeList\img\]] .. texture .. [[_up]])
	normal:SetTexCoord(0, 1, 0, 1)
	normal:SetAllPoints(self)
	self:SetNormalTexture(normal)

	pushed:SetTexture([[Interface\Addons\AckisRecipeList\img\]] .. texture .. [[_down]])
	pushed:SetTexCoord(0, 1, 0, 1)
	pushed:SetAllPoints(self)
	self:SetPushedTexture(pushed)

	disabled:SetTexture([[Interface\Addons\AckisRecipeList\img\]] .. texture .. [[_up]])
	disabled:SetTexCoord(0, 1, 0, 1)
	disabled:SetAllPoints(self)
	self:SetDisabledTexture(disabled)
end

-------------------------------------------------------------------------------
-- Create the X-close button, and set its scripts.
-------------------------------------------------------------------------------
MainPanel.xclose_button = CreateFrame("Button", nil, MainPanel, "UIPanelCloseButton")
MainPanel.xclose_button:SetPoint("TOPRIGHT", MainPanel, "TOPRIGHT", 5, -6)

MainPanel.xclose_button:SetScript("OnClick",
				  function(self, button, down)
					  MainPanel:Hide()
				  end)

-------------------------------------------------------------------------------
-- Create MainPanel.filter_toggle, and set its scripts.
-------------------------------------------------------------------------------
MainPanel.filter_toggle = GenericCreateButton(nil, MainPanel, 25, 90, "GameFontNormalSmall", "GameFontHighlightSmall", L["FILTER_OPEN"], "CENTER", L["FILTER_OPEN_DESC"], 1)
MainPanel.filter_toggle:SetPoint("TOPRIGHT", MainPanel, "TOPRIGHT", -8, -40)

MainPanel.filter_toggle:SetScript("OnClick",
			   function(self, button, down)
				   if MainPanel.is_expanded then
					   -- Change the text and tooltip for the filter button
					   self:SetText(L["FILTER_OPEN"])
					   SetTooltipScripts(self, L["FILTER_OPEN_DESC"])

					   -- Hide my 7 buttons
					   ARL_ExpGeneralOptCB:Hide()
					   ARL_ExpObtainOptCB:Hide()
					   ARL_ExpBindingOptCB:Hide()
					   ARL_ExpItemOptCB:Hide()
					   ARL_ExpPlayerOptCB:Hide()
					   ARL_ExpRepOptCB:Hide()
					   ARL_ExpMiscOptCB:Hide()

					   -- Uncheck the seven buttons
					   HideARL_ExpOptCB()

					   MainPanel.filter_menu:Hide()
					   MainPanel.filter_reset:Hide()
				   else
					   -- Change the text and tooltip for the filter button
					   self:SetText(L["FILTER_CLOSE"])
					   SetTooltipScripts(self, L["FILTER_CLOSE_DESC"])

					   -- Show my 7 buttons
					   ARL_ExpGeneralOptCB:Show()
					   ARL_ExpObtainOptCB:Show()
					   ARL_ExpBindingOptCB:Show()
					   ARL_ExpItemOptCB:Show()
					   ARL_ExpPlayerOptCB:Show()
					   ARL_ExpRepOptCB:Show()
					   ARL_ExpMiscOptCB:Show()

					   MainPanel.filter_reset:Show()
				   end
				   MainPanel:ToggleState()
			   end)

-------------------------------------------------------------------------------
-- Create MainPanel.filter_reset and set its scripts.
-------------------------------------------------------------------------------
MainPanel.filter_reset = GenericCreateButton(nil, MainPanel, 25, 90, "GameFontNormalSmall", "GameFontHighlightSmall", _G.RESET, "CENTER",
					     L["RESET_DESC"], 1)
MainPanel.filter_reset:SetPoint("TOPRIGHT", MainPanel.filter_toggle, "BOTTOMRIGHT", 0, -2)
MainPanel.filter_reset:Hide()

do
	local function recursiveReset(t)
		-- Thanks to Antiarc for this code
		for k, v in pairs(t) do
			if type(v) == "table" then
				recursiveReset(v)
			else
				t[k] = true
			end
		end
	end

	MainPanel.filter_reset:SetScript("OnClick",
					 function()
						 local filterdb = addon.db.profile.filters

						 -- Reset all filters to true
						 recursiveReset(addon.db.profile.filters)

						 -- Reset specific filters to false
						 filterdb.general.specialty = false
						 filterdb.general.known = false

						 -- Reset all classes to false
						 for class in pairs(filterdb.classes) do
							 filterdb.classes[class] = false
						 end
						 -- Set your own class to true
						 filterdb.classes[strlower(Player["Class"])] = true

						 if MainPanel:IsVisible() then
							 MainPanel:UpdateTitle()
							 HideARL_ExpOptCB()
							 MainPanel.filter_menu:Hide()
							 ReDisplay()
						 end
					 end)
end	-- do

-------------------------------------------------------------------------------
-- Create the seven buttons for opening/closing the filter menus
-------------------------------------------------------------------------------
local CreateFilterMenuButton
do
	local ExpButtonTT = {
		L["FILTERING_GENERAL_DESC"],	-- 1
		L["FILTERING_OBTAIN_DESC"],	-- 2
		L["FILTERING_BINDING_DESC"],	-- 3
		L["FILTERING_ITEM_DESC"],	-- 4
		L["FILTERING_PLAYERTYPE_DESC"],	-- 5
		L["FILTERING_REP_DESC"],	-- 6
		L["FILTERING_MISC_DESC"]	-- 7
	}

	local function ToggleFilterMenu(panel)
		-- This manages the filter menu panel, as well as checking or unchecking the
		-- buttons that got us here in the first place
		--
		-- our panels are:
		-- 1	ARL_ExpGeneralOptCB			General Filters
		-- 2	ARL_ExpObtainOptCB			Obtain Filters
		-- 3	ARL_ExpBindingOptCB			Binding Filters
		-- 4	ARL_ExpItemOptCB			Item Filters
		-- 5	ARL_ExpPlayerOptCB			Role Filters
		-- 6	ARL_ExpRepOptCB				Reputation Filters
		-- 7	ARL_ExpMiscOptCB			Miscellaneous Filters

		local ChangeFilters = false

		MainPanel.filter_menu.rep.Classic:Hide()
		MainPanel.filter_menu.rep.BC:Hide()
		MainPanel.filter_menu.rep.LK:Hide()

		ARL_Rep_ClassicCB:SetChecked(false)
		ARL_Rep_BCCB:SetChecked(false)
		ARL_Rep_LKCB:SetChecked(false)

		if panel == 1 then
			if ARL_ExpGeneralOptCB:GetChecked() then
				-- uncheck all other buttons
				HideARL_ExpOptCB("general")

				-- display the correct subframe with all the buttons and such, hide the others
				MainPanel.filter_menu.general:Show()
				MainPanel.filter_menu.obtain:Hide()
				MainPanel.filter_menu.binding:Hide()
				MainPanel.filter_menu.item:Hide()
				MainPanel.filter_menu.player:Hide()
				MainPanel.filter_menu.rep:Hide()
				MainPanel.filter_menu.misc:Hide()

				ChangeFilters = true
			else
				ARL_ExpGeneralOptCB.text:SetText(addon:Yellow(ExpButtonText[1])) 
				ChangeFilters = false
			end
		elseif panel == 2 then
			if ARL_ExpObtainOptCB:GetChecked() then
				HideARL_ExpOptCB("obtain")

				-- display the correct subframe with all the buttons and such, hide the others
				MainPanel.filter_menu.general:Hide()
				MainPanel.filter_menu.obtain:Show()
				MainPanel.filter_menu.binding:Hide()
				MainPanel.filter_menu.item:Hide()
				MainPanel.filter_menu.player:Hide()
				MainPanel.filter_menu.rep:Hide()
				MainPanel.filter_menu.misc:Hide()

				ChangeFilters = true
			else
				ARL_ExpObtainOptCB.text:SetText(addon:Yellow(ExpButtonText[2]))
				ChangeFilters = false
			end
		elseif panel == 3 then
			if ARL_ExpBindingOptCB:GetChecked() then
				HideARL_ExpOptCB("binding")

				-- display the correct subframe with all the buttons and such, hide the others
				MainPanel.filter_menu.general:Hide()
				MainPanel.filter_menu.obtain:Hide()
				MainPanel.filter_menu.binding:Show()
				MainPanel.filter_menu.item:Hide()
				MainPanel.filter_menu.player:Hide()
				MainPanel.filter_menu.rep:Hide()
				MainPanel.filter_menu.misc:Hide()

				ChangeFilters = true
			else
				ARL_ExpBindingOptCB.text:SetText(addon:Yellow(ExpButtonText[3])) 
				ChangeFilters = false
			end
		elseif panel == 4 then
			if ARL_ExpItemOptCB:GetChecked() then
				HideARL_ExpOptCB("item")

				-- display the correct subframe with all the buttons and such, hide the others
				MainPanel.filter_menu.general:Hide()
				MainPanel.filter_menu.obtain:Hide()
				MainPanel.filter_menu.binding:Hide()
				MainPanel.filter_menu.item:Show()
				MainPanel.filter_menu.player:Hide()
				MainPanel.filter_menu.rep:Hide()
				MainPanel.filter_menu.misc:Hide()

				ChangeFilters = true
			else
				ARL_ExpItemOptCB.text:SetText(addon:Yellow(ExpButtonText[4])) 
				ChangeFilters = false
			end
		elseif panel == 5 then
			if ARL_ExpPlayerOptCB:GetChecked() then
				HideARL_ExpOptCB("player")

				-- display the correct subframe with all the buttons and such, hide the others
				MainPanel.filter_menu.general:Hide()
				MainPanel.filter_menu.obtain:Hide()
				MainPanel.filter_menu.binding:Hide()
				MainPanel.filter_menu.item:Hide()
				MainPanel.filter_menu.player:Show()
				MainPanel.filter_menu.rep:Hide()
				MainPanel.filter_menu.misc:Hide()

				ChangeFilters = true
			else
				ARL_ExpPlayerOptCB.text:SetText(addon:Yellow(ExpButtonText[5])) 
				ChangeFilters = false
			end
		elseif panel == 6 then
			if ARL_ExpRepOptCB:GetChecked() then
				HideARL_ExpOptCB("rep")

				-- display the correct subframe with all the buttons and such, hide the others
				MainPanel.filter_menu.general:Hide()
				MainPanel.filter_menu.obtain:Hide()
				MainPanel.filter_menu.binding:Hide()
				MainPanel.filter_menu.item:Hide()
				MainPanel.filter_menu.player:Hide()
				MainPanel.filter_menu.rep:Show()
				MainPanel.filter_menu.misc:Hide()

				ChangeFilters = true
			else
				ARL_ExpRepOptCB.text:SetText(addon:Yellow(ExpButtonText[6])) 
				ChangeFilters = false
			end
		elseif panel == 7 then
			if ARL_ExpMiscOptCB:GetChecked() then
				HideARL_ExpOptCB("misc")

				-- display the correct subframe with all the buttons and such, hide the others
				MainPanel.filter_menu.general:Hide()
				MainPanel.filter_menu.obtain:Hide()
				MainPanel.filter_menu.binding:Hide()
				MainPanel.filter_menu.item:Hide()
				MainPanel.filter_menu.player:Hide()
				MainPanel.filter_menu.rep:Hide()
				MainPanel.filter_menu.misc:Show()

				ChangeFilters = true
			else
				ARL_ExpMiscOptCB.text:SetText(addon:Yellow(ExpButtonText[7])) 
				ChangeFilters = false
			end
		end

		if ChangeFilters then
			-- Depending on which panel we're showing, either display one column
			-- or two column
			if panel == 1 or panel == 2 or panel == 3 or panel == 4 or panel == 7 then
				MainPanel.filter_menu.texture:ClearAllPoints()
				MainPanel.filter_menu:SetWidth(FILTERMENU_DOUBLE_WIDTH)
				MainPanel.filter_menu.texture:SetTexture([[Interface\Addons\AckisRecipeList\img\fly_2col]])
				MainPanel.filter_menu.texture:SetAllPoints(MainPanel.filter_menu)
				MainPanel.filter_menu.texture:SetTexCoord(0, (FILTERMENU_DOUBLE_WIDTH/256), 0, (FILTERMENU_HEIGHT/512))
			elseif ((panel == 5) or (panel == 6)) then
				MainPanel.filter_menu.texture:ClearAllPoints()
				MainPanel.filter_menu:SetWidth(FILTERMENU_SINGLE_WIDTH)
				MainPanel.filter_menu.texture:SetTexture([[Interface\Addons\AckisRecipeList\img\fly_1col]])
				MainPanel.filter_menu.texture:SetAllPoints(MainPanel.filter_menu)
				MainPanel.filter_menu.texture:SetTexCoord(0, (FILTERMENU_SINGLE_WIDTH/256), 0, (FILTERMENU_HEIGHT/512))
			end
			-- Change the filters to the current panel
			MainPanel.filter_menu:Show()
		else
			-- We're hiding, don't bother changing anything
			MainPanel.filter_menu:Hide()
		end
	end

	function CreateFilterMenuButton(bName, bTex, panelIndex)
		local ExpTextureSize = 34
		local cButton = CreateFrame("CheckButton", bName, MainPanel) -- , "UICheckButtonTemplate")

		cButton:SetWidth(ExpTextureSize)
		cButton:SetHeight(ExpTextureSize)
		cButton:SetScript("OnClick",
				  function() 
					  ToggleFilterMenu(panelIndex)
				  end)

		local bgTex = cButton:CreateTexture(cButton:GetName() .. "bgTex", "BACKGROUND")
		bgTex:SetTexture('Interface/SpellBook/UI-Spellbook-SpellBackground')
		bgTex:SetHeight(ExpTextureSize + 6)
		bgTex:SetWidth(ExpTextureSize + 4)
		bgTex:SetTexCoord(0, (43/64), 0, (43/64))
		bgTex:SetPoint("CENTER", cButton, "CENTER", 0, 0)

		local iconTex = cButton:CreateTexture(cButton:GetName() .. "iconTex", "BORDER")
		iconTex:SetTexture('Interface/Icons/' .. bTex)
		iconTex:SetAllPoints(cButton)

		local pushedTexture = cButton:CreateTexture(cButton:GetName() .. "pTex", "ARTWORK")
		pushedTexture:SetTexture('Interface/Buttons/UI-Quickslot-Depress')
		pushedTexture:SetAllPoints(cButton)
		cButton:SetPushedTexture(pushedTexture)

		local highlightTexture = cButton:CreateTexture()
		highlightTexture:SetTexture('Interface/Buttons/ButtonHilight-Square')
		highlightTexture:SetAllPoints(cButton)
		highlightTexture:SetBlendMode('ADD')
		cButton:SetHighlightTexture(highlightTexture)

		local checkedTexture = cButton:CreateTexture()
		checkedTexture:SetTexture('Interface/Buttons/CheckButtonHilight')
		checkedTexture:SetAllPoints(cButton)
		checkedTexture:SetBlendMode('ADD')
		cButton:SetCheckedTexture(checkedTexture)

		-- Create the text object to go along with it
		local cbText = cButton:CreateFontString("cbText", "OVERLAY", "GameFontHighlight")
		cbText:SetText(addon:Yellow(ExpButtonText[panelIndex]))
		cbText:SetPoint("LEFT", cButton, "RIGHT", 5, 0)
		cbText:SetHeight(14)
		cbText:SetWidth(100)
		cbText:SetJustifyH("LEFT")
		cButton.text = cbText

		-- And throw up a tooltip
		SetTooltipScripts(cButton, ExpButtonTT[panelIndex])
		cButton:Hide()

		return cButton
	end
end	-- do

ARL_ExpGeneralOptCB = CreateFilterMenuButton("ARL_ExpGeneralOptCB", "INV_Misc_Note_06", 1)
ARL_ExpGeneralOptCB:SetPoint("TOPRIGHT", MainPanel.filter_reset, "BOTTOMLEFT", -7, -23)

ARL_ExpObtainOptCB = CreateFilterMenuButton("ARL_ExpObtainOptCB", "Spell_Shadow_MindRot", 2)
ARL_ExpObtainOptCB:SetPoint("TOPLEFT", ARL_ExpGeneralOptCB, "BOTTOMLEFT", 0, -8)

ARL_ExpBindingOptCB = CreateFilterMenuButton("ARL_ExpBindingOptCB", "INV_Belt_20", 3)
ARL_ExpBindingOptCB:SetPoint("TOPLEFT", ARL_ExpObtainOptCB, "BOTTOMLEFT", -0, -8)

ARL_ExpItemOptCB = CreateFilterMenuButton("ARL_ExpItemOptCB", "INV_Misc_EngGizmos_19", 4)
ARL_ExpItemOptCB:SetPoint("TOPLEFT", ARL_ExpBindingOptCB, "BOTTOMLEFT", -0, -8)

ARL_ExpPlayerOptCB = CreateFilterMenuButton("ARL_ExpPlayerOptCB", "INV_Misc_GroupLooking", 5)
ARL_ExpPlayerOptCB:SetPoint("TOPLEFT", ARL_ExpItemOptCB, "BOTTOMLEFT", -0, -8)

ARL_ExpRepOptCB = CreateFilterMenuButton("ARL_ExpRepOptCB", "INV_Scroll_05", 6)
ARL_ExpRepOptCB:SetPoint("TOPLEFT", ARL_ExpPlayerOptCB, "BOTTOMLEFT", -0, -8)

ARL_ExpMiscOptCB = CreateFilterMenuButton("ARL_ExpMiscOptCB", "Trade_Engineering", 7)
ARL_ExpMiscOptCB:SetPoint("TOPLEFT", ARL_ExpRepOptCB, "BOTTOMLEFT", -0, -8)

-------------------------------------------------------------------------------
-- Create MainPanel.filter_menu and set its scripts.
-------------------------------------------------------------------------------
MainPanel.filter_menu = CreateFrame("Frame", "ARL_FilterMenu", MainPanel)
MainPanel.filter_menu:SetWidth(FILTERMENU_DOUBLE_WIDTH)
MainPanel.filter_menu:SetHeight(FILTERMENU_HEIGHT)
MainPanel.filter_menu:SetPoint("TOPLEFT", MainPanel, "TOPRIGHT", -6, -102)
MainPanel.filter_menu:EnableMouse(true)
MainPanel.filter_menu:EnableKeyboard(true)
MainPanel.filter_menu:SetMovable(false)
MainPanel.filter_menu:SetHitRectInsets(5, 5, 5, 5)
MainPanel.filter_menu:Hide()

-- Set all the current options in the filter menu to make sure they are consistent with the SV options.
MainPanel.filter_menu:SetScript("OnShow",
				function()
					for filter, info in pairs(FilterValueMap) do
						if info.svroot then
							info.cb:SetChecked(info.svroot[filter])
						end
					end
					-- Miscellaneous Options
					ARL_IgnoreCB:SetChecked(addon.db.profile.ignoreexclusionlist)
				end)

MainPanel.filter_menu.texture = MainPanel.filter_menu:CreateTexture(nil, "ARTWORK")
MainPanel.filter_menu.texture:SetTexture("Interface\\Addons\\AckisRecipeList\\img\\fly_2col")
MainPanel.filter_menu.texture:SetAllPoints(MainPanel.filter_menu)
MainPanel.filter_menu.texture:SetTexCoord(0, (FILTERMENU_DOUBLE_WIDTH/256), 0, (FILTERMENU_HEIGHT/512))

-------------------------------------------------------------------------------
-- Function to initialize a check-button with the given values. Used in all of
-- the sub-menus of MainPanel.filter_menu
-------------------------------------------------------------------------------
local InitializeCheckButton
do
	local PUSHDOWN = {
		["cloak"]	= true,
		["necklace"]	= true,
		["ring"]	= true,
		["trinket"]	= true,
		["shield"]	= true,
	}
	function InitializeCheckButton(cButton, anchorFrame, ttText, scriptVal, row, col, misc)
		-- set the position of the new checkbox
		local xPos = 2 + ((col - 1) * 100)
		local yPos = -3 - ((row - 1) * 17)

		if PUSHDOWN[scriptVal] then
			yPos = yPos - 5
		end
		cButton:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", xPos, yPos)
		cButton:SetHeight(24)
		cButton:SetWidth(24)

		cButton:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
		cButton:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
		cButton:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
		cButton:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
		cButton:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

		cButton.text = cButton:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		cButton.text:SetPoint("LEFT", cButton, "RIGHT", 0, 0)

		-- depending if we're on the misc panel or not, set an alternative OnClick method
		if misc == 0 then
			cButton:SetScript("OnClick",
					  function()
						  FilterValueMap[scriptVal].svroot[scriptVal] = FilterValueMap[scriptVal].cb:GetChecked() and true or false
						  MainPanel:UpdateTitle()
						  ReDisplay()
					  end)
		else
			cButton:SetScript("OnClick",
					  function()
						  addon.db.profile.ignoreexclusionlist = not addon.db.profile.ignoreexclusionlist
						  ReDisplay()
					  end)
		end
		SetTooltipScripts(cButton, ttText, 1)
	end
end	-- do

-------------------------------------------------------------------------------
-- Create MainPanel.filter_menu.general, and set its scripts.
-------------------------------------------------------------------------------
MainPanel.filter_menu.general = CreateFrame("Frame", nil, MainPanel.filter_menu)
MainPanel.filter_menu.general:SetWidth(FILTERMENU_SMALL)
MainPanel.filter_menu.general:SetHeight(280)
MainPanel.filter_menu.general:EnableMouse(true)
MainPanel.filter_menu.general:EnableKeyboard(true)
MainPanel.filter_menu.general:SetMovable(false)
MainPanel.filter_menu.general:SetPoint("TOPLEFT", MainPanel.filter_menu, "TOPLEFT", 17, -16)
MainPanel.filter_menu.general:Hide()

-------------------------------------------------------------------------------
-- Create the CheckButtons for MainPanel.filter_menu.general
-------------------------------------------------------------------------------
MainPanel.filter_menu.general.specialty = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.specialty, MainPanel.filter_menu.general, L["SPECIALTY_DESC"], "specialty", 1, 1, 0)
MainPanel.filter_menu.general.specialty.text:SetText(L["Specialties"])

MainPanel.filter_menu.general.skill = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.skill, MainPanel.filter_menu.general, L["SKILL_DESC"], "skill", 1, 2, 0)
MainPanel.filter_menu.general.skill.text:SetText(_G.SKILL)

MainPanel.filter_menu.general.faction = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.faction, MainPanel.filter_menu.general, L["FACTION_DESC"], "faction", 2, 1, 0)
MainPanel.filter_menu.general.faction.text:SetText(_G.FACTION)

MainPanel.filter_menu.general.known = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.known, MainPanel.filter_menu.general, L["KNOWN_DESC"], "known", 2, 2, 0)
MainPanel.filter_menu.general.known.text:SetText(L["Show Known"])

MainPanel.filter_menu.general.unknown = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.unknown, MainPanel.filter_menu.general, L["UNKNOWN_DESC"], "unknown", 3, 1, 0)
MainPanel.filter_menu.general.unknown.text:SetText(L["Show Unknown"])

-------------------------------------------------------------------------------
-- Create the Class toggle and CheckButtons for MainPanel.filter_menu.general
-------------------------------------------------------------------------------
MainPanel.filter_menu.general.class_toggle = GenericCreateButton(nil, MainPanel.filter_menu.general, 20, 105, "GameFontHighlight", "GameFontHighlightSmall",
								 L["Classes"] .. ":", "LEFT", L["CLASS_TEXT_DESC"], 0)
MainPanel.filter_menu.general.class_toggle:SetPoint("TOPLEFT", MainPanel.filter_menu.general.unknown, "BOTTOMLEFT", -4, -10)
MainPanel.filter_menu.general.class_toggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
MainPanel.filter_menu.general.class_toggle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
MainPanel.filter_menu.general.class_toggle:SetScript("OnClick",
						     function(self, button)
							     local classes = addon.db.profile.filters.classes
							     local general = MainPanel.filter_menu.general
							     local toggle = (button == "LeftButton") and true or false

							     for class in pairs(classes) do
								     classes[class] = toggle
								     general[class]:SetChecked(toggle)
							     end

							     if toggle == false then
								     local class = strlower(Player["Class"])
								     classes[class] = true
								     general[class]:SetChecked(true)
							     end
							     MainPanel:UpdateTitle()
							     ReDisplay()
						     end)

MainPanel.filter_menu.general.deathknight = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.deathknight, MainPanel.filter_menu.general, L["CLASS_DESC"], "deathknight", 6, 1, 0)
MainPanel.filter_menu.general.deathknight.text:SetText(LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"])

MainPanel.filter_menu.general.druid = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.druid, MainPanel.filter_menu.general, L["CLASS_DESC"], "druid", 6, 2, 0)
MainPanel.filter_menu.general.druid.text:SetText(LOCALIZED_CLASS_NAMES_MALE["DRUID"])

MainPanel.filter_menu.general.hunter = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.hunter, MainPanel.filter_menu.general, L["CLASS_DESC"], "hunter", 7, 1, 0)
MainPanel.filter_menu.general.hunter.text:SetText(LOCALIZED_CLASS_NAMES_MALE["HUNTER"])

MainPanel.filter_menu.general.mage = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.mage, MainPanel.filter_menu.general, L["CLASS_DESC"], "mage", 7, 2, 0)
MainPanel.filter_menu.general.mage.text:SetText(LOCALIZED_CLASS_NAMES_MALE["MAGE"])

MainPanel.filter_menu.general.paladin = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.paladin, MainPanel.filter_menu.general, L["CLASS_DESC"], "paladin", 8, 1, 0)
MainPanel.filter_menu.general.paladin.text:SetText(LOCALIZED_CLASS_NAMES_MALE["PALADIN"])

MainPanel.filter_menu.general.priest = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.priest, MainPanel.filter_menu.general, L["CLASS_DESC"], "priest", 8, 2, 0)
MainPanel.filter_menu.general.priest.text:SetText(LOCALIZED_CLASS_NAMES_MALE["PRIEST"])

MainPanel.filter_menu.general.rogue = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.rogue, MainPanel.filter_menu.general, L["CLASS_DESC"], "rogue", 9, 1, 0)
MainPanel.filter_menu.general.rogue.text:SetText(LOCALIZED_CLASS_NAMES_MALE["ROGUE"])

MainPanel.filter_menu.general.shaman = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.shaman, MainPanel.filter_menu.general, L["CLASS_DESC"], "shaman", 9, 2, 0)
MainPanel.filter_menu.general.shaman.text:SetText(LOCALIZED_CLASS_NAMES_MALE["SHAMAN"])

MainPanel.filter_menu.general.warlock = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.warlock, MainPanel.filter_menu.general, L["CLASS_DESC"], "warlock", 10, 1, 0)
MainPanel.filter_menu.general.warlock.text:SetText(LOCALIZED_CLASS_NAMES_MALE["WARLOCK"])

MainPanel.filter_menu.general.warrior = CreateFrame("CheckButton", nil, MainPanel.filter_menu.general)
InitializeCheckButton(MainPanel.filter_menu.general.warrior, MainPanel.filter_menu.general, L["CLASS_DESC"], "warrior", 10, 2, 0)
MainPanel.filter_menu.general.warrior.text:SetText(LOCALIZED_CLASS_NAMES_MALE["WARRIOR"])

-------------------------------------------------------------------------------
-- Create MainPanel.filter_menu.obtain, and set its scripts.
-------------------------------------------------------------------------------
MainPanel.filter_menu.obtain = CreateFrame("Frame", nil, MainPanel.filter_menu)
MainPanel.filter_menu.obtain:SetWidth(FILTERMENU_SMALL)
MainPanel.filter_menu.obtain:SetHeight(280)
MainPanel.filter_menu.obtain:EnableMouse(true)
MainPanel.filter_menu.obtain:EnableKeyboard(true)
MainPanel.filter_menu.obtain:SetMovable(false)
MainPanel.filter_menu.obtain:SetPoint("TOPLEFT", MainPanel.filter_menu, "TOPLEFT", 17, -16)
MainPanel.filter_menu.obtain:Hide()

-------------------------------------------------------------------------------
-- Create the CheckButtons for MainPanel.filter_menu.obtain
-------------------------------------------------------------------------------
MainPanel.filter_menu.obtain.instance = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.instance, MainPanel.filter_menu.obtain, L["INSTANCE_DESC"], "instance", 1, 1, 0)
MainPanel.filter_menu.obtain.instance.text:SetText(_G.INSTANCE)

MainPanel.filter_menu.obtain.raid = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.raid, MainPanel.filter_menu.obtain, L["RAID_DESC"], "raid", 1, 2, 0)
MainPanel.filter_menu.obtain.raid.text:SetText(_G.RAID)

MainPanel.filter_menu.obtain.quest = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.quest, MainPanel.filter_menu.obtain, L["QUEST_DESC"], "quest", 2, 1, 0)
MainPanel.filter_menu.obtain.quest.text:SetText(L["Quest"])

MainPanel.filter_menu.obtain.seasonal = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.seasonal, MainPanel.filter_menu.obtain, L["SEASONAL_DESC"], "seasonal", 2, 2, 0)
MainPanel.filter_menu.obtain.seasonal.text:SetText(SEASONAL_CATEGORY)

MainPanel.filter_menu.obtain.trainer = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.trainer, MainPanel.filter_menu.obtain, L["TRAINER_DESC"], "trainer", 3, 1, 0)
MainPanel.filter_menu.obtain.trainer.text:SetText(L["Trainer"])

MainPanel.filter_menu.obtain.vendor = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.vendor, MainPanel.filter_menu.obtain, L["VENDOR_DESC"], "vendor", 3, 2, 0)
MainPanel.filter_menu.obtain.vendor.text:SetText(L["Vendor"])

MainPanel.filter_menu.obtain.pvp = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.pvp, MainPanel.filter_menu.obtain, L["PVP_DESC"], "pvp", 4, 1, 0)
MainPanel.filter_menu.obtain.pvp.text:SetText(_G.PVP)

MainPanel.filter_menu.obtain.discovery = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.discovery, MainPanel.filter_menu.obtain, L["DISCOVERY_DESC"], "discovery", 4, 2, 0)
MainPanel.filter_menu.obtain.discovery.text:SetText(L["Discovery"])

MainPanel.filter_menu.obtain.worlddrop = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.worlddrop, MainPanel.filter_menu.obtain, L["WORLD_DROP_DESC"], "worlddrop", 5, 1, 0)
MainPanel.filter_menu.obtain.worlddrop.text:SetText(L["World Drop"])

MainPanel.filter_menu.obtain.mobdrop = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.mobdrop, MainPanel.filter_menu.obtain, L["MOB_DROP_DESC"], "mobdrop", 5, 2, 0)
MainPanel.filter_menu.obtain.mobdrop.text:SetText(L["Mob Drop"])

MainPanel.filter_menu.obtain.originalwow = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.originalwow, MainPanel.filter_menu.obtain, L["ORIGINAL_WOW_DESC"], "originalwow", 7, 1, 0)
MainPanel.filter_menu.obtain.originalwow.text:SetText(_G.EXPANSION_NAME0)

MainPanel.filter_menu.obtain.bc = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.bc, MainPanel.filter_menu.obtain, L["BC_WOW_DESC"], "bc", 8, 1, 0)
MainPanel.filter_menu.obtain.bc.text:SetText(_G.EXPANSION_NAME1)

MainPanel.filter_menu.obtain.wrath = CreateFrame("CheckButton", nil, MainPanel.filter_menu.obtain)
InitializeCheckButton(MainPanel.filter_menu.obtain.wrath, MainPanel.filter_menu.obtain, L["LK_WOW_DESC"], "wrath", 9, 1, 0)
MainPanel.filter_menu.obtain.wrath.text:SetText(_G.EXPANSION_NAME2)

-------------------------------------------------------------------------------
-- Create MainPanel.filter_menu.binding, and set its scripts.
-------------------------------------------------------------------------------
MainPanel.filter_menu.binding = CreateFrame("Frame", nil, MainPanel.filter_menu)
MainPanel.filter_menu.binding:SetWidth(FILTERMENU_LARGE)
MainPanel.filter_menu.binding:SetHeight(280)
MainPanel.filter_menu.binding:EnableMouse(true)
MainPanel.filter_menu.binding:EnableKeyboard(true)
MainPanel.filter_menu.binding:SetMovable(false)
MainPanel.filter_menu.binding:SetPoint("TOPLEFT", MainPanel.filter_menu, "TOPLEFT", 17, -16)
MainPanel.filter_menu.binding:Hide()

-------------------------------------------------------------------------------
-- Create the CheckButtons for MainPanel.filter_menu.binding
-------------------------------------------------------------------------------
MainPanel.filter_menu.binding.itemboe = CreateFrame("CheckButton", nil, MainPanel.filter_menu.binding)
InitializeCheckButton(MainPanel.filter_menu.binding.itemboe, MainPanel.filter_menu.binding, L["BOE_DESC"], "itemboe", 1, 1, 0)
MainPanel.filter_menu.binding.itemboe.text:SetText(L["BOEFilter"])

MainPanel.filter_menu.binding.itembop = CreateFrame("CheckButton", nil, MainPanel.filter_menu.binding)
InitializeCheckButton(MainPanel.filter_menu.binding.itembop, MainPanel.filter_menu.binding, L["BOP_DESC"], "itembop", 2, 1, 0)
MainPanel.filter_menu.binding.itembop.text:SetText(L["BOPFilter"])

MainPanel.filter_menu.binding.recipeboe = CreateFrame("CheckButton", nil, MainPanel.filter_menu.binding)
InitializeCheckButton(MainPanel.filter_menu.binding.recipeboe, MainPanel.filter_menu.binding, L["RECIPE_BOE_DESC"], "recipeboe", 3, 1, 0)
MainPanel.filter_menu.binding.recipeboe.text:SetText(L["RecipeBOEFilter"])

MainPanel.filter_menu.binding.recipebop = CreateFrame("CheckButton", nil, MainPanel.filter_menu.binding)
InitializeCheckButton(MainPanel.filter_menu.binding.recipebop, MainPanel.filter_menu.binding, L["RECIPE_BOP_DESC"], "recipebop", 4, 1, 0)
MainPanel.filter_menu.binding.recipebop.text:SetText(L["RecipeBOPFilter"])

-------------------------------------------------------------------------------
-- Create MainPanel.filter_menu.item, and set its scripts.
-------------------------------------------------------------------------------
MainPanel.filter_menu.item = CreateFrame("Frame", nil, MainPanel.filter_menu)
MainPanel.filter_menu.item:SetWidth(FILTERMENU_LARGE)
MainPanel.filter_menu.item:SetHeight(280)
MainPanel.filter_menu.item:EnableMouse(true)
MainPanel.filter_menu.item:EnableKeyboard(true)
MainPanel.filter_menu.item:SetMovable(false)
MainPanel.filter_menu.item:SetPoint("TOPLEFT", MainPanel.filter_menu, "TOPLEFT", 17, -16)
MainPanel.filter_menu.item:Hide()

-------------------------------------------------------------------------------
-- Create the Armor toggle and CheckButtons for MainPanel.filter_menu.item
-------------------------------------------------------------------------------
MainPanel.filter_menu.item.armor_toggle = GenericCreateButton(nil, MainPanel.filter_menu.item, 20, 105, "GameFontHighlight", "GameFontHighlightSmall", _G.ARMOR_COLON,
							      "LEFT", L["ARMOR_TEXT_DESC"], 0)
MainPanel.filter_menu.item.armor_toggle:SetPoint("TOPLEFT", MainPanel.filter_menu.item, "TOPLEFT", -2, -4)
MainPanel.filter_menu.item.armor_toggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
MainPanel.filter_menu.item.armor_toggle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
MainPanel.filter_menu.item.armor_toggle:SetScript("OnClick",
						  function(self, button)
							  local armors = addon.db.profile.filters.item.armor
							  local items = MainPanel.filter_menu.item
							  local toggle = (button == "LeftButton") and true or false

							  for armor in pairs(armors) do
								  armors[armor] = toggle
								  items[armor]:SetChecked(toggle)
							  end
							  MainPanel:UpdateTitle()
							  ReDisplay()
						  end)

MainPanel.filter_menu.item.cloth = CreateFrame("CheckButton", nil, MainPanel.filter_menu.item)
InitializeCheckButton(MainPanel.filter_menu.item.cloth, MainPanel.filter_menu.item, L["CLOTH_DESC"], "cloth", 2, 1, 0)
MainPanel.filter_menu.item.cloth.text:SetText(L["Cloth"])

MainPanel.filter_menu.item.leather = CreateFrame("CheckButton", nil, MainPanel.filter_menu.item)
InitializeCheckButton(MainPanel.filter_menu.item.leather, MainPanel.filter_menu.item, L["LEATHER_DESC"], "leather", 2, 2, 0)
MainPanel.filter_menu.item.leather.text:SetText(L["Leather"])

MainPanel.filter_menu.item.mail = CreateFrame("CheckButton", nil, MainPanel.filter_menu.item)
InitializeCheckButton(MainPanel.filter_menu.item.mail, MainPanel.filter_menu.item, L["MAIL_DESC"], "mail", 3, 1, 0)
MainPanel.filter_menu.item.mail.text:SetText(L["Mail"])

MainPanel.filter_menu.item.plate = CreateFrame("CheckButton", nil, MainPanel.filter_menu.item)
InitializeCheckButton(MainPanel.filter_menu.item.plate, MainPanel.filter_menu.item, L["PLATE_DESC"], "plate", 3, 2, 0)
MainPanel.filter_menu.item.plate.text:SetText(L["Plate"])

MainPanel.filter_menu.item.cloak = CreateFrame("CheckButton", nil, MainPanel.filter_menu.item)
InitializeCheckButton(MainPanel.filter_menu.item.cloak, MainPanel.filter_menu.item, L["CLOAK_DESC"], "cloak", 4, 1, 0)
MainPanel.filter_menu.item.cloak.text:SetText(L["Cloak"])

MainPanel.filter_menu.item.necklace = CreateFrame("CheckButton", nil, MainPanel.filter_menu.item)
InitializeCheckButton(MainPanel.filter_menu.item.necklace, MainPanel.filter_menu.item, L["NECKLACE_DESC"], "necklace", 4, 2, 0)
MainPanel.filter_menu.item.necklace.text:SetText(L["Necklace"])

MainPanel.filter_menu.item.ring = CreateFrame("CheckButton", nil, MainPanel.filter_menu.item)
InitializeCheckButton(MainPanel.filter_menu.item.ring, MainPanel.filter_menu.item, L["RING_DESC"], "ring", 5, 1, 0)
MainPanel.filter_menu.item.ring.text:SetText(L["Ring"])

MainPanel.filter_menu.item.trinket = CreateFrame("CheckButton", nil, MainPanel.filter_menu.item)
InitializeCheckButton(MainPanel.filter_menu.item.trinket, MainPanel.filter_menu.item, L["TRINKET_DESC"], "trinket", 5, 2, 0)
MainPanel.filter_menu.item.trinket.text:SetText(L["Trinket"])

MainPanel.filter_menu.item.shield = CreateFrame("CheckButton", nil, MainPanel.filter_menu.item)
InitializeCheckButton(MainPanel.filter_menu.item.shield, MainPanel.filter_menu.item, L["SHIELD_DESC"], "shield", 6, 1, 0)
MainPanel.filter_menu.item.shield.text:SetText(L["Shield"])

-------------------------------------------------------------------------------
-- Create the Weapon toggle and CheckButtons for MainPanel.filter_menu.item
-------------------------------------------------------------------------------
	local ARL_WeaponButton = GenericCreateButton("ARL_WeaponButton", MainPanel.filter_menu.item, 20, 105, "GameFontHighlight", "GameFontHighlightSmall", L["Weapon"] .. ":",
						     "LEFT", L["WEAPON_TEXT_DESC"], 0)
	ARL_WeaponButton:SetPoint("TOPLEFT", MainPanel.filter_menu.item, "TOPLEFT", -2, -122)

	ARL_WeaponButton:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
	ARL_WeaponButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	ARL_WeaponButton:SetScript("OnClick",
				   function(self, button)
					   local weapondb = addon.db.profile.filters.item.weapon

					   if button == "LeftButton" then
						   -- Reset all weapon to true
						   for weapon in pairs(weapondb) do
							   weapondb[weapon] = true
						   end
					   elseif button == "RightButton" then
						   -- Reset all weapon to false
						   for weapon in pairs(weapondb) do
							   weapondb[weapon] = false
						   end
					   end
					   -- Update the checkboxes with the new value
					   ARL_Weapon1HCB:SetChecked(weapondb.onehand)
					   ARL_Weapon2HCB:SetChecked(weapondb.twohand)
					   ARL_WeaponDaggerCB:SetChecked(weapondb.dagger)
					   ARL_WeaponAxeCB:SetChecked(weapondb.axe)
					   ARL_WeaponMaceCB:SetChecked(weapondb.mace)
					   ARL_WeaponSwordCB:SetChecked(weapondb.sword)
					   ARL_WeaponPolearmCB:SetChecked(weapondb.polearm)
					   ARL_WeaponWandCB:SetChecked(weapondb.wand)
					   ARL_WeaponThrownCB:SetChecked(weapondb.thrown)
					   ARL_WeaponAmmoCB:SetChecked(weapondb.ammo)
					   ARL_WeaponFistCB:SetChecked(weapondb.fist)
					   ARL_WeaponGunCB:SetChecked(weapondb.gun)
					   -- Reset our title
					   MainPanel:UpdateTitle()
					   -- Use new filters
					   ReDisplay()
				   end)

	local ARL_Weapon1HCB = CreateFrame("CheckButton", "ARL_Weapon1HCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_Weapon1HCB, MainPanel.filter_menu.item, L["ONEHAND_DESC"], "onehand", 9, 1, 0)
	ARL_Weapon1HCBText:SetText(L["One Hand"])

	local ARL_Weapon2HCB = CreateFrame("CheckButton", "ARL_Weapon2HCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_Weapon2HCB, MainPanel.filter_menu.item, L["TWOHAND_DESC"], "twohand", 9, 2, 0)
	ARL_Weapon2HCBText:SetText(L["Two Hand"])

	local ARL_WeaponDaggerCB = CreateFrame("CheckButton", "ARL_WeaponDaggerCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponDaggerCB, MainPanel.filter_menu.item, L["DAGGER_DESC"], "dagger", 10, 1, 0)
	ARL_WeaponDaggerCBText:SetText(L["Dagger"])

	local ARL_WeaponAxeCB = CreateFrame("CheckButton", "ARL_WeaponAxeCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponAxeCB, MainPanel.filter_menu.item, L["AXE_DESC"], "axe", 10, 2, 0)
	ARL_WeaponAxeCBText:SetText(L["Axe"])

	local ARL_WeaponMaceCB = CreateFrame("CheckButton", "ARL_WeaponMaceCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponMaceCB, MainPanel.filter_menu.item, L["MACE_DESC"], "mace", 11, 1, 0)
	ARL_WeaponMaceCBText:SetText(L["Mace"])

	local ARL_WeaponSwordCB = CreateFrame("CheckButton", "ARL_WeaponSwordCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponSwordCB, MainPanel.filter_menu.item, L["SWORD_DESC"], "sword", 11, 2, 0)
	ARL_WeaponSwordCBText:SetText(L["Sword"])

	local ARL_WeaponPolearmCB = CreateFrame("CheckButton", "ARL_WeaponPolearmCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponPolearmCB, MainPanel.filter_menu.item, L["POLEARM_DESC"], "polearm", 12, 1, 0)
	ARL_WeaponPolearmCBText:SetText(L["Polearm"])

	local ARL_WeaponFistCB = CreateFrame("CheckButton", "ARL_WeaponFistCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponFistCB, MainPanel.filter_menu.item, L["FIST_DESC"], "fist", 12, 2, 0)
	ARL_WeaponFistCBText:SetText(L["Fist"])

	local ARL_WeaponStaffCB = CreateFrame("CheckButton", "ARL_WeaponStaffCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponStaffCB, MainPanel.filter_menu.item, L["STAFF_DESC"], "staff", 13, 1, 0)
	ARL_WeaponStaffCBText:SetText(L["Staff"])
	ARL_WeaponStaffCBText:SetText(addon:Grey(L["Staff"]))
	ARL_WeaponStaffCB:Disable()

	local ARL_WeaponWandCB = CreateFrame("CheckButton", "ARL_WeaponWandCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponWandCB, MainPanel.filter_menu.item, L["WAND_DESC"], "wand", 13, 2, 0)
	ARL_WeaponWandCBText:SetText(L["Wand"])

	local ARL_WeaponThrownCB = CreateFrame("CheckButton", "ARL_WeaponThrownCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponThrownCB, MainPanel.filter_menu.item, L["THROWN_DESC"], "thrown", 14, 1, 0)
	ARL_WeaponThrownCBText:SetText(L["Thrown"])

	local ARL_WeaponBowCB = CreateFrame("CheckButton", "ARL_WeaponBowCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponBowCB, MainPanel.filter_menu.item, L["BOW_DESC"], "bow", 14, 2, 0)
	ARL_WeaponBowCBText:SetText(L["Bow"])
	ARL_WeaponBowCBText:SetText(addon:Grey(L["Bow"]))
	ARL_WeaponBowCB:Disable()

	local ARL_WeaponCrossbowCB = CreateFrame("CheckButton", "ARL_WeaponCrossbowCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponCrossbowCB, MainPanel.filter_menu.item, L["CROSSBOW_DESC"], "crossbow", 15, 1, 0)
	ARL_WeaponCrossbowCBText:SetText(L["Crossbow"])
	ARL_WeaponCrossbowCBText:SetText(addon:Grey(L["Crossbow"]))
	ARL_WeaponCrossbowCB:Disable()

	local ARL_WeaponAmmoCB = CreateFrame("CheckButton", "ARL_WeaponAmmoCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponAmmoCB, MainPanel.filter_menu.item, L["AMMO_DESC"], "ammo", 15, 2, 0)
	ARL_WeaponAmmoCBText:SetText(L["Ammo"])

	local ARL_WeaponGunCB = CreateFrame("CheckButton", "ARL_WeaponGunCB", MainPanel.filter_menu.item, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WeaponGunCB, MainPanel.filter_menu.item, L["GUN_DESC"], "gun", 16, 1, 0)
	ARL_WeaponGunCBText:SetText(L["Gun"])

-------------------------------------------------------------------------------
-- Generic function to create expansion buttons in MainPanel.filter_menu.rep
-------------------------------------------------------------------------------
local function CreateExpansionButton(bName, bTex)
	local cButton = CreateFrame("CheckButton", bName, MainPanel.filter_menu.rep)
	cButton:SetWidth(100)
	cButton:SetHeight(46)
	cButton:SetChecked(false)
	
	local iconTex = cButton:CreateTexture(cButton:GetName() .. "buttonTex", "BORDER")

	if bName == "ARL_Rep_LKCB" then
		iconTex:SetTexture("Interface\\Addons\\AckisRecipeList\\img\\" .. bTex)
	else
		iconTex:SetTexture('Interface/Glues/Common/' .. bTex)
	end
	iconTex:SetWidth(100)
	iconTex:SetHeight(46)
	iconTex:SetAllPoints(cButton)

	local pushedTexture = cButton:CreateTexture(cButton:GetName() .. "pTex", "ARTWORK")
	pushedTexture:SetTexture('Interface/Buttons/UI-Quickslot-Depress')
	pushedTexture:SetAllPoints(cButton)
	cButton:SetPushedTexture(pushedTexture)

	local highlightTexture = cButton:CreateTexture()
	highlightTexture:SetTexture('Interface/Buttons/ButtonHilight-Square')
	highlightTexture:SetAllPoints(cButton)
	highlightTexture:SetBlendMode('ADD')
	cButton:SetHighlightTexture(highlightTexture)

	local checkedTexture = cButton:CreateTexture()
	checkedTexture:SetTexture('Interface/Buttons/CheckButtonHilight')
	checkedTexture:SetAllPoints(cButton)
	checkedTexture:SetBlendMode('ADD')
	cButton:SetCheckedTexture(checkedTexture)

	-- And throw up a tooltip
	if bName == "ARL_Rep_ClassicCB" then
		SetTooltipScripts(cButton, L["FILTERING_OLDWORLD_DESC"])
	elseif bName == "ARL_Rep_BCCB" then
		SetTooltipScripts(cButton, L["FILTERING_BC_DESC"])
	else
		SetTooltipScripts(cButton, L["FILTERING_WOTLK_DESC"])
	end
	return cButton
end

-------------------------------------------------------------------------------
-- Create MainPanel.scrollframe and set its scripts.
-------------------------------------------------------------------------------
MainPanel.scroll_frame = CreateFrame("ScrollFrame", "ARL_MainPanelScrollFrame", MainPanel, "FauxScrollFrameTemplate")
MainPanel.scroll_frame:SetHeight(322)
MainPanel.scroll_frame:SetWidth(243)
MainPanel.scroll_frame:SetPoint("TOPLEFT", MainPanel, "TOPLEFT", 20, -97)
MainPanel.scroll_frame:SetScript("OnVerticalScroll",
				 function(self, arg1)
					 self.scrolling = true
					 FauxScrollFrame_OnVerticalScroll(self, arg1, 16, self.Update)
					 self.scrolling = nil
				 end)

MainPanel.scroll_frame.entries = {}
MainPanel.scroll_frame.state_buttons = {}
MainPanel.scroll_frame.recipe_buttons = {}

do
	local highlight = CreateFrame("Frame", nil, UIParent)
	highlight:SetFrameStrata("TOOLTIP")
	highlight:Hide()

	highlight._texture = highlight:CreateTexture(nil, "OVERLAY")
	highlight._texture:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	highlight._texture:SetBlendMode("ADD")
	highlight._texture:SetAllPoints(highlight)

	local function Button_OnEnter(self)
		GenerateTooltipContent(self, MainPanel.scroll_frame.entries[self.string_index].recipe_id)
	end

	local function Button_OnLeave()
		QTip:Release(arlTooltip)
		arlSpellTooltip:Hide()
	end

	local function Bar_OnEnter(self)
		highlight:SetParent(self)
		highlight:SetAllPoints(self)
		highlight:Show()
		GenerateTooltipContent(self, MainPanel.scroll_frame.entries[self.string_index].recipe_id)
	end

	local function Bar_OnLeave()
		highlight:Hide()
		highlight:ClearAllPoints()
		highlight:SetParent(nil)
		QTip:Release(arlTooltip)
		arlSpellTooltip:Hide()
	end

	function MainPanel.scroll_frame:Update(expand_acquires, refresh)
		local sorted_recipes = addon.sorted_recipes
		local recipe_list = addon.recipe_list
		local exclusions = addon.db.profile.exclusionlist
		local sort_type = addon.db.profile.sorting
		local skill_sort = (sort_type == "SkillAsc" or sort_type == "SkillDesc")
		local insert_index = 1

		-- If not refreshing an existing list and not scrolling up/down, wipe and re-initialize the entries.
		if not refresh and not self.scrolling then
			for i = 1, #self.entries do
				ReleaseTable(self.entries[i])
			end
			twipe(self.entries)

			for i = 1, #sorted_recipes do
				local recipe_index = sorted_recipes[i]
				local recipe_entry = recipe_list[recipe_index]

				if recipe_entry["Display"] and recipe_entry["Search"] then
					local recipe_string = recipe_entry["Name"]

					if exclusions[recipe_index] then
						recipe_string = "** " .. recipe_string .. " **"
					end
					local recipe_level = recipe_entry["Level"]

					recipe_string = skill_sort and ("[" .. recipe_level .. "] - " .. recipe_string) or (recipe_string .. " - [" .. recipe_level .. "]")

					local t = AcquireTable()
					t.text = ColourSkillLevel(recipe_entry, Player:HasProperRepLevel(recipe_index), recipe_string)

					t.recipe_id = recipe_index
					t.is_header = true

					if expand_acquires and recipe_entry["Acquire"] then
						-- we have acquire information for this. push the title entry into the strings
						-- and start processing the acquires
						t.is_expanded = true
						tinsert(self.entries, insert_index, t)
						insert_index = self:ExpandEntry(insert_index)
					else
						t.is_expanded = false
						tinsert(self.entries, insert_index, t)
						insert_index = insert_index + 1
					end
				end
			end
		end

		-- Reset the current buttons/lines
		for i = 1, NUM_RECIPE_LINES do
			local recipe = self.recipe_buttons[i]
			local state = self.state_buttons[i]

			recipe.string_index = 0
			recipe:SetText("")
			recipe:SetScript("OnEnter", nil)
			recipe:SetScript("OnLeave", nil)

			state.string_index = 0
			state:Hide()
			state:SetScript("OnEnter", nil)
			state:SetScript("OnLeave", nil)
		end
		local num_entries = #self.entries
		local display_lines = NUM_RECIPE_LINES

		if num_entries < display_lines then
			display_lines = num_entries / 2
		end
		FauxScrollFrame_Update(self, num_entries, display_lines, 16)
		addon:ClosePopups()

		if num_entries > 0 then
			ARL_ExpandButton:SetNormalFontObject("GameFontNormalSmall")
			ARL_ExpandButton:Enable()

			-- Populate the buttons with new values
			local button_index = 1
			local string_index = button_index + FauxScrollFrame_GetOffset(self)
			local stayInLoop = true

			while stayInLoop do
				local cur_state = self.state_buttons[button_index]
				local cur_entry = self.entries[string_index]

				if cur_entry.is_header then
					cur_state:Show()

					if cur_entry.is_expanded then
						cur_state:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
						cur_state:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
						cur_state:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
						cur_state:SetDisabledTexture("Interface\\Buttons\\UI-MinusButton-Disabled")
					else
						cur_state:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
						cur_state:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
						cur_state:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
						cur_state:SetDisabledTexture("Interface\\Buttons\\UI-PlusButton-Disabled")
					end
					cur_state.string_index = string_index
					cur_state:SetScript("OnEnter", Button_OnEnter)
					cur_state:SetScript("OnLeave", Button_OnLeave)
				else
					cur_state:Hide()
				end
				local cur_recipe = self.recipe_buttons[button_index]

				cur_recipe.string_index = string_index
				cur_recipe:SetText(cur_entry.text)
				cur_recipe:SetScript("OnEnter", Bar_OnEnter)
				cur_recipe:SetScript("OnLeave", Bar_OnLeave)

				button_index = button_index + 1
				string_index = string_index + 1

				if (button_index > NUM_RECIPE_LINES) or (string_index > num_entries) then
					stayInLoop = false
				end
			end
		else
			-- disable expand button, it's useless here and would spam the same error again
			ARL_ExpandButton:SetNormalFontObject("GameFontDisableSmall")
			ARL_ExpandButton:Disable()

			local showpopup = false

			if not addon.db.profile.hidepopup then
				showpopup = true
			end

			-- If we haven't run this before we'll show pop-ups for the first time.
			if addon.db.profile.addonversion ~= addon.version then
				addon.db.profile.addonversion = addon.version
				showpopup = true
			end

			if Player.recipes_total == 0 then
				if showpopup then
					StaticPopup_Show("ARL_NOTSCANNED")
				end
			elseif Player.recipes_known == Player.recipes_total then
				if showpopup then
					StaticPopup_Show("ARL_ALLKNOWN")
				end
			elseif (Player.recipes_total_filtered - Player.recipes_known_filtered) == 0 then
				if showpopup then
					StaticPopup_Show("ARL_ALLFILTERED")
				end
			elseif Player.excluded_recipes_unknown ~= 0 then
				if showpopup then
					StaticPopup_Show("ARL_ALLEXCLUDED")
				end
			elseif ARL_SearchText:GetText() ~= "" then
				StaticPopup_Show("ARL_SEARCHFILTERED")
			else
				addon:Print(L["NO_DISPLAY"])
				addon:Print("DEBUG: recipes_total check for 0")
				addon:Print("DEBUG: recipes_total: " .. Player.recipes_total)
				addon:Print("DEBUG: recipes_total check for equal to recipes_total")
				addon:Print("DEBUG: recipes_known: " .. Player.recipes_known)
				addon:Print("DEBUG: recipes_total: " .. Player.recipes_total)
				addon:Print("DEBUG: recipes_total_filtered - recipes_known_filtered = 0")
				addon:Print("DEBUG: recipes_total_filtered: " .. Player.recipes_total_filtered)
				addon:Print("DEBUG: recipes_known_filtered: " .. Player.recipes_known_filtered)
				addon:Print("DEBUG: excluded_recipes_unknown ~= 0")
				addon:Print("DEBUG: excluded_recipes_unknown: " .. Player.excluded_recipes_unknown)
			end
		end
	end
	local faction_strings

	local function CheckDisplayFaction(faction)
		if addon.db.profile.filters.general.faction then
			return true
		end
		return (not faction or faction == BFAC[Player["Faction"]] or faction == FACTION_NEUTRAL)
	end

	function MainPanel.scroll_frame:ExpandEntry(entry_index)
		local obtain_filters = addon.db.profile.filters.obtain
		local recipe_id = self.entries[entry_index].recipe_id
		local pad = "  "

		-- entry_index is the position in self.entries that we want
		-- to expand. Since we are expanding the current entry, the return
		-- value should be the index of the next button after the expansion
		-- occurs
		entry_index = entry_index + 1

		for k, v in pairs(addon.recipe_list[recipe_id]["Acquire"]) do
			-- Initialize the first line here, since every type below will have one.
			local acquire_type = v["Type"]
			local t = AcquireTable()
			t.recipe_id = recipe_id
			t.is_expanded = true

			if acquire_type == A_TRAINER and obtain_filters.trainer then
				local trainer = addon.trainer_list[v["ID"]]

				if CheckDisplayFaction(trainer["Faction"]) then
					local nStr = ""

					if trainer["Faction"] == FACTION_HORDE then
						nStr = addon:Horde(trainer["Name"])
					elseif trainer["Faction"] == FACTION_ALLIANCE then
						nStr = addon:Alliance(trainer["Name"])
					else
						nStr = addon:Neutral(trainer["Name"])
					end
					t.text = pad .. addon:Trainer(L["Trainer"] .. " : ") .. nStr

					tinsert(self.entries, entry_index, t)
					entry_index = entry_index + 1

					local cStr = ""

					if trainer["Coordx"] ~= 0 and trainer["Coordy"] ~= 0 then
						cStr = addon:Coords("(" .. trainer["Coordx"] .. ", " .. trainer["Coordy"] .. ")")
					end
					t = AcquireTable()
					t.recipe_id = recipe_id
					t.is_expanded = true
					t.text = pad .. pad .. trainer["Location"] .. " " .. cStr

					tinsert(self.entries, entry_index, t)
					entry_index = entry_index + 1
				end
				-- Right now PVP obtained items are located on vendors so they have the vendor and pvp flag.
				-- We need to display the vendor in the drop down if we want to see vendors or if we want to see PVP
				-- This allows us to select PVP only and to see just the PVP recipes
			elseif acquire_type == A_VENDOR and (obtain_filters.vendor or obtain_filters.pvp) then
				local vendor = addon.vendor_list[v["ID"]]

				if CheckDisplayFaction(vendor["Faction"]) then
					local nStr = ""

					if vendor["Faction"] == FACTION_HORDE then
						nStr = addon:Horde(vendor["Name"])
					elseif vendor["Faction"] == FACTION_ALLIANCE then
						nStr = addon:Alliance(vendor["Name"])
					else
						nStr = addon:Neutral(vendor["Name"])
					end
					t.text = pad .. addon:Vendor(L["Vendor"] .. " : ") .. nStr

					tinsert(self.entries, entry_index, t)
					entry_index = entry_index + 1

					local cStr = ""

					if vendor["Coordx"] ~= 0 and vendor["Coordy"] ~= 0 then
						cStr = addon:Coords("(" .. vendor["Coordx"] .. ", " .. vendor["Coordy"] .. ")")
					end
					t = AcquireTable()
					t.recipe_id = recipe_id
					t.is_expanded = true
					t.text = pad .. pad .. vendor["Location"] .. " " .. cStr

					tinsert(self.entries, entry_index, t)
					entry_index = entry_index + 1
				end
				-- Mobs can be in instances, raids, or specific mob related drops.
			elseif acquire_type == A_MOB and (obtain_filters.mobdrop or obtain_filters.instance or obtain_filters.raid) then
				local mob = addon.mob_list[v["ID"]]
				t.text = pad .. addon:MobDrop(L["Mob Drop"] .. " : ") .. addon:Red(mob["Name"])

				tinsert(self.entries, entry_index, t)
				entry_index = entry_index + 1

				local cStr = ""

				if mob["Coordx"] ~= 0 and mob["Coordy"] ~= 0 then
					cStr = addon:Coords("(" .. mob["Coordx"] .. ", " .. mob["Coordy"] .. ")")
				end
				t = AcquireTable()
				t.recipe_id = recipe_id
				t.is_expanded = true
				t.text = pad .. pad .. mob["Location"] .. " " .. cStr

				tinsert(self.entries, entry_index, t)
				entry_index = entry_index + 1
			elseif acquire_type == A_QUEST and obtain_filters.quest then
				local quest = addon.quest_list[v["ID"]]

				if CheckDisplayFaction(quest["Faction"]) then
					local nStr = ""

					if quest["Faction"] == FACTION_HORDE then
						nStr = addon:Horde(quest["Name"])
					elseif quest["Faction"] == FACTION_ALLIANCE then
						nStr = addon:Alliance(quest["Name"])
					else
						nStr = addon:Neutral(quest["Name"])
					end
					t.text = pad .. addon:Quest(L["Quest"] .. " : ") .. nStr

					tinsert(self.entries, entry_index, t)
					entry_index = entry_index + 1

					local cStr = ""

					if quest["Coordx"] ~= 0 and quest["Coordy"] ~= 0 then
						cStr = addon:Coords("(" .. quest["Coordx"] .. ", " .. quest["Coordy"] .. ")")
					end
					t = AcquireTable()
					t.recipe_id = recipe_id
					t.is_expanded = true
					t.text = pad .. pad .. quest["Location"] .. " " .. cStr

					tinsert(self.entries, entry_index, t)
					entry_index = entry_index + 1
				end
			elseif acquire_type == A_SEASONAL and obtain_filters.seasonal then
				t.text = pad .. addon:Season(SEASONAL_CATEGORY .. " : " .. addon.seasonal_list[v["ID"]]["Name"])
				tinsert(self.entries, entry_index, t)
				entry_index = entry_index + 1
			elseif acquire_type == A_REPUTATION then -- Need to check if we're displaying the currently id'd rep or not as well
				-- Reputation Obtain
				-- Rep: ID, Faction
				-- RepLevel = 0 (Neutral), 1 (Friendly), 2 (Honored), 3 (Revered), 4 (Exalted)
				-- RepVendor - VendorID
				local rep_vendor = addon.vendor_list[v["RepVendor"]]

				if CheckDisplayFaction(rep_vendor["Faction"]) then
					t.text = pad .. addon:Rep(_G.REPUTATION .. " : ") .. addon.reputation_list[v["ID"]]["Name"]
					tinsert(self.entries, entry_index, t)
					entry_index = entry_index + 1

					if not faction_strings then
						faction_strings = {
							[0] = addon:Neutral(FACTION_NEUTRAL .. " : "),
							[1] = addon:Friendly(BFAC["Friendly"] .. " : "),
							[2] = addon:Honored(BFAC["Honored"] .. " : "),
							[3] = addon:Revered(BFAC["Revered"] .. " : "),
							[4] = addon:Exalted(BFAC["Exalted"] .. " : ")
						}
					end
					local nStr = ""

					if rep_vendor["Faction"] == FACTION_HORDE then
						nStr = addon:Horde(rep_vendor["Name"])
					elseif rep_vendor["Faction"] == FACTION_ALLIANCE then
						nStr = addon:Alliance(rep_vendor["Name"])
					else
						nStr = addon:Neutral(rep_vendor["Name"])
					end
					t = AcquireTable()
					t.recipe_id = recipe_id
					t.is_expanded = true

					t.text = pad .. pad .. faction_strings[v["RepLevel"]] .. nStr 

					tinsert(self.entries, entry_index, t)
					entry_index = entry_index + 1

					local cStr = ""

					if rep_vendor["Coordx"] ~= 0 and rep_vendor["Coordy"] ~= 0 then
						cStr = addon:Coords("(" .. rep_vendor["Coordx"] .. ", " .. rep_vendor["Coordy"] .. ")")
					end
					t = AcquireTable()
					t.recipe_id = recipe_id
					t.is_expanded = true
					t.text = pad .. pad .. pad .. rep_vendor["Location"] .. " " .. cStr

					tinsert(self.entries, entry_index, t)
					entry_index = entry_index + 1
				end
			elseif acquire_type == A_WORLD_DROP and obtain_filters.worlddrop then
				t.text = pad .. addon:RarityColor(v["ID"] + 1, L["World Drop"])
				tinsert(self.entries, entry_index, t)
				entry_index = entry_index + 1
			elseif acquire_type == A_CUSTOM then
				t.text = pad .. addon:Normal(addon.custom_list[v["ID"]]["Name"])
				tinsert(self.entries, entry_index, t)
				entry_index = entry_index + 1
			elseif acquire_type == A_PVP and obtain_filters.pvp then
				local vendor = addon.vendor_list[v["ID"]]

				if CheckDisplayFaction(vendor["Faction"]) then
					local cStr = ""

					if vendor["Coordx"] ~= 0 and vendor["Coordy"] ~= 0 then
						cStr = addon:Coords("(" .. vendor["Coordx"] .. ", " .. vendor["Coordy"] .. ")")
					end
					local nStr = ""

					if vendor["Faction"] == FACTION_HORDE then
						nStr = addon:Horde(vendor["Name"])
					elseif vendor["Faction"] == FACTION_ALLIANCE then
						nStr = addon:Alliance(vendor["Name"])
					else
						nStr = addon:Neutral(vendor["Name"])
					end
					t.text = pad .. addon:Vendor(L["Vendor"] .. " : ") .. nStr

					tinsert(self.entries, entry_index, t)
					entry_index = entry_index + 1

					t = AcquireTable()
					t.recipe_id = recipe_id
					t.is_expanded = true
					t.text = pad .. pad .. vendor["Location"] .. " " .. cStr

					tinsert(self.entries, entry_index, t)
					entry_index = entry_index + 1
				end
				--@alpha@
			elseif acquire_type > A_MAX then
				t.text = "Unhandled Acquire Case - Type: " .. acquire_type
				tinsert(self.entries, entry_index, t)
				entry_index = entry_index + 1
				--@end-alpha@
			end
		end
		return entry_index
	end
end	-- do

-------------------------------------------------------------------------------
-- Create MainPanel.progress_bar and set its scripts
-------------------------------------------------------------------------------
do
	-- Default values for the progressbar
	local pbMin = 0
	local pbMax = 100
	local pbCur = 50

	MainPanel.progress_bar = CreateFrame("StatusBar", nil, MainPanel)
	MainPanel.progress_bar:SetWidth(195)
	MainPanel.progress_bar:SetHeight(14)

	MainPanel.progress_bar:ClearAllPoints()
	MainPanel.progress_bar:SetPoint("BOTTOMLEFT", MainPanel, 17, 7)

	MainPanel.progress_bar:SetStatusBarTexture("Interface\\Addons\\AckisRecipeList\\img\\progressbar")
	MainPanel.progress_bar:SetOrientation("HORIZONTAL")
	MainPanel.progress_bar:SetStatusBarColor(0.25, 0.25, 0.75)
	MainPanel.progress_bar:SetMinMaxValues(pbMin, pbMax)
	MainPanel.progress_bar:SetValue(pbCur)

	MainPanel.progress_bar.text = MainPanel.progress_bar:CreateFontString(nil, "ARTWORK")
	MainPanel.progress_bar.text:SetWidth(195)
	MainPanel.progress_bar.text:SetHeight(14)
	MainPanel.progress_bar.text:SetFontObject("GameFontHighlightSmall")

	MainPanel.progress_bar.text:ClearAllPoints()
	MainPanel.progress_bar.text:SetPoint("CENTER", MainPanel.progress_bar, "CENTER", 0, 0)
	MainPanel.progress_bar.text:SetJustifyH("CENTER")
	MainPanel.progress_bar.text:SetFormattedText("%d / %d - %d%%", pbCur, pbMax, floor(pbCur / pbMax * 100))
end	-- do

function MainPanel.progress_bar:Update()
	local pbCur, pbMax
	local settings = addon.db.profile

	if settings.includefiltered then
		pbCur = Player.recipes_known
		pbMax = Player.recipes_total
	else
		-- We're removing filtered recipes from the final count
		pbCur = Player.recipes_known_filtered
		pbMax = Player.recipes_total_filtered
	end

	if not settings.includeexcluded and not settings.ignoreexclusionlist then
		pbCur = pbCur - Player.excluded_recipes_unknown
		pbMax = pbMax - Player.excluded_recipes_known
	end
	self:SetMinMaxValues(0, pbMax)
	self:SetValue(pbCur)

	if (floor(pbCur / pbMax * 100) < 101) and pbCur >= 0 and pbMax >= 0 then
		self.text:SetFormattedText("%d / %d - %d%%", pbCur, pbMax, floor(pbCur / pbMax * 100))
	else
		self.text:SetFormattedText("0 / 0 - %s", L["NOT_YET_SCANNED"])
	end
end

-------------------------------------------------------------------------------
-- Create the close button, and set its scripts.
-------------------------------------------------------------------------------
MainPanel.close_button = GenericCreateButton(nil, MainPanel, 22, 69, "GameFontNormalSmall", "GameFontHighlightSmall", L["Close"], "CENTER", L["CLOSE_DESC"], 1)
MainPanel.close_button:SetPoint("BOTTOMRIGHT", MainPanel, "BOTTOMRIGHT", -4, 3)

MainPanel.close_button:SetScript("OnClick",
				 function(self, button, down)
					 MainPanel:Hide()
				 end)

-------------------------------------------------------------------------------
-- Map waypoint code.
-------------------------------------------------------------------------------
do
	local function LoadZones(c, y, ...)
		-- Fill up the list for normal lookup
		for i = 1, select('#', ...),1 do
			c[i] = select(i,...)
		end
		-- Reverse lookup to make work easier later on
		for i in pairs(c) do
			y[c[i]] = i
		end
	end

	local C1 = {}
	local C2 = {}
	local C3 = {}
	local C4 = {}
	local c1 = {}
	local c2 = {}
	local c3 = {}
	local c4 = {}

	LoadZones(C1, c1, GetMapZones(1))
	LoadZones(C2, c2, GetMapZones(2))
	LoadZones(C3, c3, GetMapZones(3))
	LoadZones(C4, c4, GetMapZones(4))

	local iconlist = {}

	-- Clears all the icons from the world map and the mini-map
	function addon:ClearMap()
		if TomTom then
			for i in pairs(iconlist) do
				TomTom:RemoveWaypoint(iconlist[i])
			end
			iconlist = twipe(iconlist)
		end

	end

	local function CheckMapDisplay(acquire_entry, flags)
		local maptrainer = addon.db.profile.maptrainer
		local mapquest = addon.db.profile.mapquest
		local mapvendor = addon.db.profile.mapvendor
		local mapmob = addon.db.profile.mapmob
		local player_faction = Player["Faction"]
		local acquire_type = acquire_entry["Type"]
		local acquire_id = acquire_entry["ID"]
		local display = false

		-- Trainers - Display if it's your faction or neutral.
		if maptrainer then
			if acquire_type == A_TRAINER then 
				local trainer = addon.trainer_list[acquire_id]

				display = (trainer["Faction"] == BFAC[player_faction] or trainer["Faction"] == FACTION_NEUTRAL)
			elseif acquire_type == A_CUSTOM and flags[3] then
				return true
			end
			-- Vendors - Display if it's your faction or neutral
		elseif mapvendor then
			if acquire_type == A_VENDOR then
				local vendor = addon.vendor_list[acquire_id]

				display = (vendor["Faction"] == BFAC[player_faction] or vendor["Faction"] == FACTION_NEUTRAL)
			elseif acquire_type == A_CUSTOM and flags[4] then
				return true
			end
			-- Always display mobs
		elseif (acquire_type == A_MOB and mapmob) or
			(acquire_type == A_CUSTOM and (flags[5] or flags[6] or flags[10] or flags[11])) then
			return true
		-- Quests
		elseif mapquest then
			if acquire_type == A_QUEST then
				local quest = addon.quest_list[acquire_id]
				display = (quest["Faction"] == BFAC[player_faction] or quest["Faction"] == FACTION_NEUTRAL)
			elseif acquire_type == A_CUSTOM and flags[8] then
				return true
			end
		end
		return display
	end

	local BZ = LibStub("LibBabble-Zone-3.0"):GetLookupTable()

	local INSTANCE_LOCATIONS = {
		[BZ["Ahn'kahet: The Old Kingdom"]] = {
			["loc"] = c1[BZ["Dragonblight"]],
			["c"] = 4,
		},
		[BZ["Auchenai Crypts"]] = {
			["loc"] = c1[BZ["Terokkar Forest"]],
			["c"] = 3,
		},
		[BZ["Azjol-Nerub"]] = {
			["loc"] = c1[BZ["Dragonblight"]],
			["c"] = 4,
		},
		[BZ["Blackrock Depths"]] = {
			["loc"] = c1[BZ["Searing Gorge"]],
			["c"] = 2,
		},
		[BZ["Blackrock Spire"]] = {
			["loc"] = c1[BZ["Searing Gorge"]],
			["c"] = 2,
		},
		[BZ["Blackwing Lair"]] = {
			["loc"] = c1[BZ["Searing Gorge"]],
			["c"] = 2,
		},
		[BZ["Dire Maul"]] = {
			["loc"] = c1[BZ["Feralas"]],
			["c"] = 1,
		},
		[BZ["Drak'Tharon Keep"]] = {
			["loc"] = c1[BZ["Zul'Drak"]],
			["c"] = 4,
		},
		[BZ["Gnomeregan"]] = {
			["loc"] = c1[BZ["Dun Morogh"]],
			["c"] = 2,
		},
		[BZ["Halls of Lightning"]] = {
			["loc"] = c1[BZ["The Storm Peaks"]],
			["c"] = 4,
		},
		[BZ["Halls of Stone"]] = {
			["loc"] = c1[BZ["The Storm Peaks"]],
			["c"] = 4,
		},
		[BZ["Karazhan"]] = {
			["loc"] = c1[BZ["Deadwind Pass"]],
			["c"] = 2,
		},
		[BZ["Magisters' Terrace"]] = {
			["loc"] = c1[BZ["Isle of Quel'Danas"]],
			["c"] = 3,
		},
		[BZ["Mana-Tombs"]] = {
			["loc"] = c1[BZ["Terokkar Forest"]],
			["c"] = 3,
		},
		[BZ["The Oculus"]] = {
			["loc"] = c1[BZ["Borean Tundra"]],
			["c"] = 4,
		},
		[BZ["Old Hillsbrad Foothills"]] = {
			["loc"] = c1[BZ["Tanaris"]],
			["c"] = 1,
		},
		[BZ["Onyxia's Lair"]] = {
			["loc"] = c1[BZ["Dustwallow Marsh"]],
			["c"] = 1,
		},
		[BZ["Ruins of Ahn'Qiraj"]] = {
			["loc"] = c1[BZ["Tanaris"]],
			["c"] = 1,
		},
		[BZ["Scholomance"]] = {
			["loc"] = c1[BZ["Western Plaguelands"]],
			["c"] = 2,
		},
		[BZ["Sethekk Halls"]] = {
			["loc"] = c1[BZ["Terokkar Forest"]],
			["c"] = 3,
		},
		[BZ["Shadow Labyrinth"]] = {
			["loc"] = c1[BZ["Terokkar Forest"]],
			["c"] = 3,
		},
		[BZ["Stratholme"]] = {
			["loc"] = c1[BZ["Eastern Plaguelands"]],
			["c"] = 2,
		},
		[BZ["Temple of Ahn'Qiraj"]] = {
			["loc"] = c1[BZ["Tanaris"]],
			["c"] = 1,
		},
		[BZ["The Arcatraz"]] = {
			["loc"] = c1[BZ["Netherstorm"]],
			["c"] = 3,
		},
		[BZ["The Black Morass"]] = {
			["loc"] = c1[BZ["Tanaris"]],
			["c"] = 1,
		},
		[BZ["The Botanica"]] = {
			["loc"] = c1[BZ["Netherstorm"]],
			["c"] = 3,
		},
		[BZ["The Deadmines"]] = {
			["loc"] = c1[BZ["Westfall"]],
			["c"] = 2,
		},
		[BZ["The Mechanar"]] = {
			["loc"] = c1[BZ["Netherstorm"]],
			["c"] = 3,
		},
		[BZ["The Nexus"]] = {
			["loc"] = c1[BZ["Borean Tundra"]],
			["c"] = 4,
		},
		[BZ["The Shattered Halls"]] = {
			["loc"] = c1[BZ["Hellfire Peninsula"]],
			["c"] = 3,
		},
		[BZ["The Slave Pens"]] = {
			["loc"] = c1[BZ["Zangarmarsh"]],
			["c"] = 3,
		},
		[BZ["The Steamvault"]] = {
			["loc"] = c1[BZ["Zangarmarsh"]],
			["c"] = 3,
		},
		[BZ["The Temple of Atal'Hakkar"]] = {
			["loc"] = c1[BZ["Swamp of Sorrows"]],
			["c"] = 2,
		},
		[BZ["The Violet Hold"]] = {
			["loc"] = c1[BZ["Dalaran"]],
			["c"] = 4,
		},
		[BZ["Utgarde Keep"]] = {
			["loc"] = c1[BZ["Howling Fjord"]],
			["c"] = 4,
		},
		[BZ["Utgarde Pinnacle"]] = {
			["loc"] = c1[BZ["Howling Fjord"]],
			["c"] = 4,
		},
		[BZ["Zul'Gurub"]] = {
			["loc"] = c1[BZ["Stranglethorn Vale"]],
			["c"] = 2,
		},
	}

	local maplist = {}

	-- Description: Adds mini-map and world map icons with tomtom.
	-- Expected result: Icons are added to the world map and mini-map.
	-- Input: An optional recipe ID
	-- Output: Points are added to the maps
	function addon:SetupMap(single_recipe)
		if not TomTom then
			return
		end

		local worldmap = addon.db.profile.worldmap
		local minimap = addon.db.profile.minimap

		if not (worldmap or minimap) then
			return
		end

		local icontext = "Interface\\AddOns\\AckisRecipeList\\img\\enchant_up"

		-- Get the proper icon to put on the mini-map
		--		for i, k in pairs(SortedProfessions) do
		--			if (k["name"] == Player["Profession"]) then
		--				icontext = "Interface\\AddOns\\AckisRecipeList\\img\\" .. k["texture"] .. "_up"
		--				break
		--			end
		--		end

		twipe(maplist)

		local recipe_list = addon.recipe_list

		-- We're only getting a single recipe, not a bunch
		if single_recipe then
			-- loop through acquire methods, display each
			for k, v in pairs(recipe_list[single_recipe]["Acquire"]) do
				if CheckMapDisplay(v, recipe_list[single_recipe]["Flags"]) then
					maplist[v["ID"]] = v["Type"]
				end
			end
		elseif addon.db.profile.autoscanmap then
			local sorted_recipes = addon.sorted_recipes

			-- Scan through all recipes to display, and add the vendors to a list to get their acquire info
			for i = 1, #sorted_recipes do
				local recipe_index = sorted_recipes[i]

				if recipe_list[recipe_index]["Display"] and recipe_list[recipe_index]["Search"] then
					-- loop through acquire methods, display each
					for k, v in pairs(recipe_list[recipe_index]["Acquire"]) do
						if CheckMapDisplay(v, recipe_list[recipe_index]["Flags"]) then
							maplist[v["ID"]] = v["Type"]
						end
					end
				end
			end
		end

		--		local ARLWorldMap = CreateFrame("Button","ARLWorldMap",WorldMapDetailFrame)
		--		ARLWorldMap:ClearAllPoints()
		--		ARLWorldMap:SetWidth(8)
		--		ARLWorldMap:SetHeight(8)
		--		ARLWorldMap.icon = ARLWorldMap:CreateTexture("ARTWORK") 
		--		ARLWorldMap.icon:SetTexture(icontext)
		--		ARLWorldMap.icon:SetAllPoints()

		--		local ARLMiniMap = CreateFrame("Button","ARLMiniMap",MiniMap)
		--		ARLMiniMap:ClearAllPoints()
		--		ARLMiniMap:SetWidth(8)
		--		ARLMiniMap:SetHeight(8)
		--		ARLMiniMap.icon = ARLMiniMap:CreateTexture("ARTWORK") 
		--		ARLMiniMap.icon:SetTexture(icontext)
		--		ARLMiniMap.icon:SetAllPoints()

		for k, j in pairs(maplist) do
			local loc
			local custom = false

			-- Get the entries location
			if maplist[k] == A_TRAINER then
				loc = addon.trainer_list[k]
			elseif maplist[k] == A_VENDOR then
				loc = addon.vendor_list[k]
			elseif maplist[k] == A_MOB then
				loc = addon.mob_list[k]
			elseif maplist[k] == A_QUEST then
				loc = addon.quest_list[k]
			elseif maplist[k] == A_CUSTOM then
				loc = addon.custom_list[k]
				custom = true
			end

			local name = loc["Name"]
			local x = loc["Coordx"]
			local y = loc["Coordy"]
			local location = loc["Location"]
			local continent, zone

			if not loc then
				--@alpha@
				addon:Print("DEBUG: No continent/zone map match for ID " .. k .. " - loc is nil.")
				--@end-alpha@
			elseif c1[location] then
				continent = 1
				zone = c1[location]
			elseif c2[location] then
				continent = 2
				zone = c2[location]
			elseif c3[location] then
				continent = 3
				zone = c3[location]
			elseif c4[location] then
				continent = 4
				zone = c4[location]
			elseif INSTANCE_LOCATIONS[location] then
				continent = INSTANCE_LOCATIONS[location]["c"]
				zone = INSTANCE_LOCATIONS[location]["loc"]
				name = name .. " (" .. location .. ")"
			else
				--@alpha@
				addon:Print("DEBUG: No continent/zone map match for ID " .. k .. " Location: " .. location)
				--@end-alpha@
			end

			--@alpha@
			if (x < -100) or (x > 100) or (y < -100) or (y > 100) then
				addon:Print("DEBUG: Invalid location coordinates for ID " .. k .. " Location: " .. location)
			end
			--@end-alpha@

			if zone and continent then
				--@alpha@
				if (x == 0) and (y == 0) then
					addon:Print("DEBUG: Location is 0,0 for ID " .. k .. " Location: " .. location)
				end
				--@end-alpha@
				local iconuid = TomTom:AddZWaypoint(continent, zone, x, y, nil, false, minimap, worldmap)

				tinsert(iconlist, iconuid)
			end

		end
	end
end -- do block

-- Description: Converting from hex to rgb (Thanks Maldivia)
local function toRGB(hex)
	local r, g, b = hex:match("(..)(..)(..)")

	return (tonumber(r, 16) / 256), (tonumber(g,16) / 256), (tonumber(b, 16) / 256)
end

local function SetSortName()
	local sort_type = addon.db.profile.sorting

	if sort_type == "Name" then
		ARL_DD_SortText:SetText(L["Sort"] .. ": " .. _G.NAME)
	elseif sort_type == "SkillAsc" then
		ARL_DD_SortText:SetText(L["Sort"] .. ": " .. L["Skill (Asc)"])
	elseif sort_type == "SkillDesc" then
		ARL_DD_SortText:SetText(L["Sort"] .. ": " .. L["Skill (Desc)"])
	elseif sort_type == "Acquisition" then
		ARL_DD_SortText:SetText(L["Sort"] .. ": " .. L["Acquisition"])
	elseif sort_type == "Location" then
		ARL_DD_SortText:SetText(L["Sort"] .. ": " .. L["Location"])
	end

end

local function ARL_DD_Sort_OnClick(button, value)
	CloseDropDownMenus()
	addon.db.profile.sorting = value
	SetSortName()
	ReDisplay()
end

local function ARL_DD_Sort_Initialize()
	local info = UIDropDownMenu_CreateInfo()

	local k = "Name"
	info.text = k
	info.arg1 = info.text
	info.func = ARL_DD_Sort_OnClick
	info.checked = (addon.db.profile.sorting == k)
	UIDropDownMenu_AddButton(info)

	k = "SkillAsc"
	info.text = k
	info.arg1 = info.text
	info.func = ARL_DD_Sort_OnClick
	info.checked = (addon.db.profile.sorting == k)
	UIDropDownMenu_AddButton(info)

	k = "SkillDesc"
	info.text = k
	info.arg1 = info.text
	info.func = ARL_DD_Sort_OnClick
	info.checked = (addon.db.profile.sorting == k)
	UIDropDownMenu_AddButton(info)

	k = "Acquisition"
	info.text = k
	info.arg1 = info.text
	info.func = ARL_DD_Sort_OnClick
	info.checked = (addon.db.profile.sorting == k)
	UIDropDownMenu_AddButton(info)

	k = "Location"
	info.text = k
	info.arg1 = info.text
	info.func = ARL_DD_Sort_OnClick
	info.checked = (addon.db.profile.sorting == k)
	UIDropDownMenu_AddButton(info)

	SetSortName()
end

-------------------------------------------------------------------------------
-- Data used in GenerateClickableTT() and its support functions.
-------------------------------------------------------------------------------
local click_info = {
	anchor = nil,
	change_realm = nil,
	target_realm = nil,
	modified = nil,
	name = nil,
	realm = nil,
}
local clicktip
local GenerateClickableTT	-- Upvalued!

-------------------------------------------------------------------------------
-- Clicktip OnMouseUp scripts.
-------------------------------------------------------------------------------
local function ChangeRealm(cell, arg, button)
	click_info.modified = true
	click_info.realm = nil
	click_info.change_realm = true
	click_info.target_realm = nil
	GenerateClickableTT()
end

local function SelectRealm(cell, arg, button)
	click_info.modified = true

	if click_info.change_realm then
		click_info.target_realm = arg
	end
	click_info.realm = arg
	GenerateClickableTT()
end

local function SelectName(cell, arg, button)
	click_info.modified = true
	click_info.name = arg

	-- Wipe tradeskill information for the selected toon. -Torhal
	if IsAltKeyDown() and button == "LeftButton" then
		local tskl_list = addon.db.global.tradeskill
		tskl_list[click_info.realm][click_info.name] = nil

		-- See if there are any toons left on the realm. If not, nuke it as well.
		local found = false
		for name in pairs(tskl_list[click_info.realm]) do
			found = true
		end
		if not found then 
			tskl_list[click_info.realm] = nil
		end
		local anchor = click_info.anchor
		twipe(click_info)
		click_info.anchor = anchor
		GenerateClickableTT()
		return
	end
	GenerateClickableTT()
end

local function SelectProfession(cell, arg, button)
	local tskl_list = addon.db.global.tradeskill
	click_info.modified = true
	addon:Print(click_info.name .. " - " .. click_info.realm .. ": " .. tskl_list[click_info.realm][click_info.name][arg])
end

-------------------------------------------------------------------------------
-- Creates a list of names/alts/etc in a tooltip which can be clicked.
-------------------------------------------------------------------------------
function GenerateClickableTT(anchor)
	local tskl_list = addon.db.global.tradeskill
	local tip = clicktip
	local y, x
	local prealm = GetRealmName()
	local target_realm = prealm

	if click_info.change_realm then
		target_realm = click_info.target_realm
		click_info.change_realm = nil
	end
	tip:Clear()

	if not click_info.realm then
		local other_realms = nil
		local header = nil
		for realm in pairs(tskl_list) do
			if target_realm and (realm ~= target_realm) then
				other_realms = true
			end

			if not target_realm and (realm ~= prealm) then
				if not header then
					tip:AddHeader(L["Other Realms"])
					tip:AddSeparator()
					header = true
				end
				y, x = tip:AddLine()
				tip:SetCell(y, x, realm)
				tip:SetCellScript(y, x, "OnMouseUp", SelectRealm, realm)
			elseif realm == target_realm then
				tip:AddHeader(realm)
				tip:AddSeparator()

				click_info.realm = realm
				for name in pairs(tskl_list[click_info.realm]) do
					if name ~= UnitName("player") then
						y, x = tip:AddLine()
						tip:SetCell(y, x, name)
						tip:SetCellScript(y, x, "OnMouseUp", SelectName, name)
					end
				end
			end
		end
		if other_realms then
			tip:AddSeparator()
			y, x = tip:AddLine()
			tip:SetCell(y, x, L["Other Realms"])
			tip:SetCellScript(y, x, "OnMouseUp", ChangeRealm)
		end
		tip:AddSeparator()
	elseif not click_info.name then
		local realm_list = tskl_list[click_info.realm]

		if realm_list then
			tip:AddLine(click_info.realm)
			tip:AddSeparator()
			for name in pairs(realm_list) do
				y, x = tip:AddLine()
				tip:SetCell(y, x, name)
				tip:SetCellScript(y, x, "OnMouseUp", SelectName, name)
			end
			tip:AddSeparator()
		end
	else
		tip:AddHeader(click_info.name)
		tip:AddSeparator()
		for prof in pairs(tskl_list[click_info.realm][click_info.name]) do
			y, x = tip:AddLine()
			tip:SetCell(y, x, prof)
			tip:SetCellScript(y, x, "OnMouseUp", SelectProfession, prof)
		end
		tip:AddSeparator()
	end
	if anchor then
		click_info.anchor = anchor
		tip:SetPoint("TOP", anchor, "BOTTOM")
	else
		tip:SetPoint("TOP", click_info.anchor, "BOTTOM")
	end
	tip:Show()
end

-------------------------------------------------------------------------------
-- Initializes runtime elements of MainPanel.
-------------------------------------------------------------------------------
function addon:InitializeFrame()
	-------------------------------------------------------------------------------
	-- Check to see if we're Horde or Alliance, and change the displayed
	-- reputation strings to be faction-correct.
	-------------------------------------------------------------------------------
	local isAlliance = (Player["Faction"] == "Alliance")

	local HonorHold_Thrallmar_FactionText = isAlliance and BFAC["Honor Hold"] or BFAC["Thrallmar"]
	local Kurenai_Maghar_FactionText = isAlliance and BFAC["Kurenai"] or BFAC["The Mag'har"]
	local Vanguard_Expedition_FactionText = isAlliance and BFAC["Alliance Vanguard"] or BFAC["Horde Expedition"]
	local SilverConv_Sunreaver_FactionText = isAlliance and BFAC["The Silver Covenant"] or BFAC["The Sunreavers"]
	local Valiance_Warsong_FactionText = isAlliance and BFAC["Valiance Expedition"] or BFAC["Warsong Offensive"]
	local Frostborn_Taunka_FactionText = isAlliance and BFAC["The Frostborn"] or BFAC["The Taunka"]
	local Explorer_Hand_FactionText = isAlliance and BFAC["Explorers' League"] or BFAC["The Hand of Vengeance"]

	-------------------------------------------------------------------------------
	-- Create the sort-type DropDown.
	-------------------------------------------------------------------------------
	local ARL_DD_Sort = CreateFrame("Frame", "ARL_DD_Sort", MainPanel, "UIDropDownMenuTemplate")
	ARL_DD_Sort:SetPoint("TOPLEFT", MainPanel, "TOPLEFT", 55, -39)
	ARL_DD_Sort:SetHitRectInsets(16, 16, 0, 0)
	SetSortName()
	UIDropDownMenu_SetWidth(ARL_DD_Sort, 105)

	-------------------------------------------------------------------------------
	-- Create the expand button and set its scripts.
	-------------------------------------------------------------------------------
	local ARL_ExpandButton = GenericCreateButton("ARL_ExpandButton", MainPanel, 21, 40, "GameFontNormalSmall", "GameFontHighlightSmall", L["EXPANDALL"], "CENTER",
						     L["EXPANDALL_DESC"], 1)
	ARL_ExpandButton:SetPoint("TOPRIGHT", ARL_DD_Sort, "BOTTOMLEFT", -2, 0)

	ARL_ExpandButton:SetScript("OnClick",
				   function(self, mouse_button, down)
					   local expand_acquires = (self:GetText() == L["EXPANDALL"])

					   if expand_acquires then
						   self:SetText(L["CONTRACTALL"])
						   SetTooltipScripts(self, L["CONTRACTALL_DESC"])
					   else
						   self:SetText(L["EXPANDALL"])
						   SetTooltipScripts(self, L["EXPANDALL_DESC"])
					   end
					   MainPanel.scroll_frame:Update(expand_acquires, false)
				   end)
	ARL_ExpandButton:SetText(L["EXPANDALL"])
	SetTooltipScripts(ARL_ExpandButton, L["EXPANDALL_DESC"])

	-------------------------------------------------------------------------------
	-- The search button, clear button, and search entry box.
	-------------------------------------------------------------------------------
	local SearchRecipes
	do
		local search_params = {
			["ItemID"]	= true,
			["Name"]	= true,
			["Locations"]	= true,
			["Specialty"]	= true,
			["Level"]	= true,
			["Rarity"]	= true,
		}
		-- Scans through the recipe database and toggles the flag on if the item is in the search criteria
		function SearchRecipes(pattern)
			if not pattern then
				return
			end
			pattern = pattern:lower()

			local recipe_list = addon.recipe_list

			for index in pairs(recipe_list) do
				local entry = recipe_list[index]
				entry["Search"] = false

				for field in pairs(search_params) do
					local str = entry[field] and tostring(entry[field]):lower() or nil

					if str and str:find(pattern) then
						entry["Search"] = true
						break
					end
				end
			end
		end
	end	-- do

	local ARL_SearchButton = GenericCreateButton("ARL_SearchButton", MainPanel, 25, 74, "GameFontDisableSmall", "GameFontHighlightSmall", _G.SEARCH, "CENTER",
						     L["SEARCH_DESC"], 1)
	ARL_SearchButton:SetPoint("TOPLEFT", ARL_DD_Sort, "BOTTOMRIGHT", 1, 4)

	ARL_SearchButton:Disable()
	ARL_SearchButton:SetScript("OnClick",
				   function(this)
					   local searchtext = ARL_SearchText:GetText()
					   searchtext = searchtext:trim()

					   if (searchtext ~= "") then
						   ARL_LastSearchedText = searchtext

						   SearchRecipes(searchtext)
						   MainPanel.scroll_frame:Update(false, false)

						   ARL_ExpandButton:SetText(L["EXPANDALL"])
						   SetTooltipScripts(ARL_ExpandButton, L["EXPANDALL_DESC"])

						   ARL_SearchButton:SetNormalFontObject("GameFontDisableSmall")
						   ARL_SearchButton:Disable()
					   end
				   end)

	local ARL_ClearButton = GenericCreateButton("ARL_ClearButton", MainPanel, 28, 28, "GameFontNormalSmall", "GameFontHighlightSmall", "", "CENTER", L["CLEAR_DESC"], 3)
	ARL_ClearButton:SetPoint("RIGHT", ARL_SearchButton, "LEFT", 4, -1)

	ARL_ClearButton:SetScript("OnClick",
				  function()
					  local recipe_list = addon.recipe_list

					  -- Reset the search flags
					  for index in pairs(recipe_list) do
						  recipe_list[index]["Search"] = true
					  end
					  ARL_SearchText:SetText(L["SEARCH_BOX_DESC"])

					  -- Make sure our expand all button is set to expandall
					  ARL_ExpandButton:SetText(L["EXPANDALL"])
					  SetTooltipScripts(ARL_ExpandButton, L["EXPANDALL_DESC"])

					  -- Make sure to clear the focus of the searchbox
					  ARL_SearchText:ClearFocus()

					  -- Disable the search button since we're not searching for anything now
					  ARL_SearchButton:SetNormalFontObject("GameFontDisableSmall")
					  ARL_SearchButton:Disable()

					  -- Make sure to clear text for last search
					  ARL_LastSearchedText = ""

					  MainPanel.scroll_frame:Update(false, false)
				  end)

	ARL_SearchText = CreateFrame("EditBox", "ARL_SearchText", MainPanel, "InputBoxTemplate")
	ARL_SearchText:SetText(L["SEARCH_BOX_DESC"])
	ARL_SearchText:SetScript("OnEnterPressed",
				 function(this)
					 local searchtext = ARL_SearchText:GetText()
					 searchtext = searchtext:trim()
					 if (searchtext ~= "") and (searchtext ~= L["SEARCH_BOX_DESC"]) then
						 ARL_LastSearchedText = searchtext

						 SearchRecipes(searchtext)
						 MainPanel.scroll_frame:Update(false, false)

						 ARL_ExpandButton:SetText(L["EXPANDALL"])
						 SetTooltipScripts(ARL_ExpandButton, L["EXPANDALL_DESC"])

						 ARL_SearchButton:SetNormalFontObject("GameFontDisableSmall")
						 ARL_SearchButton:Disable()
					 end
				 end)
	ARL_SearchText:SetScript("OnEditFocusGained",
				 function(this)
					 if this:GetText() == L["SEARCH_BOX_DESC"] then
						 this:SetText("")
					 end
				 end)
	ARL_SearchText:SetScript("OnEditFocusLost",
				 function(this)
					 if this:GetText() == "" then
						 this:SetText(L["SEARCH_BOX_DESC"])
					 end
				 end)
	ARL_SearchText:SetScript("OnTextChanged",
				 function(this)
					 if (this:GetText() ~= "" and this:GetText() ~= L["SEARCH_BOX_DESC"] and this:GetText() ~= ARL_LastSearchedText) then
						 ARL_SearchButton:SetNormalFontObject("GameFontNormalSmall")
						 ARL_SearchButton:Enable()
					 else
						 ARL_SearchButton:SetNormalFontObject("GameFontDisableSmall")
						 ARL_SearchButton:Disable()
					 end
				 end)
	ARL_SearchText:EnableMouse(true)
	ARL_SearchText:SetAutoFocus(false)
	ARL_SearchText:SetFontObject(ChatFontNormal)
	ARL_SearchText:SetWidth(130)
	ARL_SearchText:SetHeight(12)
	ARL_SearchText:SetPoint("RIGHT", ARL_ClearButton, "LEFT", 3, -1)
	ARL_SearchText:Show()

	-------------------------------------------------------------------------------
	-- Set the scripts for MainPanel.scroll_frame's buttons.
	-------------------------------------------------------------------------------
	do
		local function RecipeItem_OnClick(self, button)
			local clickedIndex = self.string_index

			-- Don't do anything if they've clicked on an empty button
			if not clickedIndex or clickedIndex == 0 then
				return
			end
			local clicked_line = MainPanel.scroll_frame.entries[clickedIndex]
			local traverseIndex = 0

			-- First, check if this is a "modified" click, and react appropriately
			if IsModifierKeyDown() then
				if IsControlKeyDown() and IsShiftKeyDown() then
					addon:SetupMap(clicked_line.recipe_id)
				elseif IsShiftKeyDown() then
					local itemID = addon.recipe_list[clicked_line.recipe_id]["ItemID"]

					if itemID then
						local _, itemLink = GetItemInfo(itemID)

						if itemLink then
							ChatFrameEditBox:Insert(itemLink)
						else
							addon:Print(L["NoItemLink"])
						end
					else
						addon:Print(L["NoItemLink"])
					end
				elseif IsControlKeyDown() then
					ChatFrameEditBox:Insert(addon.recipe_list[clicked_line.recipe_id]["RecipeLink"])
				elseif IsAltKeyDown() then
					-- Code needed here to insert this item into the "Ignore List"
					addon:ToggleExcludeRecipe(clicked_line.recipe_id)
					ReDisplay()
				end
			elseif clicked_line.is_header then
				-- three possibilities here (all with no modifiers)
				-- 1) We clicked on the recipe button on a closed recipe
				-- 2) We clicked on the recipe button of an open recipe
				-- 3) we clicked on the expanded text of an open recipe
				if clicked_line.is_expanded then
					traverseIndex = clickedIndex + 1

					-- get rid of our expanded lines
					while (MainPanel.scroll_frame.entries[traverseIndex] and not MainPanel.scroll_frame.entries[traverseIndex].is_header) do
						ReleaseTable(tremove(MainPanel.scroll_frame.entries, traverseIndex))

						if not MainPanel.scroll_frame.entries[traverseIndex] then
							break
						end
					end
					clicked_line.is_expanded = false
				else
					MainPanel.scroll_frame:ExpandEntry(clickedIndex)
					clicked_line.is_expanded = true
				end
			else
				-- this inherently implies that we're on an expanded recipe
				-- first, back up in the list of buttons until we find our recipe line
				local entries = MainPanel.scroll_frame.entries

				traverseIndex = clickedIndex - 1

				while entries[traverseIndex] and not entries[traverseIndex].is_header do
					traverseIndex = traverseIndex - 1
				end
				entries[traverseIndex].is_expanded = false
				traverseIndex = traverseIndex + 1

				-- now remove the expanded lines until we get to a recipe again
				while entries[traverseIndex] and not entries[traverseIndex].is_header do
					ReleaseTable(tremove(entries, traverseIndex))

					if not entries[traverseIndex] then
						break
					end
				end
			end
			MainPanel.scroll_frame:Update(false, true)
		end

		for i = 1, NUM_RECIPE_LINES do
			local temp_state = GenericCreateButton("ARL_StateButton" .. i, MainPanel.scroll_frame, 16, 16, "GameFontNormalSmall", "GameFontHighlightSmall",
							       "", "LEFT", "", 2)

			local temp_recipe = GenericCreateButton("ARL_RecipeButton" .. i, MainPanel.scroll_frame, 16, 224, "GameFontNormalSmall", "GameFontHighlightSmall",
								"Blort", "LEFT", "", 0)

			if i ~= 1 then
				temp_state:SetPoint("TOPLEFT", MainPanel.scroll_frame.state_buttons[i - 1], "BOTTOMLEFT", 0, 3)
				temp_recipe:SetPoint("TOPLEFT", MainPanel.scroll_frame.recipe_buttons[i - 1], "BOTTOMLEFT", 0, 3)
			else
				temp_state:SetPoint("TOPLEFT", MainPanel, "TOPLEFT", 20, -100)
				temp_recipe:SetPoint("TOPLEFT", MainPanel, "TOPLEFT", 37, -100)
			end
			temp_state:SetScript("OnClick", RecipeItem_OnClick)
			temp_recipe:SetScript("OnClick", RecipeItem_OnClick)

			MainPanel.scroll_frame.state_buttons[i] = temp_state
			MainPanel.scroll_frame.recipe_buttons[i] = temp_recipe
		end
	end	-- do

	-------------------------------------------------------------------------------
	-- Flyaway virtual frames to group buttons/text easily (and make them easy to show/hide)
	-------------------------------------------------------------------------------

	MainPanel.filter_menu.player = CreateFrame("Frame", "ARL_FilterMenu_Player", MainPanel.filter_menu)
	MainPanel.filter_menu.player:SetWidth(FILTERMENU_SMALL)
	MainPanel.filter_menu.player:SetHeight(280)
	MainPanel.filter_menu.player:EnableMouse(true)
	MainPanel.filter_menu.player:EnableKeyboard(true)
	MainPanel.filter_menu.player:SetMovable(false)
	MainPanel.filter_menu.player:SetPoint("TOPLEFT", MainPanel.filter_menu, "TOPLEFT", 17, -16)
	MainPanel.filter_menu.player:Hide()

	local ARL_PlayerTankCB = CreateFrame("CheckButton", "ARL_PlayerTankCB", MainPanel.filter_menu.player, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_PlayerTankCB, MainPanel.filter_menu.player, L["TANKS_DESC"], "tank", 1, 1, 0)
	ARL_PlayerTankCBText:SetText(_G.TANK)

	local ARL_PlayerMeleeCB = CreateFrame("CheckButton", "ARL_PlayerMeleeCB", MainPanel.filter_menu.player, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_PlayerMeleeCB, MainPanel.filter_menu.player, L["MELEE_DPS_DESC"], "melee", 2, 1, 0)
	ARL_PlayerMeleeCBText:SetText(_G.MELEE)

	local ARL_PlayerHealerCB = CreateFrame("CheckButton", "ARL_PlayerHealerCB", MainPanel.filter_menu.player, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_PlayerHealerCB, MainPanel.filter_menu.player, L["HEALERS_DESC"], "healer", 3, 1, 0)
	ARL_PlayerHealerCBText:SetText(_G.HEALER)

	local ARL_PlayerCasterCB = CreateFrame("CheckButton", "ARL_PlayerCasterCB", MainPanel.filter_menu.player, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_PlayerCasterCB, MainPanel.filter_menu.player, L["CASTER_DPS_DESC"], "caster", 4, 1, 0)
	ARL_PlayerCasterCBText:SetText(_G.DAMAGER)

	MainPanel.filter_menu.rep = CreateFrame("Frame", "ARL_FilterMenu_Rep", MainPanel.filter_menu)
	MainPanel.filter_menu.rep:SetWidth(FILTERMENU_SMALL)
	MainPanel.filter_menu.rep:SetHeight(280)
	MainPanel.filter_menu.rep:EnableMouse(true)
	MainPanel.filter_menu.rep:EnableKeyboard(true)
	MainPanel.filter_menu.rep:SetMovable(false)
	MainPanel.filter_menu.rep:SetPoint("TOPLEFT", MainPanel.filter_menu, "TOPLEFT", 17, -16)
	MainPanel.filter_menu.rep:Hide()

	do
		-- Rep Filtering panel switcher
		local function RepFilterSwitch(whichrep)
			-- 1	ARL_Rep_ClassicCB		Classic Rep
			-- 2	ARL_Rep_BCCB			Burning Crusade
			-- 3	ARL_Rep_LKCB			Wrath of the Lich King
			local ShowPanel = false

			if whichrep == 1 then
				if ARL_Rep_ClassicCB:GetChecked() then
					ShowPanel = true
					MainPanel.filter_menu.rep.Classic:Show()
					MainPanel.filter_menu.rep.BC:Hide()
					MainPanel.filter_menu.rep.LK:Hide()
					ARL_Rep_BCCB:SetChecked(false)
					ARL_Rep_LKCB:SetChecked(false)
				else
					ShowPanel = false
				end
			elseif whichrep == 2 then
				if ARL_Rep_BCCB:GetChecked() then
					ShowPanel = true
					MainPanel.filter_menu.rep.Classic:Hide()
					MainPanel.filter_menu.rep.BC:Show()
					MainPanel.filter_menu.rep.LK:Hide()
					ARL_Rep_ClassicCB:SetChecked(false)
					ARL_Rep_LKCB:SetChecked(false)
				else
					ShowPanel = false
				end
			else -- whichrep == 3 (WotLK)
				if ARL_Rep_LKCB:GetChecked() then
					ShowPanel = true
					MainPanel.filter_menu.rep.Classic:Hide()
					MainPanel.filter_menu.rep.BC:Hide()
					MainPanel.filter_menu.rep.LK:Show()
					ARL_Rep_ClassicCB:SetChecked(false)
					ARL_Rep_BCCB:SetChecked(false)
				else
					ShowPanel = false
				end
			end
			local texture = MainPanel.filter_menu.texture
			texture:ClearAllPoints()

			if ShowPanel then
				MainPanel.filter_menu:SetWidth(FILTERMENU_DOUBLE_WIDTH)

				texture:SetTexture([[Interface\Addons\AckisRecipeList\img\fly_repcol]])
				texture:SetAllPoints(MainPanel.filter_menu)
				texture:SetTexCoord(0, (FILTERMENU_DOUBLE_WIDTH/512), 0, (FILTERMENU_HEIGHT/512))

				MainPanel.filter_menu.rep.Classic:SetPoint("TOPRIGHT", MainPanel.filter_menu, "TOPRIGHT", -7, -14)
				MainPanel.filter_menu.rep.BC:SetPoint("TOPRIGHT", MainPanel.filter_menu, "TOPRIGHT", -7, -14)
				MainPanel.filter_menu.rep.LK:SetPoint("TOPRIGHT", MainPanel.filter_menu, "TOPRIGHT", -7, -14)
			else
				MainPanel.filter_menu:SetWidth(FILTERMENU_SINGLE_WIDTH)

				texture:SetTexture([[Interface\Addons\AckisRecipeList\img\fly_1col]])
				texture:SetAllPoints(MainPanel.filter_menu)
				texture:SetTexCoord(0, (FILTERMENU_SINGLE_WIDTH/256), 0, (FILTERMENU_HEIGHT/512))

				MainPanel.filter_menu.rep.Classic:Hide()
				MainPanel.filter_menu.rep.BC:Hide()
				MainPanel.filter_menu.rep.LK:Hide()

				ARL_Rep_ClassicCB:SetChecked(false)
				ARL_Rep_BCCB:SetChecked(false)
				ARL_Rep_LKCB:SetChecked(false)
			end
		end

		ARL_Rep_ClassicCB = CreateExpansionButton("ARL_Rep_ClassicCB", "Glues-WoW-Logo")
		ARL_Rep_ClassicCB:SetPoint("TOPLEFT", MainPanel.filter_menu.rep, "TOPLEFT", 0, -10)
		ARL_Rep_ClassicCB:SetScript("OnClick",
					    function()
						    RepFilterSwitch(1)
					    end)

		ARL_Rep_BCCB = CreateExpansionButton("ARL_Rep_BCCB", "GLUES-WOW-BCLOGO")
		ARL_Rep_BCCB:SetPoint("TOPLEFT", MainPanel.filter_menu.rep, "TOPLEFT", 0, -60)
		ARL_Rep_BCCB:SetScript("OnClick",
				      function()
					      RepFilterSwitch(2)
				      end)

		ARL_Rep_LKCB = CreateExpansionButton("ARL_Rep_LKCB", "wotlk_logo")
		ARL_Rep_LKCB:SetPoint("TOPLEFT", MainPanel.filter_menu.rep, "TOPLEFT", 0, -110)
		ARL_Rep_LKCB:SetScript("OnClick",
				      function()
					      RepFilterSwitch(3)
				      end)
	end
	-------------------------------------------------------------------------------
	-- Classic Reputations
	-------------------------------------------------------------------------------
	MainPanel.filter_menu.rep.Classic = CreateFrame("Frame", "ARL_FilterMenu_Rep_Classic", MainPanel.filter_menu.rep)
	MainPanel.filter_menu.rep.Classic:SetWidth(150)
	MainPanel.filter_menu.rep.Classic:SetHeight(280)
	MainPanel.filter_menu.rep.Classic:EnableMouse(true)
	MainPanel.filter_menu.rep.Classic:EnableKeyboard(true)
	MainPanel.filter_menu.rep.Classic:SetMovable(false)
	MainPanel.filter_menu.rep.Classic:SetPoint("TOPRIGHT", MainPanel.filter_menu, "TOPRIGHT", -7, -16)
	MainPanel.filter_menu.rep.Classic:Hide()

	local ARL_Rep_ClassicButton = GenericCreateButton("ARL_Rep_ClassicButton", MainPanel.filter_menu.rep.Classic, 20, 140, "GameFontHighlight", "GameFontHighlightSmall",
							  _G.REPUTATION .. ":", "LEFT", L["REP_TEXT_DESC"], 0)
	ARL_Rep_ClassicButton:SetPoint("TOPLEFT", MainPanel.filter_menu.rep.Classic, "TOPLEFT", -2, -4)

	ARL_Rep_ClassicButton:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
	ARL_Rep_ClassicButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	ARL_Rep_ClassicButton:SetScript("OnClick",
				   function(self,button)
					   local filterdb = addon.db.profile.filters.rep
					   if button == "LeftButton" then
						   -- Set all Reputations to true
						   filterdb.argentdawn = true
						   filterdb.cenarioncircle = true
						   filterdb.thoriumbrotherhood = true
						   filterdb.timbermaw = true
						   filterdb.zandalar = true
					   elseif button == "RightButton" then
						   -- Set all Reputations to false
						   filterdb.argentdawn = false
						   filterdb.cenarioncircle = false
						   filterdb.thoriumbrotherhood = false
						   filterdb.timbermaw = false
						   filterdb.zandalar = false
					   end
					   -- Update the checkboxes with the new value
					   ARL_RepArgentDawnCB:SetChecked(filterdb.argentdawn)
					   ARL_RepCenarionCircleCB:SetChecked(filterdb.cenarioncircle)
					   ARL_RepThoriumCB:SetChecked(filterdb.thoriumbrotherhood)
					   ARL_RepTimbermawCB:SetChecked(filterdb.timbermaw)
					   ARL_RepZandalarCB:SetChecked(filterdb.zandalar)
					   -- Reset our title
					   MainPanel:UpdateTitle()
					   -- Use new filters
					   ReDisplay()
				   end)

	local ARL_RepArgentDawnCB = CreateFrame("CheckButton", "ARL_RepArgentDawnCB", MainPanel.filter_menu.rep.Classic, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepArgentDawnCB, MainPanel.filter_menu.rep.Classic, sformat(L["SPECIFIC_REP_DESC"], BFAC["Argent Dawn"]), "argentdawn", 2, 1, 0)
	ARL_RepArgentDawnCBText:SetText(BFAC["Argent Dawn"])
	ARL_RepArgentDawnCBText:SetFont(narrowFont, 11)

	local ARL_RepCenarionCircleCB = CreateFrame("CheckButton", "ARL_RepCenarionCircleCB", MainPanel.filter_menu.rep.Classic, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepCenarionCircleCB, MainPanel.filter_menu.rep.Classic, sformat(L["SPECIFIC_REP_DESC"], BFAC["Cenarion Circle"]), "cenarioncircle", 3, 1, 0)
	ARL_RepCenarionCircleCBText:SetText(BFAC["Cenarion Circle"])
	ARL_RepCenarionCircleCBText:SetFont(narrowFont, 11)

	local ARL_RepThoriumCB = CreateFrame("CheckButton", "ARL_RepThoriumCB", MainPanel.filter_menu.rep.Classic, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepThoriumCB, MainPanel.filter_menu.rep.Classic, sformat(L["SPECIFIC_REP_DESC"], BFAC["Thorium Brotherhood"]), "thoriumbrotherhood", 4, 1, 0)
	ARL_RepThoriumCBText:SetText(BFAC["Thorium Brotherhood"])
	ARL_RepThoriumCBText:SetFont(narrowFont, 11)

	local ARL_RepTimbermawCB = CreateFrame("CheckButton", "ARL_RepTimbermawCB", MainPanel.filter_menu.rep.Classic, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepTimbermawCB, MainPanel.filter_menu.rep.Classic, sformat(L["SPECIFIC_REP_DESC"], BFAC["Timbermaw Hold"]), "timbermaw", 5, 1, 0)
	ARL_RepTimbermawCBText:SetText(BFAC["Timbermaw Hold"])
	ARL_RepTimbermawCBText:SetFont(narrowFont, 11)

	local ARL_RepZandalarCB = CreateFrame("CheckButton", "ARL_RepZandalarCB", MainPanel.filter_menu.rep.Classic, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepZandalarCB, MainPanel.filter_menu.rep.Classic, sformat(L["SPECIFIC_REP_DESC"], BFAC["Zandalar Tribe"]), "zandalar", 6, 1, 0)
	ARL_RepZandalarCBText:SetText(BFAC["Zandalar Tribe"])
	ARL_RepZandalarCBText:SetFont(narrowFont, 11)

	-------------------------------------------------------------------------------
	-- The Burning Crusade Reputations
	-------------------------------------------------------------------------------
	MainPanel.filter_menu.rep.BC = CreateFrame("Frame", "ARL_FilterMenu_Rep_BC", MainPanel.filter_menu.rep)
	MainPanel.filter_menu.rep.BC:SetWidth(150)
	MainPanel.filter_menu.rep.BC:SetHeight(280)
	MainPanel.filter_menu.rep.BC:EnableMouse(true)
	MainPanel.filter_menu.rep.BC:EnableKeyboard(true)
	MainPanel.filter_menu.rep.BC:SetMovable(false)
	MainPanel.filter_menu.rep.BC:SetPoint("TOPRIGHT", MainPanel.filter_menu, "TOPRIGHT", -7, -16)
	MainPanel.filter_menu.rep.BC:Hide()

	local ARL_Rep_BCButton = GenericCreateButton("ARL_Rep_ClassicButton", MainPanel.filter_menu.rep.BC, 20, 140, "GameFontHighlight", "GameFontHighlightSmall",
						     _G.REPUTATION .. ":", "LEFT", L["REP_TEXT_DESC"], 0)
	ARL_Rep_BCButton:SetPoint("TOPLEFT", MainPanel.filter_menu.rep.BC, "TOPLEFT", -2, -4)

	ARL_Rep_BCButton:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
	ARL_Rep_BCButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	ARL_Rep_BCButton:SetScript("OnClick",
				   function(self,button)
					   local filterdb = addon.db.profile.filters.rep
					   if button == "LeftButton" then
						   -- Set all Reputations to true
						   filterdb.aldor = true
						   filterdb.ashtonguedeathsworn = true
						   filterdb.cenarionexpedition = true
						   filterdb.consortium = true
						   filterdb.hellfire = true
						   filterdb.keepersoftime = true
						   filterdb.nagrand = true
						   filterdb.lowercity = true
						   filterdb.scaleofthesands = true
						   filterdb.scryer = true
						   filterdb.shatar = true
						   filterdb.shatteredsun = true
						   filterdb.sporeggar = true
						   filterdb.violeteye = true
					   elseif button == "RightButton" then
						   -- Set all Reputations to false
						   filterdb.aldor = false
						   filterdb.ashtonguedeathsworn = false
						   filterdb.cenarionexpedition = false
						   filterdb.consortium = false
						   filterdb.hellfire = false
						   filterdb.keepersoftime = false
						   filterdb.nagrand = false
						   filterdb.lowercity = false
						   filterdb.scaleofthesands = false
						   filterdb.scryer = false
						   filterdb.shatar = false
						   filterdb.shatteredsun = false
						   filterdb.sporeggar = false
						   filterdb.violeteye = false
					   end
					   -- Update the checkboxes with the new value
					   ARL_RepAldorCB:SetChecked(filterdb.aldor)
					   ARL_RepAshtongueCB:SetChecked(filterdb.ashtonguedeathsworn)
					   ARL_RepCenarionExpeditionCB:SetChecked(filterdb.cenarionexpedition)
					   ARL_RepConsortiumCB:SetChecked(filterdb.consortium)
					   ARL_RepHonorHoldCB:SetChecked(filterdb.hellfire)
					   ARL_RepKeepersOfTimeCB:SetChecked(filterdb.keepersoftime)
					   ARL_RepKurenaiCB:SetChecked(filterdb.nagrand)
					   ARL_RepLowerCityCB:SetChecked(filterdb.lowercity)
					   ARL_RepScaleSandsCB:SetChecked(filterdb.scaleofthesands)
					   ARL_RepScryersCB:SetChecked(filterdb.scryer)
					   ARL_RepShatarCB:SetChecked(filterdb.shatar)
					   ARL_RepShatteredSunCB:SetChecked(filterdb.shatteredsun)
					   ARL_RepSporeggarCB:SetChecked(filterdb.sporeggar)
					   ARL_RepVioletEyeCB:SetChecked(filterdb.violeteye)
					   -- Reset our title
					   MainPanel:UpdateTitle()
					   -- Use new filters
					   ReDisplay()
				   end)

	local ARL_RepAldorCB = CreateFrame("CheckButton", "ARL_RepAldorCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepAldorCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["The Aldor"]), "aldor", 2, 1, 0)
	ARL_RepAldorCBText:SetText(BFAC["The Aldor"])
	ARL_RepAldorCBText:SetFont(narrowFont, 11)

	local ARL_RepAshtongueCB = CreateFrame("CheckButton", "ARL_RepAshtongueCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepAshtongueCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["Ashtongue Deathsworn"]), "ashtonguedeathsworn", 3, 1, 0)
	ARL_RepAshtongueCBText:SetText(BFAC["Ashtongue Deathsworn"])
	ARL_RepAshtongueCBText:SetFont(narrowFont, 11)

	local ARL_RepCenarionExpeditionCB = CreateFrame("CheckButton", "ARL_RepCenarionExpeditionCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepCenarionExpeditionCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["Cenarion Expedition"]), "cenarionexpedition", 4, 1, 0)
	ARL_RepCenarionExpeditionCBText:SetText(BFAC["Cenarion Expedition"])
	ARL_RepCenarionExpeditionCBText:SetFont(narrowFont, 11)

	local ARL_RepConsortiumCB = CreateFrame("CheckButton", "ARL_RepConsortiumCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepConsortiumCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["The Consortium"]), "consortium", 5, 1, 0)
	ARL_RepConsortiumCBText:SetText(BFAC["The Consortium"])
	ARL_RepConsortiumCBText:SetFont(narrowFont, 11)

	local ARL_RepHonorHoldCB = CreateFrame("CheckButton", "ARL_RepHonorHoldCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepHonorHoldCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], HonorHold_Thrallmar_FactionText), "hellfire", 6, 1, 0)
	ARL_RepHonorHoldCBText:SetText(HonorHold_Thrallmar_FactionText)
	ARL_RepHonorHoldCBText:SetFont(narrowFont, 11)

	local ARL_RepKeepersOfTimeCB = CreateFrame("CheckButton", "ARL_RepKeepersOfTimeCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepKeepersOfTimeCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["Keepers of Time"]), "keepersoftime", 7, 1, 0)
	ARL_RepKeepersOfTimeCBText:SetText(BFAC["Keepers of Time"])
	ARL_RepKeepersOfTimeCBText:SetFont(narrowFont, 11)

	local ARL_RepKurenaiCB = CreateFrame("CheckButton", "ARL_RepKurenaiCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepKurenaiCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], Kurenai_Maghar_FactionText), "nagrand", 8, 1, 0)
	ARL_RepKurenaiCBText:SetText(Kurenai_Maghar_FactionText)
	ARL_RepKurenaiCBText:SetFont(narrowFont, 11)

	local ARL_RepLowerCityCB = CreateFrame("CheckButton", "ARL_RepLowerCityCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepLowerCityCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["Lower City"]), "lowercity", 9, 1, 0)
	ARL_RepLowerCityCBText:SetText(BFAC["Lower City"])
	ARL_RepLowerCityCBText:SetFont(narrowFont, 11)

	local ARL_RepScaleSandsCB = CreateFrame("CheckButton", "ARL_RepScaleSandsCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepScaleSandsCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["The Scale of the Sands"]), "scaleofthesands", 10, 1, 0)
	ARL_RepScaleSandsCBText:SetText(BFAC["The Scale of the Sands"])
	ARL_RepScaleSandsCBText:SetFont(narrowFont, 11)

	local ARL_RepScryersCB = CreateFrame("CheckButton", "ARL_RepScryersCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepScryersCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["The Scryers"]), "scryer", 11, 1, 0)
	ARL_RepScryersCBText:SetText(BFAC["The Scryers"])
	ARL_RepScryersCBText:SetFont(narrowFont, 11)

	local ARL_RepShatarCB = CreateFrame("CheckButton", "ARL_RepShatarCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepShatarCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["The Sha'tar"]), "shatar", 12, 1, 0)
	ARL_RepShatarCBText:SetText(BFAC["The Sha'tar"])
	ARL_RepShatarCBText:SetFont(narrowFont, 11)

	local ARL_RepShatteredSunCB = CreateFrame("CheckButton", "ARL_RepShatteredSunCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepShatteredSunCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["Shattered Sun Offensive"]), "shatteredsun", 13, 1, 0)
	ARL_RepShatteredSunCBText:SetText(BFAC["Shattered Sun Offensive"])
	ARL_RepShatteredSunCBText:SetFont(narrowFont, 11)

	local ARL_RepSporeggarCB = CreateFrame("CheckButton", "ARL_RepSporeggarCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepSporeggarCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["Sporeggar"]), "sporeggar", 14, 1, 0)
	ARL_RepSporeggarCBText:SetText(BFAC["Sporeggar"])
	ARL_RepSporeggarCBText:SetFont(narrowFont, 11)

	local ARL_RepVioletEyeCB = CreateFrame("CheckButton", "ARL_RepVioletEyeCB", MainPanel.filter_menu.rep.BC, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepVioletEyeCB, MainPanel.filter_menu.rep.BC, sformat(L["SPECIFIC_REP_DESC"], BFAC["The Violet Eye"]), "violeteye", 15, 1, 0)
	ARL_RepVioletEyeCBText:SetText(BFAC["The Violet Eye"])
	ARL_RepVioletEyeCBText:SetFont(narrowFont, 11)

	-------------------------------------------------------------------------------
	-- Wrath of the Lich King Reputations
	-------------------------------------------------------------------------------
	MainPanel.filter_menu.rep.LK = CreateFrame("Frame", "ARL_FilterMenu_Rep_LK", MainPanel.filter_menu.rep)
	MainPanel.filter_menu.rep.LK:SetWidth(150)
	MainPanel.filter_menu.rep.LK:SetHeight(280)
	MainPanel.filter_menu.rep.LK:EnableMouse(true)
	MainPanel.filter_menu.rep.LK:EnableKeyboard(true)
	MainPanel.filter_menu.rep.LK:SetMovable(false)
	MainPanel.filter_menu.rep.LK:SetPoint("TOPRIGHT", MainPanel.filter_menu, "TOPRIGHT", -7, -16)
	MainPanel.filter_menu.rep.LK:Hide()

	local ARL_Rep_LKButton = GenericCreateButton("ARL_Rep_ClassicButton", MainPanel.filter_menu.rep.LK, 20, 140, "GameFontHighlight", "GameFontHighlightSmall",
						     _G.REPUTATION .. ":", "LEFT", L["REP_TEXT_DESC"], 0)
	ARL_Rep_LKButton:SetPoint("TOPLEFT", MainPanel.filter_menu.rep.LK, "TOPLEFT", -2, -4)

	ARL_Rep_LKButton:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
	ARL_Rep_LKButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	ARL_Rep_LKButton:SetScript("OnClick",
				   function(self,button)
					   local filterdb = addon.db.profile.filters.rep
					   if button == "LeftButton" then
						   -- Set all Reputations to true
						   filterdb.argentcrusade = true
						   filterdb.frenzyheart = true
						   filterdb.ebonblade = true
						   filterdb.kirintor = true
						   filterdb.sonsofhodir = true
						   filterdb.kaluak = true
						   filterdb.oracles = true
						   filterdb.wyrmrest = true
						   filterdb.ashenverdict = true
						   filterdb.wrathcommon1 = true
					   elseif button == "RightButton" then
						   -- Set all Reputations to false
						   filterdb.argentcrusade = false
						   filterdb.frenzyheart = false
						   filterdb.ebonblade = false
						   filterdb.kirintor = false
						   filterdb.sonsofhodir = false
						   filterdb.kaluak = false
						   filterdb.oracles = false
						   filterdb.wyrmrest = false
						   filterdb.ashenverdict = false
						   filterdb.wrathcommon1 = false
					   end
					   -- Update the checkboxes with the new value
					   ARL_RepArgentCrusadeCB:SetChecked(filterdb.argentcrusade)
					   ARL_RepFrenzyheartCB:SetChecked(filterdb.frenzyheart)
					   ARL_RepEbonBladeCB:SetChecked(filterdb.ebonblade)
					   ARL_RepKirinTorCB:SetChecked(filterdb.kirintor)
					   ARL_RepSonsOfHodirCB:SetChecked(filterdb.sonsofhodir)
					   ARL_RepKaluakCB:SetChecked(filterdb.kaluak)
					   ARL_RepOraclesCB:SetChecked(filterdb.oracles)
					   ARL_RepWyrmrestCB:SetChecked(filterdb.wyrmrest)
					   ARL_RepAshenVerdictCB:SetChecked(filterdb.ashenverdict)
					   ARL_WrathCommon1CB:SetChecked(filterdb.wrathcommon1)
					   -- Reset our title
					   MainPanel:UpdateTitle()
					   -- Use new filters
					   ReDisplay()
				   end)

	local ARL_WrathCommon1CB = CreateFrame("CheckButton", "ARL_WrathCommon1CB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WrathCommon1CB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"],  Vanguard_Expedition_FactionText), "wrathcommon1", 2, 1, 0)
	ARL_WrathCommon1CBText:SetText(Vanguard_Expedition_FactionText)
	ARL_WrathCommon1CBText:SetFont(narrowFont, 11)

	local ARL_RepArgentCrusadeCB = CreateFrame("CheckButton", "ARL_RepArgentCrusadeCB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepArgentCrusadeCB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], BFAC["Argent Crusade"]), "argentcrusade", 3, 1, 0)
	ARL_RepArgentCrusadeCBText:SetText(BFAC["Argent Crusade"])
	ARL_RepArgentCrusadeCBText:SetFont(narrowFont, 11)

	local ARL_WrathCommon5CB = CreateFrame("CheckButton", "ARL_WrathCommon5CB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WrathCommon5CB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], Explorer_Hand_FactionText), "wrathcommon5", 4, 1, 0)
	ARL_WrathCommon5CBText:SetText(Explorer_Hand_FactionText)
	ARL_WrathCommon5CBText:SetFont(narrowFont, 11)
	ARL_WrathCommon5CBText:SetText(addon:Grey(Explorer_Hand_FactionText))
	ARL_WrathCommon5CB:Disable()

	local ARL_RepFrenzyheartCB = CreateFrame("CheckButton", "ARL_RepFrenzyheartCB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepFrenzyheartCB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], BFAC["Frenzyheart Tribe"]), "frenzyheart", 5, 1, 0)
	ARL_RepFrenzyheartCBText:SetText(BFAC["Frenzyheart Tribe"])
	ARL_RepFrenzyheartCBText:SetFont(narrowFont, 11)

	local ARL_RepKaluakCB = CreateFrame("CheckButton", "ARL_RepKaluakCB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepKaluakCB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], BFAC["The Kalu'ak"]), "kaluak", 6, 1, 0)
	ARL_RepKaluakCBText:SetText(BFAC["The Kalu'ak"])
	ARL_RepKaluakCBText:SetFont(narrowFont, 11)

	local ARL_RepKirinTorCB = CreateFrame("CheckButton", "ARL_RepKirinTorCB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepKirinTorCB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], BFAC["Kirin Tor"]), "kirintor", 7, 1, 0)
	ARL_RepKirinTorCBText:SetText(BFAC["Kirin Tor"])
	ARL_RepKirinTorCBText:SetFont(narrowFont, 11)

	local ARL_RepEbonBladeCB = CreateFrame("CheckButton", "ARL_RepEbonBladeCB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepEbonBladeCB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], BFAC["Knights of the Ebon Blade"]), "ebonblade", 8, 1, 0)
	ARL_RepEbonBladeCBText:SetText(BFAC["Knights of the Ebon Blade"])
	ARL_RepEbonBladeCBText:SetFont(narrowFont, 11)

	local ARL_RepOraclesCB = CreateFrame("CheckButton", "ARL_RepOraclesCB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepOraclesCB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], BFAC["The Oracles"]), "oracles", 9, 1, 0)
	ARL_RepOraclesCBText:SetText(BFAC["The Oracles"])
	ARL_RepOraclesCBText:SetFont(narrowFont, 11)

	local ARL_WrathCommon2CB = CreateFrame("CheckButton", "ARL_WrathCommon2CB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WrathCommon2CB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], SilverConv_Sunreaver_FactionText), "wrathcommon2", 10, 1, 0)
	ARL_WrathCommon2CBText:SetText(SilverConv_Sunreaver_FactionText)
	ARL_WrathCommon2CBText:SetFont(narrowFont, 11)
	ARL_WrathCommon2CBText:SetText(addon:Grey(SilverConv_Sunreaver_FactionText))
	ARL_WrathCommon2CB:Disable()

	local ARL_RepSonsOfHodirCB = CreateFrame("CheckButton", "ARL_RepSonsOfHodirCB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepSonsOfHodirCB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], BFAC["The Sons of Hodir"]), "sonsofhodir", 11, 1, 0)
	ARL_RepSonsOfHodirCBText:SetText(BFAC["The Sons of Hodir"])
	ARL_RepSonsOfHodirCBText:SetFont(narrowFont, 11)

	local ARL_WrathCommon4CB = CreateFrame("CheckButton", "ARL_WrathCommon4CB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WrathCommon4CB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], Frostborn_Taunka_FactionText), "wrathcommon4", 12, 1, 0)
	ARL_WrathCommon4CBText:SetText(Frostborn_Taunka_FactionText)
	ARL_WrathCommon4CBText:SetFont(narrowFont, 11)
	ARL_WrathCommon4CBText:SetText(addon:Grey(Frostborn_Taunka_FactionText))
	ARL_WrathCommon4CB:Disable()

	local ARL_WrathCommon3CB = CreateFrame("CheckButton", "ARL_WrathCommon3CB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_WrathCommon3CB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], Valiance_Warsong_FactionText), "wrathcommon3", 13, 1, 0)
	ARL_WrathCommon3CBText:SetText(Valiance_Warsong_FactionText)
	ARL_WrathCommon3CBText:SetFont(narrowFont, 11)
	ARL_WrathCommon3CBText:SetText(addon:Grey(Valiance_Warsong_FactionText))
	ARL_WrathCommon3CB:Disable()

	local ARL_RepWyrmrestCB = CreateFrame("CheckButton", "ARL_RepWyrmrestCB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepWyrmrestCB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], BFAC["The Wyrmrest Accord"]), "wyrmrest", 14, 1, 0)
	ARL_RepWyrmrestCBText:SetText(BFAC["The Wyrmrest Accord"])
	ARL_RepWyrmrestCBText:SetFont(narrowFont, 11)

	local ARL_AshenVerdictCB = CreateFrame("CheckButton", "ARL_RepAshenVerdictCB", MainPanel.filter_menu.rep.LK, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_RepAshenVerdictCB, MainPanel.filter_menu.rep.LK, sformat(L["SPECIFIC_REP_DESC"], BFAC["The Ashen Verdict"]), "ashenverdict", 15, 1, 0)
	ARL_RepAshenVerdictCBText:SetText(BFAC["The Ashen Verdict"])
	ARL_RepAshenVerdictCBText:SetFont(narrowFont, 11)

	-------------------------------------------------------------------------------
	-- Miscellaneous Filter Menu
	-------------------------------------------------------------------------------
	MainPanel.filter_menu.misc = CreateFrame("Frame", "ARL_FilterMenu_Misc", MainPanel.filter_menu)
	MainPanel.filter_menu.misc:SetWidth(FILTERMENU_LARGE)
	MainPanel.filter_menu.misc:SetHeight(280)
	MainPanel.filter_menu.misc:EnableMouse(true)
	MainPanel.filter_menu.misc:EnableKeyboard(true)
	MainPanel.filter_menu.misc:SetMovable(false)
	MainPanel.filter_menu.misc:SetPoint("TOPLEFT", MainPanel.filter_menu, "TOPLEFT", 17, -16)
	MainPanel.filter_menu.misc:Hide()

	local ARL_MiscText = MainPanel.filter_menu.misc:CreateFontString("ARL_MiscText", "OVERLAY", "GameFontHighlight")
	ARL_MiscText:SetText(_G.MISCELLANEOUS .. ":")
	ARL_MiscText:SetPoint("TOPLEFT", MainPanel.filter_menu.misc, "TOPLEFT", 5, -8)
	ARL_MiscText:SetHeight(14)
	ARL_MiscText:SetWidth(150)
	ARL_MiscText:SetJustifyH("LEFT")

	local ARL_IgnoreCB = CreateFrame("CheckButton", "ARL_IgnoreCB", MainPanel.filter_menu.misc, "UICheckButtonTemplate")
	InitializeCheckButton(ARL_IgnoreCB, MainPanel.filter_menu.misc, L["DISPLAY_EXCLUSION_DESC"], 0, 2, 1, 1)
	ARL_IgnoreCBText:SetText(L["Display Exclusions"])

	local ARL_MiscAltText = MainPanel.filter_menu.misc:CreateFontString("ARL_MiscAltBtn", "OVERLAY", "GameFontNormal")
	ARL_MiscAltText:SetText(L["Alt-Tradeskills"] .. ":")
	ARL_MiscAltText:SetPoint("TOPLEFT", ARL_IgnoreCB, "BOTTOMLEFT", 4, 0)
	ARL_MiscAltText:SetHeight(14)
	ARL_MiscAltText:SetWidth(95)
	ARL_MiscAltText:SetJustifyH("LEFT")

	local ARL_MiscAltBtn = CreateFrame("Button", "ARL_IgnoreCB", MainPanel.filter_menu.misc)
	ARL_MiscAltBtn:SetPoint("LEFT", ARL_MiscAltText, "RIGHT")
	ARL_MiscAltBtn:SetHeight(22)
	ARL_MiscAltBtn:SetWidth(22)
	ARL_MiscAltBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
	ARL_MiscAltBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
	ARL_MiscAltBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
	ARL_MiscAltBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
	SetTooltipScripts(ARL_MiscAltBtn, L["ALT_TRADESKILL_DESC"], 1)
	ARL_MiscAltBtn:RegisterForClicks("LeftButtonUp")
	ARL_MiscAltBtn:SetScript("OnClick",
				 function(this, button)
					 if clicktip then
						 if not click_info.modified then
							 clicktip = QTip:Release(clicktip)
							 twipe(click_info)
						 else
							 twipe(click_info)
							 GenerateClickableTT(this)
						 end
					 else
						 clicktip = QTip:Acquire("ARL_Clickable", 1, "CENTER")
						 twipe(click_info)
						 if TipTac and TipTac.AddModifiedTip then
							 TipTac:AddModifiedTip(clicktip, true)
						 end
						 GenerateClickableTT(this)
					 end
				 end)
	ARL_MiscAltBtn:SetScript("OnHide",
				 function(this, button)
					 clicktip = QTip:Release(clicktip)
					 twipe(click_info)
				 end)

	-------------------------------------------------------------------------------
	-- Now that everything exists, populate the global filter table
	-------------------------------------------------------------------------------
	local filterdb = addon.db.profile.filters

	FilterValueMap = {
		------------------------------------------------------------------------------------------------
		-- General Options
		------------------------------------------------------------------------------------------------
		["specialty"]		= { cb = MainPanel.filter_menu.general.specialty,		svroot = filterdb.general },
		["skill"]		= { cb = MainPanel.filter_menu.general.skill,			svroot = filterdb.general },
		["faction"]		= { cb = MainPanel.filter_menu.general.faction,			svroot = filterdb.general },
		["known"]		= { cb = MainPanel.filter_menu.general.known,			svroot = filterdb.general },
		["unknown"]		= { cb = MainPanel.filter_menu.general.unknown,			svroot = filterdb.general },
		------------------------------------------------------------------------------------------------
		-- Classes
		------------------------------------------------------------------------------------------------
		["deathknight"]		= { cb = MainPanel.filter_menu.general.deathknight,		svroot = filterdb.classes },
		["druid"]		= { cb = MainPanel.filter_menu.general.druid,			svroot = filterdb.classes },
		["hunter"]		= { cb = MainPanel.filter_menu.general.hunter,			svroot = filterdb.classes },
		["mage"]		= { cb = MainPanel.filter_menu.general.mage,			svroot = filterdb.classes },
		["paladin"]		= { cb = MainPanel.filter_menu.general.paladin,			svroot = filterdb.classes },
		["priest"]		= { cb = MainPanel.filter_menu.general.priest,			svroot = filterdb.classes },
		["rogue"]		= { cb = MainPanel.filter_menu.general.rogue,			svroot = filterdb.classes },
		["shaman"]		= { cb = MainPanel.filter_menu.general.shaman,			svroot = filterdb.classes },
		["warlock"]		= { cb = MainPanel.filter_menu.general.warlock,			svroot = filterdb.classes },
		["warrior"]		= { cb = MainPanel.filter_menu.general.warrior,			svroot = filterdb.classes },
		------------------------------------------------------------------------------------------------
		-- Obtain Options
		------------------------------------------------------------------------------------------------
		["instance"]		= { cb = MainPanel.filter_menu.obtain.instance,			svroot = filterdb.obtain },
		["raid"]		= { cb = MainPanel.filter_menu.obtain.raid,			svroot = filterdb.obtain },
		["quest"]		= { cb = MainPanel.filter_menu.obtain.quest,			svroot = filterdb.obtain },
		["seasonal"]		= { cb = MainPanel.filter_menu.obtain.seasonal,			svroot = filterdb.obtain },
		["trainer"]		= { cb = MainPanel.filter_menu.obtain.trainer,			svroot = filterdb.obtain },
		["vendor"]		= { cb = MainPanel.filter_menu.obtain.vendor,			svroot = filterdb.obtain },
		["pvp"]			= { cb = MainPanel.filter_menu.obtain.pvp,			svroot = filterdb.obtain },
		["discovery"]		= { cb = MainPanel.filter_menu.obtain.discovery,		svroot = filterdb.obtain },
		["worlddrop"]		= { cb = MainPanel.filter_menu.obtain.worlddrop,		svroot = filterdb.obtain },
		["mobdrop"]		= { cb = MainPanel.filter_menu.obtain.mobdrop,			svroot = filterdb.obtain },
		["originalwow"]		= { cb = MainPanel.filter_menu.obtain.originalwow,		svroot = filterdb.obtain },
		["bc"]			= { cb = MainPanel.filter_menu.obtain.bc,			svroot = filterdb.obtain },
		["wrath"]		= { cb = MainPanel.filter_menu.obtain.wrath,			svroot = filterdb.obtain },
		------------------------------------------------------------------------------------------------
		-- Binding Options
		------------------------------------------------------------------------------------------------
		["itemboe"]		= { cb = MainPanel.filter_menu.binding.itemboe,			svroot = filterdb.binding },
		["itembop"]		= { cb = MainPanel.filter_menu.binding.itembop,			svroot = filterdb.binding },
		["recipeboe"]		= { cb = MainPanel.filter_menu.binding.recipeboe,		svroot = filterdb.binding },
		["recipebop"]		= { cb = MainPanel.filter_menu.binding.recipebop,		svroot = filterdb.binding },
		------------------------------------------------------------------------------------------------
		-- Armor Options
		------------------------------------------------------------------------------------------------
		["cloth"]		= { cb = MainPanel.filter_menu.item.cloth,			svroot = filterdb.item.armor },
		["leather"]		= { cb = MainPanel.filter_menu.item.leather,			svroot = filterdb.item.armor },
		["mail"]		= { cb = MainPanel.filter_menu.item.mail,			svroot = filterdb.item.armor },
		["plate"]		= { cb = MainPanel.filter_menu.item.plate,			svroot = filterdb.item.armor },
		["cloak"]		= { cb = MainPanel.filter_menu.item.cloak,			svroot = filterdb.item.armor },
		["necklace"]		= { cb = MainPanel.filter_menu.item.necklace,			svroot = filterdb.item.armor },
		["ring"]		= { cb = MainPanel.filter_menu.item.ring,			svroot = filterdb.item.armor },
		["trinket"]		= { cb = MainPanel.filter_menu.item.trinket,			svroot = filterdb.item.armor },
		["shield"]		= { cb = MainPanel.filter_menu.item.shield,			svroot = filterdb.item.armor },
		------------------------------------------------------------------------------------------------
		-- Weapon Options
		------------------------------------------------------------------------------------------------
		["onehand"]		= { cb = ARL_Weapon1HCB,		svroot = filterdb.item.weapon },
		["twohand"]		= { cb = ARL_Weapon2HCB,		svroot = filterdb.item.weapon },
		["dagger"]		= { cb = ARL_WeaponDaggerCB,		svroot = filterdb.item.weapon },
		["axe"]			= { cb = ARL_WeaponAxeCB,		svroot = filterdb.item.weapon },
		["mace"]		= { cb = ARL_WeaponMaceCB,		svroot = filterdb.item.weapon },
		["sword"]		= { cb = ARL_WeaponSwordCB,		svroot = filterdb.item.weapon },
		["polearm"]		= { cb = ARL_WeaponPolearmCB,		svroot = filterdb.item.weapon },
		["fist"]		= { cb = ARL_WeaponFistCB,		svroot = filterdb.item.weapon },
		["staff"]		= { cb = ARL_WeaponStaffCB,		svroot = nil },
		["wand"]		= { cb = ARL_WeaponWandCB,		svroot = filterdb.item.weapon },
		["thrown"]		= { cb = ARL_WeaponThrownCB,		svroot = filterdb.item.weapon },
		["bow"]			= { cb = ARL_WeaponBowCB,		svroot = nil },
		["crossbow"]		= { cb = ARL_WeaponCrossbowCB,		svroot = nil },
		["ammo"]		= { cb = ARL_WeaponAmmoCB,		svroot = filterdb.item.weapon },
		["gun"]			= { cb = ARL_WeaponGunCB,		svroot = filterdb.item.weapon },
		------------------------------------------------------------------------------------------------
		-- Role Options
		------------------------------------------------------------------------------------------------
		["tank"]		= { cb = ARL_PlayerTankCB,		svroot = filterdb.player },
		["melee"]		= { cb = ARL_PlayerMeleeCB,		svroot = filterdb.player },
		["healer"]		= { cb = ARL_PlayerHealerCB,		svroot = filterdb.player },
		["caster"]		= { cb = ARL_PlayerCasterCB,		svroot = filterdb.player },
		------------------------------------------------------------------------------------------------
		-- Old World Rep Options
		------------------------------------------------------------------------------------------------
		["argentdawn"]		= { cb = ARL_RepArgentDawnCB,		svroot = filterdb.rep },
		["cenarioncircle"]	= { cb = ARL_RepCenarionCircleCB,	svroot = filterdb.rep },
		["thoriumbrotherhood"]	= { cb = ARL_RepThoriumCB,		svroot = filterdb.rep },
		["timbermaw"]		= { cb = ARL_RepTimbermawCB,		svroot = filterdb.rep },
		["zandalar"]		= { cb = ARL_RepZandalarCB,		svroot = filterdb.rep },
		------------------------------------------------------------------------------------------------
		-- BC Rep Options
		------------------------------------------------------------------------------------------------
		["aldor"]		= { cb = ARL_RepAldorCB,		svroot = filterdb.rep },
		["ashtonguedeathsworn"]	= { cb = ARL_RepAshtongueCB,		svroot = filterdb.rep },
		["cenarionexpedition"]	= { cb = ARL_RepCenarionExpeditionCB,	svroot = filterdb.rep },
		["consortium"]		= { cb = ARL_RepConsortiumCB,		svroot = filterdb.rep },
		["hellfire"]		= { cb = ARL_RepHonorHoldCB,		svroot = filterdb.rep },
		["keepersoftime"]	= { cb = ARL_RepKeepersOfTimeCB,	svroot = filterdb.rep },
		["nagrand"]		= { cb = ARL_RepKurenaiCB,		svroot = filterdb.rep },
		["lowercity"]		= { cb = ARL_RepLowerCityCB,		svroot = filterdb.rep },
		["scaleofthesands"]	= { cb = ARL_RepScaleSandsCB,		svroot = filterdb.rep },
		["scryer"]		= { cb = ARL_RepScryersCB,		svroot = filterdb.rep },
		["shatar"]		= { cb = ARL_RepShatarCB,		svroot = filterdb.rep },
		["shatteredsun"]	= { cb = ARL_RepShatteredSunCB,		svroot = filterdb.rep },
		["sporeggar"]		= { cb = ARL_RepSporeggarCB,		svroot = filterdb.rep },
		["violeteye"]		= { cb = ARL_RepVioletEyeCB,		svroot = filterdb.rep },
		------------------------------------------------------------------------------------------------
		-- LK Rep Options
		------------------------------------------------------------------------------------------------
		["argentcrusade"]	= { cb = ARL_RepArgentCrusadeCB,	svroot = filterdb.rep },
		["frenzyheart"]		= { cb = ARL_RepFrenzyheartCB,		svroot = filterdb.rep },
		["ebonblade"]		= { cb = ARL_RepEbonBladeCB,		svroot = filterdb.rep },
		["kirintor"]		= { cb = ARL_RepKirinTorCB,		svroot = filterdb.rep },
		["sonsofhodir"]		= { cb = ARL_RepSonsOfHodirCB,		svroot = filterdb.rep },
		["kaluak"]		= { cb = ARL_RepKaluakCB,		svroot = filterdb.rep },
		["oracles"]		= { cb = ARL_RepOraclesCB,		svroot = filterdb.rep },
		["wyrmrest"]		= { cb = ARL_RepWyrmrestCB,		svroot = filterdb.rep },
		["ashenverdict"]	= { cb = ARL_RepAshenVerdictCB,		svroot = filterdb.rep },
		["wrathcommon1"]	= { cb = ARL_WrathCommon1CB,		svroot = filterdb.rep },
		["wrathcommon2"]	= { cb = ARL_WrathCommon2CB,		svroot = nil },
		["wrathcommon3"]	= { cb = ARL_WrathCommon3CB,		svroot = nil },
		["wrathcommon4"]	= { cb = ARL_WrathCommon4CB,		svroot = nil },
		["wrathcommon5"]	= { cb = ARL_WrathCommon5CB,		svroot = nil },
	}
end

-------------------------------------------------------------------------------
-- Displays the main recipe frame.
-------------------------------------------------------------------------------
function addon:DisplayFrame()
	MainPanel:SetPosition()
	MainPanel:SetProfession()
	MainPanel:SetScale(addon.db.profile.frameopts.uiscale)

	ARL_DD_Sort.initialize = ARL_DD_Sort_Initialize				-- Initialize dropdown

	SortRecipeList()

	MainPanel:UpdateTitle()
	MainPanel.scroll_frame:Update(false, false)
	MainPanel.progress_bar:Update()
	MainPanel:Show()

	-- Set the search text to the last searched text or the global default string for the search box
	-- We should think about either preserving the search everytime arl is open or we clear it completely  - pompachomp
	ARL_SearchText:SetText(ARL_LastSearchedText  or L["SEARCH_BOX_DESC"])
end

-------------------------------------------------------------------------------
-- Under various conditions, the recipe list will have to be re-displayed.
-- This could happen because a filter changes, a new profession is chosen, or
-- a new search occurred. Use this function to do all the dirty work
--
-- Upvalued at the top of the file.
-------------------------------------------------------------------------------
function ReDisplay()
	addon:UpdateFilters()
	Player:MarkExclusions()

	SortRecipeList()
	MainPanel.scroll_frame:Update(false, false)
	MainPanel.progress_bar:Update()

	-- Make sure our expand all button is set to expandall
	ARL_ExpandButton:SetText(L["EXPANDALL"])
	SetTooltipScripts(ARL_ExpandButton, L["EXPANDALL_DESC"])
end

-------------------------------------------------------------------------------
--- Creates a new frame with the contents of a text dump so you can copy and paste
-- Code borrowed from Antiarc (Chatter) with permission
-- @name AckisRecipeList:DisplayTextDump
-- @param RecipeDB The database (array) which you wish read data from.
-- @param profession Which profession are you displaying data for
-- @param text The text to be dumped
-------------------------------------------------------------------------------
do
	local copy_frame = CreateFrame("Frame", "ARLCopyFrame", UIParent)
	copy_frame:SetBackdrop({
				       bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
				       edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
				       tile = true,
				       tileSize = 16,
				       edgeSize = 16,
				       insets = {
					       left = 3,
					       right = 3,
					       top = 5,
					       bottom = 3
				       }
			       })
	copy_frame:SetBackdropColor(0, 0, 0, 1)
	copy_frame:SetWidth(750)
	copy_frame:SetHeight(400)
	copy_frame:SetPoint("CENTER", UIParent, "CENTER")
	copy_frame:SetFrameStrata("DIALOG")

	tinsert(UISpecialFrames, "ARLCopyFrame")

	local scrollArea = CreateFrame("ScrollFrame", "ARLCopyScroll", copy_frame, "UIPanelScrollFrameTemplate")
	scrollArea:SetPoint("TOPLEFT", copy_frame, "TOPLEFT", 8, -30)
	scrollArea:SetPoint("BOTTOMRIGHT", copy_frame, "BOTTOMRIGHT", -30, 8)

	local edit_box = CreateFrame("EditBox", nil, copy_frame)
	edit_box:SetMultiLine(true)
	edit_box:SetMaxLetters(0)
	edit_box:EnableMouse(true)
	edit_box:SetAutoFocus(true)
	edit_box:SetFontObject(ChatFontNormal)
	edit_box:SetWidth(650)
	edit_box:SetHeight(270)
	edit_box:SetScript("OnEscapePressed",
			   function()
				   copy_frame:Hide()
			   end)
	edit_box:HighlightText(0)

	scrollArea:SetScrollChild(edit_box)

	local close = CreateFrame("Button", nil, copy_frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", copy_frame, "TOPRIGHT")

	copy_frame:Hide()

	function addon:DisplayTextDump(RecipeDB, profession, text)
		edit_box:SetText((not RecipeDB and not profession) and text or self:GetTextDump(RecipeDB, profession))
		edit_box:HighlightText(0)
		copy_frame:Show()
	end
end	-- do
