-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: vga.ui's one settings dialog as the accepted draft orders it (manual/view/vga-settings.html), standing high on the screen, its top fixed, as tall as the tab shown and growing or shrinking downward with a soft, eased animation, as wide as its widest tab: a tab with picture and word per thing the player sees - Allgemein, Einheiten, Plaketten, then each element's own, Leisten, Erfahrung, Quests -, at most seven rows a tab; Allgemein ending in the red »Alles zurücksetzen …«, which asks once; the last tab, Anordnen, reached from everywhere, with the alignment - free or on a grid of eight or of sixteen pixels - and the gold »Anordnen …«, which closes the dialog and shows the handles; every choice working at once - a new face measured again a moment later, when the game has loaded its file, so that every width follows it; the one menu there is - a widget's gold corner opens it on the widget's tab, the widget's own settings in the group »Widgets« at the tab's foot; and the command /vga.

-- {K0268} {K0311} {K0316} {K0324} {K0330} {K0337} {K0383} {K0384} {K0430}

local library = LibVGA

local settings
local ORDER = { "mainbar", "experience", "arcs", "quests", "bags", "map" }
local GROW = 0.25
local FROM_TOP = 0.12
local FONT_LOADED = 0.3

local function update_grown(dialog)
    local share = math.min((GetTime() - dialog.grow_from) / GROW, 1)
    local eased = 1 - (1 - share) * (1 - share) * (1 - share)
    dialog:SetHeight(dialog.grow_start + (dialog.grow_to - dialog.grow_start) * eased)
    if share >= 1 then dialog:SetScript("OnUpdate", nil) end
end

local function update_height()
    local page = settings.pages[settings.chosen]
    if not page or not page.wanted then return end
    local target = settings.frame_height + page.wanted
    if math.abs(target - settings:GetHeight()) < 1 or not settings:IsShown() then
        settings:SetHeight(target)
        return
    end
    settings.grow_from, settings.grow_start, settings.grow_to = GetTime(), settings:GetHeight(), target
    settings:SetScript("OnUpdate", update_grown)
end

local function update_tab(name)
    settings.chosen = name
    for key, page in pairs(settings.pages) do
        page:SetShown(key == name)
    end
    update_height()
end

local function update_top(dialog)
    dialog:StopMovingOrSizing()
    local left, top = dialog:GetLeft(), dialog:GetTop()
    dialog:ClearAllPoints()
    dialog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

function library.create_choice_row(page, label, labels, chosen, on_choose)
    local row = library.create_row(page, label)
    row.control = library.create_choice(row, labels, chosen, on_choose)
    return row
end

local function update_arranging()
    settings:Hide()
    library.update_edit(true, true)
end

local function update_reset_all()
    library.update_reset()
    library.render_settings_anew()
end

local function create_general_page(page)
    local texts = library.texts
    local sizes = { "small", "medium", "large" }
    local size = library.create_choice_row(page, texts.interface_size, { texts.small, texts.medium, texts.large }, ({ small = 1, medium = 2, large = 3 })[LibVGASettings.size] or 2, function(index)
        LibVGASettings.size = sizes[index]
        library.update_elements()
    end)
    local faces_row = library.create_row(page, "", "wide")
    local samples, chosen = {}, 1
    for index, key in ipairs(library.face_order) do
        local name, plain = library.read_face(key)
        samples[index] = { label = name, sample = "Ag", face = plain }
        if key == (LibVGASettings.face or "geologica") then chosen = index end
    end
    faces_row.control = library.create_pictures(faces_row, samples, chosen, function(index)
        library.update_choice_setting("face", library.face_order[index])
        C_Timer.After(FONT_LOADED, library.update_elements)
    end, "tile")
    local frames = library.create_row(page, texts.background)
    frames.control = library.create_slider(frames, library.ground_stops, library.read_ground(), function(value)
        LibVGASettings.ground = value
        library.update_grounds()
    end)
    frames.control.on_settle = library.update_elements
    local dialogs = library.create_row(page, texts.dialogs)
    dialogs.control = library.create_slider(dialogs, library.dialog_stops, library.read_dialog_ground(), function(value)
        LibVGASettings.dialog = value
        library.update_elements()
    end)
    local faces = library.create_choice_row(page, texts.portraits, { texts.animated, texts.still_picture }, library.read_faces_moving() and 1 or 2, function(index)
        library.update_choice_setting("faces", index == 1 and "moving" or "still")
    end)
    local cursor = library.create_choice_row(page, texts.cursor, { texts.off, texts.on }, library.read_cursor_trail() and 2 or 1, function(index)
        library.update_choice_setting("cursor", index == 2 and "on" or "off")
    end)
    local reset = library.create_button(page, texts.reset_all, "alarm", update_reset_all)
    reset.ask = texts.reset_sure
    local font = library.create_row(page, texts.font, "heading")
    font.members = { faces_row }
    page.rows = { font, faces_row, size, frames, dialogs, faces, cursor }
    page.foot = { reset }
end

local function create_units_page(page)
    local texts = library.texts
    page.rows = {
        library.create_choice_row(page, texts.values, { texts.absolute, texts.percent }, library.read_values_percent() and 2 or 1, function(index)
            library.update_choice_setting("values", index == 2 and "percent" or "absolute")
        end),
    }
    for _, row in ipairs(library.create_widget_rows(page, "units", {
        { key = "units", title = texts.unit_frames },
        { key = "party", title = texts.party },
    })) do page.rows[#page.rows + 1] = row end
end

local function create_plates_page(page)
    local texts = library.texts
    page.rows = {
        library.create_choice_row(page, texts.level, { texts.shield, texts.number }, library.read_plate_number() and 2 or 1, function(index)
            library.update_choice_setting("plate_level", index == 2 and "number" or "shield")
        end),
        library.create_choice_row(page, texts.friends, { texts.line, texts.frame }, LibVGASettings.friend_style == "frame" and 2 or 1, function(index)
            library.update_choice_setting("friend_style", index == 2 and "frame" or "line")
        end),
        library.create_choice_row(page, texts.guild, { texts.above_name, texts.below_name }, LibVGASettings.friend_name == "above" and 1 or 2, function(index)
            library.update_choice_setting("friend_name", index == 1 and "above" or "below")
        end),
    }
end

local function create_arrange_page(page)
    local texts = library.texts
    page.rows = {
        library.create_choice_row(page, texts.alignment, { texts.free, texts.grid, texts.grid16 }, ({ grid = 2, grid16 = 3 })[LibVGASettings.alignment] or 1, function(index)
            LibVGASettings.alignment = ({ "free", "grid", "grid16" })[index]
        end),
    }
    page.foot = { library.create_button(page, texts.arrange, "gold", update_arranging) }
end

local function read_pages()
    local texts = library.texts
    local pages = {
        { key = "general", title = texts.general, icon = "TabGeneral", build = create_general_page },
        { key = "units", title = texts.units, icon = "TabUnits", build = create_units_page },
        { key = "plates", title = texts.plates, icon = "TabPlates", build = create_plates_page },
    }
    for _, key in ipairs(ORDER) do
        local element = library.elements[key]
        if element and element.tab then
            pages[#pages + 1] = { key = key, title = element.title or key, icon = element.icon, build = element.tab }
        end
    end
    pages[#pages + 1] = { key = "arrange", title = texts.arranging, icon = "TabArrange", build = create_arrange_page }
    pages[#pages + 1] = { key = "profiles", title = texts.profiles, icon = "TabProfiles", build = library.create_profiles_page }
    return pages
end

local function create_settings()
    settings = library.create_dialog("LibVGASettingsDialog", "vga.ui · " .. library.texts.settings)
    settings:SetClipsChildren(true)
    settings:SetScript("OnDragStop", update_top)
    settings.pages, settings.order = {}, {}
    local pages = read_pages()
    for index, entry in ipairs(pages) do
        local page = CreateFrame("Frame", nil, settings.body)
        entry.build(page)
        settings.pages[entry.key] = page
        settings.order[index] = entry.key
    end
    settings.tabs = library.create_tabs(settings.body, pages, function(index)
        update_tab(settings.order[index])
    end)
    library.create_element("settings", { update = library.update_settings })
    update_tab("general")
end

local function read_foot_height(page)
    return page.foot and library.read_size(2) + 2 * library.read_size(-2) or 0
end

local function update_foot(page)
    local pad = library.read_size(0)
    for index, button in ipairs(page.foot or {}) do
        library.update_button(button)
        button:ClearAllPoints()
        if index == 1 and button.kind ~= "alarm" then
            button:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", pad, library.read_size(-2))
        else
            button:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -pad, library.read_size(-2))
        end
    end
end

function library.update_settings()
    if not settings then return end
    library.update_dialog(settings)
    local band = library.read_tabs_height()
    local widest, columns = 0, {}
    for _, key in ipairs(settings.order) do
        local page = settings.pages[key]
        columns[key] = library.update_row_controls(page.rows or {})
        page.wanted = library.read_rows_height(page.rows or {}) + read_foot_height(page)
        widest = math.max(widest, library.read_rows_width(page.rows or {}, columns[key]))
    end
    local head, inner = library.read_size(4), library.read_size(-4)
    local width = math.max(widest, library.read_tabs_width(settings.tabs), settings.title:GetStringWidth() + library.read_size(6)) + 2 * inner
    settings.frame_height = head + 1 + band + 2 * inner
    settings:SetWidth(width)
    settings.tabs:ClearAllPoints()
    settings.tabs:SetPoint("TOPLEFT", settings.body, "TOPLEFT")
    settings.tabs:SetSize(width - 2 * inner, band)
    library.update_tabs(settings.tabs)
    for _, key in ipairs(settings.order) do
        local page = settings.pages[key]
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT", settings.body, "TOPLEFT", 0, -band)
        page:SetPoint("BOTTOMRIGHT", settings.body, "BOTTOMRIGHT")
        library.update_rows(page.rows or {}, page, 0, columns[key], width - 2 * inner)
        update_foot(page)
    end
    update_height()
end

function library.render_settings_anew()
    local chosen = settings and settings.chosen
    if settings then settings:Hide() end
    settings = nil
    library.render_settings(chosen or "general")
end

function library.render_settings(key)
    if not settings then
        create_settings()
        settings:SetPoint("TOP", UIParent, "TOP", 0, -math.floor(UIParent:GetHeight() * FROM_TOP))
        library.update_settings()
    end
    settings:Show()
    for index, name in ipairs(settings.order) do
        if name == (key or settings.chosen) then
            settings.tabs.chosen = index
            library.update_tabs(settings.tabs)
            update_tab(name)
        end
    end
end

SLASH_LIBVGA1 = "/vga"
local function update_from_command(message)
    if (message or ""):lower():match("^%s*edit") then
        library.update_edit(not library.editing, true)
    elseif (message or ""):lower():match("^%s*overlap") then
        library.render_overlaps()
    elseif (message or ""):lower():match("^%s*outline") then
        library.update_choice_setting("plate_outline", LibVGASettings.plate_outline == "light" and "thick" or "light")
    else
        library.render_settings()
    end
end
SlashCmdList.LIBVGA = update_from_command
