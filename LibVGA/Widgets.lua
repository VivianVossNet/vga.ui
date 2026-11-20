-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: What concerns one widget, in its tab of the one settings dialog, as the accepted draft draws it (manual/view/vga-settings-one.html): a group »Widgets« at the tab's foot, its title naming what its columns set - Deckkraft des Hintergrunds, and Größe where a widget has sizes -, a row a widget - its name, its background reading »wie alle« until moved, a double click setting it back, and K / N / G for its size where it has sizes; a widget's gold corner opens the dialog on that tab, and its row shines gold a moment and fades.

-- {K0267} {K0319} {K0382} {K0383} {K0384}

local library = LibVGA
local colours = library.colours
local SIZES = { "small", "normal", "large" }
local DOUBLE_CLICK = 0.35
local SHINE = 1.5
local places = {}

local function update_like(row)
    row.control.like = LibVGASettings.grounds[row.key] == nil and library.texts.like_all or nil
    library.update_slider_value(row.control, library.read_ground(row.key))
    library.update_slider(row.control)
end

local function update_reset(control)
    local now = GetTime()
    if control.clicked and now - control.clicked < DOUBLE_CLICK then
        LibVGASettings.grounds[control.row.key] = nil
        update_like(control.row)
        library.update_elements()
    end
    control.clicked = now
end

local function create_widget_row(page, entry)
    local texts = library.texts
    local row = library.create_row(page, entry.title, "widget")
    row.key, row.when = entry.key, entry.when
    row.control = library.create_slider(row, library.ground_stops, library.read_ground(entry.key), function(value)
        LibVGASettings.grounds[row.key] = value
        row.control.like = nil
        library.update_grounds()
    end)
    row.control.on_settle = library.update_elements
    row.control.row = row
    row.control:HookScript("OnMouseUp", update_reset)
    update_like(row)
    local _, chosen = library.read_size_step(entry.key)
    local index = ({ small = 1, normal = 2, large = 3 })[chosen]
    row.size = library.create_choice(row, { texts.size_small_short, texts.size_normal_short, texts.size_large_short }, index, function(place)
        LibVGASettings.sizes[row.key] = SIZES[place]
        library.update_elements()
    end)
    row.size:SetShown(entry.sized or false)
    return row
end

local function check_group_shown(heading)
    for index = 2, #heading.group do
        local row = heading.group[index]
        if not row.when or row.when(row) then return true end
    end
    return false
end

function library.create_widget_rows(page, page_key, entries)
    local texts, sized = library.texts, false
    for _, entry in ipairs(entries) do sized = sized or entry.sized or false end
    local title = texts.widgets .. " · " .. texts.ground_opacity .. (sized and " · " .. texts.size or "")
    local heading = library.create_row(page, title, "heading")
    local rows = { heading }
    for _, entry in ipairs(entries) do
        local row = create_widget_row(page, entry)
        rows[#rows + 1] = row
        places[entry.key] = { page = page_key, row = row }
    end
    heading.group, heading.when = rows, check_group_shown
    heading.members = { unpack(rows, 2) }
    return rows
end

function library.read_widget_row_width()
    return library.read_slider_width() + library.read_size(-2) + library.read_size(2) * 3 + 2
end

function library.update_widget_row(row, right)
    local size_width = library.read_size(2) * 3 + 2
    library.update_slider(row.control, library.read_slider_width())
    library.update_choice(row.size, size_width)
    row.size:ClearAllPoints()
    row.size:SetPoint("RIGHT", row, "RIGHT", -right, 0)
    row.control:ClearAllPoints()
    row.control:SetPoint("RIGHT", row, "RIGHT", -right - size_width - library.read_size(-2) - library.read_size(4) - row.control.reach, 0)
end

local function create_shine(row)
    row.shine = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.shine:SetAllPoints()
    row.shine:SetColorTexture(1, 1, 1, 1)
    row.shine:SetGradient("HORIZONTAL", CreateColor(colours.gold[1], colours.gold[2], colours.gold[3], 0.2), CreateColor(colours.gold[1], colours.gold[2], colours.gold[3], 0))
end

local function update_shine(row)
    if not row.shine then create_shine(row) end
    local started = GetTime()
    row.shine:SetAlpha(1)
    row.shine:Show()
    row:SetScript("OnUpdate", function(self)
        local left = 1 - (GetTime() - started) / SHINE
        if left <= 0 then
            self.shine:Hide()
            self:SetScript("OnUpdate", nil)
            return
        end
        self.shine:SetAlpha(left)
    end)
end

function library.create_widget_place(key, page_key, row, on_open)
    places[key] = { page = page_key, row = row, open = on_open }
end

function library.render_widget(_, key)
    if not places[key] then library.render_settings() end
    local place = places[key]
    library.render_settings(place and place.page or "general")
    if place and place.open then place.open() end
    if place then update_shine(place.row) end
end
