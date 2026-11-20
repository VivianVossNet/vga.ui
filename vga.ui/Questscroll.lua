-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The quest tracker's body as a scrolling list (K0548): the tracker is at most as high as the settings' slider says - between a fifth and half of the screen's height, half by default (K0550) -, smaller where its quests need less; a longer list scrolls under the head, the foot staying beneath, by the mouse wheel and by dragging a slender bar at the right in the way of macOS - a rounded thumb, white at a third of full strength, its length the share of the list in view, with no track behind it, shown only while the list is longer than the room. Quests.lua lays the rows into the body; Questzones.lua's labels too.

-- {K0548}

local _, vga = ...
local library = LibVGA
local DRAFT_BASE = 13
local THUMB = 4
local THUMB_ALPHA = 0.35
local INSET = 3
local SHARE = 0.5
local WHEEL = 40
local THUMB_SHORTEST = 24

local function read_draft(pixels)
    return math.floor(pixels * library.read_base() / DRAFT_BASE + 0.5)
end

local function update_thumb(body)
    local room, length = body:GetHeight(), body.length or 0
    local shown = length > room + 0.5
    body.thumb:SetShown(shown)
    if not shown then return end
    local inset = read_draft(INSET)
    local track = room - 2 * inset
    local size = math.max(read_draft(THUMB_SHORTEST), track * room / length)
    local travel = (track - size) * body:GetVerticalScroll() / math.max(length - room, 1)
    local width = read_draft(THUMB)
    body.thumb:SetSize(width, size)
    body.thumb:ClearAllPoints()
    body.thumb:SetPoint("TOPRIGHT", body, "TOPRIGHT", -inset, -inset - travel)
    library.update_surface(body.thumb.face, 0, width / 2, { 1, 1, 1 }, { 1, 1, 1 }, THUMB_ALPHA)
end

local function update_scrolled(body, offset)
    local most = math.max((body.length or 0) - body:GetHeight(), 0)
    body:SetVerticalScroll(math.min(math.max(offset, 0), most))
    update_thumb(body)
end

local function update_wheel(body, delta)
    update_scrolled(body, body:GetVerticalScroll() - delta * read_draft(WHEEL))
end

local function update_drag(thumb)
    local body = thumb:GetParent()
    local _, cursor = GetCursorPosition()
    cursor = cursor / thumb:GetEffectiveScale()
    local room = body:GetHeight() - 2 * read_draft(INSET) - thumb:GetHeight()
    local moved = (thumb.grab - cursor) / math.max(room, 1)
    update_scrolled(body, thumb.from + moved * math.max((body.length or 0) - body:GetHeight(), 0))
end

local function update_drag_safely(thumb)
    library.update_safely("quest scroll drag", update_drag, thumb)
end

local function update_grab(thumb)
    local _, cursor = GetCursorPosition()
    thumb.grab, thumb.from = cursor / thumb:GetEffectiveScale(), thumb:GetParent():GetVerticalScroll()
    thumb:SetScript("OnUpdate", update_drag_safely)
end

local function update_release(thumb)
    thumb:SetScript("OnUpdate", nil)
end

function vga.create_quest_body(tracker)
    local body = CreateFrame("ScrollFrame", nil, tracker)
    body.content = CreateFrame("Frame", nil, body)
    body:SetScrollChild(body.content)
    body:EnableMouseWheel(true)
    body:SetScript("OnMouseWheel", update_wheel)
    body.thumb = CreateFrame("Frame", nil, body)
    body.thumb.face = library.create_surface(body.thumb, "OVERLAY", 0)
    body.thumb:EnableMouse(true)
    body.thumb:SetScript("OnMouseDown", update_grab)
    body.thumb:SetScript("OnMouseUp", update_release)
    body.thumb:SetFrameLevel(body:GetFrameLevel() + 10)
    return body
end

function vga.read_quest_room(tracker)
    local screen = UIParent:GetHeight() * UIParent:GetEffectiveScale() / tracker:GetEffectiveScale()
    return math.floor(screen * (vga.read_quest_most_height and vga.read_quest_most_height() or SHARE))
end

function vga.update_quest_body(tracker, head, length, width, foot)
    local body = tracker.body
    local room = math.max(math.min(length, vga.read_quest_room(tracker) - head - foot), 0)
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, -head)
    body:SetSize(width, room)
    body.content:SetSize(width, math.max(length, 1))
    body.length = length
    update_scrolled(body, body:GetVerticalScroll())
    return room
end
