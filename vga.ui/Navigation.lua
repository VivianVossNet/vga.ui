-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The navigation arrow centred between the player frame and the target frame: three gold chevrons, the foremost strongest and each behind it fainter, laid on the ground as if they lay on the way, each tilted back on its own, with room between them, the farther a little smaller - turned towards the nearest open quest's target as the player sees it - the quest set as the game's tracked one, so the game's own navigation tells where its target stands on the screen, and the arrow points from the screen's middle there, turning with the camera however it is turned, behind the camera pointing back; where the game knows no place for the quest, a map waypoint of the game's is set on the arrow's target and tracked instead, so its place on the screen is known too (K0570); only where neither gives one, by the character's facing - and tilted back (K0545) -, its distance beneath it; shown whenever the tracker has such a target, in a fight too, gone without one.

-- {K0370} {K0372} {K0398} {K0399} {K0545} {K0570}

local _, vga = ...
local library = LibVGA
local atan2 = math.atan2 or math.atan
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

local waypoint_set, navigation_way

local function update_tracked(aim)
    if not (aim.id and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID) then return end
    if C_SuperTrack.GetSuperTrackedQuestID() ~= aim.id then C_SuperTrack.SetSuperTrackedQuestID(aim.id) end
end

local function check_screen_place()
    return C_Navigation and C_Navigation.GetFrame and C_Navigation.GetFrame() and C_Navigation.HasValidScreenPosition and C_Navigation.HasValidScreenPosition()
end

local function update_waypoint(aim)
    local map = C_Map.GetBestMapForUnit("player")
    if not (map and aim.point and C_Map.SetUserWaypoint and UiMapPoint and C_SuperTrack.SetSuperTrackedUserWaypoint) then return end
    local wanted = map .. ":" .. aim.point[1] .. ":" .. aim.point[2]
    if waypoint_set ~= wanted then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, aim.point[1], aim.point[2]))
        waypoint_set = wanted
    end
    if not (C_SuperTrack.IsSuperTrackingUserWaypoint and C_SuperTrack.IsSuperTrackingUserWaypoint()) then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
end

local function write_way(way)
    if navigation_way == way then return end
    navigation_way = way
    LibVGASettings.measures = LibVGASettings.measures or {}
    LibVGASettings.measures.navigation = way
end

function vga.read_screen_heading(aim)
    update_tracked(aim)
    local way = "quest"
    if not check_screen_place() then
        update_waypoint(aim)
        way = "waypoint"
    end
    if not check_screen_place() then
        write_way("none")
        return nil
    end
    write_way(way)
    local marker = C_Navigation.GetFrame()
    local marker_x, marker_y = marker:GetCenter()
    local middle_x, middle_y = WorldFrame:GetCenter()
    if not (marker_x and middle_x) then return nil end
    return atan2(middle_x - marker_x, marker_y - middle_y)
end

local function update_navigation()
    local aim = vga.quest_aim
    local heading = aim and aim.point and (vga.read_screen_heading(aim) or vga.read_heading(aim.point))
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
