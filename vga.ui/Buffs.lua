-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The player's buffs as the accepted draft draws .buffs and .buff (manual/view/vga-probe.html): icons with rounded corners in a black line, the time left small beneath each; from the player frame's left edge above it to the right, as many to a row as the frame's width holds, two rows at most; Blizzard's own buff frame hidden. When the game refuses the auras in a fight, the icons shown stay.

-- {K0261} {K0355}

local library = LibVGA
local colours = library.colours
local ROWS = 2
local SLOTS = 40
local BLACK = { 0, 0, 0 }
local buffs

local function create_icon()
    local icon = CreateFrame("Frame", nil, buffs)
    icon.line = icon:CreateTexture(nil, "BACKGROUND")
    icon.line:SetAllPoints()
    icon.line:SetColorTexture(0, 0, 0, 1)
    icon.art = icon:CreateTexture(nil, "ARTWORK")
    icon.art:SetPoint("TOPLEFT", 1, -1)
    icon.art:SetPoint("BOTTOMRIGHT", -1, 1)
    icon.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.notches = library.create_notches(icon, "OVERLAY", 0)
    icon.count = library.create_text(icon, "caption")
    icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    icon.time = library.create_text(icon, "small", colours.ink)
    icon.time:SetPoint("TOP", icon, "BOTTOM", 0, -2)
    icon:Hide()
    return icon
end

local function render_time(data)
    local ends = data.expirationTime
    if not ends or (issecretvalue and issecretvalue(ends)) or ends == 0 then return "" end
    local left = math.max(0, ends - GetTime())
    if left >= 3600 then return math.floor(left / 3600 + 0.5) .. " " .. library.texts.hours end
    if left >= 60 then return math.floor(left / 60 + 0.5) .. " " .. library.texts.minutes end
    return math.floor(left) .. " " .. library.texts.seconds
end

local function read_buffs()
    local found = {}
    for index = 1, SLOTS do
        local readable, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
        if not readable then return nil end
        if not data then break end
        found[#found + 1] = data
    end
    return found
end

local function update_buffs_layout(count)
    local frame = VGAUnitFrame_player
    if not frame then return 0 end
    local size, gap = library.read_size(3), library.read_size(-4)
    local per_row = math.max(1, math.floor((frame:GetWidth() + gap) / (size + gap)))
    local row_height = size + library.read_size(-1) + 2 + gap
    buffs:ClearAllPoints()
    buffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, gap)
    buffs:SetSize(frame:GetWidth(), ROWS * row_height)
    for index, icon in ipairs(buffs.icons) do
        local row, column = math.floor((index - 1) / per_row), (index - 1) % per_row
        icon:ClearAllPoints()
        icon:SetSize(size, size)
        icon:SetPoint("BOTTOMLEFT", buffs, "BOTTOMLEFT", column * (size + gap), row * row_height + library.read_size(-1) + 2)
        library.update_notches(icon.notches, icon, library.read_size(-4), BLACK)
        icon.time:SetFontObject(library.read_frame_font("small"))
        icon.count:SetFontObject(library.read_frame_font("caption"))
    end
    return math.min(count, per_row * ROWS)
end

local function update_buffs()
    local found = read_buffs()
    if not found then return end
    local shown = update_buffs_layout(#found)
    for index, icon in ipairs(buffs.icons) do
        local data = index <= shown and found[index]
        icon:SetShown(data and true or false)
        if data then
            icon.art:SetTexture(data.icon)
            icon.time:SetText(render_time(data))
            local stacks = data.applications
            icon.count:SetText((not (issecretvalue and issecretvalue(stacks)) and stacks and stacks > 1) and stacks or "")
        end
    end
end

local function update_times()
    library.update_safely("buffs time", update_buffs)
end

local function create_buffs()
    buffs = CreateFrame("Frame", "VGABuffs", UIParent)
    buffs.icons = {}
    for index = 1, ROWS * 16 do buffs.icons[index] = create_icon() end
    if BuffFrame then
        BuffFrame:UnregisterAllEvents()
        BuffFrame:Hide()
        BuffFrame:SetAlpha(0)
    end
    C_Timer.NewTicker(1, update_times)
    library.create_element("buffs", { update = update_buffs })
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        library.update_safely("buffs login", create_buffs)
    elseif buffs then
        library.update_safely("buffs", update_buffs)
    end
end)
