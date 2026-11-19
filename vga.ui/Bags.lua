-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: vga.ui's bags as the accepted drafts draw them (manual/view/vga-reference.html §3, vga-windows.html A, vga-rewards.html): a dialog of the template, always framed, the backpack and its bags as one grid of ten columns in the game's order, no sorted sections; beneath it every special bag - a profession's bag in one of the four places, the reagent bag in its own - as an area set apart, its name in small capitals above it, a quiver or an ammunition pouch always last; at its head a search field, »Taschen durchsuchen«, and the segmented filters - Alle as a word, then as icons with their word as tooltip: Ausrüstung a breastplate, Verbrauch a bottle, Handwerk a hammer, Quest a question mark, Plunder - the poor, grey items - a teddy -, what does not match darkened whole in its place - icon, edges and glow together, through the frame's own alpha, since the game's item button narrows SetAlpha to its icon and border - so nothing moves; each slot in the template's inset metal, our edge laid over the game's slot, two pixels wide with gently rounded corners - an item's quality from uncommon up in its colour, a quest item and a new one in gold, an empty slot in the metal's grey -, a quest item with a small gold question mark in its lower left corner, a little in from the icon's edge, a kept corner for our rarity's gem once vga.data brings it; a new item brighter, edged and glowing in gold, every three seconds a shimmer running once round its rim that ends in a star flashing at its corner, until it is seen - hovered, or the bags closed; at the foot the slots in use of all and the money with the accepted coins. The game's own bags open and close as ever - B, the bag bar, a merchant, the mailbox -, kept under a hidden parent before they show, so they never appear and never clear their new items, while ours follow them and sound as they did; the bank stays the game's. At the filters' right end a button with the sorting arrows opens the settings on the tab »Taschen«, where the order is chosen (Bagsettings.lua); their size, place and pin are Bagplace.lua's. Using, dragging, selling and the tooltip are the game's own item buttons'.

-- {K0258} {K0259} {K0303} {K0403} {K0405} {K0406} {K0407} {K0409} {K0410} {K0411} {K0412} {K0413} {K0414}

local _, vga = ...
local library = LibVGA
local colours = library.colours
local DRAFT_BASE = 13
local COLUMNS = 10
local SLOT = 38
local GAP = 4
local PAD = 12
local FIELD = 30
local FOOT = 30
local RADIUS = 4
local EDGE_WIDTH = 2
local DIM = 0.25
local CYCLE = 3
local RUN_END = 0.26
local STAR_FROM, STAR_PEAK, STAR_END = 0.24, 0.27, 0.34
local TRAIL = { { 0, 1 }, { 0.025, 0.6 }, { 0.05, 0.3 } }
local SLOT_GROUND = { 0.031, 0.035, 0.043 }
local SLOT_EDGE = { 0.18, 0.192, 0.22 }
local FIELD_INK = { 0.435, 0.424, 0.4 }
local FOOT_INK = { 0.467, 0.451, 0.42 }
local FOOT_GROUND = { 0.039, 0.043, 0.051 }
local UNCOMMON = 2
local FILTERS = { false, { [2] = true, [4] = true }, { [0] = true }, { [3] = true, [5] = true, [7] = true, [9] = true }, { [12] = true } }
local QUEST_FILTER = 5
local SECTION_TOP = 8
local AMMO_FAMILIES = 3
local SECTION_GAP = 6
local JUNK_FILTER = 6
local PARTS = { "IconBorder", "IconOverlay", "IconOverlay2", "NewItemTexture", "BattlepayItemTexture", "IconQuestTexture", "flash", "searchOverlay", "ItemContextOverlay", "ExtendedSlot", "UpgradeIcon", "JunkIcon" }
local bags
local hidden = CreateFrame("Frame")
local WHOLE_ALPHA = hidden.SetAlpha
hidden:Hide()
local watched = {}

local function read_draft(pixels)
    return math.floor(pixels * library.read_base() / DRAFT_BASE + 0.5)
end

local function read_last_bag()
    return Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots or NUM_BAG_SLOTS or 4
end

local function read_final_bag()
    local reagent = Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumReagentBagSlots or 0
    return read_last_bag() + reagent
end

local function read_bag_slots()
    local used, total = 0, 0
    for bag = 0, read_final_bag() do
        local size = C_Container.GetContainerNumSlots(bag) or 0
        total = total + size
        for slot = 1, size do
            if C_Container.GetContainerItemInfo(bag, slot) then used = used + 1 end
        end
    end
    return used, total
end

local function update_button_parts(button)
    for _, name in ipairs(PARTS) do
        if button[name] then button[name]:SetAlpha(0) end
    end
    if button.GetNormalTexture and button:GetNormalTexture() then button:GetNormalTexture():SetAlpha(0) end
    for _, state in ipairs({ button:GetHighlightTexture(), button:GetPushedTexture() }) do
        state:SetTexture("Interface\\Buttons\\WHITE8X8")
        state:SetVertexColor(1, 1, 1, 0.15)
        state:SetAllPoints(button)
    end
    if button.icon then button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
end

local function create_shimmer(button)
    button.vga_bright = button:CreateTexture(nil, "OVERLAY", nil, 1)
    button.vga_bright:SetAllPoints()
    button.vga_bright:SetColorTexture(1, 1, 1, 0.18)
    button.vga_bright:SetBlendMode("ADD")
    button.vga_glow = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    button.vga_glow:SetTexture(library.media .. "SlotGlow")
    button.vga_glow:SetVertexColor(colours.gold[1], colours.gold[2], colours.gold[3], 0.55)
    button.vga_trail = {}
    for index in ipairs(TRAIL) do
        local dot = button:CreateTexture(nil, "OVERLAY", nil, 7)
        dot:SetTexture(library.media .. "Disc")
        dot:SetBlendMode("ADD")
        button.vga_trail[index] = dot
    end
    button.vga_star = button:CreateTexture(nil, "OVERLAY", nil, 7)
    button.vga_star:SetTexture(library.media .. "Star")
    button.vga_star:SetBlendMode("ADD")
end

local function create_slot(holder, slot)
    local button = CreateFrame("ItemButton", nil, holder, "ContainerFrameItemButtonTemplate")
    button:SetID(slot)
    button.vga_ground = library.create_surface(button, "BACKGROUND", -6)
    button.vga_notches = library.create_notches(button, "OVERLAY", 4)
    button.vga_edge = library.create_ring(button, "OVERLAY", 5, nil, true)
    button.vga_gem = button:CreateTexture(nil, "OVERLAY", nil, 6)
    button.vga_gem:Hide()
    button.vga_quest = library.create_text(button, "figure", colours.gold)
    button.vga_quest:SetText("?")
    update_button_parts(button)
    create_shimmer(button)
    return button
end

local function read_category(item)
    local _, _, _, _, _, class = C_Item.GetItemInfoInstant(item.itemID)
    return class
end

local function check_quest(bag, slot, item)
    local quest = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
    return read_category(item) == 12 or (quest and (quest.isQuestItem or quest.questID)) and true or false
end

local function check_match(bag, slot, item)
    local filter, wanted = bags.filter.chosen, bags.wanted
    if filter == 1 and wanted == "" then return true end
    if not item then return false end
    if filter == QUEST_FILTER and not check_quest(bag, slot, item) then return false end
    if filter == JUNK_FILTER and item.quality ~= 0 then return false end
    if filter > 1 and filter < QUEST_FILTER and not FILTERS[filter][read_category(item) or -1] then return false end
    local name = item.itemName or C_Item.GetItemNameByID(item.itemID) or ""
    return wanted == "" or string.find(name:lower(), wanted, 1, true) ~= nil
end

local function update_quest_mark(button, quest)
    button.vga_quest:SetShown(quest)
    if not quest then return end
    button.vga_quest:SetFontObject(library.read_font("figure"))
    button.vga_quest:SetTextColor(colours.gold[1], colours.gold[2], colours.gold[3])
    button.vga_quest:ClearAllPoints()
    button.vga_quest:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", read_draft(3), read_draft(2))
end

local function read_edge(item, quest, new)
    if quest or new then return colours.gold, 1 end
    if item and (item.quality or 0) >= UNCOMMON then return { C_Item.GetItemQualityColor(item.quality) }, 1 end
    return SLOT_EDGE, 1
end

local function update_slot_look(button, item, new, quest)
    local radius = 2 * EDGE_WIDTH
    local edge, share = read_edge(item, quest, new)
    library.update_surface(button.vga_ground, 0, radius, SLOT_GROUND, SLOT_GROUND)
    library.update_notches(button.vga_notches, button, radius, colours.ground)
    library.update_ring(button.vga_edge, EDGE_WIDTH, edge, share)
    local glow = read_draft(SLOT) * 64 / 42
    button.vga_glow:SetSize(glow, glow)
    button.vga_glow:SetPoint("CENTER")
    button.vga_glow:SetShown(new)
    button.vga_bright:SetShown(new)
    if not new then
        for _, dot in ipairs(button.vga_trail) do dot:Hide() end
        button.vga_star:Hide()
    end
end

local function update_slot(button, bag, slot)
    local item = C_Container.GetContainerItemInfo(bag, slot)
    local new = item ~= nil and C_NewItems.IsNewItem(bag, slot) == true
    SetItemButtonTexture(button, item and item.iconFileID)
    SetItemButtonCount(button, item and item.stackCount or 0)
    SetItemButtonDesaturated(button, item and item.isLocked)
    if button.Count then
        button.Count:SetFontObject(library.read_font("caption"))
        button.Count:SetTextColor(1, 1, 1)
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -read_draft(3), read_draft(1))
    end
    if button.UpdateCooldown then button:UpdateCooldown(item ~= nil) end
    local quest = item ~= nil and check_quest(bag, slot, item)
    update_slot_look(button, item, new, quest)
    update_quest_mark(button, quest)
    WHOLE_ALPHA(button, check_match(bag, slot, item) and 1 or DIM)
    button.vga_new = new
    return item ~= nil
end

local function read_point(share, side)
    local walked = (share % 1) * 4
    local edge, along = math.floor(walked), walked % 1
    if edge == 0 then return along * side, 0 end
    if edge == 1 then return side, -along * side end
    if edge == 2 then return side - along * side, -side end
    return 0, -side + along * side
end

local function update_trail(button, phase, side)
    local dot = read_draft(4)
    for index, step in ipairs(TRAIL) do
        local piece = button.vga_trail[index]
        local share = phase / RUN_END - step[1]
        piece:SetShown(phase < RUN_END and share >= 0)
        if piece:IsShown() then
            local across, down = read_point(share, side)
            local colour = index == 1 and { 1, 1, 1 } or colours.gold_high
            piece:SetSize(dot, dot)
            piece:ClearAllPoints()
            piece:SetPoint("CENTER", button, "TOPLEFT", across, down)
            piece:SetVertexColor(colour[1], colour[2], colour[3], step[2])
        end
    end
end

local function update_star(button, phase)
    local star = button.vga_star
    star:SetShown(phase >= STAR_FROM and phase <= STAR_END)
    if not star:IsShown() then return end
    local rising = phase <= STAR_PEAK
    local share = rising and (phase - STAR_FROM) / (STAR_PEAK - STAR_FROM) or (phase - STAR_PEAK) / (STAR_END - STAR_PEAK)
    local scale = rising and 0.3 + 0.9 * share or 1.2 - 0.8 * share
    local size = read_draft(14) * scale
    star:SetSize(size, size)
    star:ClearAllPoints()
    star:SetPoint("CENTER", button, "TOPLEFT", read_draft(1), -read_draft(1))
    star:SetRotation(math.rad(rising and 45 * share or 45 + 45 * share))
    star:SetAlpha(rising and share or 1 - share)
end

local function update_shimmer()
    local phase, side = (GetTime() % CYCLE) / CYCLE, read_draft(SLOT)
    for _, button in ipairs(bags.slots) do
        if button:IsShown() and button.vga_new then
            update_trail(button, phase, side)
            update_star(button, phase)
        end
    end
end

local function update_shimmer_safely()
    library.update_safely("bags shimmer", update_shimmer)
end

local function check_ammo(bag)
    local _, family = C_Container.GetContainerNumFreeSlots(bag)
    return family ~= nil and bit.band(family, AMMO_FAMILIES) ~= 0
end

local function check_special(bag)
    if bag > read_last_bag() or check_ammo(bag) then return true end
    return bag > 0 and IsInventoryItemProfessionBag ~= nil and IsInventoryItemProfessionBag("player", C_Container.ContainerIDToInventoryID(bag)) == true
end

local function read_groups()
    local main, special, ammo = { 0 }, {}, {}
    for bag = 1, read_final_bag() do
        if (C_Container.GetContainerNumSlots(bag) or 0) > 0 then
            if check_ammo(bag) then
                ammo[#ammo + 1] = bag
            elseif check_special(bag) then
                special[#special + 1] = bag
            else
                main[#main + 1] = bag
            end
        end
    end
    for _, bag in ipairs(ammo) do special[#special + 1] = bag end
    return main, special
end

local function update_label(holder, top)
    holder.label:SetFontObject(library.read_font("small"))
    holder.label:SetText((C_Container.GetBagName(holder:GetID()) or ""):upper())
    holder.label:ClearAllPoints()
    holder.label:SetPoint("TOPLEFT", bags.grid, "TOPLEFT", 0, -top)
    holder.label:Show()
    return top + math.ceil(holder.label:GetStringHeight()) + read_draft(SECTION_GAP)
end

local function read_entries(group)
    local entries = {}
    for _, bag in ipairs(group) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            entries[#entries + 1] = { bag = bag, slot = slot, item = C_Container.GetContainerItemInfo(bag, slot) }
        end
    end
    return vga.update_bag_order(entries)
end

local function update_group(group, top, counted)
    local size, gap = read_draft(SLOT), read_draft(GAP)
    local entries = read_entries(group)
    for place, entry in ipairs(entries) do
        local holder = bags.holders[entry.bag]
        holder.slots[entry.slot] = holder.slots[entry.slot] or create_slot(holder, entry.slot)
        local button = holder.slots[entry.slot]
        counted.index = counted.index + 1
        bags.slots[counted.index] = button
        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bags.grid, "TOPLEFT", ((place - 1) % COLUMNS) * (size + gap), -(top + math.floor((place - 1) / COLUMNS) * (size + gap)))
        button:Show()
        if update_slot(button, entry.bag, entry.slot) then counted.used = counted.used + 1 end
    end
    local rows = math.max(1, math.ceil(#entries / COLUMNS))
    return top + rows * size + (rows - 1) * gap
end

local function update_hidden_slots()
    for bag, holder in pairs(bags.holders) do
        holder.label:Hide()
        for slot = (C_Container.GetContainerNumSlots(bag) or 0) + 1, #holder.slots do holder.slots[slot]:Hide() end
    end
end

local function update_grid()
    local counted = { index = 0, used = 0 }
    local main, special = read_groups()
    update_hidden_slots()
    local top = update_group(main, 0, counted)
    for _, bag in ipairs(special) do
        top = update_label(bags.holders[bag], top + read_draft(SECTION_TOP))
        top = update_group({ bag }, top, counted)
    end
    for extra = counted.index + 1, #bags.slots do bags.slots[extra] = nil end
    return counted.index, counted.used, top
end

local function update_field()
    local field, pad = bags.field, read_draft(10)
    local radius = read_draft(RADIUS)
    field:SetHeight(read_draft(FIELD))
    library.update_surface(field.edge, -1, radius + 1, SLOT_EDGE, SLOT_EDGE)
    library.update_surface(field.ground, 0, radius, SLOT_GROUND, SLOT_GROUND)
    field.icon:SetSize(read_draft(14), read_draft(14))
    field.icon:ClearAllPoints()
    field.icon:SetPoint("LEFT", field, "LEFT", pad, 0)
    field:SetFontObject(library.read_font("body"))
    field:SetTextInsets(pad + read_draft(14) + read_draft(8), pad, 0, 0)
    field.hint:SetFontObject(library.read_font("body"))
    field.hint:ClearAllPoints()
    field.hint:SetPoint("LEFT", field.icon, "RIGHT", read_draft(8), 0)
    field.hint:SetShown(field:GetText() == "" and not field:HasFocus())
end

local function update_foot(count, used)
    local foot = bags.foot
    foot.ground:SetColorTexture(FOOT_GROUND[1], FOOT_GROUND[2], FOOT_GROUND[3], library.read_dialog_ground())
    foot.text:SetFontObject(library.read_font("small"))
    foot.text:SetText(string.format(library.texts.slots_used, used, count))
    foot.text:ClearAllPoints()
    foot.text:SetPoint("LEFT", foot, "LEFT", read_draft(PAD), 0)
    library.update_money(foot.money, GetMoney())
    foot.money:ClearAllPoints()
    foot.money:SetPoint("RIGHT", foot, "RIGHT", -read_draft(PAD), 0)
end

local function update_lines(tools_height, grid_height)
    for _, line in ipairs({ bags.tools_line, bags.foot_line }) do
        line:SetColorTexture(colours.line[1], colours.line[2], colours.line[3], 1)
        line:SetHeight(1)
    end
    bags.tools_line:ClearAllPoints()
    bags.tools_line:SetPoint("TOPLEFT", bags.body, "TOPLEFT", 0, -tools_height)
    bags.tools_line:SetPoint("TOPRIGHT", bags.body, "TOPRIGHT", 0, -tools_height)
    bags.foot_line:ClearAllPoints()
    bags.foot_line:SetPoint("BOTTOMLEFT", bags.foot, "TOPLEFT")
    bags.foot_line:SetPoint("BOTTOMRIGHT", bags.foot, "TOPRIGHT")
    return tools_height + 1 + grid_height + 1 + read_draft(FOOT)
end

local function update_bags()
    if not bags or not bags:IsShown() then return end
    library.update_dialog(bags)
    local pad, size, gap = read_draft(PAD), read_draft(SLOT), read_draft(GAP)
    local inner = COLUMNS * size + (COLUMNS - 1) * gap
    local count, used, slots_height = update_grid()
    local grid_height = slots_height + 2 * pad
    update_field()
    library.update_choice(bags.filter)
    bags.field:ClearAllPoints()
    bags.field:SetPoint("TOPLEFT", bags.body, "TOPLEFT", pad, -pad)
    bags.field:SetWidth(inner)
    bags.filter:ClearAllPoints()
    bags.filter:SetPoint("TOPLEFT", bags.field, "BOTTOMLEFT", 0, -read_draft(8))
    library.update_choice(bags.sort)
    bags.sort:ClearAllPoints()
    bags.sort:SetPoint("TOPRIGHT", bags.field, "BOTTOMRIGHT", 0, -read_draft(8))
    local tools_height = pad + read_draft(FIELD) + read_draft(8) + library.read_size(2) + pad
    bags.grid:ClearAllPoints()
    bags.grid:SetPoint("TOPLEFT", bags.body, "TOPLEFT", pad, -(tools_height + 1 + pad))
    bags.grid:SetSize(inner, grid_height - 2 * pad)
    bags.foot:ClearAllPoints()
    bags.foot:SetPoint("BOTTOMLEFT", bags.body, "BOTTOMLEFT")
    bags.foot:SetPoint("BOTTOMRIGHT", bags.body, "BOTTOMRIGHT")
    bags.foot:SetHeight(read_draft(FOOT))
    update_foot(count, used)
    local body_height = update_lines(tools_height, grid_height)
    local frame_inner = library.read_size(-4)
    bags:SetSize(inner + 2 * pad + 2 * frame_inner, library.read_size(4) + 1 + body_height + 2 * frame_inner)
    vga.update_bag_place(bags)
end

local function update_bags_safely()
    library.update_safely("bags", update_bags)
end

local function render_sorting()
    bags.sort.chosen = 0
    library.update_choice(bags.sort)
    library.render_settings("bags")
end

local function write_filter()
    update_bags_safely()
end

local function write_wanted(field)
    bags.wanted = (field:GetText() or ""):lower():match("^%s*(.-)%s*$")
    update_bags_safely()
end

local function create_field()
    local field = CreateFrame("EditBox", nil, bags.body)
    field:SetAutoFocus(false)
    field:SetMaxLetters(40)
    field.edge = library.create_surface(field, "BACKGROUND", 0)
    field.ground = library.create_surface(field, "BACKGROUND", 1)
    field.icon = field:CreateTexture(nil, "ARTWORK")
    field.icon:SetTexture(library.media .. "Search")
    field.icon:SetVertexColor(FIELD_INK[1], FIELD_INK[2], FIELD_INK[3], 1)
    field.hint = library.create_text(field, "body", FIELD_INK)
    field.hint:SetText(library.texts.search_bags)
    field:SetScript("OnEscapePressed", field.ClearFocus)
    field:SetScript("OnEnterPressed", field.ClearFocus)
    field:SetScript("OnTextChanged", write_wanted)
    field:SetScript("OnEditFocusGained", update_field)
    field:SetScript("OnEditFocusLost", update_field)
    return field
end

local function create_foot()
    local foot = CreateFrame("Frame", nil, bags.body)
    foot.ground = foot:CreateTexture(nil, "BACKGROUND")
    foot.ground:SetAllPoints()
    foot.text = library.create_text(foot, "small", FOOT_INK)
    foot.money = library.create_money(foot, FOOT_INK)
    foot.money.kind = "small"
    return foot
end

local function check_ours(frame)
    local bag = frame:GetID()
    return frame == ContainerFrameCombinedBags or (bag ~= nil and bag >= 0 and bag <= read_final_bag())
end

local function check_wanted()
    for _, frame in ipairs(watched) do
        if frame:IsShown() and frame:GetParent() == hidden then return true end
    end
    return false
end

local function update_from_game()
    bags.pending = false
    local wanted = check_wanted()
    if wanted ~= bags:IsShown() then bags:SetShown(wanted) end
end

local function update_from_game_soon()
    if not bags or bags.pending then return end
    bags.pending = true
    C_Timer.After(0, update_from_game)
end

local function update_game_parent(frame)
    if frame:IsShown() then return end
    frame:SetParent(check_ours(frame) and hidden or UIParent)
end

local function update_game_frames()
    for _, frame in ipairs(watched) do update_game_parent(frame) end
end

local function update_opened()
    PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    update_bags_safely()
end

local function update_closed()
    PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
    if check_wanted() and CloseAllBags then CloseAllBags() end
    if C_NewItems and C_NewItems.ClearAll then C_NewItems.ClearAll() end
end

local function create_watch()
    local frames = { ContainerFrameCombinedBags }
    for index = 1, NUM_CONTAINER_FRAMES or 13 do frames[#frames + 1] = _G["ContainerFrame" .. index] end
    for _, frame in ipairs(frames) do
        if frame then
            watched[#watched + 1] = frame
            update_game_parent(frame)
            if frame.SetBagID then hooksecurefunc(frame, "SetBagID", update_game_parent) end
            hooksecurefunc(frame, "Show", update_from_game_soon)
            hooksecurefunc(frame, "Hide", update_from_game_soon)
        end
    end
    if ContainerFrame_SetFullScreenFrame then hooksecurefunc("ContainerFrame_SetFullScreenFrame", update_game_frames) end
end

local function update_on_event()
    if bags and bags:IsShown() then update_bags_safely() end
end

local function create_bags()
    local texts = library.texts
    bags = library.create_dialog("VGABags", texts.bags)
    vga.create_bag_place(bags)
    bags:Hide()
    bags.wanted = ""
    bags.slots, bags.holders = {}, {}
    bags.field = create_field()
    bags.filter = library.create_choice(bags.body, {
        texts.filter_all,
        { icon = "FilterArmour", tip = texts.equipment },
        { icon = "FilterBottle", tip = texts.consumables },
        { icon = "FilterHammer", tip = texts.crafting },
        { icon = "FilterQuest", tip = texts.quest_items },
        { icon = "FilterJunk", tip = texts.junk },
    }, 1, write_filter)
    bags.tools_line = bags.body:CreateTexture(nil, "BORDER")
    bags.grid = CreateFrame("Frame", nil, bags.body)
    for bag = 0, read_final_bag() do
        local holder = CreateFrame("Frame", nil, bags.grid)
        holder:SetID(bag)
        holder:SetAllPoints()
        holder.slots = {}
        holder.label = library.create_text(holder, "small", colours.quiet)
        bags.holders[bag] = holder
    end
    bags.foot = create_foot()
    bags.foot_line = bags.body:CreateTexture(nil, "BORDER")
    bags:SetScript("OnShow", update_opened)
    bags:SetScript("OnHide", update_closed)
    bags:SetScript("OnUpdate", update_shimmer_safely)
    create_watch()
    bags.sort = library.create_choice(bags.body, { { icon = "Sort", tip = texts.sort_tip } }, 0, render_sorting)
    library.create_element("bags", { update = update_bags, title = texts.bags, icon = "TabBags", tab = vga.create_bags_page })
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "BAG_NEW_ITEMS_UPDATED", "PLAYER_MONEY" }) do
    events:RegisterEvent(name)
end
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        library.update_safely("bags login", create_bags)
    else
        update_on_event()
    end
end)
vga.read_bag_slots = read_bag_slots
