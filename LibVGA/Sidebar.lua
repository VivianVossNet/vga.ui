-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: LibVGA's sidebar as manual/view/vga-settings-apple.html draws it (K0565), in the way of the macOS System Settings: a column at the dialog's left on a faintly lighter ground, its entries in groups, each group under a small quiet heading in capitals, a last group set apart by a thin line without a heading; an entry a small picture and its word, the column as wide as its widest word needs with the same room after the word as before the picture (K0566), the chosen one on a gold rounded ground with dark ink, the others quiet, lighter under the mouse.

-- {K0565} {K0566}

local library = LibVGA
local colours = library.colours
local GROUND = { 1, 1, 1, 0.03 }
local LINE = { 0.137, 0.149, 0.173 }
local DARK = { 0.102, 0.078, 0.031 }
local HOVER = 0.06

local function update_entry_look(entry)
    local on = entry.sidebar.chosen == entry.key
    local ink = on and DARK or (entry.hovered and colours.ink or colours.label)
    entry.icon:SetVertexColor(ink[1], ink[2], ink[3], on and 0.7 or 1)
    entry.text:SetTextColor(ink[1], ink[2], ink[3], 1)
    entry.text:SetFontObject(library.read_font(on and "caption" or "body"))
    local fill = on and colours.gold or { 1, 1, 1 }
    library.update_surface(entry.ground, 0, library.read_size(-4), fill, fill, on and 1 or (entry.hovered and HOVER or 0))
end

local function update_entered(entry)
    entry.hovered = true
    update_entry_look(entry)
end

local function update_left(entry)
    entry.hovered = nil
    update_entry_look(entry)
end

local function render_chosen(entry)
    entry.sidebar.chosen = entry.key
    for _, other in ipairs(entry.sidebar.entries) do update_entry_look(other) end
    entry.sidebar.on_choose(entry.key)
end

local function create_entry(sidebar, item)
    local entry = CreateFrame("Button", nil, sidebar)
    entry.sidebar, entry.key = sidebar, item.key
    entry.ground = library.create_surface(entry, "BACKGROUND", 0)
    entry.icon = entry:CreateTexture(nil, "ARTWORK")
    entry.icon:SetTexture(library.media .. item.icon)
    entry.text = library.create_text(entry, "body")
    entry.text:SetText(item.title)
    entry:SetScript("OnEnter", update_entered)
    entry:SetScript("OnLeave", update_left)
    entry:SetScript("OnClick", render_chosen)
    return entry
end

function library.create_sidebar(parent, groups, on_choose)
    local sidebar = CreateFrame("Frame", nil, parent)
    sidebar.ground = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebar.ground:SetAllPoints()
    sidebar.ground:SetColorTexture(GROUND[1], GROUND[2], GROUND[3], GROUND[4])
    sidebar.edge = sidebar:CreateTexture(nil, "BORDER")
    sidebar.edge:SetColorTexture(LINE[1], LINE[2], LINE[3], 1)
    sidebar.on_choose, sidebar.groups, sidebar.entries = on_choose, {}, {}
    for index, group in ipairs(groups) do
        local made = { items = {} }
        if group.title then
            made.heading = library.create_text(sidebar, "caption", colours.quiet)
            made.heading:SetText(group.title:upper())
        else
            made.line = sidebar:CreateTexture(nil, "BORDER")
            made.line:SetColorTexture(LINE[1], LINE[2], LINE[3], 1)
        end
        for _, item in ipairs(group.entries) do
            local entry = create_entry(sidebar, item)
            made.items[#made.items + 1] = entry
            sidebar.entries[#sidebar.entries + 1] = entry
        end
        sidebar.groups[index] = made
    end
    return sidebar
end

function library.read_sidebar_width(sidebar)
    local widest, pad = 0, library.read_size(-2)
    for _, entry in ipairs(sidebar.entries) do
        for _, font in ipairs({ "caption", "body" }) do
            entry.text:SetFontObject(library.read_font(font))
            widest = math.max(widest, math.ceil(entry.text:GetStringWidth()))
        end
        entry.text:SetFontObject(library.read_font(sidebar.chosen == entry.key and "caption" or "body"))
    end
    return 2 * pad + library.read_size(0) + pad + widest + 2 * pad + 1
end

local function update_heading(sidebar, made, top, pad)
    if made.heading then
        made.heading:SetFontObject(library.read_font("caption"))
        made.heading:ClearAllPoints()
        made.heading:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 2 * pad, -top - pad)
        return top + pad + math.ceil(made.heading:GetStringHeight()) + pad / 2
    end
    made.line:ClearAllPoints()
    made.line:SetPoint("TOPLEFT", sidebar, "TOPLEFT", pad, -top - pad)
    made.line:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -pad, -top - pad)
    made.line:SetHeight(1)
    return top + 2 * pad
end

function library.update_sidebar(sidebar, chosen)
    sidebar.chosen = chosen or sidebar.chosen
    local pad, height, icon = library.read_size(-2), library.read_size(3), library.read_size(0)
    local top = pad
    for _, made in ipairs(sidebar.groups) do
        top = update_heading(sidebar, made, top, pad)
        for _, entry in ipairs(made.items) do
            entry:ClearAllPoints()
            entry:SetPoint("TOPLEFT", sidebar, "TOPLEFT", pad, -top)
            entry:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -pad, -top)
            entry:SetHeight(height)
            entry.icon:SetSize(icon, icon)
            entry.icon:ClearAllPoints()
            entry.icon:SetPoint("LEFT", entry, "LEFT", pad, 0)
            entry.text:ClearAllPoints()
            entry.text:SetPoint("LEFT", entry.icon, "RIGHT", pad, 0)
            update_entry_look(entry)
            top = top + height + 2
        end
    end
    sidebar.edge:ClearAllPoints()
    sidebar.edge:SetPoint("TOPRIGHT")
    sidebar.edge:SetPoint("BOTTOMRIGHT")
    sidebar.edge:SetWidth(1)
    return top + pad
end
