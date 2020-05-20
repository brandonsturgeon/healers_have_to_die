--[=[
HealersHaveToDie World of Warcraft Add-on
Copyright (c) 2009 by John Wellesz (Archarodim@teaser.fr)
All rights reserved

Version 1.0.2-3-g184259f

This is a very simple and light add-on that rings when you hover or target a
unit of the opposite faction who healed someone during the last 60 seconds (can
be configured).
Now you can spot those nasty healers instantly and help them to accomplish their destiny!

This add-on uses the Ace3 framework.

type /hhtd to get a list of existing options.

-----
    Core.lua
-----


--]=]
local addonName, T = ...

-- [=[ Add-on basics and variable declarations {{{
T.hhtd = LibStub("AceAddon-3.0"):NewAddon("Healers Have To Die", "AceConsole-3.0", "AceEvent-3.0")
local hhtd = T.hhtd

hhtd.L = LibStub("AceLocale-3.0"):GetLocale("HealersHaveToDie", true)

local L = hhtd.L

-- Constants values holder
local HHTD_C = {}
hhtd.C = HHTD_C

HHTD_C.HealingClasses = {
    ["PRIEST"]  = true,
    ["PALADIN"] = true,
    ["DRUID"]   = true,
    ["SHAMAN"]  = true,
}

hhtd.EnemyHealers = {}


-- upvalues
local UnitIsPlayer      = _G.UnitIsPlayer
local UnitIsDead        = _G.UnitIsDead
local UnitFactionGroup  = _G.UnitFactionGroup
local UnitGUID          = _G.UnitGUID
local UnitIsUnit        = _G.UnitIsUnit
local UnitSex           = _G.UnitSex
local UnitClass         = _G.UnitClass
local UnitName          = _G.UnitName
local UnitFactionGroup  = _G.UnitFactionGroup
local GetTime           = _G.GetTime
local PlaySoundFile     = _G.PlaySoundFile


-- }}} ]=]

-- 03 Ghosts I

-- [=[ options and defaults {{{
local options = {
    name = "Healers Have To Die",
    handler = hhtd,
    type = 'group',
    args = {
        VersionHeader = {
            type = 'header',
            name = L["VERSION"] .. ' 1.0.2-3-g184259f',
            order = 1,
        },
        ReleaseDateHeader = {
            type = 'header',
            name = L["RELEASE_DATE"] .. ' 2010-10-03T18:58:08Z',
            order = 2,
        },
        on = {
            type = 'toggle',
            name = L["OPT_ON"],
            desc = L["OPT_ON_DESC"],
            set = function(info) hhtd.db.global.Enabled = hhtd:Enable() return hhtd.db.global.Enabled end,
            get = function(info) return hhtd:IsEnabled() end,
            order = 10,
        },
        off = {
            type = 'toggle',
            name = L["OPT_OFF"],
            desc = L["OPT_OFF_DESC"],
            set = function(info) hhtd.db.global.Enabled = not hhtd:Disable() return not hhtd.db.global.Enabled end,
            get = function(info) return not hhtd:IsEnabled() end,
            order = 20,
        },
        Header1 = {
            type = 'header',
            name = '',
            order = 25,
        },
        Header1000 = {
            type = 'header',
            name = '',
            order = 999,
        },
        debug = {
            type = 'toggle',
            name = L["OPT_DEBUG"],
            desc = L["OPT_DEBUG_DESC"],
            set = function(info, value) hhtd.db.global.Debug = value hhtd:Print(L["DEBUGGING_STATUS"], value and L["OPT_ON"] or L["OPT_OFF"]) return value end,
            get = function(info) return hhtd.db.global.Debug end,
            order = 1000,
        },
		report = {
			type = 'toggle',
			name = L["OPT_REPORT"],
			desc = L["OPT_REPORT_DESC"],
			set = function(info, value) hhtd.db.global.Report = value return value end,
			get = function(info) return hhtd.db.global.Report end,
			order = 1005,
		},
        version = {
            type = 'execute',
            name = L["OPT_VERSION"],
            desc = L["OPT_VERSION_DESC"],
            guiHidden = true,
            func = function () hhtd:Print(L["VERSION"], '1.0.2-3-g184259f,', L["RELEASE_DATE"], '2010-10-03T18:58:08Z') end,
            order = 1010,
        },
    },
}

local defaults = {
  global = {
      Enabled = true,
      Debug = false,
	  Report = false
  }
}

local healerOnlySpells = {
    -- Resto Shaman
    ["Riptide"] = true,
	["Earth Shield"] = true,
	["Mana Tide Totem"] = true,
	["Cleanse Spirit"] = true,
	["Earthliving"] = true,
	["Earthliving Weapon"] = true,
	["Ancestral Awakening"] = true,
	
	-- Holy Paladin
	["Holy Shock"] = true,
    ["Beacon of Light"] = true,
	["Divine Illumination"] = true,
	["Sacred Cleansing"] = true,

    -- Resto Druid
	["Tree of Life"] = true,
	["Living Seed"] = true,
	["Wild Growth"] = true,
	["Tree of Life"] = true,
	["Swiftmend"] = true,
	["Nature's Swiftness"] = true,
	["Revitalize"] = true,
	
	-- Disc Priest
	["Penance"] = true,
	["Borrowed Time"] = true,
	["Pain Suppression"] = true,
	["Grace"] = true,
	["Rapture"] = true,
	["Focused Will"] = true,
	["Power Infusion"] = true,
	["Renewed Hope"] = true,
	
	-- Holy Priest
	["Guardian Spirit"] = true,
	["Circle of Healing"] = true,
	["Serendipity"] = true,
	["Lightwell"] = true,
	["Holy Concentration"] = true,
	["Surge of Light"] = true,
	["Spirit of Redemption"] = true,
	
	-- Items
	["Release of Light"] = true, -- Bauble of True Blood
	["Echoes of Light"] = true, -- Althor's Abacus
	["Protection of Ancient Kings"] = true, -- Val'anyr
	["Holiness"] = true, -- T10 Holy Paladin 4P Bonus
	["Rapid Currents"] = true,	 -- T10 Resto Shaman 2P Bonus
	["Fountain of Light"] = true, -- Trauma
	["Twilight Renewal"] = true, -- Glowing Twilight Scale
	["Chilling Knowledge"] = true, -- Ashen Band of Endless Wisdom
}

-- }}} ]=]

-- [=[ Add-on Management functions {{{
function hhtd:OnInitialize()

  self.db = LibStub("AceDB-3.0"):New("HealersHaveToDieDB", defaults)

  LibStub("AceConfig-3.0"):RegisterOptionsTable("Healers Have To Die", options, {"HealersHaveToDie", "hhtd"})
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Healers Have To Die")

  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "TestUnit")
  self:RegisterEvent("PLAYER_TARGET_CHANGED", "TestUnit")

  self:CreateClassColorTables()

  self:SetEnabledState(self.db.global.Enabled)

end

local PlayerFaction = ""
function hhtd:OnEnable()
    self:Print(L["ENABLED"])

    PlayerFaction = UnitFactionGroup("player")
end

function hhtd:OnDisable()
    self:Print(L["DISABLED"])
end

function hhtd:Debug(...)
    if not self.db.global.Debug then return end

    self:Print("|cFFFF2222Debug:|r", ...)
end

-- }}} ]=]

-- Max buff count is 40
local MAX_BUFF_COUNT = 40

local function getUnitBuffs(unit)
    local unitBuffs = {}

    for i = 1, 40 do
        name = UnitAura(unit, i)

        if name == nil then break end

		unitBuffs[name] = true
	end

	return unitBuffs
end

function hhtd:unitHasHealerOnlyBuff(unit)
	for spellName in pairs( getUnitBuffs(unit) ) do
		if healerOnlySpells[spellName] then
			self:Debug("Player has healer-only buff! Player: " .. UnitName(unit) .. ", Buff Name: " .. spellName )
			return true
		end
	end
	
	return false
end

function hhtd:unitIsHealer(unit)
	if not unit or unit == "" then return end

    local _, unitClass = UnitClass(unit)
	local unitGUID = UnitGUID(unit)
	
    local isHealingClass = HHTD_C.HealingClasses[unitClass]
	if not isHealingClass then return false end
	
	if hhtd.EnemyHealers[unitGUID] then
		return true
	end

	if self:unitHasHealerOnlyBuff(unit) then return true end
end

function hhtd:registerHealer(enemyGUID, enemyName)
    local isRegistered = self.EnemyHealers[enemyGUID]
	
	if isRegistered then return end
	
	self:Debug("Registering healer: " .. enemyName)
	
	self.EnemyHealers[enemyGUID] = true
	
	if not self.db.global.Report then return end
	
	self:Debug("Reporting healer: " .. enemyName)

	-- TODO: Report to the proper channel
	SendChatMessage( enemyName .. " is a healer!", "BATTLEGROUND" )
end

local LastDetectedGUID = ""
function hhtd:TestUnit(EventName)

    local Unit=""

    if EventName=="UPDATE_MOUSEOVER_UNIT" then
        Unit = "mouseover"
    elseif EventName=="PLAYER_TARGET_CHANGED" then
        Unit = "target"
    else
        self:Print("called on invalid event")
        return
    end

    if not UnitIsPlayer(Unit) or UnitIsDead(Unit) then
        return
    end

    local UnitFaction = UnitFactionGroup(Unit)

    if UnitFaction == PlayerFaction then
        return
    end

    local TheUG = UnitGUID(Unit)
    local TheUnitClass_loc, TheUnitClass

    if UnitIsUnit("mouseover", "target") then
	    return
	end
	
	if LastDetectedGUID == TheUG and Unit == "target" then
        PlaySoundFile("Sound\\interface\\AuctionWindowOpen.wav")
        self:Debug("AuctionWindowOpen.wav played")

        local sex = UnitSex(Unit)
        local what = (sex == 1 and L["YOU_GOT_IT"] or sex == 2 and L["YOU_GOT_HIM"] or L["YOU_GOT_HER"])
        TheUnitClass_loc, TheUnitClass = UnitClass(Unit)
        local subjectColor = self:GetClassHexColor(TheUnitClass)

        self:Print(what:format("|c" .. subjectColor ))
        return
        
    end

    if not TheUG then
        self:Debug("No unit GUID")
        return
    end

    TheUnitClass_loc, TheUnitClass = UnitClass(Unit)

    if not TheUnitClass then
        self:Debug("No unit Class")
        return
    end

    -- Is the unit a healer?
	if self:unitIsHealer(Unit) then
		if LastDetectedGUID ~= TheUG then
			self:Print("|cFFFF0000", (L["IS_A_HEALER"]):format(self:ColorText((UnitName(Unit)), self:GetClassHexColor(TheUnitClass))), "|r")
		end
		
		self:registerHealer(TheUG, UnitName(Unit))

		LastDetectedGUID = TheUG

		PlaySoundFile("Sound\\interface\\AlarmClockWarning3.wav")
		self:Debug("AlarmClockWarning3.wav played")

    end

end

do
    local bit       = _G.bit
    local band      = _G.bit.band
    local bor       = _G.bit.bor
    local UnitGUID  = _G.UnitGUID
    local sub       = _G.string.sub
    local GetTime   = _G.GetTime
    
    local PET                   = COMBATLOG_OBJECT_TYPE_PET

    local OUTSIDER              = COMBATLOG_OBJECT_AFFILIATION_OUTSIDER
    local HOSTILE_OUTSIDER      = bit.bor (COMBATLOG_OBJECT_AFFILIATION_OUTSIDER, COMBATLOG_OBJECT_REACTION_HOSTILE)
    local FRIENDLY_TARGET       = bit.bor (COMBATLOG_OBJECT_TARGET, COMBATLOG_OBJECT_REACTION_FRIENDLY)

    -- http://www.wowwiki.com/API_COMBAT_LOG_EVENT
    function hhtd:COMBAT_LOG_EVENT_UNFILTERED(e, timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, arg9, spellName, arg11, arg12)
        if not sourceGUID then return end

        if band (sourceFlags, HOSTILE_OUTSIDER) ~= HOSTILE_OUTSIDER or band(destFlags, PET) == PET then
            return
        end
		
		_, className = GetPlayerInfoByGUID(sourceGUID)
		if not HHTD_C.HealingClasses[className] then return end
	
		if healerOnlySpells[spellName] then
			self:Debug("Player cast likely healer spell! " .. "Player: " .. sourceName .. ", Spell: " .. spellName)
			self:registerHealer(sourceGUID, sourceName)
		end
    end
end

-- Clean healers list when changing area
function hhtd:PLAYER_ENTERING_WORLD()
	hhtd.EnemyHealers = {}
	self:Debug("Clearning enemy healers list")
end
