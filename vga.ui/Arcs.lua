-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: Two transparent arcs either side of the character, wide enough to clear it and centred on its middle, as manual/view/vga-hud.html draws them (D): twelve segments each, lit one by one; an arc with nothing to show fades slowly out, each on its own, and back in when it has. Each side shows what the settings choose - the range, the threat, the target's cast or its health, the player's own resource, named as the game names the class's power - Mana, Wut, Energie, for a druid all three -, filling the arc in the power bar's colour, with or without a target, a rogue's or cat's combo points as five beads beside it, lit gold when earned -, or nothing -, by default the range at the left and the threat at the right. The range to an attackable target filling from its foot as the target comes nearer - the distance known in steps by the game's own range checks - the player's harmful spells and a few items, each at the range the game gives its spell, and the interact distances of 10 and 28 yards -, shown as the smallest step the target stands within, »>« before the largest when beyond it -, its lit segments in one colour that tells the reach - red when the target stands near, through orange and yellow to a deep green at the edge of the best range of the player's class, by the steps' yards -; every segment grey where it stands beyond that range or beyond every step; the threat drawn from the target fills in the threat meter's five colours, the health in green, each segment set by the game from the value even where it is secret; the target's cast fills as it runs, gold while it can be interrupted, grey while not, its spell's name at the head - for the moment to interrupt. Each arc's value stands at its head or its foot, or not at all, as the settings say. Free to be placed while arranging.

-- {K0392} {K0393} {K0395} {K0400} {K0416} {K0417} {K0418}

local _, vga = ...
local library = LibVGA
local DRAFT_BASE = 13
local SEGMENTS = 12
local SPAN = 120
local RADIUS = 150
local RANGE_MOST = 40
local STEP = 0.01
local FADE = 1.5
local TRACK = { 0, 0, 0, 0.35 }
local GREY = { 0.54, 0.55, 0.57 }
local MELEE = 10
local REACH = { { 0.9, 0.28, 0.24 }, { 0.96, 0.55, 0.2 }, { 0.95, 0.79, 0.25 }, { 0.16, 0.6, 0.27 } }
local OUT_OF_REACH = { 0.45, 0.46, 0.48 }
local HEALTH = { 0.37, 0.82, 0.42 }
local MARK_OPEN = { 0.2, 0.21, 0.24 }
local COMBO_MARKS = 5
local BEST = { HUNTER = 75, MAGE = 133, WARLOCK = 686, PRIEST = 585, DRUID = 5176, SHAMAN = 403, WARRIOR = 78, ROGUE = 1752 }
local RANGE_ITEMS = { 8149, 10645, 835, 4941, 18904, 13289, 9328, 7734, 4945, 17202 }
local checks = {}
local arcs

local function read_draft(pixels)
    return math.floor(pixels * library.read_base() / DRAFT_BASE + 0.5)
end

local function read_mix(from, to, share)
    return { from[1] + (to[1] - from[1]) * share, from[2] + (to[2] - from[2]) * share, from[3] + (to[3] - from[3]) * share }
end

local function read_range_colour(yards, best_yards, best)
    if not yards or (yards > best_yards and not best) then return OUT_OF_REACH end
    local place = math.max(0, math.min(1, yards / best_yards)) * (#REACH - 1)
    local from = math.min(math.floor(place) + 1, #REACH - 1)
    return read_mix(REACH[from], REACH[from + 1], place - (from - 1))
end

local function create_segment(side)
    local segment = CreateFrame("StatusBar", nil, side)
    segment:SetStatusBarTexture(library.media .. "ArcSegment")
    segment:SetMinMaxValues(0, STEP)
    segment:SetValue(0)
    segment.track = segment:CreateTexture(nil, "BACKGROUND")
    segment.track:SetTexture(library.media .. "ArcSegment")
    segment.track:SetAllPoints()
    segment.track:SetVertexColor(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
    return segment
end

local function update_fade(side, elapsed)
    local alpha = side:GetAlpha()
    if alpha == side.wanted then return end
    local step = elapsed / FADE
    side:SetAlpha(side.wanted > alpha and math.min(side.wanted, alpha + step) or math.max(side.wanted, alpha - step))
end

local function create_side(mirror)
    local side = CreateFrame("Frame", nil, arcs)
    side:SetAllPoints(arcs)
    side.mirror = mirror
    side.segments = {}
    for index = 1, SEGMENTS do side.segments[index] = create_segment(side) end
    side.value = library.create_text(side, "small", library.colours.ink)
    side.wanted = 0
    side:SetAlpha(0)
    side:SetScript("OnUpdate", update_fade)
    return side
end

local function update_side_layout(side)
    local radius, size = read_draft(RADIUS), read_draft(16)
    for index, segment in ipairs(side.segments) do
        local share = (index - 0.5) / SEGMENTS
        local angle = math.rad(-SPAN / 2 + share * SPAN)
        segment:SetSize(size, size)
        segment:ClearAllPoints()
        segment:SetPoint("CENTER", arcs, "CENTER", side.mirror * radius * math.cos(angle), radius * math.sin(angle))
        local turn = math.pi / 2 + side.mirror * angle
        segment:GetStatusBarTexture():SetRotation(turn)
        segment.track:SetRotation(turn)
    end
    local foot = LibVGASettings.arc_values == "bottom"
    local head = math.rad(foot and -SPAN / 2 or SPAN / 2)
    side.value:SetFontObject(library.read_font("small"))
    side.value:ClearAllPoints()
    side.value:SetPoint(foot and "TOP" or "BOTTOM", arcs, "CENTER", side.mirror * radius * math.cos(head), radius * math.sin(head) + (foot and -1 or 1) * read_draft(10))
end

local function read_spell_range(spell)
    local known = spell and C_Spell.GetSpellInfo(spell)
    if not known or (known.minRange or 0) > 0 or (known.maxRange or 0) <= 0 then return nil end
    return known.maxRange
end

local function write_check(yards, check)
    for _, kept in ipairs(checks) do
        if kept[1] == yards then return end
    end
    checks[#checks + 1] = { yards, check }
end

local function write_spell_checks()
    local lines = C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines() or 0
    for line = 1, lines do
        local skill = C_SpellBook.GetSpellBookSkillLineInfo(line)
        for slot = skill.itemIndexOffset + 1, skill.itemIndexOffset + skill.numSpellBookItems do
            local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
            local spell = item and item.spellID
            local yards = spell and C_Spell.IsSpellHarmful(spell) and read_spell_range(spell)
            if yards then write_check(yards, function() return C_Spell.IsSpellInRange(spell, "target") end) end
        end
    end
end

local function write_item_checks()
    for _, item in ipairs(RANGE_ITEMS) do
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(item) end
        local _, spell = C_Item.GetItemSpell(item)
        local yards = read_spell_range(spell)
        if yards then write_check(yards, function() return C_Item.IsItemInRange(item, "target") end) end
    end
end

local function write_checks()
    checks = {}
    write_check(10, function() return CheckInteractDistance("target", 3) end)
    write_check(28, function() return CheckInteractDistance("target", 1) end)
    pcall(write_spell_checks)
    pcall(write_item_checks)
    table.sort(checks, function(one, other) return one[1] < other[1] end)
end

local function read_range()
    for _, step in ipairs(checks) do
        local ran, near = pcall(step[2])
        if ran and near then return step[1] end
    end
    return nil
end

local function read_best_yards()
    local _, class = UnitClass("player")
    local known = BEST[class or ""] and C_Spell and C_Spell.GetSpellInfo(BEST[class])
    return known and (known.maxRange or 0) > 0 and known.maxRange or MELEE
end

local function check_best_range()
    local _, class = UnitClass("player")
    local spell = BEST[class or ""]
    if not spell then return CheckInteractDistance("target", 3) and true or false end
    return C_Spell and C_Spell.IsSpellInRange and C_Spell.IsSpellInRange(spell, "target") == true
end

local function update_range(side)
    local yards, foe = read_range(), UnitCanAttack("player", "target")
    side.wanted = (yards or foe) and 1 or 0
    local share = yards and (RANGE_MOST - yards) / RANGE_MOST or 0
    local lit, best = math.max(foe and 1 or 0, math.ceil(share * SEGMENTS)), yards and check_best_range()
    local colour = read_range_colour(yards, read_best_yards(), best)
    if colour == OUT_OF_REACH then lit = SEGMENTS end
    for index, segment in ipairs(side.segments) do
        segment:SetStatusBarColor(colour[1], colour[2], colour[3], 0.9)
        segment:SetMinMaxValues(0, STEP)
        segment:SetValue(index <= lit and STEP or 0)
    end
    local farthest = checks[#checks] and checks[#checks][1] or 35
    side.value:SetText(yards and vga.render_distance(yards) or ("> " .. vga.render_distance(farthest)))
end

local function update_by_game(side, share, colour_of)
    for index, segment in ipairs(side.segments) do
        local colour = colour_of(index)
        segment:SetStatusBarColor(colour[1], colour[2], colour[3], 0.9)
        segment:SetMinMaxValues((index - 1) * 100 / SEGMENTS, (index - 1) * 100 / SEGMENTS + STEP)
        segment:SetValue(share or 0)
    end
    pcall(side.value.SetFormattedText, side.value, "%d %%", share or 0)
end

local function read_threat_colour(index)
    return library.colours.steps[math.min(5, math.floor((index - 1) / SEGMENTS * 5) + 1)]
end

local function update_threat(side)
    local status = UnitThreatSituation("player", "target")
    side.wanted = ((issecretvalue and issecretvalue(status)) or status ~= nil) and 1 or 0
    local _, _, share = UnitDetailedThreatSituation("player", "target")
    update_by_game(side, share, read_threat_colour)
end

local function read_health_colour()
    return HEALTH
end

local function update_health(side)
    side.wanted = 1
    local share = UnitHealthPercent and CurveConstants and UnitHealthPercent("target", true, CurveConstants.ScaleTo100)
    update_by_game(side, share, read_health_colour)
end

local function read_cast_share(start, finish, channel)
    local now = GetTime() * 1000
    local share = (now - start) / math.max(finish - start, 1)
    return math.max(0, math.min(1, channel and 1 - share or share))
end

local function update_cast(side)
    local name, _, _, start, finish, _, _, locked = UnitCastingInfo("target")
    local channel = false
    if not name then
        name, _, _, start, finish, _, locked = UnitChannelInfo("target")
        channel = name ~= nil
    end
    side.wanted = name and 1 or 0
    if not name then return end
    local ran, share = pcall(read_cast_share, start, finish, channel)
    local lit = math.ceil((ran and share or 1) * SEGMENTS)
    local colour = locked and GREY or library.colours.gold
    for index, segment in ipairs(side.segments) do
        segment:SetStatusBarColor(colour[1], colour[2], colour[3], 0.9)
        segment:SetMinMaxValues(0, STEP)
        segment:SetValue(index <= lit and STEP or 0)
    end
    side.value:SetText(name)
end

local function update_marks(side, shown)
    local points = shown and vga.read_combo_points() or nil
    local radius, size = read_draft(RADIUS + 14), read_draft(7)
    side.marks = side.marks or {}
    for index = 1, COMBO_MARKS do
        side.marks[index] = side.marks[index] or library.create_bead(side, "OVERLAY", 3)
        local bead, angle = side.marks[index], math.rad(-SPAN / 2 + (index - 0.5) / COMBO_MARKS * SPAN)
        local colour = points and index <= points and library.colours.gold or MARK_OPEN
        bead:SetSize(size, size)
        bead:SetVertexColor(colour[1], colour[2], colour[3], 1)
        bead:ClearAllPoints()
        bead:SetPoint("CENTER", arcs, "CENTER", side.mirror * radius * math.cos(angle), radius * math.sin(angle))
        library.update_bead_shown(bead, points ~= nil)
    end
end

local function read_resource_wanted(points)
    local ran, empty = pcall(function() return UnitPower("player") == 0 end)
    if ran and empty and (points or 0) == 0 then return 0 end
    return 1
end

local function update_resource(side)
    local kind = UnitPowerType("player")
    local colour = library.read_bar_colour(vga.read_power_kind(kind))
    local share = UnitPowerPercent and CurveConstants and UnitPowerPercent("player", kind, false, CurveConstants.ScaleTo100)
    side.wanted = read_resource_wanted(vga.read_combo_points())
    update_by_game(side, share, function() return colour end)
    update_marks(side, true)
end

local SHOWS = { range = update_range, threat = update_threat, cast = update_cast, health = update_health, resource = update_resource }

local function check_target()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
end

local function read_show(side)
    local chosen = LibVGASettings[side.key] or side.default
    return SHOWS[chosen] and chosen or nil
end

local function update_values()
    if not arcs then return end
    local target = check_target()
    for _, side in ipairs({ arcs.left, arcs.right }) do
        local show = read_show(side)
        side:SetShown(show ~= nil)
        side.value:SetShown(LibVGASettings.arc_values ~= "off")
        if side.marks and show ~= "resource" then update_marks(side, false) end
        if show == "resource" then
            update_resource(side)
        elseif not target then
            side.wanted = 0
        elseif show then
            SHOWS[show](side)
        end
    end
end

local function update_arcs()
    if not arcs then return end
    local radius = read_draft(RADIUS)
    arcs:SetSize(2 * radius + read_draft(40), 2 * radius)
    update_side_layout(arcs.left)
    update_side_layout(arcs.right)
    update_values()
end

local function read_resource_name()
    local _, class = UnitClass("player")
    if class == "DRUID" then return (MANA or "Mana") .. "/" .. (RAGE or "Rage") .. "/" .. (ENERGY or "Energy") end
    local _, token = UnitPowerType("player")
    return token and _G[token] or library.texts.resource_arc
end

local function read_kinds()
    local texts = library.texts
    return { "range", "threat", "cast", "health", "resource", "off" }, { texts.range_arc, texts.threat_arc, texts.cast_arc, texts.health_arc, read_resource_name(), texts.off }
end
local PLACES = { "top", "bottom", "off" }

local function read_place(list, wanted, fallback)
    for index, value in ipairs(list) do
        if value == (wanted or fallback) then return index end
    end
    return 1
end

local function create_side_row(page, label, key, fallback)
    local kinds, labels = read_kinds()
    return library.create_choice_row(page, label, labels, read_place(kinds, LibVGASettings[key], fallback), function(index)
        library.update_choice_setting(key, kinds[index])
    end)
end

local function create_arcs_page(page)
    local texts = library.texts
    page.rows = {
        create_side_row(page, texts.left_arc, "arc_left", "range"),
        create_side_row(page, texts.right_arc, "arc_right", "threat"),
        library.create_choice_row(page, texts.values_shown, { texts.top, texts.bottom, texts.off }, read_place(PLACES, LibVGASettings.arc_values, "top"), function(index)
            library.update_choice_setting("arc_values", PLACES[index])
        end),
    }
end

local function create_arcs()
    arcs = CreateFrame("Frame", "VGAArcs", UIParent)
    arcs:SetFrameStrata("BACKGROUND")
    arcs.left = create_side(-1)
    arcs.left.key, arcs.left.default = "arc_left", "range"
    arcs.right = create_side(1)
    arcs.right.key, arcs.right.default = "arc_right", "threat"
    library.create_place(arcs, "arcs", "CENTER", UIParent, 0, -read_draft(165))
    library.create_element("arcs", { title = library.texts.arcs, icon = "TabArcs", update = update_arcs, tab = create_arcs_page })
    write_checks()
    C_Timer.After(5, function() library.update_safely("arcs checks", write_checks) end)
    C_Timer.NewTicker(0.2, function() library.update_safely("arcs", update_values) end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("SPELLS_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then library.update_safely("arcs login", create_arcs) end
    if event == "SPELLS_CHANGED" and arcs then library.update_safely("arcs checks", write_checks) end
    library.update_safely("arcs", update_values)
end)

vga.read_range_colour = read_range_colour
