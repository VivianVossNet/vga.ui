-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: Where the bags stand and how large: their size small, normal or large as the settings choose, the whole dialog scaled in proportion; their place kept where they were dragged, across a reload and through a change of size; and the pin in their head beside the close button, which fixes the place so the dialog can no longer be dragged, gold while it holds, its meaning in a tooltip.

-- {K0415}

local _, vga = ...
local library = LibVGA
local colours = library.colours

local function read_scale()
    return (library.read_size_step("bags"))
end

local function update_anchor(bags)
    local scale, place = read_scale(), LibVGASettings.bags_place
    bags:SetScale(scale)
    bags:ClearAllPoints()
    if place then
        bags:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", place[1] / scale, place[2] / scale)
    else
        bags:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -library.read_size(6) / scale, library.read_size(12) / scale)
    end
end

local function update_pin_look(bags)
    local pinned, colour = LibVGASettings.bags_pinned, colours.quiet
    if pinned then colour = colours.gold end
    bags.pin.icon:SetVertexColor(colour[1], colour[2], colour[3], 1)
    bags:SetMovable(not pinned)
end

local function update_dragged(bags)
    if LibVGASettings.bags_pinned then return end
    bags:StartMoving()
end

local function write_place(bags)
    bags:StopMovingOrSizing()
    local scale = read_scale()
    LibVGASettings.bags_place = { bags:GetLeft() * scale, bags:GetTop() * scale }
    update_anchor(bags)
end

local function render_pin_tip(pin)
    local texts = library.texts
    GameTooltip:SetOwner(pin, "ANCHOR_TOP")
    GameTooltip:AddLine(LibVGASettings.bags_pinned and texts.unpin_place or texts.pin_place, colours.ink[1], colours.ink[2], colours.ink[3])
    GameTooltip:Show()
end

local function update_tip_left()
    GameTooltip:Hide()
end

local function write_pinned(pin)
    LibVGASettings.bags_pinned = not LibVGASettings.bags_pinned or nil
    update_pin_look(pin:GetParent())
    render_pin_tip(pin)
end

function vga.create_bag_place(bags)
    bags.pin = library.create_dialog_button(bags, "Pin", write_pinned)
    bags.pin:SetScript("OnEnter", render_pin_tip)
    bags.pin:SetScript("OnLeave", update_tip_left)
    bags:SetScript("OnDragStart", update_dragged)
    bags:SetScript("OnDragStop", write_place)
end

function vga.update_bag_place(bags)
    update_anchor(bags)
    update_pin_look(bags)
end
