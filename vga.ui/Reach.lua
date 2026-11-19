-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: How far vga.ui's nameplates reach and how they fade: the game's plate reach set as high as it allows and recorded where it caps it; the plates full size to ten yards, then smaller on a slope to 60 per cent at the reach - the game counts nameplateMinScaleDistance back from the reach, so it stands at 0 -; the fading left to the game, which fades every plate but a pet's with distance - a pet's plate takes the fade the game gives a plate of the same scale; the game's own small names over units hidden, their pets', guardians', minions' and totems' too, and the neutral, hostile and interactive NPCs' (the game spells one setting UnitNameHostleNPC); the player's settings restored at logout.

-- {K0373}

local _, vga = ...
local library = LibVGA
local ASKED_REACH = "100"
local NEAR = "10"
local SMALLEST = 0.6

local function check_pet(unit)
    return UnitPlayerControlled(unit) and not UnitIsPlayer(unit)
end

local function read_alpha_at(samples, scale)
    local alpha, nearest = 1, math.huge
    for _, sample in ipairs(samples) do
        local apart = math.abs(sample[1] - scale)
        if apart < nearest then alpha, nearest = sample[2], apart end
    end
    return alpha
end

local function update_pet_fading()
    local samples = {}
    for unit, plate in pairs(vga.plates) do
        local owner = plate:GetParent()
        if not check_pet(unit) then samples[#samples + 1] = { owner:GetScale(), owner:GetAlpha() } end
    end
    for unit, plate in pairs(vga.plates) do
        plate:SetAlpha(check_pet(unit) and read_alpha_at(samples, plate:GetParent():GetScale()) or 1)
    end
end

local function update_reach()
    library.update_switches("reach", { nameplateMaxDistance = ASKED_REACH })
    local reach = GetCVar("nameplateMaxDistance")
    LibVGASettings.measures = LibVGASettings.measures or {}
    LibVGASettings.measures.reach = reach
    library.update_switches("reach", {
        nameplateMinScale = tostring(SMALLEST), nameplateMaxScale = "1",
        nameplateMaxScaleDistance = NEAR, nameplateMinScaleDistance = "0",
        UnitNameFriendlyPlayerName = "0", UnitNameEnemyPlayerName = "0", UnitNameFriendlySpecialNPCName = "0",
        UnitNameNPC = "0", UnitNameOwn = "0",
        UnitNameFriendlyPetName = "0", UnitNameFriendlyGuardianName = "0", UnitNameFriendlyMinionName = "0", UnitNameFriendlyTotemName = "0",
        UnitNameEnemyPetName = "0", UnitNameEnemyGuardianName = "0", UnitNameEnemyMinionName = "0", UnitNameEnemyTotemName = "0",
        UnitNameHostleNPC = "0", UnitNameInteractiveNPC = "0", UnitNameNonCombatCreatureName = "0",
    })
    local known = {}
    for name in pairs(LibVGASettings.reach or {}) do known[#known + 1] = name end
    table.sort(known)
    LibVGASettings.measures.reach_known = table.concat(known, " ")
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then
        library.update_safely("reach back", library.update_switches_back, "reach")
        return
    end
    library.update_safely("reach", update_reach)
    C_Timer.NewTicker(0.1, function() library.update_safely("pets fading", update_pet_fading) end)
end)
