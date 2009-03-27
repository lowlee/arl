--[[

****************************************************************************************

ARLConfig.lua

Ace3 Configuration options for ARL

File date: @file-date-iso@ 
File revision: @file-revision@ 
Project revision: @project-revision@
Project version: @project-version@

****************************************************************************************

]]--

local MODNAME			= "Ackis Recipe List"
local addon				= LibStub("AceAddon-3.0"):GetAddon(MODNAME)

local BFAC				= LibStub("LibBabble-Faction-3.0"):GetLookupTable()
local L					= LibStub("AceLocale-3.0"):GetLocale(MODNAME)

local AceConfig 		= LibStub("AceConfig-3.0")
local AceConfigReg 		= LibStub("AceConfigRegistry-3.0")
local AceConfigDialog 	= LibStub("AceConfigDialog-3.0")

local modularOptions = {}
local nagrandfac = BFAC["Kurenai"] .. "\\" .. BFAC["The Mag'har"]
local hellfirefac = BFAC["Honor Hold"] .. "\\" .. BFAC["Thrallmar"]
local howlingtundra = BFAC["Alliance Vanguard"] .. "\\" .. BFAC["Horde Expedition"]
local addonversion = GetAddOnMetadata("AckisRecipeList", "Version")

-- Description: Function which provides "profiles" options table
-- Expected result: modularOptions extended with Ace3 profiles options
-- Input: None
-- Output: Ace3 config table

local function giveProfiles()

	return LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db)

end

-- Description: Function which provides our "filter" options tabkle
-- Expected result: extend modularOptions with our "filter" options
-- Input: None
-- Output: Ace3 config table

local filterOptions = nil

local function giveFilter()

	if (not filterOptions) then

		filterOptions = {
			order = 1,
			type = "group",
			name = L["Filtering Options"],
			desc = L["FILTERING_OPTIONS_DESC"],
			args = {
				header1 = {
					order	= 1,
					type	= "header",
					name	= L["Filtering Options"],
				},
				desc = {
					order	= 2,
					type	= "description",
					name	= L["FILTERING_OPTIONS_DESC"],
				},
				general = {
					order	= 3,
					type	= "group",
					name	= L["General"],
					desc	= L["FILTERING_GENERAL_DESC"],
					args	= {
						header1 = {
							order	= 1,
							type	= "header",
							name	= L["General Filtering Options"],
						},
						desc = {
							order	= 2,
							type	= "description",
							name	= L["FILTERING_GENERAL_DESC"] .. "\n",
						},
						factions = {
							order	= 3,
							type	= "toggle",
							name	= L["Faction"],
							desc	= L["FACTION_DESC"],
							get		= function() return addon.db.profile.filters.general.faction end,
							set		= function() addon.db.profile.filters.general.faction = not addon.db.profile.filters.general.faction end,
						},
						classes = {
							order	= 4,
							type	= "toggle",
							name	= L["Classes"],
							desc	= L["CLASS_DESC"],
							get		= function() return addon.db.profile.filters.general.class end,
							set		= function() addon.db.profile.filters.general.class = not addon.db.profile.filters.general.class end,
						},
						specialities = {
							order	= 5,
							type	= "toggle",
							name	= L["Specialties"],
							desc	= L["SPECIALTY_DESC"],
							get		= function() return addon.db.profile.filters.general.specialty end,
							set		= function() addon.db.profile.filters.general.specialty = not addon.db.profile.filters.general.specialty end,
						},
						skill = {
							order	= 6,
							type	= "toggle",
							name	= L["Skill"],
							desc	= L["SKILL_DESC"],
							get		= function() return addon.db.profile.filters.general.skill end,
							set		= function() addon.db.profile.filters.general.skill = not addon.db.profile.filters.general.skill end,
						},
						known = {
							order	= 7,
							type	= "toggle",
							name	= L["Known"],
							desc	= L["KNOWN_DESC"],
							get		= function() return addon.db.profile.filters.general.known end,
							set		= function() addon.db.profile.filters.general.known = not addon.db.profile.filters.general.known end,
						},
						unknown = {
							order	= 8,
							type	= "toggle",
							name	= L["Unknown"],
							desc	= L["UNKNOWN_DESC"],
							get		= function() return addon.db.profile.filters.general.unknown end,
							set		= function() addon.db.profile.filters.general.unknown = not addon.db.profile.filters.general.unknown end,
						},
					},
				},
				obtain = {
					order	= 4,
					type	= "group",
					name	= L["Obtain"],
					desc	= L["FILTERING_OBTAIN_DESC"],
					args	= {
						header1 = {
							order	= 1,
							type	= "header",
							name	= L["Obtain Filtering Options"],
						},
						desc = {
							order	= 2,
							type	= "description",
							name	= L["FILTERING_OBTAIN_DESC"] .. "\n",
						},
						instance = {
							order	= 3,
							type	= "toggle",
							name	= L["Instance"],
							desc	= L["INSTANCE_DESC"],
							get		= function() return addon.db.profile.filters.obtain.instance end,
							set		= function() addon.db.profile.filters.obtain.instance = not addon.db.profile.filters.obtain.instance end,
						},
						raid = {
							order	= 4,
							type	= "toggle",
							name	= L["Raid"],
							desc	= L["RAID_DESC"],
							get		= function() return addon.db.profile.filters.obtain.raid end,
							set		= function() addon.db.profile.filters.obtain.raid = not addon.db.profile.filters.obtain.raid end,
						},
						quest = {
							order	= 5,
							type	= "toggle",
							name	= L["Quest"],
							desc	= L["QUEST_DESC"],
							get		= function() return addon.db.profile.filters.obtain.quest end,
							set		= function() addon.db.profile.filters.obtain.quest = not addon.db.profile.filters.obtain.quest end,
						},
						seasonal = {
							order	= 6,
							type	= "toggle",
							name	= L["Seasonal"],
							desc	= L["SEASONAL_DESC"],
							get		= function() return addon.db.profile.filters.obtain.seasonal end,
							set		= function() addon.db.profile.filters.obtain.seasonal = not addon.db.profile.filters.obtain.seasonal end,
						},
						trainer = {
							order	= 7,
							type	= "toggle",
							name	= L["Trainer"],
							desc	= L["TRAINER_DESC"],
							get		= function() return addon.db.profile.filters.obtain.trainer end,
							set		= function() addon.db.profile.filters.obtain.trainer = not addon.db.profile.filters.obtain.trainer end,
						},
						vendor = {
							order	= 8,
							type	= "toggle",
							name	= L["Vendor"],
							desc	= L["VENDOR_DESC"],
							get		= function() return addon.db.profile.filters.obtain.vendor end,
							set		= function() addon.db.profile.filters.obtain.vendor = not addon.db.profile.filters.obtain.vendor end,
						},
						PVP = {
							order	= 9,
							type	= "toggle",
							name	= L["PVP"],
							desc	= L["PVP_DESC"],
							get		= function() return addon.db.profile.filters.obtain.pvp end,
							set		= function() addon.db.profile.filters.obtain.pvp = not addon.db.profile.filters.obtain.pvp end,
						},
						discovery = {
							order	= 10,
							type	= "toggle",
							name	= L["Discovery"],
							desc	= L["DISCOVERY_DESC"],
							get		= function() return addon.db.profile.filters.obtain.discovery end,
							set		= function() addon.db.profile.filters.obtain.discovery = not addon.db.profile.filters.obtain.discovery end,
						},
						worlddrop = {
							order	= 11,
							type	= "toggle",
							name	= L["World Drop"],
							desc	= L["WORLD_DROP_DESC"],
							get		= function() return addon.db.profile.filters.obtain.worlddrop end,
							set		= function() addon.db.profile.filters.obtain.worlddrop = not addon.db.profile.filters.obtain.worlddrop end,
						},
						mobdrop = {
							order	= 12,
							type	= "toggle",
							name	= L["Mob Drop"],
							desc	= L["MOB_DROP_DESC"],
							get		= function() return addon.db.profile.filters.obtain.mobdrop end,
							set		= function() addon.db.profile.filters.obtain.mobdrop = not addon.db.profile.filters.obtain.mobdrop end,
						},
					}
				},
				binding = {
					order	= 5,
					type	= "group",
					name	= L["Binding"],
					desc	= L["FILTERING_BINDING_DESC"],
					args	= {
						header1 = {
							order	= 1,
							type	= "header",
							name	= L["Binding Filtering Options"],
						},
						desc = {
							order	= 2,
							type	= "description",
							name	= L["FILTERING_BINDING_DESC"] .. "\n",
						},
						BOE = {
							order	= 3,
							type	= "toggle",
							name	= L["BOEFilter"],
							desc	= L["BOE_DESC"],
							get		= function() return addon.db.profile.filters.binding.itemboe end,
							set		= function() addon.db.profile.filters.binding.itemboe = not addon.db.profile.filters.binding.itemboe end,
						},
						BOP = {
							order	= 4,
							type	= "toggle",
							name	= L["BOPFilter"],
							desc	= L["BOP_DESC"],
							get		= function() return addon.db.profile.filters.binding.itembop end,
							set		= function() addon.db.profile.filters.binding.itembop = not addon.db.profile.filters.binding.itembop end,
						},
						RecipeBOE = {
							order	= 5,
							type	= "toggle",
							name	= L["RecipeBOEFilter"],
							desc	= L["RECIPE_BOE_DESC"],
							get		= function() return addon.db.profile.filters.binding.recipeboe end,
							set		= function() addon.db.profile.filters.binding.recipeboe = not addon.db.profile.filters.binding.recipeboe end,
						},
						RecipeBOP = {
							order	= 6,
							type	= "toggle",
							name	= L["RecipeBOPFilter"],
							desc	= L["RECIPE_BOP_DESC"],
							get		= function() return addon.db.profile.filters.binding.recipebop end,
							set		= function() addon.db.profile.filters.binding.recipebop = not addon.db.profile.filters.binding.recipebop end,
						},
					},
				},
				item = {
					order	= 6,
					type	= "group",
					name	= L["Item"],
					desc	= L["FILTERING_ITEM_DESC"],
					args	= {
						header1 = {
							order	= 1,
							type	= "header",
							name	= L["Item Filtering Options"],
						},
						desc = {
							order	= 2,
							type	= "description",
							name	= L["FILTERING_ITEM_DESC"] .. "\n",
						},
						Armor = {
							order	= 3,
							type	= "group",
							name	= L["Armor"],
							desc	= L["FILTERING_Armor_DESC"],
							args	= {
								header1 = {
									order	= 1,
									type	= "header",
									name	= L["Armor Filtering Options"],
								},
								desc = {
									order	= 2,
									type	= "description",
									name	= L["FILTERING_Armor_DESC"] .. "\n",
								},
								cloth = {
									order	= 3,
									type	= "toggle",
									name	= L["Cloth"],
									desc	= L["CLOTH_DESC"],
									get		= function() return addon.db.profile.filters.item.armor.cloth end,
									set		= function() addon.db.profile.filters.item.armor.cloth = not addon.db.profile.filters.item.armor.cloth end,
								},
								leather = {
									order	= 4,
									type	= "toggle",
									name	= L["Leather"],
									desc	= L["LEATHER_DESC"],
									get		= function() return addon.db.profile.filters.item.armor.leather end,
									set		= function() addon.db.profile.filters.item.armor.leather = not addon.db.profile.filters.item.armor.leather end,
								},
								mail = {
									order	= 5,
									type	= "toggle",
									name	= L["Mail"],
									desc	= L["MAIL_DESC"],
									get		= function() return addon.db.profile.filters.item.armor.mail end,
									set		= function() addon.db.profile.filters.item.armor.mail = not addon.db.profile.filters.item.armor.mail end,
								},
								plate = {
									order	= 6,
									type	= "toggle",
									name	= L["Plate"],
									desc	= L["PLATE_DESC"],
									get		= function() return addon.db.profile.filters.item.armor.plate end,
									set		= function() addon.db.profile.filters.item.armor.plate = not addon.db.profile.filters.item.armor.plate end,
								},
								spacer1 ={
									order	= 7,
									type	= "header",
									name	= "",
								},

								cloak = {
									order	= 8,
									type	= "toggle",
									name	= L["Cloak"],
									desc	= L["CLOAK_DESC"],
									get		= function() return addon.db.profile.filters.item.armor.cloak end,
									set		= function() addon.db.profile.filters.item.armor.cloak = not addon.db.profile.filters.item.armor.cloak end,
								},
								ring = {
									order	= 9,
									type	= "toggle",
									name	= L["Ring"],
									desc	= L["RING_DESC"],
									get		= function() return addon.db.profile.filters.item.armor.ring end,
									set		= function() addon.db.profile.filters.item.armor.ring = not addon.db.profile.filters.item.armor.ring end,
								},
								trinket = {
									order	= 10,
									type	= "toggle",
									name	= L["Trinket"],
									desc	= L["TRINKET_DESC"],
									get		= function() return addon.db.profile.filters.item.armor.trinket end,
									set		= function() addon.db.profile.filters.item.armor.trinket = not addon.db.profile.filters.item.armor.trinket end,
								},
								necklace = {
									order	= 11,
									type	= "toggle",
									name	= L["Necklace"],
									desc	= L["NECKLACE_DESC"],
									get		= function() return addon.db.profile.filters.item.armor.necklace end,
									set		= function() addon.db.profile.filters.item.armor.necklace = not addon.db.profile.filters.item.armor.necklace end,
								},
								shield = {
									order	= 12,
									type	= "toggle",
									name	= L["Shield"],
									desc	= L["SHIELD_DESC"],
									get		= function() return addon.db.profile.filters.item.armor.shield end,
									set		= function() addon.db.profile.filters.item.armor.shield = not addon.db.profile.filters.item.armor.shield end,
								},
							},
						},
						weapons = {
							order	= 4,
							type	= "group",
							name	= L["Weapon"],
							desc	= L["FILTERING_WEAPONS_DESC"],
							args	= {
								header1 = {
									order	= 1,
									type	= "header",
									name	= L["Weapon Filtering Options"],
								},
								desc =  {
									order	= 2,
									type	= "description",
									name	= L["FILTERING_WEAPONS_DESC"] .. "\n",
								},
								onehand = {
									order	= 3,
									type	= "toggle",
									name	= L["One Hand"],
									desc	= L["ONEHAND_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.onehand end,
									set		= function() addon.db.profile.filters.item.weapon.onehand = not addon.db.profile.filters.item.weapon.onehand end,
								},
								twohand = {
									order	= 4,
									type	= "toggle",
									name	= L["Two Hand"],
									desc	= L["TWOHAND_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.twohand end,
									set		= function() addon.db.profile.filters.item.weapon.twohand = not addon.db.profile.filters.item.weapon.twohand end,
								},
								axe = {
									order	= 5,
									type	= "toggle",
									name	= L["Axe"],
									desc	= L["AXE_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.axe end,
									set		= function() addon.db.profile.filters.item.weapon.axe = not addon.db.profile.filters.item.weapon.axe end,
								},
								sword = {
									order	= 6,
									type	= "toggle",
									name	= L["Sword"],
									desc	= L["SWORD_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.sword end,
									set		= function() addon.db.profile.filters.item.weapon.sword = not addon.db.profile.filters.item.weapon.sword end,
								},
								mace = {
									order	= 7,
									type	= "toggle",
									name	= L["Mace"],
									desc	= L["MACE_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.mace end,
									set		= function() addon.db.profile.filters.item.weapon.mace = not addon.db.profile.filters.item.weapon.mace end,
								},
								polearm = {
									order	= 8,
									type	= "toggle",
									name	= L["Polearm"],
									desc	= L["POLEARM_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.polearm end,
									set		= function() addon.db.profile.filters.item.weapon.polearm = not addon.db.profile.filters.item.weapon.polearm end,
								},
								dagger = {
									order	= 9,
									type	= "toggle",
									name	= L["Dagger"],
									desc	= L["DAGGER_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.dagger end,
									set		= function() addon.db.profile.filters.item.weapon.dagger = not addon.db.profile.filters.item.weapon.dagger end,
								},
								fist = {
									order	= 10,
									type	= "toggle",
									name	= L["Fist"],
									desc	= L["FIST_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.fist end,
									set		= function() addon.db.profile.filters.item.weapon.fist = not addon.db.profile.filters.item.weapon.fist end,
								},
								staff = {
									order	= 11,
									type	= "toggle",
									name	= L["Staff"],
									desc	= L["STAFF_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.staff end,
									set		= function() addon.db.profile.filters.item.weapon.staff = not addon.db.profile.filters.item.weapon.staff end,
									disabled	= true,
								},
								wand = {
									order	= 12,
									type	= "toggle",
									name	= L["Wand"],
									desc	= L["WAND_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.wand end,
									set		= function() addon.db.profile.filters.item.weapon.wand = not addon.db.profile.filters.item.weapon.wand end,
								},
								thrown = {
									order	= 13,
									type	= "toggle",
									name	= L["Thrown"],
									desc	= L["THROWN_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.thrown end,
									set		= function() addon.db.profile.filters.item.weapon.thrown = not addon.db.profile.filters.item.weapon.thrown end,
								},
								bow = {
									order	= 14,
									type	= "toggle",
									name	= L["Bow"],
									desc	= L["BOW_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.bow end,
									set		= function() addon.db.profile.filters.item.weapon.bow = not addon.db.profile.filters.item.weapon.bow end,
									disabled= true,
								},
								crossbow = {
									order	= 15,
									type	= "toggle",
									name	= L["Crossbow"],
									desc	= L["CROSSBOW_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.crossbow end,
									set		= function() addon.db.profile.filters.item.weapon.crossbow = not addon.db.profile.filters.item.weapon.crossbow end,
									disabled	= true,
								},
								ammo = {
									order	= 16,
									type	= "toggle",
									name	= L["Ammo"],
									desc	= L["AMMO_DESC"],
									get		= function() return addon.db.profile.filters.item.weapon.ammo end,
									set		= function() addon.db.profile.filters.item.weapon.ammo = not addon.db.profile.filters.item.weapon.ammo end,
								},
							},
						},
					},
				},
				playertype = {
					order	= 7,
					type	= "group",
					name	= L["Player Type"],
					desc	= L["FILTERING_PLAYERTYPE_DESC"],
					args	= {
						header1 = {
							order	= 1,
							type	= "header",
							name	= L["Player Type Filtering Options"],
						},
						desc = {
							order	= 2,
							type	= "description",
							name	= L["FILTERING_PLAYERTYPE_DESC"] .. "\n",
						},
						melee = {
							order	= 3,
							type	= "toggle",
							name	= L["Melee DPS"],
							desc	= L["MELEE_DPS_DESC"],
							get		= function() return addon.db.profile.filters.player.melee end,
							set		= function() addon.db.profile.filters.player.melee = not addon.db.profile.filters.player.melee end,
						},
						tanking = {
							order	= 4,
							type	= "toggle",
							name	= L["Tanks"],
							desc	= L["TANKS_DESC"],
							get		= function() return addon.db.profile.filters.player.tank end,
							set		= function() addon.db.profile.filters.player.tank = not addon.db.profile.filters.player.tank end,
						},
						casterdps = {
							order	= 5,
							type	= "toggle",
							name	= L["Caster DPS"],
							desc	= L["CASTER_DPS_DESC"],
							get		= function() return addon.db.profile.filters.player.caster end,
							set		= function() addon.db.profile.filters.player.caster = not addon.db.profile.filters.player.caster end,
						},
						healing = {
							order	= 6,
							type	= "toggle",
							name	= L["Healers"],
							desc	= L["HEALERS_DESC"],
							get		= function() return addon.db.profile.filters.player.healer end,
							set		= function() addon.db.profile.filters.player.healer = not addon.db.profile.filters.player.healer end,
						},
					},
				},
				reputations = {
					order	= 8,
					type	= "group",
					name	= L["Reputation"],
					desc	= L["FILTERING_REP_DESC"],
					args	= {
						header1 = {
							order	= 1,
							type	= "header",
							name	= L["Reputation Filtering Options"],
						},
						desc = {
							order	= 2,
							type	= "description",
							name	= L["FILTERING_REP_DESC"] .. "\n",
						},
						oldworld = {
							order	= 3,
							type	= "group",
							name	= L["Old World"],
							desc	= L["FILTERING_OLDWORLD_DESC"],
							args	= {
								header1 = {
									order	= 1,
									type	= "header",
									name	= L["Old World"],
								},
								header2 = {
									order	= 2,
									type	= "header",
									name	= L["Reputation Filtering Options"],
								},
								desc = {
									order	= 3,
									type	= "description",
									name	= L["FILTERING_OLDWORLD_DESC"] .. "\n",
								},
								ArgentDawn = {
									order	= 10,
									type	= "toggle",
									name	= BFAC["Argent Dawn"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Argent Dawn"]),
									get		= function() return addon.db.profile.filters.rep.argentdawn end,
									set		= function() addon.db.profile.filters.rep.argentdawn = not addon.db.profile.filters.rep.argentdawn end,
								},
								CenarionCircle = {
									order	= 11,
									type	= "toggle",
									name	= BFAC["Cenarion Circle"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Cenarion Circle"]),
									get		= function() return addon.db.profile.filters.rep.cenarioncircle end,
									set		= function() addon.db.profile.filters.rep.cenarioncircle = not addon.db.profile.filters.rep.cenarioncircle end,
								},
								TB = {
									order	= 12,
									type	= "toggle",
									name	= BFAC["Thorium Brotherhood"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Thorium Brotherhood"]),
									get		= function() return addon.db.profile.filters.rep.thoriumbrotherhood end,
									set		= function() addon.db.profile.filters.rep.thoriumbrotherhood = not addon.db.profile.filters.rep.thoriumbrotherhood end,
								},
								Timbermaw = {
									order	= 13,
									type	= "toggle",
									name	= BFAC["Timbermaw Hold"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Timbermaw Hold"]),
									get		= function() return addon.db.profile.filters.rep.timbermaw end,
									set		= function() addon.db.profile.filters.rep.timbermaw = not addon.db.profile.filters.rep.timbermaw end,
								},
								Zandalar = {
									order	= 14,
									type	= "toggle",
									name	= BFAC["Zandalar Tribe"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Zandalar Tribe"]),
									get		= function() return addon.db.profile.filters.rep.zandalar end,
									set		= function() addon.db.profile.filters.rep.zandalar = not addon.db.profile.filters.rep.zandalar end,
								},
							},
						},
						BC = {
							order	= 4,
							type	= "group",
							name	= L["Burning Crusade"],
							desc	= L["FILTERING_BC_DESC"],
							args	= {
								header1 = {
									order	= 1,
									type	= "header",
									name	= L["Burning Crusade"],
								},
								header2 = {
									order	= 2,
									type	= "header",
									name	= L["Reputation Filtering Options"],
								},
								desc = {
									order	= 3,
									type	= "description",
									name	= L["FILTERING_BC_DESC"] .. "\n",
								},
								Aldor = {
									order	= 10,
									type	= "toggle",
									name	= BFAC["The Aldor"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Aldor"]),
									get		= function() return addon.db.profile.filters.rep.aldor end,
									set		= function() addon.db.profile.filters.rep.aldor = not addon.db.profile.filters.rep.aldor end,
								},
								Ashtongue = {
									order	= 11,
									type	= "toggle",
									name	= BFAC["Ashtongue Deathsworn"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Ashtongue Deathsworn"]),
									get		= function() return addon.db.profile.filters.rep.ashtonguedeathsworn end,
									set		= function() addon.db.profile.filters.rep.ashtonguedeathsworn = not addon.db.profile.filters.rep.ashtonguedeathsworn end,
								},
								CenarionExpedition = {
									order	= 12,
									type	= "toggle",
									name	= BFAC["Cenarion Expedition"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Cenarion Expedition"]),
									get		= function() return addon.db.profile.filters.rep.cenarionexpedition end,
									set		= function() addon.db.profile.filters.rep.cenarionexpedition = not addon.db.profile.filters.rep.cenarionexpedition end,
								},
								Consortium = {
									order	= 13,
									type	= "toggle",
									name	= BFAC["The Consortium"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Consortium"]),
									get		= function() return addon.db.profile.filters.rep.consortium end,
									set		= function() addon.db.profile.filters.rep.consortium = not addon.db.profile.filters.rep.consortium end,
								},
								HellfireFactions = {
									order	= 14,
									type	= "toggle",
									name	= hellfirefac,
									desc	= format(L["SPECIFIC_REP_DESC"],hellfirefac),
									get		= function() return addon.db.profile.filters.rep.hellfire end,
									set		= function() addon.db.profile.filters.rep.hellfire = not addon.db.profile.filters.rep.hellfire end,
								},
								KoT = {
									order	= 15,
									type	= "toggle",
									name	= BFAC["Keepers of Time"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Keepers of Time"]),
									get		= function() return addon.db.profile.filters.rep.keepersoftime end,
									set		= function() addon.db.profile.filters.rep.keepersoftime = not addon.db.profile.filters.rep.keepersoftime end,
								},
								NagrandFactions = {
									order	= 16,
									type	= "toggle",
									name	= nagrandfac,
									desc	= format(L["SPECIFIC_REP_DESC"],nagrandfac),
									get		= function() return addon.db.profile.filters.rep.nagrand end,
									set		= function() addon.db.profile.filters.rep.nagrand = not addon.db.profile.filters.rep.nagrand end,
								},
								LowerCity = {
									order	= 17,
									type	= "toggle",
									name	= BFAC["Lower City"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Lower City"]),
									get		= function() return addon.db.profile.filters.rep.lowercity end,
									set		= function() addon.db.profile.filters.rep.lowercity = not addon.db.profile.filters.rep.lowercity end,
								},
								Scale = {
									order	= 18,
									type	= "toggle",
									name	= BFAC["The Scale of the Sands"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Scale of the Sands"]),
									get		= function() return addon.db.profile.filters.rep.scaleofthesands end,
									set		= function() addon.db.profile.filters.rep.scaleofthesands = not addon.db.profile.filters.rep.scaleofthesands end,
								},
								Scryer = {
									order	= 19,
									type	= "toggle",
									name	= BFAC["The Scryers"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Scryers"]),
									get		= function() return addon.db.profile.filters.rep.scryer end,
									set		= function() addon.db.profile.filters.rep.scryer = not addon.db.profile.filters.rep.scryer end,
								},
								Shatar = {
									order	= 20,
									type	= "toggle",
									name	= BFAC["The Sha'tar"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Sha'tar"]),
									get		= function() return addon.db.profile.filters.rep.shatar end,
									set		= function() addon.db.profile.filters.rep.shatar = not addon.db.profile.filters.rep.shatar end,
								},
								SSO = {
									order	= 21,
									type	= "toggle",
									name	= BFAC["Shattered Sun Offensive"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Shattered Sun Offensive"]),
									get		= function() return addon.db.profile.filters.rep.shatteredsun end,
									set		= function() addon.db.profile.filters.rep.shatteredsun = not addon.db.profile.filters.rep.shatteredsun end,
								},
								Sporeggar = {
									order	= 22,
									type	= "toggle",
									name	= BFAC["Sporeggar"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Sporeggar"]),
									get		= function() return addon.db.profile.filters.rep.sporeggar end,
									set		= function() addon.db.profile.filters.rep.sporeggar = not addon.db.profile.filters.rep.sporeggar end,
								},
								Violeteye = {
									order	= 23,
									type	= "toggle",
									name	= BFAC["The Violet Eye"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Violet Eye"]),
									get		= function() return addon.db.profile.filters.rep.violeteye end,
									set		= function() addon.db.profile.filters.rep.violeteye = not addon.db.profile.filters.rep.violeteye end,
								},
							},
						},
						WotLK = {
							order	= 5,
							type	= "group",
							name	= L["Wrath of the Lich King"],
							desc	= L["FILTERING_WOTLK_DESC"],
							args	= {
								header1 = {
									order	= 1,
									type	= "header",
									name	= L["Wrath of the Lich King"],
								},
								header2 = {
									order	= 2,
									type	= "header",
									name	= L["Reputation Filtering Options"],
								},
								desc = {
									order	= 3,
									type	= "description",
									name	= L["FILTERING_WOTLK_DESC"] .. "\n",
								},
								ArgentCrusade = {
									order	= 10,
									type	= "toggle",
									name	= BFAC["Argent Crusade"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Argent Crusade"]),
									get		= function() return addon.db.profile.filters.rep.argentcrusade end,
									set		= function() addon.db.profile.filters.rep.argentcrusade = not addon.db.profile.filters.rep.argentcrusade end,
								},
								Frenzyheart = {
									order	= 11,
									type	= "toggle",
									name	= BFAC["Frenzyheart Tribe"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Frenzyheart Tribe"]),
									get		= function() return addon.db.profile.filters.rep.frenzyheart end,
									set		= function() addon.db.profile.filters.rep.frenzyheart = not addon.db.profile.filters.rep.frenzyheart end,
								},
								WrathCommon1 = {
									order	= 12,
									type	= "toggle",
									name	= howlingtundra,
									desc	= format(L["SPECIFIC_REP_DESC"],howlingtundra),
									get		= function() return addon.db.profile.filters.rep.wrathcommon1 end,
									set		= function() addon.db.profile.filters.rep.wrathcommon1 = not addon.db.profile.filters.rep.wrathcommon1 end,
								},
								EbonBlade = {
									order	= 16,
									type	= "toggle",
									name	= BFAC["Knights of the Ebon Blade"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Knights of the Ebon Blade"]),
									get		= function() return addon.db.profile.filters.rep.ebonblade end,
									set		= function() addon.db.profile.filters.rep.ebonblade = not addon.db.profile.filters.rep.ebonblade end,
								},
								KirinTor = {
									order	= 17,
									type	= "toggle",
									name	= BFAC["Kirin Tor"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Kirin Tor"]),
									get		= function() return addon.db.profile.filters.rep.kirintor end,
									set		= function() addon.db.profile.filters.rep.kirintor = not addon.db.profile.filters.rep.kirintor end,
								},
								SonsOfHodir = {
									order	= 20,
									type	= "toggle",
									name	= BFAC["The Sons of Hodir"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Sons of Hodir"]),
									get		= function() return addon.db.profile.filters.rep.sonsofhodir end,
									set		= function() addon.db.profile.filters.rep.sonsofhodir = not addon.db.profile.filters.rep.sonsofhodir end,
								},
								Kaluak = {
									order	= 21,
									type	= "toggle",
									name	= BFAC["The Kalu'ak"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Kalu'ak"]),
									get		= function() return addon.db.profile.filters.rep.kaluak end,
									set		= function() addon.db.profile.filters.rep.kaluak = not addon.db.profile.filters.rep.kaluak end,
								},
								Oracles = {
									order	= 22,
									type	= "toggle",
									name	= BFAC["The Oracles"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Oracles"]),
									get		= function() return addon.db.profile.filters.rep.oracles end,
									set		= function() addon.db.profile.filters.rep.oracles = not addon.db.profile.filters.rep.oracles end,
								},
								Wyrmrest = {
									order	= 25,
									type	= "toggle",
									name	= BFAC["The Wyrmrest Accord"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Wyrmrest Accord"]),
									get		= function() return addon.db.profile.filters.rep.wyrmrest end,
									set		= function() addon.db.profile.filters.rep.wyrmrest = not addon.db.profile.filters.rep.wyrmrest end,
								},
								SilverCovenant = {
									order	= 26,
									type	= "toggle",
									name	= BFAC["The Silver Covenant"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Silver Covenant"]),
									get		= function() return addon.db.profile.filters.rep.silvercovenant end,
									set		= function() addon.db.profile.filters.rep.silvercovenant = not addon.db.profile.filters.rep.silvercovenant end,
								},
								Sunreavers = {
									order	= 27,
									type	= "toggle",
									name	= BFAC["The Sunreavers"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Sunreavers"]),
									get		= function() return addon.db.profile.filters.rep.sunreavers end,
									set		= function() addon.db.profile.filters.rep.sunreavers = not addon.db.profile.filters.rep.sunreavers end,
								},
								ExplorersLeague = {
									order	= 28,
									type	= "toggle",
									name	= BFAC["Explorers' League"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Explorers' League"]),
									get		= function() return addon.db.profile.filters.rep.explorersleague end,
									set		= function() addon.db.profile.filters.rep.explorersleague = not addon.db.profile.filters.rep.explorersleague end,
								},
								ValianceExpedition = {
									order	= 29,
									type	= "toggle",
									name	= BFAC["Valiance Expedition"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Valiance Expedition"]),
									get		= function() return addon.db.profile.filters.rep.valiance end,
									set		= function() addon.db.profile.filters.rep.valiance = not addon.db.profile.filters.rep.valiance end,
								},
								HandOfVengeance = {
									order	= 35,
									type	= "toggle",
									name	= BFAC["The Hand of Vengeance"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Hand of Vengeance"]),
									get		= function() return addon.db.profile.filters.rep.handofvengeance end,
									set		= function() addon.db.profile.filters.rep.valiance = not addon.db.profile.filters.rep.valiance end,
								},
								Taunka = {
									order	= 36,
									type	= "toggle",
									name	= BFAC["The Taunka"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["The Taunka"]),
									get		= function() return addon.db.profile.filters.rep.taunka end,
									set		= function() addon.db.profile.filters.rep.taunka = not addon.db.profile.filters.rep.taunka end,
								},
								WarsongOffensive = {
									order	= 37,
									type	= "toggle",
									name	= BFAC["Warsong Offensive"],
									desc	= format(L["SPECIFIC_REP_DESC"],BFAC["Warsong Offensive"]),
									get		= function() return addon.db.profile.filters.rep.warsongoffensive end,
									set		= function() addon.db.profile.filters.rep.warsongoffensive = not addon.db.profile.filters.rep.warsongoffensive end,
								},
							},
						},
					},
				},
			},
		}

	end

	return filterOptions

end

-- Description: function to return the top level Ace3 config table
-- Expected result: Will return the top level ace3 config table
-- Input: None
-- Output: Ace3 config table

local options = nil

local function fullOptions()

	local tomtomsupport = true

	if (TomTom) then
		tomtomsupport = false
	end

	if (not options) then

		options = {
			type = "group",
			name = MODNAME,
			args = {
				general = {
					order	= 1,
					type	= "group",
					name	= L["Main Options"],
					desc	= L["MAIN_OPTIONS_DESC"],
					args	= {
						header1 = {
							order	= 10,
							type	= "header",
							name	= L["General Settings"],
						},
						version = {
							order	= 11,
							type	= "description",
							name	= L["Version"] .. addonversion .. "\n",
						},
						run = {
							order	= 12,
							type	= "execute",
							name	= L["Scan"],
							desc	= L["SCAN_RECIPES_DESC"],
							func	= function(info) addon:AckisRecipeList_Command(false) end,
						},
						textdump = {	
							order	= 13,
							type	= "execute",
							name	= L["Text Dump"],
							desc	= L["TEXT_DUMP_DESC"],
							func	= function(info) addon:AckisRecipeList_Command(true) end,
						},
						exclusionlist = {	
							order	= 14,
							type	= "execute",
							name	= L["View Exclusion List"],
							desc	= L["VIEW_EXCLUSION_LIST_DESC"],
							func	= function(info) addon:ViewExclusionList() end,
						},
						resetguiwindow = {	
							order	= 15,
							type	= "execute",
							name	= L["Reset Window Position"],
							desc	= L["RESET_WINDOW_DESC"],
							func	= function(info) addon:ResetGUI() end,
						},
						spacer1 = {
							order	= 19,
							type	= "description",
							name	= "\n",
						},
						header1a = {
							order	= 20,
							type	= "header",
							name	= L["Main Filter Settings"],
						},
						mainfilter_desc = {
							order	= 21,
							type	= "description",
							name	= L["MAINFILTER_SETTINGS_DESC"] .. "\n",
						},
						includefiltered = {
							order	= 22,
							type	= "toggle",
							name	= L["Include Filtered"],
							desc	= L["FILTERCOUNT_DESC"],
							get		= function() return addon.db.profile.includefiltered end,
							set		= function() addon.db.profile.includefiltered = not addon.db.profile.includefiltered end,
						},
						includeexcluded = {
							order	= 23,
							type	= "toggle",
							name	= L["Include Excluded"],
							desc	= L["EXCLUDECOUNT_DESC"],
							get		= function() return addon.db.profile.includeexcluded end,
							set		= function() addon.db.profile.includeexcluded = not addon.db.profile.includeexcluded end,
						},
						ignoreexclusionlist = {
							order	= 24,
							type	= "toggle",
							name	= L["Display Exclusions"],
							desc	= L["DISPLAY_EXCLUSION_DESC"],
							get		= function() return addon.db.profile.ignoreexclusionlist end,
							set		= function() addon.db.profile.ignoreexclusionlist = not addon.db.profile.ignoreexclusionlist end,
						},
						spacer1a = {
							order	= 30,
							type	= "description",
							name	= "\n",
						},
						header2 = {
							order	= 31,
							type	= "header",
							name	= L["Display Settings"],
						},
						display_desc = {
							order	= 32,
							type	= "description",
							name	= L["DISPLAY_SETTINGS_DESC"] .. "\n",
						},
						scanbuttonlocation = {
							order	= 33,
							type	= "select",
							name	= L["Scan Button Position"],
							desc	= L["SCANBUTTONPOSITION_DESC"],
							get		= function() return addon.db.profile.scanbuttonlocation end,
							set		= function(info,name) addon.db.profile.scanbuttonlocation = name end,
							values	= function() return {TR = L["Top Right"], TL = L["Top Left"], BR = L["Bottom Right"], BL = L["Bottom Left"]} end,
						},
						uiscale = {
							order	= 34,
							type	= "range",
							name	= L["UI Scale"],
							desc	= L["UI_SCALE_DESC"],
							min		= .5,
							max		= 1.5,
							step	= .05,
							bigStep = .05,
							get		= function() return addon.db.profile.frameopts.uiscale end,
							set		= function(info, v) 
										addon.db.profile.frameopts.uiscale = v
										if (addon.Frame) then addon.Frame:SetScale(v) end
									  end,
						},
						fontsize = {
							order	= 35,
							type	= "range",
							name	= L["Font Size"],
							desc	= L["FONT_SIZE_DESC"],
							min		= 6,
							max		= 20,
							step	= 1,
							bigStep = 5,
							get		= function() return addon.db.profile.frameopts.fontsize end,
							set		= function(info, v) addon.db.profile.frameopts.fontsize = v end,
						},
						closegui = {
							order	= 37,
							type	= "toggle",
							name	= L["Close GUI"],
							desc	= L["CLOSEGUI_DESC"],
							get		= function() return addon.db.profile.closeguionskillclose end,
							set		= function() addon.db.profile.closeguionskillclose = not addon.db.profile.closeguionskillclose end,
						},
						hidepopup = {
							order	= 38,
							type	= "toggle",
							name	= L["Hide Pop-Up"],
							desc	= L["HIDEPOPUP_DESC"],
							get		= function() return addon.db.profile.hidepopup end,
							set		= function() addon.db.profile.hidepopup = not addon.db.profile.hidepopup end,
						},
						spacer2 = {
							order	= 39,
							type	= "description",
							name	= "\n",
						},
						header3 = {
							order	= 40,
							type	= "header",
							name	= L["Sorting Settings"],
						},
						sort_desc =	{
							order	= 41,
							type	= "description",
							name	= L["SORTING_SETTINGS_DESC"] .. "\n",
						},
						sorting = {
							order	= 45,
							type	= "select",
							name	= L["Sorting"],
							desc	= L["SORTING_DESC"],
							get		= function() return addon.db.profile.sorting end,
							set		= function(info,name) addon.db.profile.sorting = name end,
							values	= function() return {Name = L["Name"], SkillAsc = L["Skill (Asc)"], SkillDesc = L["Skill (Desc)"], Acquisition = L["Acquisition"], Location = L["Location"]} end,
						},
						spacer3 = {
							order	= 50,
							type	= "description",
							name	= "\n",
						},
						header4 = {
							order	= 51,
							type	= "header",
							name	= L["Tooltip Settings"],
						},
						tt_desc =	{
							order	= 52,
							type	= "description",
							name	= L["TOOLTIP_SETTINGS_DESC"] .. "\n",
						},
						tooltipscale = {
							order	= 53,
							type	= "range",
							name	= L["Tooltip Scale"],
							desc	= L["TOOLTIP_SCALE_DESC"],
							min		= .5,
							max		= 1.5,
							step	= .05,
							bigStep = .05,
							get		= function() return addon.db.profile.frameopts.tooltipscale end,
							set		= function(info, v) 
										addon.db.profile.frameopts.tooltipscale = v
										if (arlTooltip) then arlTooltip:SetScale(v) end
										if (arlTooltip2) then arlTooltip:SetScale(v) end
									  end,
						},
						acquiretooltiplocation = {
							order	= 54,
							type	= "select",
							name	= L["Tooltip (Acquire) Position"],
							desc	= L["ACQUIRETOOLTIPPOSITION_DESC"],
							get		= function() return addon.db.profile.acquiretooltiplocation end,
							set		= function(info,name) addon.db.profile.acquiretooltiplocation = name end,
							values	= function() return {Right = L["Right"], Left = L["Left"], Top = L["Top"], Bottom = L["Bottom"], Off = L["Off"], Mouse = L["Mouse"]} end,
						},
						spelltooltiplocation = {
							order	= 55,
							type	= "select",
							name	= L["Tooltip (Recipe) Position"],
							desc	= L["SPELLTOOLTIPPOSITION_DESC"],
							get		= function() return addon.db.profile.spelltooltiplocation end,
							set		= function(info,name) addon.db.profile.spelltooltiplocation = name end,
							values	= function() return {Right = L["Right"], Left = L["Left"], Top = L["Top"], Bottom = L["Bottom"], Off = L["Off"]} end,
						},
						spacer4 = {
							order	= 60,
							type	= "description",
							name	= "\n",
						},
						header5 = {
							order	= 61,
							type	= "header",
							name	= L["Map Settings"],
						},
						map_desc =	{
							order	= 62,
							type	= "description",
							name	= L["MAP_SETTINGS_DESC"] .. "\n",
						},
						autoscanmap = {
							order	= 63,
							type	= "toggle",
							name	= L["Auto Scan Map"],
							desc	= L["AUTOSCANMAP_DESC"],
							disabled = tomtomsupport,
							get		= function() return addon.db.profile.autoscanmap end,
							set		= function() addon.db.profile.autoscanmap = not addon.db.profile.autoscanmap end,
						},
						worldmap = {
							order	= 65,
							type	= "toggle",
							name	= L["World Map"],
							desc	= L["WORLDMAP_DESC"],
							disabled = tomtomsupport,
							get		= function() return addon.db.profile.worldmap end,
							set		= function() addon.db.profile.worldmap = not addon.db.profile.worldmap end,
						},
						minimap = {
							order	= 66,
							type	= "toggle",
							name	= L["Mini Map"],
							desc	= L["MINIMAP_DESC"],
							disabled = tomtomsupport,
							get		= function() return addon.db.profile.minimap end,
							set		= function() addon.db.profile.minimap = not addon.db.profile.minimap end,
						},
						clearmap = {	
							order	= 67,
							type	= "execute",
							name	= L["Clear Waypoints"],
							disabled = tomtomsupport,
							desc	= L["CLEAR_WAYPOINTS_DESC"],
							func	= function() addon:ClearMap() end,
						},
					},
				},
			},
		}

		for k,v in pairs(modularOptions) do
			options.args[k] = (type(v) == "function") and v() or v
		end

	end

	return options

end

local documentation = nil

local function giveDocs()

	if (not documentation) then

		documentation = {
			order = 1,
			type = "group",
			name = L["ARL Documentation"],
			desc = L["ARL_DOC_DESC"],
			args = {
				header1 = {
					order	= 1,
					type	= "header",
					name	= L["ARL Documentation"],
				},
				desc1 = {
					order	= 2,
					type	= "description",
					name	= L["ARL_DOC_DESC"],
				},
				header2 = {
					order	= 3,
					type	= "header",
					name	= L["Using Filters"],
				},
				desc2 = {
					order	= 4,
					type	= "description",
					name	= L["USING_FILTERS_DESC"],
				},
				header3 = {
					order	= 5,
					type	= "header",
					name	= L["Common Issues"],
				},
				desc3 = {
					order	= 6,
					type	= "description",
					name	= L["COMMON_ISSUES_DESC"],
				},
				header4 = {
					order	= 7,
					type	= "header",
					name	= L["Reporting Bugs"],
				},
				desc4 = {
					order	= 8,
					type	= "description",
					name	= L["REPORTING_BUGS_DESC"],
				},
				header5 = {
					order	= 9,
					type	= "header",
					name	= L["Exclusion Issues"],
				},
				desc5 = {
					order	= 10,
					type	= "description",
					name	= L["EXCLUSION_ISSUES_DESC"],
				},
				header6 = {
					order	= 11,
					type	= "header",
					name	= L["Map Issues"],
				},
				desc6 = {
					order	= 12,
					type	= "description",
					name	= L["MAP_ISSUES_DESC"],
				},
				header7 = {
					order	= 13,
					type	= "header",
					name	= L["Game Commands"],
				},
				desc7 = {
					order	= 14,
					type	= "description",
					name	= L["GAME_COMMANDS_DESC"],
				},
			},
		}

	end

	return documentation

end

-- Description: 
-- Expected result: 
-- Input: None
-- Output: None.

function addon:SetupOptions()

	AceConfigReg:RegisterOptionsTable(MODNAME, fullOptions)
	self.optionsFrame = AceConfigDialog:AddToBlizOptions(MODNAME, nil, nil, "general")

	-- Add in the about panel to the Bliz options (but not the ace3 config)
	if LibStub:GetLibrary("LibAboutPanel", true) then
		self.optionsFrame["About"] = LibStub:GetLibrary("LibAboutPanel").new(MODNAME, MODNAME)
	else
		self:Print("Lib AboutPanel not loaded.")
	end

	-- Fill up our modular options...
	self:RegisterModuleOptions("Filters", giveFilter(), L["Filtering Options"])
	self:RegisterModuleOptions("Profiles", giveProfiles(), L["Profile Options"])
	self:RegisterModuleOptions("Documentation", giveDocs(), L["ARL Documentation"])

end

-- Description: Function which extends our options table in a modular way
-- Expected result: add a new modular options table to the modularOptions upvalue as well as the Blizzard config
-- Input:
--		name			: index of the options table in our main options table
--		optionsTable	: the sub-table to insert
--		displayName	: the name to display in the config interface for this set of options
-- Output: None.

function addon:RegisterModuleOptions(name, optionsTable, displayName)

	modularOptions[name] = optionsTable
	self.optionsFrame[name] = AceConfigDialog:AddToBlizOptions(MODNAME, displayName, MODNAME, name)

end
