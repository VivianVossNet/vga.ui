-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: LibVGA's tabs as the accepted draft draws them (manual/view/vga-settings.html, .tabs): a band across the dialog, each tab a picture over a word, all of one width; the chosen one gold, underlined in gold over a faint gold glow, the others quiet.

-- {K0383}

local library = LibVGA
local colours = library.colours
local BAND = { 0.067, 0.071, 0.082 }

function library.create_tabs(parent, entries, on_choose)
    local tabs = CreateFrame("Frame", nil, parent)
    tabs.band = tabs:CreateTexture(nil, "BACKGROUND")
    tabs.band:SetAllPoints()
    tabs.band:SetColorTexture(BAND[1], BAND[2], BAND[3], 1)
    tabs.line = tabs:CreateTexture(nil, "BORDER")
    tabs.line:SetColorTexture(0.137, 0.149, 0.173, 1)
    tabs.buttons = {}
    for index, entry in ipairs(entries) do
        local tab = CreateFrame("Button", nil, tabs)
        tab.glow = tab:CreateTexture(nil, "BACKGROUND", nil, 1)
        tab.glow:SetColorTexture(1, 1, 1, 1)
        tab.under = tab:CreateTexture(nil, "ARTWORK")
        tab.under:SetColorTexture(colours.gold[1], colours.gold[2], colours.gold[3], 1)
        tab.icon = tab:CreateTexture(nil, "ARTWORK")
        tab.icon:SetTexture(library.media .. entry.icon)
        tab.text = library.create_text(tab, "small")
        tab.text:SetText(entry.title)
        tab:SetScript("OnClick", function()
            tabs.chosen = index
            library.update_tabs(tabs)
            on_choose(index)
        end)
        tabs.buttons[index] = tab
    end
    tabs.chosen = 1
    return tabs
end

function library.read_tabs_width(tabs)
    local widest = 0
    for _, tab in ipairs(tabs.buttons) do
        tab.text:SetFontObject(library.read_font("small"))
        widest = math.max(widest, math.ceil(tab.text:GetStringWidth()))
    end
    return #tabs.buttons * (widest + 2 * library.read_size(-2))
end

function library.update_tabs(tabs)
    local width = tabs:GetWidth() / #tabs.buttons
    local icon, pad = library.read_size(1), library.read_size(-4)
    for index, tab in ipairs(tabs.buttons) do
        local on = index == tabs.chosen
        local ink = on and colours.gold or colours.quiet
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", tabs, "TOPLEFT", math.floor((index - 1) * width + 0.5), 0)
        tab:SetSize(math.floor(width + 0.5), tabs:GetHeight())
        tab.icon:SetSize(icon, icon)
        tab.icon:ClearAllPoints()
        tab.icon:SetPoint("TOP", tab, "TOP", 0, -pad - 1)
        tab.icon:SetVertexColor(ink[1], ink[2], ink[3], 1)
        tab.text:SetFontObject(library.read_font("small"))
        tab.text:SetTextColor(ink[1], ink[2], ink[3], 1)
        tab.text:ClearAllPoints()
        tab.text:SetPoint("TOP", tab.icon, "BOTTOM", 0, -math.max(2, library.read_size(-6)))
        tab.under:ClearAllPoints()
        tab.under:SetPoint("BOTTOMLEFT")
        tab.under:SetPoint("BOTTOMRIGHT")
        tab.under:SetHeight(2)
        tab.under:SetShown(on)
        tab.glow:SetAllPoints()
        tab.glow:SetGradient("VERTICAL", CreateColor(colours.gold[1], colours.gold[2], colours.gold[3], 0), CreateColor(colours.gold[1], colours.gold[2], colours.gold[3], 0.07))
        tab.glow:SetShown(on)
    end
    tabs.line:ClearAllPoints()
    tabs.line:SetPoint("BOTTOMLEFT")
    tabs.line:SetPoint("BOTTOMRIGHT")
    tabs.line:SetHeight(1)
end

function library.read_tabs_height()
    return library.read_size(1) + library.read_size(0) + 2 * library.read_size(-4) + 4
end
