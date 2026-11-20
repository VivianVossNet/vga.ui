-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The combo points of a rogue, and of a druid in cat form - in Forever they stay on the foe they were gained on, kept there when the target changes, gone when it dies -: the points on the current target earned in VGA's orange, points still held on another foe, read from the player's power, as dimmed orange beyond them, so a turn back is seen to pay -, on the player frame: a row of five flat pills centred under the power bar, halfway between the bar and the frame's lower edge, the earned ones in VGA's orange, the open ones dark, each in a black line; the frame's lines are centred anew with the row's room kept for these classes alone, so a druid's change of form moves nothing; Blizzard's own combo frame stays hidden.

-- {K0416} {K0417} {K0420} {K0502} {K0520} {K0532}

local _, vga = ...
local library = LibVGA
local colours = library.colours
local COMBO = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
local ENERGY = 3
local POINTS = 5
local OPEN = { 0.2, 0.21, 0.24 }
local OPEN_LOW = { 0.11, 0.12, 0.14 }
local HELD = { 0.42, 0.25, 0.1 }
local HELD_LOW = { 0.25, 0.14, 0.06 }
local EDGE = { 0, 0, 0 }
local KEEPING = { ROGUE = true, DRUID = true }
local row

local function check_keeping()
    local _, class = UnitClass("player")
    return KEEPING[class or ""] == true
end

local function check_shown()
    local _, class = UnitClass("player")
    if class == "ROGUE" then return true end
    return class == "DRUID" and UnitPowerType("player") == ENERGY
end

local function read_known(ran, points)
    if not ran or type(points) ~= "number" or (issecretvalue and issecretvalue(points)) then return nil end
    return points
end

function vga.read_combo_points()
    local ran, points = pcall(UnitPower, "player", COMBO)
    if not check_shown() then return nil end
    local held = read_known(ran, points)
    local on_target = GetComboPoints and read_known(pcall(GetComboPoints, "player", "target"))
    if not (held or on_target) then return nil end
    if not on_target then return held, held end
    return on_target, math.max(held or 0, on_target)
end

local function read_sizes()
    local height = library.read_size(-5)
    return 3 * height, height, library.read_size(-6)
end

local function read_drop(frame, height, between)
    local bar_foot, frame_foot = frame.power:GetBottom(), frame:GetBottom()
    if not (bar_foot and frame_foot) or bar_foot - frame_foot <= height then return between end
    return math.floor((bar_foot - frame_foot - height) / 2 + 0.5)
end

local function update_pill(pill, earned, held, width, height)
    local top, bottom = OPEN, OPEN_LOW
    if held then top, bottom = HELD, HELD_LOW end
    if earned then top, bottom = colours.orange, colours.orange_low end
    pill:SetSize(width, height)
    library.update_surface(pill.edge, -1, height / 2 + 1, EDGE, EDGE)
    library.update_surface(pill.face, 0, height / 2, top, bottom)
end

local function update_row()
    if not row then return end
    local frame = VGAUnitFrame_player
    local width, height, between = read_sizes()
    local gap = library.read_size(-6)
    local shown = check_shown()
    local points, held = vga.read_combo_points()
    points, held = points or 0, held or 0
    local span = POINTS * width + (POINTS - 1) * gap
    frame.extra_height = height + between
    local drop = read_drop(frame, height, between)
    for index, pill in ipairs(row) do
        update_pill(pill, index <= points, index <= held, width, height)
        pill:ClearAllPoints()
        pill:SetPoint("TOPLEFT", frame.power, "BOTTOM", -span / 2 + (index - 1) * (width + gap), -drop)
        pill:SetShown(shown)
    end
end

local function update_row_safely()
    library.update_safely("combo points", update_row)
end

local function create_row()
    local frame = VGAUnitFrame_player
    if not (frame and frame.power and check_keeping()) then return end
    row = {}
    for index = 1, POINTS do
        local pill = CreateFrame("Frame", nil, frame)
        pill.edge = library.create_surface(pill, "ARTWORK", 0)
        pill.face = library.create_surface(pill, "ARTWORK", 1)
        row[index] = pill
    end
    local _, height, between = read_sizes()
    frame.extra_height = height + between
    library.create_element("combo", { update = update_row })
    library.update_elements()
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_LOGIN", "UNIT_POWER_UPDATE", "UNIT_DISPLAYPOWER", "UNIT_MAXPOWER", "PLAYER_TARGET_CHANGED" }) do
    events:RegisterEvent(name)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        library.update_safely("combo points login", create_row)
    else
        update_row_safely()
    end
end)
