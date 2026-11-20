-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The quest tracker's item boxes: a quest whose log carries a usable item gets a small box left of the tracker, its middle level with the quest's, in the look of the minimap's button slots - a dark ground, the item's icon rounded, a grey ring that turns gold under the mouse, the item's tooltip beside it -; a click uses the item through the game's secure action button. A quest scrolled out of the tracker's view has no box. As the game forbids moving such a button in a fight, the boxes are laid out of combat only, the tracker's every-second refresh laying them again when the fight has ended; with the tracker hidden they hide.

-- {K0469}

local _, vga = ...
local library = LibVGA
local colours = library.colours
local DRAFT_BASE = 13
local SIZE = 24
local GAP = 6
local GROUND_TOP = { 0.071, 0.075, 0.09 }
local GROUND_BOTTOM = { 0.043, 0.047, 0.059 }
local boxes = {}

local function read_draft(pixels)
    return math.floor(pixels * library.read_base() / DRAFT_BASE + 0.5)
end

local function read_item(quest_id)
    local index = quest_id and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(quest_id)
    if not (index and GetQuestLogSpecialItemInfo) then return nil end
    local link, icon, _, shown_complete = GetQuestLogSpecialItemInfo(index)
    if not link then return nil end
    local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(quest_id)
    if complete and not shown_complete then return nil end
    return { link = link, icon = icon, id = link:match("item:(%d+)") }
end

local function render_tip(box)
    if not box.link then return end
    library.update_ring(box.ring, 1, colours.gold, 1)
    GameTooltip:SetOwner(box, "ANCHOR_LEFT")
    GameTooltip:SetHyperlink(box.link)
    GameTooltip:Show()
end

local function update_left(box)
    library.update_ring(box.ring, 1, colours.metal_top, 1)
    GameTooltip:Hide()
end

local function create_box()
    local box = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    box:RegisterForClicks("AnyUp", "AnyDown")
    box:SetAttribute("type", "item")
    box.ground = library.create_surface(box, "BACKGROUND", 0)
    box.icon = box:CreateTexture(nil, "ARTWORK")
    box.rounded = box:CreateMaskTexture()
    box.rounded:SetTexture(library.media .. "MaskRounded", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    box.icon:AddMaskTexture(box.rounded)
    box.over = CreateFrame("Frame", nil, box)
    box.over:SetAllPoints()
    box.over:SetFrameLevel(box:GetFrameLevel() + 3)
    box.ring = library.create_ring(box.over, "OVERLAY", 0)
    box:SetScript("OnEnter", render_tip)
    box:SetScript("OnLeave", update_left)
    box:Hide()
    return box
end

local function update_box(box, quest, tracker, item)
    local share = tracker:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local size, inset = read_draft(SIZE) * share, read_draft(3) * share
    local middle = (quest:GetTop() + quest:GetBottom()) / 2 * share
    box:SetSize(size, size)
    box:ClearAllPoints()
    box:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", tracker:GetLeft() * share - read_draft(GAP) * share, middle)
    box:SetAttribute("item", item.id and ("item:" .. item.id) or item.link)
    box.link = item.link
    box.icon:SetTexture(item.icon)
    box.icon:ClearAllPoints()
    box.icon:SetPoint("TOPLEFT", inset, -inset)
    box.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
    box.rounded:SetAllPoints(box.icon)
    library.update_surface(box.ground, 0, 4, GROUND_TOP, GROUND_BOTTOM, 1)
    library.update_ring(box.ring, 1, colours.metal_top, 1)
    box:Show()
end

local function check_in_view(quest, tracker)
    local body = tracker.body
    if not (body and body:GetTop() and body:GetBottom()) then return true end
    local middle = (quest:GetTop() + quest:GetBottom()) / 2
    return middle <= body:GetTop() and middle >= body:GetBottom()
end

function vga.update_quest_items(tracker, quests, shown)
    if InCombatLockdown() then return end
    local used = 0
    for index, data in ipairs(tracker:IsShown() and shown or {}) do
        local quest, item = quests[index], read_item(data.id)
        if item and quest:GetTop() and tracker:GetLeft() and check_in_view(quest, tracker) then
            used = used + 1
            boxes[used] = boxes[used] or create_box()
            update_box(boxes[used], quest, tracker, item)
        end
    end
    for index = used + 1, #boxes do boxes[index]:Hide() end
end
