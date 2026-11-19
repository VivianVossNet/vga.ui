-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: vga.ui's quest tracker as the accepted draft draws .qw (manual/view/vga-probe.html): a widget in the tooltip's look, at least as wide as the draft and wider where a title or objective needs it, so no text runs out - growing towards the screen's middle: its place is kept by its outer corner - the upper right on the right half of the screen, the upper left on the left -, a place saved before by its upper left moved once to its upper right where it stands right -, the VGA mark, »Quests dieser Zone« in gold and the count shown of all in the log in its head; the watched quests whose next target lies in the player's zone, in the order the settings choose - the nearest first, by difficulty, the easiest first, or as watched in the quest log -, at most eight; each with its title in gold and its distance at the right, before the title a kept place for a mark - a green tick on a finished quest, a line arrow turned towards its target on an open one, gold on the nearest open, grey on the rest; its objectives with their counts, each after a small bead in exactly the game's colour of the quest's difficulty, a white light at its upper left and a faint shade at its lower right laid over it, centred under the arrow and on the middle of its line, its words set in where the title's begin, as the game colours it, a thin gold bar under each still open, the finished struck through; the data source at the foot; a left click on a quest opens it in the game's quest log, as Blizzard's tracker does, out of combat; a click on an open quest's arrow makes it the navigation's target instead of the nearest - a second click on the same arrow lets it go, a click on another's takes that one -, kept for each zone on its own: a quest chosen in one zone counts only there and counts again on returning; resting on the arrow explains this in a tooltip. The source is automatic - Questie when it is loaded and ready, else the game's own quest log -; Questie's internal modules are read guarded, the game's data standing where they fail. Blizzard's tracker and Questie's own are hidden while it runs.

-- {K0260} {K0370} {K0371} {K0390} {K0401} {K0408} {K0422} {K0424}

local _, vga = ...
local library = LibVGA
local colours = library.colours
local DRAFT_BASE = 13
local MOST = 8
local YARD = 0.9144
local TITLE = { 0.945, 0.812, 0.431 }
local OBJECTIVE = { 0.788, 0.773, 0.737 }
local DONE = { 0.435, 0.424, 0.4 }
local TRACK = { 0.165, 0.177, 0.2 }
local SOURCE = { 0.525, 0.725, 0.91 }
local DIVIDER = { 0.137, 0.149, 0.173 }
local TICK = { 0.498, 0.816, 0.416 }
local WIDTH = 300
local OTHERS = { "ObjectiveTrackerFrame", "Questie_BaseFrame" }
local atan2 = math.atan2 or math.atan
local tracker
local hooked = {}

local function read_draft(pixels)
    return math.floor(pixels * library.read_base() / DRAFT_BASE + 0.5)
end

local function create_objective(parent)
    local objective = CreateFrame("Frame", nil, parent)
    objective.text = library.create_text(objective, "body", OBJECTIVE)
    objective.text:SetJustifyH("LEFT")
    objective.text:SetWordWrap(false)
    objective.count = library.create_text(objective, "body", OBJECTIVE)
    objective.dot = library.create_bead(objective, "ARTWORK", 0)
    objective.strike = objective:CreateTexture(nil, "OVERLAY")
    objective.strike:SetColorTexture(DONE[1], DONE[2], DONE[3], 1)
    objective.bar = CreateFrame("Frame", nil, objective)
    objective.bar.track = library.create_surface(objective.bar, "ARTWORK", 0)
    objective.bar.fill = CreateFrame("Frame", nil, objective.bar)
    objective.bar.fill.surface = library.create_surface(objective.bar.fill, "ARTWORK", 1)
    return objective
end

local function update_opened(quest, button)
    if button ~= "LeftButton" or not quest.id or InCombatLockdown() then return end
    if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(quest.id) end
end

local function update_pin(pin)
    local quest, map = pin:GetParent(), tracker.map
    if not (quest.id and map) then return end
    LibVGASettings.quest_pins = LibVGASettings.quest_pins or {}
    local pins = LibVGASettings.quest_pins
    pins[map] = pins[map] ~= quest.id and quest.id or nil
    library.update_elements()
end

local function update_pin_safely(pin)
    library.update_safely("quest pinned", update_pin, pin)
end

local function render_pin_tip(pin)
    local texts = library.texts
    GameTooltip:SetOwner(pin, "ANCHOR_LEFT")
    GameTooltip:AddLine(texts.pin_title, colours.gold[1], colours.gold[2], colours.gold[3])
    for _, key in ipairs({ "pin_click", "pin_again", "pin_zone" }) do
        GameTooltip:AddLine(texts[key], colours.ink[1], colours.ink[2], colours.ink[3], true)
    end
    GameTooltip:Show()
end

local function update_pin_left()
    GameTooltip:Hide()
end

local function create_quest()
    local quest = CreateFrame("Frame", nil, tracker)
    quest:EnableMouse(true)
    quest:SetScript("OnMouseUp", function(self, button) library.update_safely("quest opened", update_opened, self, button) end)
    quest.arrow = quest:CreateTexture(nil, "OVERLAY")
    quest.pin = CreateFrame("Button", nil, quest)
    quest.pin:SetScript("OnClick", update_pin_safely)
    quest.pin:SetScript("OnEnter", render_pin_tip)
    quest.pin:SetScript("OnLeave", update_pin_left)
    quest.title = library.create_text(quest, "bold", TITLE)
    quest.title:SetJustifyH("LEFT")
    quest.title:SetWordWrap(false)
    quest.distance = library.create_text(quest, "small", colours.quiet)
    quest.line = quest:CreateTexture(nil, "BORDER")
    quest.line:SetColorTexture(DIVIDER[1], DIVIDER[2], DIVIDER[3], 1)
    quest.objectives = {}
    return quest
end

local ORDERS = { "near", "difficulty", "journal" }

local function create_quests_page(page)
    local texts = library.texts
    local chosen = ({ near = 1, difficulty = 2, journal = 3 })[LibVGASettings.quest_order or "near"] or 1
    page.rows = {
        library.create_choice_row(page, texts.order, { texts.nearest_first, texts.difficulty, texts.journal }, chosen, function(index)
            library.update_choice_setting("quest_order", ORDERS[index])
        end),
    }
    for _, row in ipairs(library.create_widget_rows(page, "quests", { { key = "quests", title = texts.quest_tracker } })) do page.rows[#page.rows + 1] = row end
end

local function update_outer_place()
    local places = LibVGASettings.places
    local place = places and places.quests
    if not place or place[1] ~= "TOPLEFT" or LibVGASettings.quests_outer then return end
    LibVGASettings.quests_outer = true
    local width = read_draft(WIDTH)
    if place[3] + width / 2 > UIParent:GetWidth() / 2 then
        places.quests = { "TOPRIGHT", "BOTTOMLEFT", place[3] + width, place[4] }
        library.update_places()
    end
end

local function create_tracker()
    tracker = library.create_frame("VGAQuestTracker", UIParent)
    tracker.corner:SetScript("OnClick", function(corner) library.update_safely("options", library.render_widget, corner, "quests") end)
    tracker.mark = tracker:CreateTexture(nil, "OVERLAY")
    tracker.mark:SetTexture(library.media .. "Mark")
    tracker.head = library.create_text(tracker, "bold", TITLE)
    tracker.count = library.create_text(tracker, "small", colours.quiet)
    tracker.source = CreateFrame("Frame", nil, tracker)
    tracker.source.ring = library.create_ring(tracker.source, "BORDER", 0)
    tracker.source.text = library.create_text(tracker.source, "caption", SOURCE)
    tracker.source.text:SetPoint("CENTER")
    tracker.quests = {}
    tracker.measure = library.create_text(tracker, "body")
    tracker.measure:Hide()
    tracker.place_outer = true
    library.create_place(tracker, "quests", "TOPRIGHT", ObjectiveTrackerFrame or UIParent, 0, 0)
    update_outer_place()
end

local function read_bearing(map, from, to)
    local _, here = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(from.x, from.y))
    local _, there = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(to[1], to[2]))
    if not (here and there) then return nil end
    return atan2(there.y - here.y, there.x - here.x)
end

function vga.read_heading(target)
    local map = C_Map.GetBestMapForUnit("player")
    local spot = map and C_Map.GetPlayerMapPosition(map, "player")
    local facing = GetPlayerFacing and GetPlayerFacing()
    local bearing = spot and target and facing and read_bearing(map, spot, target)
    return bearing and bearing - facing
end

local function update_arrows()
    for _, quest in ipairs(tracker.quests) do
        local target = quest:IsShown() and not quest.complete and quest.target
        local heading = target and vga.read_heading(target)
        if target then quest.arrow:SetShown(heading ~= nil) end
        if heading then quest.arrow:SetRotation(heading) end
    end
end

function vga.render_distance(yards)
    if not yards then return "" end
    if LibVGASettings.quest_unit == "yards" then return math.floor(yards + 0.5) .. " " .. library.texts.yards end
    return math.floor(yards * YARD + 0.5) .. " " .. library.texts.metres
end

local function render_objective_text(text)
    return (text or ""):gsub("^%s*%d+%s*/%s*%d+%s*", ""):gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", "")
end

local function read_objectives(id)
    local found = {}
    for _, objective in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
        found[#found + 1] = {
            text = render_objective_text(objective.text), done = objective.finished,
            have = objective.numFulfilled or 0, need = objective.numRequired or 0,
        }
    end
    return found
end

local function read_map_points(map)
    local points = {}
    for _, point in ipairs(map and C_QuestLog.GetQuestsOnMap(map) or {}) do points[point.questID] = { point.x, point.y } end
    return points
end

local function read_game_quest(entry, points)
    local id = entry.questID
    local square = C_QuestLog.GetDistanceSqToQuest(id)
    local level = entry.difficultyLevel or entry.level or 0
    local colour = GetQuestDifficultyColor and GetQuestDifficultyColor(level) or { r = 1, g = 0.82, b = 0 }
    return {
        id = id, title = entry.title, here = entry.isOnMap, point = points[id], complete = C_QuestLog.IsComplete(id),
        distance = square and math.sqrt(square), objectives = read_objectives(id), level = level, colour = colour,
    }
end

local function read_game_quests(map)
    local points, watched, total = read_map_points(map), {}, 0
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local entry = C_QuestLog.GetInfo(index)
        if entry and not entry.isHeader and entry.questID then
            total = total + 1
            if C_QuestLog.GetQuestWatchType(entry.questID) ~= nil then watched[#watched + 1] = read_game_quest(entry, points) end
        end
    end
    return watched, total
end

local function update_from_questie(quest, map)
    local loader = QuestieLoader
    local found = loader:ImportModule("QuestieDB").GetQuest(quest.id)
    local spot, zone, _, distance = loader:ImportModule("DistanceUtils").GetNearestSpawnForQuest(found)
    if not spot then return end
    quest.here = loader:ImportModule("ZoneDB"):GetUiMapIdByAreaId(zone) == map
    quest.point = { spot[1] / 100, spot[2] / 100 }
    quest.distance = distance
end

local function read_source()
    local chosen = LibVGASettings.quest_source or "auto"
    local questie = QuestieLoader and Questie and Questie.API and Questie.API.isReady
    if chosen ~= "wow" and questie then return "questie" end
    return "wow"
end

local function read_watch_order()
    local order = {}
    for index = 1, (C_QuestLog.GetNumQuestWatches and C_QuestLog.GetNumQuestWatches() or 0) do
        local id = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
        if id then order[id] = index end
    end
    return order
end

local function check_nearer(one, other)
    return (one.distance or math.huge) < (other.distance or math.huge)
end

local function read_sorter()
    if LibVGASettings.quest_order == "difficulty" then
        return function(one, other)
            if one.level ~= other.level then return one.level < other.level end
            return check_nearer(one, other)
        end
    end
    if LibVGASettings.quest_order == "journal" then
        local order = read_watch_order()
        return function(one, other) return (order[one.id] or math.huge) < (order[other.id] or math.huge) end
    end
    return check_nearer
end

local function read_shown_quests(map, source)
    local watched, total = read_game_quests(map)
    local shown = {}
    for _, quest in ipairs(watched) do
        if source == "questie" then library.update_safely("quests questie", update_from_questie, quest, map) end
        if quest.here then shown[#shown + 1] = quest end
    end
    table.sort(shown, read_sorter())
    for index = (LibVGASettings.quest_most or MOST) + 1, #shown do shown[index] = nil end
    return shown, total
end

local function update_bar(bar, share)
    local radius = 1
    library.update_surface(bar.track, 0, radius, TRACK, TRACK)
    bar.fill:ClearAllPoints()
    bar.fill:SetPoint("TOPLEFT")
    bar.fill:SetPoint("BOTTOMLEFT")
    bar.fill:SetWidth(math.max(1, bar:GetWidth() * share))
    bar.fill:SetShown(share > 0)
    library.update_surface(bar.fill.surface, 0, radius, colours.gold, colours.gold)
end

local function update_objective(objective, data, top, width, colour_of_quest)
    local pad, done = read_draft(12), data.done
    local colour = done and DONE or OBJECTIVE
    objective:ClearAllPoints()
    objective:SetPoint("TOPLEFT", objective:GetParent(), "TOPLEFT", pad, -top)
    objective:SetWidth(width - 2 * pad)
    objective.text:SetFontObject(library.read_frame_font("body"))
    objective.count:SetFontObject(library.read_frame_font("body"))
    objective.text:SetText(data.text)
    objective.count:SetText(data.need > 0 and (data.have .. "/" .. data.need) or "")
    objective.text:SetTextColor(colour[1], colour[2], colour[3])
    objective.count:SetTextColor(colour[1], colour[2], colour[3])
    local line = math.ceil(objective.text:GetStringHeight())
    objective.count:ClearAllPoints()
    objective.count:SetPoint("TOPRIGHT")
    local dot = read_draft(5)
    objective.dot:SetSize(dot, dot)
    objective.dot:SetVertexColor(colour_of_quest.r, colour_of_quest.g, colour_of_quest.b, 1)
    local column = read_draft(12)
    objective.dot:ClearAllPoints()
    objective.dot:SetPoint("CENTER", objective, "TOPLEFT", column / 2, -line / 2)
    objective.text:ClearAllPoints()
    objective.text:SetPoint("TOPLEFT", objective, "TOPLEFT", column + read_draft(6), 0)
    objective.text:SetPoint("RIGHT", objective.count, "LEFT", -read_draft(8), 0)
    objective.strike:ClearAllPoints()
    objective.strike:SetPoint("LEFT", objective.text, "LEFT")
    objective.strike:SetSize(math.min(objective.text:GetStringWidth(), objective.text:GetWidth()), 1)
    objective.strike:SetShown(done and true or false)
    local bar = read_draft(3)
    objective.bar:ClearAllPoints()
    objective.bar:SetPoint("TOPLEFT", objective, "TOPLEFT", 0, -(line + read_draft(5)))
    objective.bar:SetSize(width - 2 * pad, bar)
    objective.bar:SetShown(not done)
    update_bar(objective.bar, data.need > 0 and math.min(data.have / data.need, 1) or 0)
    local height = line + (done and 0 or read_draft(5) + bar)
    objective:SetHeight(height)
    return height
end

local function update_quest_objectives(quest, data, top, width)
    local strike, gap = LibVGASettings.quest_done ~= "hide", read_draft(5)
    local shown = 0
    for _, objective_data in ipairs(data.objectives) do
        if strike or not objective_data.done then
            shown = shown + 1
            quest.objectives[shown] = quest.objectives[shown] or create_objective(quest)
            quest.objectives[shown]:Show()
            top = top + gap + update_objective(quest.objectives[shown], objective_data, top + gap, width, data.colour)
        end
    end
    for index = shown + 1, #quest.objectives do quest.objectives[index]:Hide() end
    return top
end

local function update_mark(quest, data, active)
    local colour = data.complete and TICK or (active and colours.gold or colours.quiet)
    quest.arrow:SetTexture(library.media .. (data.complete and "Tick" or "Arrow"))
    quest.arrow:SetVertexColor(colour[1], colour[2], colour[3], 1)
    if data.complete then quest.arrow:SetRotation(0) end
    quest.arrow:SetShown(data.complete or data.point ~= nil)
    quest.pin:SetShown(not data.complete and data.point ~= nil)
    quest.complete, quest.target = data.complete, data.point
end

local function update_quest(quest, data, top, width, active)
    local pad, arrow = read_draft(12), read_draft(12)
    quest:ClearAllPoints()
    quest:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, -top)
    quest:SetWidth(width)
    quest.id = data.id
    quest.title:SetFontObject(library.read_frame_font("bold"))
    quest.distance:SetFontObject(library.read_frame_font("small"))
    quest.title:SetText(data.title)
    quest.distance:SetText(vga.render_distance(data.distance))
    quest.arrow:SetSize(arrow, arrow)
    quest.arrow:ClearAllPoints()
    quest.arrow:SetPoint("TOPLEFT", quest, "TOPLEFT", pad, -read_draft(10))
    quest.pin:SetAllPoints(quest.arrow)
    update_mark(quest, data, active)
    quest.distance:ClearAllPoints()
    quest.distance:SetPoint("TOPRIGHT", quest, "TOPRIGHT", -pad, -read_draft(10) - read_draft(2))
    quest.title:ClearAllPoints()
    quest.title:SetPoint("TOPLEFT", quest, "TOPLEFT", pad + arrow + read_draft(6), -read_draft(10))
    quest.title:SetPoint("RIGHT", quest.distance, "LEFT", -read_draft(8), 0)
    local bottom = update_quest_objectives(quest, data, read_draft(10) + math.ceil(quest.title:GetStringHeight()), width) + read_draft(10)
    quest:SetHeight(bottom)
    quest.line:ClearAllPoints()
    quest.line:SetPoint("BOTTOMLEFT")
    quest.line:SetPoint("BOTTOMRIGHT")
    quest.line:SetHeight(1)
    quest.line:SetAlpha(library.read_ground("quests"))
    return bottom
end

local function update_head(width, shown, total)
    local pad, mark = read_draft(12), read_draft(16)
    tracker.mark:SetSize(mark, mark)
    tracker.mark:ClearAllPoints()
    tracker.mark:SetPoint("TOPLEFT", tracker, "TOPLEFT", pad, -(read_draft(4) + read_draft(8)))
    tracker.head:SetFontObject(library.read_frame_font("bold"))
    tracker.head:SetText(library.texts.quests_zone)
    tracker.head:ClearAllPoints()
    tracker.head:SetPoint("LEFT", tracker.mark, "RIGHT", read_draft(8), 0)
    tracker.count:SetFontObject(library.read_frame_font("small"))
    tracker.count:SetText(shown .. " " .. library.texts.of .. " " .. total)
    tracker.count:ClearAllPoints()
    tracker.count:SetPoint("RIGHT", tracker, "TOPRIGHT", -pad - read_draft(14), -(read_draft(4) + read_draft(8) + mark / 2))
    return read_draft(4) + read_draft(8) + mark + read_draft(6)
end

local function update_foot(top, source)
    local text = tracker.source.text
    text:SetFontObject(library.read_frame_font("caption"))
    text:SetText(library.texts.data .. ": " .. (source == "questie" and "QUESTIE" or "WOW"))
    tracker.source:ClearAllPoints()
    tracker.source:SetPoint("TOPLEFT", tracker, "TOPLEFT", read_draft(12), -(top + read_draft(6)))
    tracker.source:SetSize(math.ceil(text:GetStringWidth()) + 2 * read_draft(6), math.ceil(text:GetStringHeight()) + 2 * read_draft(1) + 2)
    library.update_ring(tracker.source.ring, 1, SOURCE, 0.33)
    return top + read_draft(6) + tracker.source:GetHeight() + read_draft(8) + read_draft(4)
end

local function update_others()
    for _, name in ipairs(OTHERS) do
        local other = _G[name]
        if other and not hooked[other] then
            hooked[other] = true
            other:HookScript("OnShow", function(shown) shown:SetAlpha(0) end)
        end
        if other then
            other:SetAlpha(0)
            if not InCombatLockdown() then other:Hide() end
        end
    end
end

local function read_text_width(text, kind)
    local measure = tracker.measure
    measure:SetFontObject(library.read_frame_font(kind))
    measure:SetText(text or "")
    if measure.GetUnboundedStringWidth then return measure:GetUnboundedStringWidth() end
    return measure:GetStringWidth()
end

local function read_quest_width(data)
    local pad = read_draft(12)
    local widest = 2 * pad + read_draft(12) + read_draft(6) + read_text_width(data.title, "bold") + read_draft(8) + read_text_width(vga.render_distance(data.distance), "small")
    for _, objective in ipairs(data.objectives) do
        local count = objective.need > 0 and (objective.have .. "/" .. objective.need) or ""
        local needed = 2 * pad + read_draft(12) + read_draft(6) + read_text_width(objective.text, "body") + read_draft(8) + read_text_width(count, "body")
        widest = math.max(widest, needed)
    end
    return widest
end

local function read_width(shown, total)
    local pad = read_draft(12)
    local head = 2 * pad + read_draft(16) + read_draft(8) + read_text_width(library.texts.quests_zone, "bold") + read_draft(16) + read_text_width(shown and (#shown .. " " .. library.texts.of .. " " .. total) or "", "small") + read_draft(14)
    local widest = math.max(read_draft(WIDTH), head)
    for _, data in ipairs(shown) do widest = math.max(widest, read_quest_width(data)) end
    return math.ceil(widest)
end

local function update_tracker()
    if not tracker then return end
    update_others()
    library.update_frame(tracker)
    local map = C_Map.GetBestMapForUnit("player")
    local source = read_source()
    local shown, total = read_shown_quests(map, source)
    local width = read_width(shown, total)
    local top = update_head(width, #shown, total)
    tracker.map = map
    local pinned = map and LibVGASettings.quest_pins and LibVGASettings.quest_pins[map]
    local active
    for _, data in ipairs(shown) do
        if not data.complete and (not active or check_nearer(data, active)) then active = data end
    end
    for _, data in ipairs(shown) do
        if data.id == pinned and not data.complete and data.point then active = data end
    end
    for index, data in ipairs(shown) do
        tracker.quests[index] = tracker.quests[index] or create_quest()
        tracker.quests[index]:Show()
        top = top + update_quest(tracker.quests[index], data, top, width, data == active)
        tracker.quests[index].line:SetShown(index < #shown)
    end
    for index = #shown + 1, #tracker.quests do tracker.quests[index]:Hide() end
    tracker:SetSize(width, update_foot(top, source))
    vga.quest_aim = active or nil
    update_arrows()
end

local function update_tracker_safely()
    library.update_safely("quests", update_tracker)
end

local function update_arrow_safely(_, elapsed)
    tracker.since = (tracker.since or 0) + elapsed
    if tracker.since < 0.1 then return end
    tracker.since = 0
    library.update_safely("quests arrows", update_arrows)
end

local function create_tracker_safely()
    create_tracker()
    library.create_element("quests", { title = library.texts.quests, icon = "TabQuests", update = update_tracker, tab = create_quests_page })
    tracker:SetScript("OnUpdate", update_arrow_safely)
    C_Timer.NewTicker(1, update_tracker_safely)
    if Questie and Questie.API and Questie.API.RegisterOnReady then Questie.API.RegisterOnReady(update_tracker_safely) end
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do
    pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then library.update_safely("quests login", create_tracker_safely) end
    update_tracker_safely()
end)
