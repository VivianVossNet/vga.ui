-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The player's buffs as the accepted draft draws .buffs and .buff (manual/view/vga-probe.html): icons with rounded corners in a black line, the time left small beneath each; from the player frame's left edge above it to the right, as many to a row as the frame's width holds, two rows at most; Blizzard's own buff frame hidden. Above the target frame the same, mirrored as the target frame is, from its right edge to the left: the target's buffs, then on a row of their own its debuffs, in a fine red line (K0580). Both are the game's own aura containers (K0584), which the game fills itself, in a fight too, where an addon may not read auras: each icon shows the game's tooltip of its aura under the mouse, and a click on one of the player's own buffs ends it; the time beneath each written short, one letter for its unit, in the smallest face, so neighbours do not run into each other (K0588); a dead target's auras are hidden, and so are the last target's once none is chosen (K0585, K0586).

-- {K0261} {K0355} {K0580} {K0584} {K0585} {K0586} {K0588}

local library = LibVGA
local colours = library.colours
local ROWS = 2
local BLACK = { 0, 0, 0 }
local HARM = { 0.75, 0.16, 0.14 }
local GROW = { right = 1, left = -1, up = 1 }
local STRIPS = {
    { unit = "player", frame = "VGAUnitFrame_player", name = "VGABuffs", corner = "BOTTOMLEFT", grow = GROW.right, groups = { { key = "buffs", filter = "HELPFUL", line = BLACK, cancel = true } } },
    { unit = "target", frame = "VGAUnitFrame_target", name = "VGATargetAuras", corner = "BOTTOMRIGHT", grow = GROW.left, groups = { { key = "buffs", filter = "HELPFUL", line = BLACK }, { key = "debuffs", filter = "HARMFUL", line = HARM } } },
}
local strips = {}

local function read_icon_size()
    return library.read_size(3), library.read_size(-4)
end

local function create_time_formatter()
    local formatter = C_StringUtil.CreateSecondsFormatter()
    formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
    formatter:SetRounding(Enum.SecondsFormatterRounding.Truncate)
    formatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
    formatter:SetDesiredUnitCount(1)
    return formatter
end

local function update_time_text(button)
    local made, formatter = pcall(create_time_formatter)
    if made and pcall(button.SetDurationText, button, button.time, { textFormatter = formatter }) then return end
    button:SetDurationText(button.time)
end

local function update_button_look(button)
    local size = read_icon_size()
    button.line:SetColorTexture(button.colour[1], button.colour[2], button.colour[3], 1)
    library.update_notches(button.notches, button, library.read_size(-4), button.colour)
    button.time:SetFontObject(library.read_frame_font("tiny"))
    button.count:SetFontObject(library.read_frame_font("caption"))
    button:SetSize(size, size)
end

local function create_button_parts(button, group)
    button.colour = group.line
    button.line = button:CreateTexture(nil, "BACKGROUND")
    button.line:SetAllPoints()
    button.art = button:CreateTexture(nil, "ARTWORK")
    button.art:SetPoint("TOPLEFT", 1, -1)
    button.art:SetPoint("BOTTOMRIGHT", -1, 1)
    button.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.notches = library.create_notches(button, "OVERLAY", 0)
    button.count = library.create_text(button, "caption")
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    button.time = library.create_text(button, "small", colours.ink)
    button.time:SetPoint("TOP", button, "BOTTOM", 0, -2)
    button:SetIcon(button.art)
    update_time_text(button)
    button:SetApplicationCount(button.count)
    if group.cancel then button:SetCancelAuraButtons("LeftButtonUp RightButtonUp") end
    update_button_look(button)
end

local function create_initializer(strip, group)
    return function(button)
        create_button_parts(button, group)
        strip.buttons[#strip.buttons + 1] = button
    end
end

local function read_group_layout(index)
    local size, gap = read_icon_size()
    return { elementWidth = size, elementHeight = size, elementSpacing = gap, lineSpacing = library.read_size(-1) + 2 + gap, forceNewLine = index > 1, layoutIndex = index }
end

local function update_strip(strip)
    local frame = _G[strip.frame]
    if not frame or InCombatLockdown() then return end
    local size, gap = read_icon_size()
    local per_row = math.max(1, math.floor((frame:GetWidth() + gap) / (size + gap)))
    local container = strip.container
    container:ClearAllPoints()
    container:SetPoint(strip.corner, frame, strip.corner == "BOTTOMLEFT" and "TOPLEFT" or "TOPRIGHT", 0, gap + library.read_size(-1) + 2)
    container:SetFlowLayoutMaximumLineSize(frame:GetWidth())
    for index, group in ipairs(strip.groups) do
        container:SetAuraGroupLayout(group.key, read_group_layout(index))
        container:SetAuraGroupMaxFrameCount(group.key, per_row * ROWS)
    end
    for _, button in ipairs(strip.buttons) do pcall(update_button_look, button) end
end

local function update_dead_target()
    for _, strip in ipairs(strips) do
        if strip.unit == "target" then strip.container:SetAlpha((UnitExists("target") and not UnitIsDead("target")) and 1 or 0) end
    end
end

local function update_buffs()
    for _, strip in ipairs(strips) do update_strip(strip) end
    update_dead_target()
end

local function create_strip(shape)
    local strip = { unit = shape.unit, frame = shape.frame, corner = shape.corner, groups = shape.groups, buttons = {} }
    local container = CreateFrame("AuraContainer", shape.name, UIParent, "CustomAuraContainerTemplate")
    container:SetUnit(shape.unit)
    container:SetFlowLayoutAnchorPoint(shape.corner)
    container:SetFlowLayoutGrowthDirection(shape.grow, GROW.up)
    for index, group in ipairs(shape.groups) do
        container:AddAuraGroup(group.key, group.filter, { initializeFrame = create_initializer(strip, group), layout = read_group_layout(index) })
    end
    strip.container = container
    strips[#strips + 1] = strip
end

local function create_buffs()
    for _, shape in ipairs(STRIPS) do create_strip(shape) end
    if BuffFrame then
        BuffFrame:UnregisterAllEvents()
        BuffFrame:Hide()
        BuffFrame:SetAlpha(0)
    end
    library.create_element("buffs", { update = update_buffs })
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
pcall(events.RegisterUnitEvent, events, "UNIT_HEALTH", "target")
pcall(events.RegisterUnitEvent, events, "UNIT_FLAGS", "target")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        library.update_safely("buffs login", create_buffs)
    else
        library.update_safely("buffs dead target", update_dead_target)
    end
end)
