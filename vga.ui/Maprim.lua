-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The minimap frame's two rims, as the owner set them, equally high and every sign and word in each set at its vertical middle: above the map a small magnifier left-aligned at the map's left edge, then a little apart the zone's name, the coordinates right-aligned at its right edge; beneath the map a calendar, a little larger, left-aligned under its left edge, a button of its own that opens the game's calendar, the time and the day's sign - a sun by day, a moon by night - right-aligned at its right edge, the time's digits lowered half a pixel so their middle meets the sign's. The magnifier opens the game's tracking menu, the game's own button lying invisible over it so the menu opens where the sign is. The game's zone bar, clock, addon compartment, day sun and coordinates are put away.

-- {K0424} {K0429} {K0430} {K0439} {K0446}

local _, vga = ...
local library = LibVGA
local colours = library.colours
local DRAFT_BASE = 13
local UPDATE_EVERY = 0.2
local CALENDAR = 1.35
local DIGIT_DROP = 0.5
local rim

local function read_draft(pixels)
    return math.floor(pixels * library.read_base() / DRAFT_BASE + 0.5)
end

function vga.read_map_line()
    return library.read_size(-1) + read_draft(8)
end

local function read_game_parts()
    local cluster = MinimapCluster or {}
    local container = cluster.MinimapContainer or {}
    return { cluster.ZoneTextButton, TimeManagerClockButton, AddonCompartmentFrame, cluster.DielFrame, container.PlayerCoords, GameTimeFrame }
end

local function update_game_parts()
    for _, part in pairs(read_game_parts()) do
        part:SetAlpha(0)
        if part.EnableMouse then part:EnableMouse(false) end
    end
end

local function update_over(part, sign)
    if not part then return end
    part:SetAlpha(0)
    part:ClearAllPoints()
    part:SetPoint("CENTER", sign, "CENTER")
    part:SetSize(sign:GetWidth(), sign:GetHeight())
end

local function read_day_sign()
    local day = not (C_DateAndTime and C_DateAndTime.IsDayTime and C_DateAndTime.IsDayTime() == false)
    return library.media .. (day and "DaySun" or "NightMoon")
end

local function read_time()
    if GameTime_GetTime then return GameTime_GetTime(false) end
    return date("%H:%M")
end

local function update_texts()
    local map = C_Map.GetBestMapForUnit("player")
    local spot = map and C_Map.GetPlayerMapPosition(map, "player")
    if spot then rim.coords:SetFormattedText("%.1f, %.1f", spot.x * 100, spot.y * 100) else rim.coords:SetText("") end
    rim.zone:SetText(GetMinimapZoneText and GetMinimapZoneText() or "")
    rim.time:SetText(read_time())
    rim.day:SetTexture(read_day_sign())
end

local function update_texts_safely(_, elapsed)
    rim.since = (rim.since or 0) + elapsed
    if rim.since < UPDATE_EVERY then return end
    rim.since = 0
    library.update_safely("map rim", update_texts)
end

local function update_sign(sign, size)
    sign:SetSize(size, size)
    sign:ClearAllPoints()
end

function vga.update_map_rim(view, band)
    if not rim then return end
    local size, middle, text = library.read_size(-1), band / 2, library.read_font("small")
    for _, line in ipairs({ rim.zone, rim.coords, rim.time }) do line:SetFontObject(text) end
    update_sign(rim.glass, size)
    rim.glass:SetPoint("LEFT", view, "TOPLEFT", 0, middle)
    rim.zone:SetFontObject(library.read_font("caption"))
    rim.zone:ClearAllPoints()
    rim.zone:SetPoint("LEFT", rim.glass, "RIGHT", read_draft(6), 0)
    rim.coords:ClearAllPoints()
    rim.coords:SetPoint("RIGHT", view, "TOPRIGHT", 0, middle)
    local calendar = math.floor(size * CALENDAR + 0.5)
    rim.calendar:SetSize(calendar, calendar)
    rim.calendar:ClearAllPoints()
    rim.calendar:SetPoint("LEFT", view, "BOTTOMLEFT", 0, -middle)
    update_sign(rim.day, size)
    rim.day:SetPoint("RIGHT", view, "BOTTOMRIGHT", 0, -middle)
    rim.time:ClearAllPoints()
    rim.time:SetPoint("RIGHT", rim.day, "LEFT", -read_draft(6), -DIGIT_DROP)
    update_game_parts()
    update_over(MinimapCluster and MinimapCluster.Tracking, rim.glass)
    update_texts()
end

local function create_sign(widget, media)
    local sign = widget:CreateTexture(nil, "OVERLAY")
    sign:SetTexture(library.media .. media)
    sign:SetVertexColor(colours.ink[1], colours.ink[2], colours.ink[3], 1)
    return sign
end

local function render_calendar()
    if ToggleCalendar then
        ToggleCalendar()
    elseif Calendar_LoadUI then
        Calendar_LoadUI()
        if Calendar_Toggle then Calendar_Toggle() end
    end
end

local function render_calendar_safely()
    library.update_safely("map calendar", render_calendar)
end

local function create_calendar(widget)
    local calendar = CreateFrame("Button", "VGAMapCalendar", widget)
    calendar:SetFrameLevel(widget:GetFrameLevel() + 6)
    calendar.sign = create_sign(calendar, "Calendar")
    calendar.sign:SetAllPoints()
    calendar:SetScript("OnClick", render_calendar_safely)
    return calendar
end

function vga.create_map_rim(widget)
    rim = { widget = widget }
    rim.glass = create_sign(widget, "Search")
    rim.calendar = create_calendar(widget)
    rim.day = create_sign(widget, "DaySun")
    rim.zone = library.create_text(widget, "caption", colours.gold)
    rim.coords = library.create_text(widget, "small", colours.ink)
    rim.time = library.create_text(widget, "small", colours.ink)
    local tracking = MinimapCluster and MinimapCluster.Tracking
    if tracking then
        tracking:SetParent(widget)
        tracking:SetFrameLevel(widget:GetFrameLevel() + 6)
    end
    local ticker = CreateFrame("Frame", nil, widget)
    ticker:SetScript("OnUpdate", update_texts_safely)
end
