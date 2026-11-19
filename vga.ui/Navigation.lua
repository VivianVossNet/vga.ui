-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The navigation arrow centred between the player frame and the target frame: three gold chevrons, the foremost strongest and each behind it fainter, laid on the ground as if they lay on the way, each tilted back on its own, with room between them, the farther a little smaller - turned towards the nearest open quest's target and tilted back -, its distance beneath it; shown whenever the tracker has such a target, in a fight too, gone without one.

-- {K0370} {K0372} {K0398} {K0399}

local _, vga = ...
local library = LibVGA
local colours = library.colours
local TILT = 0.5
local CHEVRONS = { { ahead = 1, alpha = 1 }, { ahead = 0, alpha = 0.6 }, { ahead = -1, alpha = 0.25 } }
local SPACING = 0.3
local CHEVRON = 0.5
local NEARER = 0.15
local OVERHANG = 0.05
local navigation

local function create_navigation()
    navigation = CreateFrame("Frame", "VGANavigation", UIParent)
    navigation.lying = CreateFrame("Frame", nil, navigation)
    navigation.lying:SetPoint("CENTER")
    navigation.chevrons = {}
    for index, chevron in ipairs(CHEVRONS) do
        local texture = navigation.lying:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(library.media .. "NaviChevron", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        texture:SetVertexColor(colours.gold[1], colours.gold[2], colours.gold[3], chevron.alpha)
        texture.ahead = chevron.ahead
        navigation.chevrons[index] = texture
    end
    navigation.distance = library.create_text(navigation, "figure", colours.ink)
    navigation:Hide()
end

local function read_ground_corner(x, y, turn)
    local cosine, sine = math.cos(turn), math.sin(turn)
    local ground = y / TILT
    return x * cosine - ground * sine + 0.5, x * sine + ground * cosine + 0.5
end

local function update_lying(texture, turn)
    local left_top_x, left_top_y = read_ground_corner(-0.5, -0.5 * TILT, turn)
    local left_bottom_x, left_bottom_y = read_ground_corner(-0.5, 0.5 * TILT, turn)
    local right_top_x, right_top_y = read_ground_corner(0.5, -0.5 * TILT, turn)
    local right_bottom_x, right_bottom_y = read_ground_corner(0.5, 0.5 * TILT, turn)
    texture:SetTexCoord(left_top_x, left_top_y, left_bottom_x, left_bottom_y, right_top_x, right_top_y, right_bottom_x, right_bottom_y)
end

local function update_chevrons(heading)
    local width = navigation.lying:GetWidth()
    for _, texture in ipairs(navigation.chevrons) do
        local ahead = texture.ahead * SPACING * width
        local rise = math.cos(heading) * ahead * TILT
        local size = width * CHEVRON * (1 - NEARER * rise / (SPACING * width * TILT))
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", navigation.lying, "CENTER", -math.sin(heading) * ahead, rise)
        texture:SetSize(size, size * TILT)
        update_lying(texture, heading)
    end
end

local function update_place()
    local player, target = VGAUnitFrame_player, VGAUnitFrame_target
    if not (player and target) then return false end
    local width = library.read_size(8)
    navigation:ClearAllPoints()
    navigation:SetPoint("TOPLEFT", player, "TOPRIGHT")
    navigation:SetPoint("BOTTOMRIGHT", target, "BOTTOMLEFT")
    navigation.lying:SetSize(width, math.floor(width * TILT + 0.5))
    navigation.distance:SetFontObject(library.read_font("figure"))
    navigation.distance:ClearAllPoints()
    navigation.distance:SetPoint("TOP", navigation.lying, "BOTTOM", 0, -library.read_size(-6) - math.floor(width * OVERHANG + 0.5))
    return true
end

local function update_navigation()
    local aim = vga.quest_aim
    local heading = aim and aim.point and vga.read_heading(aim.point)
    navigation:SetShown(heading ~= nil and update_place())
    if not heading then return end
    update_chevrons(heading)
    navigation.distance:SetText(vga.render_distance(aim.distance))
end

local function update_navigation_safely(_, elapsed)
    navigation.since = (navigation.since or 0) + elapsed
    if navigation.since < 0.05 then return end
    navigation.since = 0
    library.update_safely("navigation", update_navigation)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    library.update_safely("navigation login", create_navigation)
    events:SetScript("OnUpdate", update_navigation_safely)
end)
