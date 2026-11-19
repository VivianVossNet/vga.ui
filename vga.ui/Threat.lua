-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The threat the player draws from the target, as five bars rising like a wifi sign above the target frame's top right: each bar appearing whole once the threat passes the start of its fifth - like a wifi sign, no bar half filled -, set by the game from the value even where it is secret, each bar's range a hundredth wide; grey, white, gold, bronze, red. Shown only while the player stands on the target's threat list.

-- {K0344} {K0356} {K0357} {K0366}

local library = LibVGA
local STEP = 0.01
local meter

local function create_meter()
    meter = CreateFrame("Frame", nil, UIParent)
    meter.bars = {}
    for index, top in ipairs(library.colours.steps) do
        local colour = { top, { top[1] * 0.62, top[2] * 0.62, top[3] * 0.62 } }
        local bar = CreateFrame("StatusBar", nil, meter)
        bar:SetOrientation("VERTICAL")
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        bar:GetStatusBarTexture():SetGradient("VERTICAL", library.create_colour(colour[2]), library.create_colour(colour[1]))
        bar:SetMinMaxValues(20 * (index - 1), 20 * (index - 1) + STEP)
        bar:SetValue(0)
        bar.line = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        bar.line:SetPoint("TOPLEFT", -1, 1)
        bar.line:SetPoint("BOTTOMRIGHT", 1, -1)
        bar.line:SetColorTexture(0, 0, 0, 1)
        bar.back = bar:CreateTexture(nil, "BACKGROUND")
        bar.back:SetAllPoints()
        bar.back:SetColorTexture(0.031, 0.035, 0.043, 1)
        meter.bars[index] = bar
    end
end

local function update_meter_layout()
    local frame = VGAUnitFrame_target
    if not frame or not meter then return end
    local base, gap = library.read_base(), library.read_size(-4)
    local width = math.max(2, library.read_size(-6))
    meter:ClearAllPoints()
    meter:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -library.read_size(-2), gap)
    meter:SetSize(5 * width + 4 * (width - 1), math.floor(base * 1.08 + 0.5))
    for index, bar in ipairs(meter.bars) do
        bar:ClearAllPoints()
        bar:SetSize(width, math.floor(base * (0.36 + 0.18 * (index - 1)) + 0.5))
        bar:SetPoint("BOTTOMLEFT", meter, "BOTTOMLEFT", (index - 1) * (2 * width - 1), 0)
    end
end

local function update_meter_value()
    if not meter then return end
    local status = UnitExists("target") and UnitThreatSituation("player", "target")
    local listed = (issecretvalue and issecretvalue(status)) or status ~= nil
    local shown = UnitExists("target") and UnitCanAttack("player", "target") and listed
    meter:SetShown(shown and true or false)
    if not shown then return end
    local _, _, share = UnitDetailedThreatSituation("player", "target")
    for _, bar in ipairs(meter.bars) do
        bar:SetValue(share or 0)
    end
end

local function update_threat()
    update_meter_layout()
    update_meter_value()
end

local function update_event(event)
    if event == "PLAYER_LOGIN" then
        create_meter()
        library.create_element("threat", { update = update_threat })
    else
        update_meter_value()
    end
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_LOGIN", "PLAYER_TARGET_CHANGED", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE" }) do
    pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", function(_, event)
    library.update_safely("threat " .. event, update_event, event)
end)
