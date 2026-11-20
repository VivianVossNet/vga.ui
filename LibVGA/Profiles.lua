-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: Each character's own layout and the account's named profiles: a character keeps its settings - places, sizes, grounds, every choice - for itself; a layout is saved under a name for the whole account and loaded by any character; a new character starts with the profile saved or loaded last, the first one after this change with the layout the account had before, and on a fresh installation with the delivered layout; the settings' tab »Profile« - a name and »Speichern«, then every saved profile with »Laden«, »Überschreiben« - the present layout saved over it - and »Löschen«, the last two asking once.

-- {K0387} {K0449}

local library = LibVGA
local colours = library.colours
local NOT_IN_PROFILE = { faults = true, measures = true, friendly = true, reach = true, quest_pins = true, history = true, bag_fresh = true, key_fresh = true }

local function read_copy(source)
    if type(source) ~= "table" then return source end
    local copy = {}
    for key, value in pairs(source) do copy[key] = read_copy(value) end
    return copy
end

local function read_layout(source)
    local layout = {}
    for key, value in pairs(source or {}) do
        if not NOT_IN_PROFILE[key] then layout[key] = read_copy(value) end
    end
    return layout
end

function library.update_storage()
    LibVGAAccount = LibVGAAccount or {}
    LibVGAAccount.profiles = LibVGAAccount.profiles or {}
    if not LibVGAAccount.legacy and LibVGASettings then LibVGAAccount.legacy = read_layout(LibVGASettings) end
    if not LibVGACharacter then
        local start = LibVGAAccount.profiles[LibVGAAccount.last_profile or ""] or LibVGAAccount.legacy or library.read_defaults()
        LibVGACharacter = read_layout(start)
    end
    LibVGASettings = LibVGACharacter
end

local function write_profile(name)
    LibVGAAccount.profiles[name] = read_layout(LibVGASettings)
    LibVGAAccount.last_profile = name
    library.render_settings_anew()
end

local function update_profile(name)
    if InCombatLockdown() or not LibVGAAccount.profiles[name] then return end
    for key in pairs(LibVGASettings) do
        if not NOT_IN_PROFILE[key] then LibVGASettings[key] = nil end
    end
    for key, value in pairs(read_layout(LibVGAAccount.profiles[name])) do LibVGASettings[key] = value end
    LibVGAAccount.last_profile = name
    library.update_defaults()
    library.update_places()
    library.update_elements()
    library.render_settings_anew()
end

local function delete_profile(name)
    LibVGAAccount.profiles[name] = nil
    if LibVGAAccount.last_profile == name then LibVGAAccount.last_profile = nil end
    library.render_settings_anew()
end

local function create_input(row)
    local input = CreateFrame("EditBox", nil, row)
    input:SetAutoFocus(false)
    input:SetMaxLetters(32)
    input.edge = library.create_surface(input, "BACKGROUND", 0)
    input.ground = library.create_surface(input, "BACKGROUND", 1)
    input:SetScript("OnEscapePressed", input.ClearFocus)
    return input
end

local function update_input(input)
    local radius = library.read_size(-6)
    input:SetFontObject(library.read_font("body"))
    input:SetTextInsets(library.read_size(-2), library.read_size(-2), 0, 0)
    input:SetSize(library.read_slider_width(), library.read_size(2))
    library.update_surface(input.edge, -1, radius + 1, colours.edge, colours.edge)
    library.update_surface(input.ground, 0, radius, { 0.031, 0.035, 0.043 }, { 0.031, 0.035, 0.043 })
end

local function create_profile_row(page, name)
    local texts = library.texts
    local row = library.create_row(page, name)
    row.control = CreateFrame("Frame", nil, row)
    local load = library.create_button(row.control, texts.load, "plain", function() update_profile(name) end)
    local overwrite = library.create_button(row.control, texts.overwrite, "plain", function() write_profile(name) end)
    overwrite.ask = texts.overwrite_sure
    local remove = library.create_button(row.control, texts.delete, "alarm", function() delete_profile(name) end)
    remove.ask = texts.delete_sure
    local gap = library.read_size(-2)
    for _, button in ipairs({ load, overwrite, remove }) do library.update_button(button) end
    remove:SetPoint("RIGHT", row.control, "RIGHT")
    overwrite:SetPoint("RIGHT", remove, "LEFT", -gap, 0)
    load:SetPoint("RIGHT", overwrite, "LEFT", -gap, 0)
    row.control:SetSize(load:GetWidth() + overwrite:GetWidth() + remove:GetWidth() + 2 * gap, load:GetHeight())
    return row
end

local function read_names()
    local names = {}
    for name in pairs(LibVGAAccount.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

local function write_input(input)
    local name = (input:GetText() or ""):match("^%s*(.-)%s*$")
    if name ~= "" then write_profile(name) end
end

function library.create_profiles_page(page)
    local texts = library.texts
    local named = library.create_row(page, texts.profile_name)
    named.control = create_input(named)
    update_input(named.control)
    named.control:SetScript("OnEnterPressed", write_input)
    local heading = library.create_row(page, texts.saved_profiles, "heading")
    page.rows = { named, heading }
    heading.members = {}
    for _, name in ipairs(read_names()) do
        local row = create_profile_row(page, name)
        page.rows[#page.rows + 1] = row
        heading.members[#heading.members + 1] = row
    end
    if #heading.members == 0 then
        local none = library.create_row(page, texts.no_profiles)
        none.label:SetTextColor(unpack(colours.quiet))
        page.rows[#page.rows + 1] = none
        heading.members[1] = none
    end
    local save = library.create_button(page, texts.save, "gold", function() write_input(named.control) end)
    page.foot = { save }
end
