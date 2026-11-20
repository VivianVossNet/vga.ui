-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The quest tracker's zones as manual/view/vga-questzones.html draws B (K0547): with »Zonen: Alle« on the tab Quests the watched quests are grouped by their zone, each group under a label of its own - a thin line above it, a chevron, the zone's name in small capitals and the count of its quests at the right, all in VGA's orange -; the zone the player stands in first, always open, its name followed by a quiet »· hier«; the others by name, closed, a click on one opening it and closing the one opened before, a second click closing it again. With »Aktuelle«, the default, the tracker shows the player's zone alone, as before. Quests.lua lays the groups.

-- {K0547}

local _, vga = ...
local library = LibVGA
local colours = library.colours
local DRAFT_BASE = 13
local LABEL_HEIGHT = 26
local CHEVRON = 9
local QUIET = "|cff9a968c"
local CAPITALS = { ["ä"] = "Ä", ["ö"] = "Ö", ["ü"] = "Ü", ["é"] = "É", ["è"] = "È", ["à"] = "À", ["ç"] = "Ç", ["ñ"] = "Ñ" }
local LINE = { 0.173, 0.184, 0.208 }
local open_zone

local function read_draft(pixels)
    return math.floor(pixels * library.read_base() / DRAFT_BASE + 0.5)
end

function vga.check_all_zones()
    return LibVGASettings.quest_zones == "all"
end

local function render_capitals(name)
    local upper = name:upper()
    for small, capital in pairs(CAPITALS) do upper = upper:gsub(small, capital) end
    return upper
end

local function check_group_before(one, other)
    if one.here ~= other.here then return one.here end
    return one.name < other.name
end

function vga.read_zone_groups(quests, here_name)
    local groups, by_name = {}, {}
    for _, quest in ipairs(quests) do
        local name = quest.here and here_name or quest.zone or library.texts.other_zone
        local group = by_name[name]
        if not group then
            group = { name = name, here = quest.here and true or false, quests = {} }
            by_name[name] = group
            groups[#groups + 1] = group
        end
        group.here = group.here or (quest.here and true or false)
        group.quests[#group.quests + 1] = quest
    end
    table.sort(groups, check_group_before)
    return groups
end

function vga.check_zone_open(group)
    return group.here or group.name == open_zone
end

local function render_toggle(label)
    open_zone = open_zone ~= label.zone and label.zone or nil
    if vga.update_quest_tracker then vga.update_quest_tracker() end
end

local function render_toggle_safely(label)
    library.update_safely("quest zone", render_toggle, label)
end

function vga.create_zone_label(parent)
    local label = CreateFrame("Button", nil, parent)
    label.line = label:CreateTexture(nil, "BACKGROUND")
    label.line:SetColorTexture(LINE[1], LINE[2], LINE[3], 1)
    label.chevron = label:CreateTexture(nil, "ARTWORK")
    label.chevron:SetTexture(library.media .. "NaviChevron")
    label.chevron:SetTexCoord(0, 1, 0.25, 0.75)
    label.chevron:SetVertexColor(colours.orange[1], colours.orange[2], colours.orange[3], 1)
    label.name = library.create_text(label, "caption", colours.orange)
    label.count = library.create_text(label, "small", colours.orange)
    label:SetScript("OnClick", render_toggle_safely)
    return label
end

function vga.update_zone_label(label, group, top, width)
    local pad, height, chevron = read_draft(12), read_draft(LABEL_HEIGHT), read_draft(CHEVRON)
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", label:GetParent(), "TOPLEFT", 0, -(top - (label:GetParent().top or 0)))
    label:SetSize(width, height)
    label:Show()
    label.zone = group.name
    label.line:ClearAllPoints()
    label.line:SetPoint("TOPLEFT")
    label.line:SetPoint("TOPRIGHT")
    label.line:SetHeight(1)
    label.chevron:SetSize(chevron, math.floor(chevron / 2 + 0.5))
    label.chevron:ClearAllPoints()
    label.chevron:SetPoint("LEFT", label, "LEFT", pad, 0)
    label.chevron:SetRotation(vga.check_zone_open(group) and math.pi or -math.pi / 2)
    label.name:SetFontObject(library.read_frame_font("caption"))
    label.name:SetText(render_capitals(group.name) .. (group.here and (QUIET .. " · " .. library.texts.here_zone .. "|r") or ""))
    label.name:ClearAllPoints()
    label.name:SetPoint("LEFT", label, "LEFT", pad + read_draft(12) + read_draft(8), 0)
    label.count:SetFontObject(library.read_frame_font("small"))
    label.count:SetText(#group.quests)
    label.count:ClearAllPoints()
    label.count:SetPoint("RIGHT", label, "RIGHT", -pad, 0)
    return height
end
