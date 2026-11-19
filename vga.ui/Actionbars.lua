-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: vga.ui's own action bars as manual/view/vga-mainbar.html draws them: eight bars of twelve protected keys of our own, on Blizzard's own pages - the main bar on the player's action slots, turning its page with stance, form, vehicle and override as Blizzard's does, the second on page 6, the third on 5, the fourth and fifth on 3 and 4, Blizzard's right bars, the sixth to eighth on 13 to 15 -, bound to the player's own keys, each shown or hidden as the settings say, bars 4 to 8 at first as the player had them in Blizzard's settings; two rows by default, the second and third bar side by side above the main bar, the second at the left, or all in one row, as the settings' »Leisten« page says, the bottom row centred on the screen whole; in one row two or three bars as the settings say, three by default, in two rows always three; the whole element - bars, game menu, bag bar and gryphons - scaled down as far as needed for the gryphons' outer ends to fit the screen's width, the widget itself never scaled but drawn around them at whole pixels, so its pieces show no seams; the game menu and the bag bar beside them; behind them one widget in the tooltip's look with its gold corner, the experience bar of Experience.lua between the rows; the keys dressed as the draft's .key; the game's own gryphons drawn at both ends. Bars 4 to 8 always stand free, each in a widget of its own. In the third form, »lose«, the gryphons and the shared widget go: each bar, the game menu, the bag bar and the experience bar stands in a widget of its own, with its own ground and gold corner, moved in the edit mode, at first scattered over the screen so that arranging them is plainly the next step; each free bar stacks its keys 1, 2, 3, 4, 6 or 12 to a row and each area is drawn small, normal or large - 80, 100 or 125 per cent - as the »Leisten« page says, which Barsettings.lua draws. Blizzard's eight bars and experience bars are put away in a hidden frame and put back there whenever Blizzard's managed layout takes them out again; nothing protected is moved in a fight. The game's range dot, which an unbound key shows in its key's corner, is drawn in the game's Arial Narrow, since our faces lack the glyph; the bars are laid anew when the game's Edit Mode layouts arrive, late on a character's first login.

-- {K0375} {K0376} {K0377} {K0380} {K0382} {K0384} {K0385} {K0419}

local _, vga = ...
local library = LibVGA
local DRAFT_BASE = 13
local KEYS = 12
local BARS = {
    { name = "VGAActionBar", page = 1, command = "ACTIONBUTTON" },
    { name = "VGASecondBar", page = 6, command = "MULTIACTIONBAR1BUTTON", blizzard = "MultiBarBottomLeft" },
    { name = "VGAThirdBar", page = 5, command = "MULTIACTIONBAR2BUTTON", blizzard = "MultiBarBottomRight" },
    { name = "VGAFourthBar", page = 3, command = "MULTIACTIONBAR3BUTTON", blizzard = "MultiBarRight", visible = "MultiBar3_IsVisible" },
    { name = "VGAFifthBar", page = 4, command = "MULTIACTIONBAR4BUTTON", blizzard = "MultiBarLeft", visible = "MultiBar4_IsVisible" },
    { name = "VGASixthBar", page = 13, command = "MULTIACTIONBAR5BUTTON", blizzard = "MultiBar5", visible = "MultiBar5_IsVisible" },
    { name = "VGASeventhBar", page = 14, command = "MULTIACTIONBAR6BUTTON", blizzard = "MultiBar6", visible = "MultiBar6_IsVisible" },
    { name = "VGAEighthBar", page = 15, command = "MULTIACTIONBAR7BUTTON", blizzard = "MultiBar7", visible = "MultiBar7_IsVisible" },
}
local DOT_FONT = "Fonts\\ARIALN.TTF"
local ALWAYS_FREE = 4
local BLACK = { 0, 0, 0 }
local PAGES = "[vehicleui][possessbar] 12; [overridebar] 14; [shapeshift] 13; [bonusbar:5] 11; [bonusbar:4] 10; [bonusbar:3] 9; [bonusbar:2] 8; [bonusbar:1] 7; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"
local TURN_PAGE = [[
    for index = 1, 12 do
        self:GetFrameRef("key" .. index):SetAttribute("actionpage", newstate)
    end
]]
local COLUMNS = { 12, 6, 4, 3, 2, 1 }
local LOOSE_AREAS = { "xpbar", "menu", "bags" }
local SCATTERED = {
    { "bar1", 0, -230 }, { "bar2", -330, 140 }, { "bar3", 300, -40 }, { "bar4", 560, 0 }, { "bar5", 500, 0 },
    { "bar6", 0, 160 }, { "bar7", 0, 220 }, { "bar8", 0, 280 }, { "menu", -360, -150 }, { "bags", 340, 210 }, { "xpbar", -40, 40 },
}
local UPRIGHT = { [4] = 1, [5] = 1 }
local mainbar
local kept = {}

local function read_draft(pixels)
    return math.floor(pixels * library.read_base() / DRAFT_BASE + 0.5)
end

local function read_one_row()
    return LibVGASettings.mainbar_form == "one"
end

local function read_loose()
    return LibVGASettings.mainbar_form == "loose"
end

local function read_three()
    return not read_one_row() or LibVGASettings.mainbar_count ~= "two"
end

local function check_free(index)
    return index >= ALWAYS_FREE or read_loose()
end

local function read_columns(index)
    if not check_free(index) then return KEYS end
    local wanted = (LibVGASettings.loose_columns or {})[index]
    for _, count in ipairs(COLUMNS) do
        if count == wanted then return count end
    end
    return UPRIGHT[index] or KEYS
end

local function read_shown(index)
    if not read_loose() and index <= 2 then return true end
    if not read_loose() and index == 3 then return read_three() end
    local shown = (LibVGASettings.bars_shown or {})[index]
    if shown == nil then return index < ALWAYS_FREE end
    return shown
end

local function write_blizzard_shown()
    LibVGASettings.bars_shown = LibVGASettings.bars_shown or {}
    for index = ALWAYS_FREE, #BARS do
        local visible = _G[BARS[index].visible]
        if LibVGASettings.bars_shown[index] == nil then
            LibVGASettings.bars_shown[index] = visible and visible() and true or false
        end
    end
end

local function update_hotkey_face(hotkey, text)
    if text == RANGE_INDICATOR then
        local _, size = library.read_font("caption"):GetFont()
        hotkey:SetFont(DOT_FONT, size or 10, "OUTLINE")
    else
        hotkey:SetFontObject(library.read_font("caption"))
    end
end

local function create_key(bar, name, index, command)
    local key = CreateFrame("CheckButton", name .. index, bar, "ActionBarButtonTemplate")
    key:SetID(index)
    key.buttonType = command
    key:SetAttribute("actionpage", bar.page)
    key:RegisterForClicks("AnyUp")
    key.command = command .. index
    if key.HotKey then hooksecurefunc(key.HotKey, "SetText", update_hotkey_face) end
    if key.UpdateHotkeys then key:UpdateHotkeys(command) end
    for _, part in ipairs({ key.NormalTexture, key.SlotArt, key.SlotBackground, key.IconMask }) do
        if part then part:SetAlpha(0) end
    end
    if key.icon and key.IconMask then key.icon:RemoveMaskTexture(key.IconMask) end
    if key.icon then key.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    key.vga_line = library.create_surface(key, "BACKGROUND", -8)
    key.vga_notches = library.create_notches(key, "OVERLAY", 7)
    for _, state in ipairs({ key:GetHighlightTexture(), key:GetPushedTexture(), key:GetCheckedTexture() }) do
        state:SetTexture("Interface\\Buttons\\WHITE8X8")
        state:SetVertexColor(1, 1, 1, 0.15)
        state:SetAllPoints(key.icon)
    end
    return key
end

local function create_bar(name, page, command)
    local bar = CreateFrame("Frame", name, UIParent, "SecureHandlerStateTemplate")
    bar.page = page
    bar.keys = {}
    for index = 1, KEYS do
        bar.keys[index] = create_key(bar, name .. "Key", index, command)
        bar:SetFrameRef("key" .. index, bar.keys[index])
    end
    return bar
end

local function update_key_look(key, size, across, down)
    local radius = read_draft(5)
    key:SetSize(size, size)
    key:ClearAllPoints()
    key:SetPoint("TOPLEFT", key:GetParent(), "TOPLEFT", across, -down)
    library.update_surface(key.vga_line, -1, radius + 1, BLACK, BLACK)
    library.update_notches(key.vga_notches, key, radius, BLACK)
    if key.HotKey then
        update_hotkey_face(key.HotKey, key.HotKey:GetText())
        key.HotKey:ClearAllPoints()
        key.HotKey:SetPoint("TOPRIGHT", key, "TOPRIGHT", -read_draft(4), -read_draft(2))
    end
end

local function update_bar_layout(bar, columns)
    local size, gap = read_draft(38), read_draft(3)
    local rows = KEYS / columns
    bar:SetSize(columns * size + (columns - 1) * gap, rows * size + (rows - 1) * gap)
    for index, key in ipairs(bar.keys) do
        local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
        update_key_look(key, size, column * (size + gap), row * (size + gap))
    end
end

local function update_bindings()
    for index, bar in ipairs(mainbar.bars) do
        ClearOverrideBindings(bar)
        for _, key in ipairs(read_shown(index) and bar.keys or {}) do
            for _, binding in ipairs({ GetBindingKey(key.command) }) do
                SetOverrideBindingClick(bar, false, binding, key:GetName(), "LeftButton")
            end
        end
    end
end

local function update_kept_away(blizzard)
    if blizzard:GetParent() ~= mainbar.hider and not InCombatLockdown() then blizzard:SetParent(mainbar.hider) end
end

local function update_put_away()
    if not mainbar.hider then
        mainbar.hider = CreateFrame("Frame")
        mainbar.hider:Hide()
    end
    local blizzards = { MainActionBar, MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }
    for _, bar in ipairs(BARS) do blizzards[#blizzards + 1] = bar.blizzard and _G[bar.blizzard] end
    for _, blizzard in pairs(blizzards) do
        if blizzard and not kept[blizzard] then
            kept[blizzard] = true
            hooksecurefunc(blizzard, "SetParent", function(frame) library.update_safely("mainbar kept", update_kept_away, frame) end)
        end
        if blizzard then update_kept_away(blizzard) end
    end
end

local function read_width(frame)
    if not frame then return 0 end
    return frame:GetWidth() * frame:GetEffectiveScale() / mainbar.first_bar:GetEffectiveScale()
end

local function read_row_shift(two, gap)
    local bar = mainbar.first_bar:GetWidth()
    local micro, bags = read_width(MicroMenuContainer), read_width(BagsBar)
    local count = two and 1 or (read_three() and 3 or 2)
    local bars = count * bar + (count - 1) * gap
    local total = micro + gap + bars + gap + bags
    return -total / 2 + micro + gap + bar / 2
end

local function update_rows()
    local first, second, third = mainbar.first_bar, mainbar.second_bar, mainbar.third_bar
    local two, gap = not read_one_row(), read_draft(14)
    first:ClearAllPoints()
    first:SetPoint("BOTTOM", UIParent, "BOTTOM", read_row_shift(two, gap), gap)
    second:ClearAllPoints()
    third:ClearAllPoints()
    local above = (vga.read_experience_height() + 2 * read_draft(5)) / first:GetScale()
    third:SetShown(read_three())
    if two and read_three() then
        second:SetPoint("BOTTOMRIGHT", first, "TOP", -gap / 2, above)
        third:SetPoint("LEFT", second, "RIGHT", gap, 0)
    elseif two then
        second:SetPoint("BOTTOM", first, "TOP", 0, above)
    else
        second:SetPoint("LEFT", first, "RIGHT", gap, 0)
        third:SetPoint("LEFT", second, "RIGHT", gap, 0)
    end
    return two
end

local function update_sides()
    local first = mainbar.first_bar
    local last = read_one_row() and (read_three() and mainbar.third_bar or mainbar.second_bar) or first
    if MicroMenuContainer then
        MicroMenuContainer:ClearAllPoints()
        MicroMenuContainer:SetPoint("RIGHT", first, "LEFT", -read_draft(14), 0)
    end
    if BagsBar then
        BagsBar:ClearAllPoints()
        BagsBar:SetPoint("LEFT", last, "RIGHT", read_draft(14), 0)
    end
    return last
end

local function read_outer(one, other, side)
    if not one then return other end
    local reach = side == "LEFT" and "GetLeft" or "GetRight"
    local mine = (one[reach](one) or 0) * one:GetEffectiveScale()
    local theirs = (other[reach](other) or 0) * other:GetEffectiveScale()
    if side == "LEFT" then return mine <= theirs and one or other end
    return mine >= theirs and one or other
end

local function update_widget(two, last)
    local pad = read_draft(8)
    local first = mainbar.first_bar
    local left = read_outer(MicroMenuContainer, two and mainbar.second_bar or first, "LEFT")
    local right = read_outer(BagsBar, two and (read_three() and mainbar.third_bar or mainbar.second_bar) or last, "RIGHT")
    mainbar:ClearAllPoints()
    mainbar:SetPoint("LEFT", left, "LEFT", -pad, 0)
    mainbar:SetPoint("RIGHT", right, "RIGHT", pad, 0)
    mainbar:SetPoint("BOTTOM", first, "BOTTOM", 0, -pad)
    mainbar:SetPoint("TOP", two and mainbar.second_bar or first, "TOP", 0, pad + (two and 0 or vga.read_experience_height() + read_draft(5)))
    library.update_frame(mainbar)
end

local function update_experience()
    local block, pad = mainbar.experience, read_draft(8)
    block:ClearAllPoints()
    block:SetPoint("LEFT", mainbar, "LEFT", pad, 0)
    block:SetPoint("RIGHT", mainbar, "RIGHT", -pad, 0)
    block:SetPoint("BOTTOM", mainbar.first_bar, "TOP", 0, read_draft(5))
    block:SetHeight(vga.read_experience_height())
    vga.update_experience(block)
end

local function update_gryphons()
    local overlap, height = read_draft(34), read_draft(95)
    for side, gryphon in pairs(mainbar.gryphons) do
        local width = math.floor(height * 154 / 95 + 0.5)
        gryphon:SetSize(width, height)
        gryphon:ClearAllPoints()
        if side == "left" then
            gryphon:SetPoint("BOTTOMRIGHT", mainbar, "BOTTOMLEFT", overlap, 0)
        else
            gryphon:SetPoint("BOTTOMLEFT", mainbar, "BOTTOMRIGHT", -overlap, 0)
        end
    end
end

local function read_natural_width(two)
    local gap, bar = read_draft(14), mainbar.first_bar:GetWidth()
    local micro = MicroMenuContainer and MicroMenuContainer:GetWidth() * mainbar.base.micro or 0
    local bags = BagsBar and BagsBar:GetWidth() * mainbar.base.bags or 0
    local count = two and 1 or (read_three() and 3 or 2)
    local bottom = micro + gap + count * bar + (count - 1) * gap + gap + bags
    local top = two and (read_three() and 2 * bar + gap or bar) or 0
    local gryphon = math.floor(read_draft(95) * 154 / 95 + 0.5) - read_draft(34)
    return math.max(bottom, top) + 2 * read_draft(8) + 2 * gryphon
end

local function update_fit()
    local fit = math.min(1, UIParent:GetWidth() / read_natural_width(not read_one_row()))
    for _, frame in ipairs({ mainbar.first_bar, mainbar.second_bar, mainbar.third_bar, mainbar.gryphons.left, mainbar.gryphons.right }) do
        frame:SetScale(fit)
    end
    if MicroMenuContainer then MicroMenuContainer:SetScale(mainbar.base.micro * fit) end
    if BagsBar then BagsBar:SetScale(mainbar.base.bags * fit) end
end

local function update_area(key, inner, width, height)
    local area, pad, step = mainbar.areas[key], read_draft(8), library.read_size_step(key)
    local scale = inner:GetEffectiveScale() / area:GetEffectiveScale()
    inner:ClearAllPoints()
    inner:SetPoint("CENTER", area, "CENTER")
    area:SetSize(math.floor(width * scale + 2 * pad + 0.5), math.floor(height * scale + 2 * pad + 0.5))
    library.update_frame(area)
    return step
end

local function update_loose_blizzard(key, frame, base)
    if not frame then return end
    frame:SetParent(mainbar.areas[key])
    frame:SetScale(base * library.read_size_step(key))
    update_area(key, frame, frame:GetWidth(), frame:GetHeight())
end

local function update_free_bars()
    for index, bar in ipairs(mainbar.bars) do
        local area = mainbar.areas["bar" .. index]
        area:SetShown(check_free(index) and read_shown(index))
        if check_free(index) then
            update_bar_layout(bar, read_columns(index))
            bar:SetParent(area)
            bar:SetScale(library.read_size_step("bar" .. index))
            bar:SetShown(read_shown(index))
            update_area("bar" .. index, bar, bar:GetWidth(), bar:GetHeight())
        end
    end
end

local function update_loose()
    update_loose_blizzard("menu", MicroMenuContainer, mainbar.base.micro)
    update_loose_blizzard("bags", BagsBar, mainbar.base.bags)
    local block = mainbar.experience
    block:SetParent(mainbar.areas.xpbar)
    block:SetScale(library.read_size_step("xpbar"))
    block:SetSize(KEYS * read_draft(38) + (KEYS - 1) * read_draft(3), vga.read_experience_height())
    update_area("xpbar", block, block:GetWidth(), block:GetHeight())
    vga.update_experience(block)
end

local function update_form()
    local loose = read_loose()
    mainbar:SetShown(not loose)
    for _, gryphon in pairs(mainbar.gryphons) do gryphon:SetShown(not loose) end
    for _, key in ipairs(LOOSE_AREAS) do mainbar.areas[key]:SetShown(loose) end
    mainbar.base = mainbar.base or {
        micro = MicroMenuContainer and MicroMenuContainer:GetScale() or 1, bags = BagsBar and BagsBar:GetScale() or 1,
        micro_parent = MicroMenuContainer and MicroMenuContainer:GetParent(), bags_parent = BagsBar and BagsBar:GetParent(),
    }
    if loose then return true end
    if MicroMenuContainer then MicroMenuContainer:SetParent(mainbar.base.micro_parent) end
    if BagsBar then BagsBar:SetParent(mainbar.base.bags_parent) end
    for _, bar in ipairs({ mainbar.first_bar, mainbar.second_bar, mainbar.third_bar }) do bar:SetParent(UIParent) end
    mainbar.experience:SetParent(mainbar)
    mainbar.experience:SetScale(1)
    return false
end

vga.bars = {
    count = #BARS, columns = COLUMNS, always_free = ALWAYS_FREE,
    read_columns = read_columns, read_shown = read_shown, check_free = check_free, read_loose = read_loose, read_one_row = read_one_row,
}

function vga.update_bar_bindings()
    if mainbar and not InCombatLockdown() then update_bindings() end
end

function vga.read_bars_anchor()
    if mainbar and read_loose() then return mainbar.areas.bar1 end
    return mainbar
end

local function update_mainbar()
    if not mainbar then return end
    if InCombatLockdown() then
        vga.update_experience(mainbar.experience)
        return
    end
    update_put_away()
    local loose = update_form()
    update_free_bars()
    if loose then
        update_loose()
        return
    end
    update_experience()
    update_bar_layout(mainbar.first_bar, KEYS)
    update_bar_layout(mainbar.second_bar, KEYS)
    update_bar_layout(mainbar.third_bar, KEYS)
    update_fit()
    local two = update_rows()
    local last = update_sides()
    update_widget(two, last)
    update_gryphons()
end

local function create_gryphons()
    local gryphons = {}
    for _, side in ipairs({ "left", "right" }) do
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:SetFrameStrata("MEDIUM")
        holder:SetFrameLevel(100)
        holder.art = holder:CreateTexture(nil, "OVERLAY")
        holder.art:SetAllPoints()
        holder.art:SetAtlas("ui-hud-actionbar-gryphon-" .. side)
        gryphons[side] = holder
    end
    return gryphons
end

local function update_mainbar_safely()
    library.update_safely("mainbar", update_mainbar)
end

local function create_area(key, x, y)
    local area = library.create_frame("VGALoose" .. key, UIParent)
    area:SetFrameStrata("BACKGROUND")
    area.corner:SetScript("OnClick", function(corner) library.update_safely("options", library.render_widget, corner, key) end)
    library.create_place(area, key, "CENTER", UIParent, x, y)
    area:Hide()
    return area
end

local function create_areas()
    local areas = {}
    for _, spot in ipairs(SCATTERED) do areas[spot[1]] = create_area(spot[1], spot[2], spot[3]) end
    return areas
end

local function create_mainbar()
    local widget = library.create_frame("VGAMainbar", UIParent)
    widget:SetFrameStrata("BACKGROUND")
    widget.place_key = "mainbar"
    widget.corner:SetScript("OnClick", function(corner) library.update_safely("options", library.render_widget, corner, "mainbar") end)
    widget.bars = {}
    for index, bar in ipairs(BARS) do widget.bars[index] = create_bar(bar.name, bar.page, bar.command) end
    widget.first_bar, widget.second_bar, widget.third_bar = widget.bars[1], widget.bars[2], widget.bars[3]
    widget.first_bar:SetAttribute("_onstate-page", TURN_PAGE)
    RegisterStateDriver(widget.first_bar, "page", PAGES)
    widget.experience = vga.create_experience(widget)
    widget.gryphons = create_gryphons()
    widget.areas = create_areas()
    mainbar = widget
    write_blizzard_shown()
    if EventRegistry then EventRegistry:RegisterCallback("EditMode.Exit", update_mainbar_safely, mainbar) end
    library.create_element("mainbar", { title = library.texts.bars, icon = "TabBars", update = update_mainbar, tab = vga.create_bars_page })
    update_bindings()
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "UI_SCALE_CHANGED", "UPDATE_BINDINGS", "EDIT_MODE_LAYOUTS_UPDATED" }) do
    pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then library.update_safely("mainbar login", create_mainbar) end
    if event == "UPDATE_BINDINGS" and mainbar and not InCombatLockdown() then library.update_safely("mainbar keys", update_bindings) end
    update_mainbar_safely()
end)
