-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: LibVGA's collision measure in the game (K0512): `/vga overlap` reads the real rectangle of every visible, named frame up to three levels beneath UIParent - ours and Blizzard's alike -, in the screen's units after every scale, and reports each pair that overlaps by more than a unit both ways, unless one holds the other; frames almost as large as the screen and those drawn nearly invisible are left out. The result is written to the chat and kept in LibVGASettings.measures.overlaps under the size setting, with the screen, so it is read after the game has saved.

-- {K0512}

local library = LibVGA
local DEPTH = 3
local LEAST = 1
local MOST_SHARE = 0.6
local LEAST_ALPHA = 0.05
local SHOWN_LINES = 12

local function read_rect(frame)
    local left, bottom, width, height = frame:GetRect()
    if not left or width < 2 or height < 2 then return nil end
    local share = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return { left * share, bottom * share, (left + width) * share, (bottom + height) * share }
end

local function check_counted(frame, rect)
    if not (rect and frame:GetName() and frame:IsVisible()) then return false end
    if frame.GetEffectiveAlpha and frame:GetEffectiveAlpha() < LEAST_ALPHA then return false end
    local screen = UIParent:GetWidth() * UIParent:GetHeight()
    return (rect[3] - rect[1]) * (rect[4] - rect[2]) < screen * MOST_SHARE
end

local function read_frames(parent, depth, found)
    if depth > DEPTH then return found end
    for _, child in ipairs({ parent:GetChildren() }) do
        if child:IsVisible() then
            local rect = read_rect(child)
            if check_counted(child, rect) then found[#found + 1] = { frame = child, rect = rect } end
            read_frames(child, depth + 1, found)
        end
    end
    return found
end

local function check_holding(one, other)
    local parent = other:GetParent()
    while parent do
        if parent == one then return true end
        parent = parent:GetParent()
    end
    return false
end

local function read_overlap(one, other)
    local width = math.min(one[3], other[3]) - math.max(one[1], other[1])
    local height = math.min(one[4], other[4]) - math.max(one[2], other[2])
    return width, height
end

local function read_overlaps(frames)
    local overlaps = {}
    for first = 1, #frames do
        for second = first + 1, #frames do
            local one, other = frames[first], frames[second]
            local width, height = read_overlap(one.rect, other.rect)
            if width > LEAST and height > LEAST and not check_holding(one.frame, other.frame) and not check_holding(other.frame, one.frame) then
                overlaps[#overlaps + 1] = string.format("%s x %s: %.0f by %.0f", one.frame:GetName(), other.frame:GetName(), width, height)
            end
        end
    end
    table.sort(overlaps)
    return overlaps
end

function library.render_overlaps()
    local frames = read_frames(UIParent, 1, {})
    local overlaps = read_overlaps(frames)
    LibVGASettings.measures = LibVGASettings.measures or {}
    LibVGASettings.measures.overlaps = LibVGASettings.measures.overlaps or {}
    LibVGASettings.measures.overlaps[LibVGASettings.size or "medium"] = {
        when = date("%Y-%m-%d %H:%M"),
        screen = string.format("%.0f by %.0f", UIParent:GetWidth(), UIParent:GetHeight()), frames = #frames, overlaps = overlaps,
    }
    DEFAULT_CHAT_FRAME:AddMessage(string.format(library.texts.overlaps_found, #overlaps, #frames))
    for index = 1, math.min(#overlaps, SHOWN_LINES) do DEFAULT_CHAT_FRAME:AddMessage(overlaps[index]) end
end
