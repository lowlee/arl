--[[

ARLLocals-enUS.lua

enUS localization strings for Ackis Recipe List

File date: @file-date-iso@ 
File revision: @file-revision@ 
Project revision: @project-revision@
Project version: @project-version@

Original translated by: Ackis
Currently maintained by: Ackis

Please make sure you update the ToC file with any translations.

Please update http://www.wowace.com/projects/arl/localization/enUS/ for any translation
additions or changes.

****************************************************************************************
]]--

--[[
Locale schema
	* single and double words are just fine, anything longer should have a tag
	* tag name rules:
		* tags should be ALL_CAPITAL_LETTERS with words separated with _'s
		* descriptions are typically used in tooltips and header in sections
		* short descriptions will end in _DESC
		* long descriptions will end in _LONG
	* don't include the object being described in the name (no _TOGGLE or _TT) since it
	  can be used several times to describe different objects (in theory)
	* group related elements together, either by their location in the GUI/config,
	  or by purpose (Weapon categories, etc)
]]--

local L = LibStub("AceLocale-3.0"):NewLocale("Ackis Recipe List", "enUS", true)

if not L then return end

--@localization(locale="enUS", format="lua_additive_table", handle-unlocalized="english", escape-non-ascii="false")@
