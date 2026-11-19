-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: Other addons' pins on the minimap - Questie's quest signs, a rare finder's marks - are placed by their libraries over the minimap's whole square, so where our frame cuts the map to its visible part they would stand on the frame; ten times a second every pin whose middle lies outside the visible map is made invisible and shown again the moment it comes back inside.

-- {K0435}

local _, vga = ...
local library = LibVGA
local EVERY = 0.1
local KEPT = { LibVGAMinimapButton = true, MinimapBackdrop = true }
local hidden = {}
local watch

local function read_edges(region)
    local scale = region:GetEffectiveScale()
    local left, right, top, bottom = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
    if not (left and right and top and bottom) then return nil end
    return left * scale, right * scale, top * scale, bottom * scale
end

local function check_inside(pin, edges)
    local across, down = pin:GetCenter()
    if not across then return true end
    local scale = pin:GetEffectiveScale()
    across, down = across * scale, down * scale
    return across >= edges[1] and across <= edges[2] and down <= edges[3] and down >= edges[4]
end

local function update_pin(pin, edges)
    local name = pin.GetName and pin:GetName()
    if name and KEPT[name] then return end
    local inside = check_inside(pin, edges)
    if not inside and not hidden[pin] then
        hidden[pin] = pin:GetAlpha()
        pin:SetAlpha(0)
    elseif inside and hidden[pin] then
        pin:SetAlpha(hidden[pin])
        hidden[pin] = nil
    end
end

local function update_pins()
    local left, right, top, bottom = read_edges(watch.view)
    if not left then return end
    local edges = { left, right, top, bottom }
    for _, pin in ipairs({ Minimap:GetChildren() }) do
        if pin:IsShown() then update_pin(pin, edges) end
    end
end

local function update_pins_safely(_, elapsed)
    watch.since = (watch.since or 0) + elapsed
    if watch.since < EVERY then return end
    watch.since = 0
    library.update_safely("map pins", update_pins)
end

function vga.create_map_pins(view)
    watch = CreateFrame("Frame", nil, view)
    watch.view = view
    watch:SetScript("OnUpdate", update_pins_safely)
end
