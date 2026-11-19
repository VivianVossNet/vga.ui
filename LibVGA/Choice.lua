-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: LibVGA's segmented choice, the chosen part in gold; one size for every part, the weight alone changing, every part as wide as the widest in its bold state, or as a given width allows, so a choice moves nothing; a part may show an icon in place of its word, the word then its tooltip; the parts joined over a black ground, its outer corners rounded, as vga-scale.html and vga-probe.html's .vt-seg draw it.

-- {K0256} {K0330} {K0334} {K0337} {K0409}

local library = LibVGA
local colours = library.colours

local function render_tip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:AddLine(button.tip, colours.ink[1], colours.ink[2], colours.ink[3])
    GameTooltip:Show()
end

local function update_tip_left()
    GameTooltip:Hide()
end

local function create_icon(button, label)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(library.media .. label.icon)
    button.icon:SetPoint("CENTER")
    button.tip = label.tip
    button:SetScript("OnEnter", render_tip)
    button:SetScript("OnLeave", update_tip_left)
end

local function read_part_width(button, pad)
    if button.icon then return library.read_size(1) + 2 * pad end
    return math.ceil(button.text:GetStringWidth()) + 2 * pad
end

function library.create_choice(parent, labels, chosen, on_choose)
    local choice = CreateFrame("Frame", nil, parent)
    choice.ground = library.create_surface(choice, "BACKGROUND", 0)
    choice.rounding = CreateFrame("Frame", nil, choice)
    choice.rounding:SetAllPoints()
    choice.rounding:SetFrameLevel(choice:GetFrameLevel() + 3)
    choice.notches = library.create_notches(choice.rounding, "OVERLAY", 0)
    choice.buttons = {}
    for index, label in ipairs(labels) do
        local button = CreateFrame("Button", nil, choice)
        button.face = button:CreateTexture(nil, "BACKGROUND")
        button.face:SetAllPoints()
        button.face:SetColorTexture(1, 1, 1, 1)
        button.text = library.create_text(button, "small")
        button.text:SetPoint("CENTER")
        if type(label) == "table" then create_icon(button, label) else button.text:SetText(label) end
        button:SetScript("OnClick", function()
            choice.chosen = index
            library.update_choice(choice)
            on_choose(index)
        end)
        choice.buttons[index] = button
    end
    choice.chosen = chosen
    return choice
end

function library.read_choice_width(choice)
    local pad, widest = library.read_size(-2), 0
    for _, button in ipairs(choice.buttons) do
        button.text:SetFontObject(library.read_font("caption"))
        widest = math.max(widest, read_part_width(button, pad))
    end
    return widest * #choice.buttons + #choice.buttons - 1
end

function library.update_choice(choice, wanted)
    choice.wanted = wanted or choice.wanted
    wanted = choice.wanted
    local height, count = library.read_size(2), #choice.buttons
    local width = math.floor((math.max(wanted or 0, library.read_choice_width(choice)) - (count - 1)) / count)
    local x = 0
    for index, button in ipairs(choice.buttons) do
        button.text:SetFontObject(library.read_font(index == choice.chosen and "caption" or "small"))
        button:ClearAllPoints()
        button:SetSize(width, height)
        button:SetPoint("LEFT", choice, "LEFT", x, 0)
        x = x + width + 1
        if index == choice.chosen then
            button.face:SetGradient("VERTICAL", CreateColor(0.765, 0.588, 0.184, 1), CreateColor(colours.gold_high[1], colours.gold_high[2], colours.gold_high[3], 1))
            button.text:SetTextColor(0.102, 0.082, 0.043)
            if button.icon then button.icon:SetVertexColor(0.102, 0.082, 0.043, 1) end
        else
            button.face:SetGradient("VERTICAL", CreateColor(0.125, 0.133, 0.153, 1), CreateColor(0.173, 0.184, 0.208, 1))
            button.text:SetTextColor(unpack(colours.quiet))
            if button.icon then button.icon:SetVertexColor(colours.quiet[1], colours.quiet[2], colours.quiet[3], 1) end
        end
        if button.icon then button.icon:SetSize(library.read_size(1), library.read_size(1)) end
    end
    choice:SetSize(x - 1, height)
    local radius = library.read_size(-6)
    library.update_surface(choice.ground, -1, radius + 1, { 0, 0, 0 }, { 0, 0, 0 })
    library.update_notches(choice.notches, choice, radius, { 0, 0, 0 })
end
