-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The layout vga.ui is delivered with, the owner's own as he set it on 19 November 2026: a new character starts with it where no profile was saved or loaded before, and »Alles zurücksetzen …« returns to it. Places are kept from the nearest edges in the owner's screen units, so they fit every screen.

-- {K0449}

local library = LibVGA

local DEFAULTS = {
    alignment = "grid",
    arc_left = "range",
    arc_right = "threat",
    bags_pinned = true,
    bars_shown = { [4] = true, [5] = false, [6] = false, [7] = false, [8] = false },
    chat_sized = true,
    cursor = "on",
    dialog = 1,
    face = "geologica",
    faces = "moving",
    friend_name = "below",
    friend_style = "line",
    ground = 0.25,
    grounds = { party = 0, quests = 0.1, units = 0.25 },
    mainbar_form = "two",
    places = {
        bar4 = { "RIGHT", "RIGHT", -27, 9 },
        map = { "TOPRIGHT", "TOPRIGHT", -21, -23 },
        quests = { "RIGHT", "RIGHT", -98, 181 },
    },
    plate_level = "number",
    size = "large",
    sizes = {},
    target_health = "absolute",
    xp_colour = "mage",
    xp_labels = "on",
    xp_money = "on",
    xp_pace = "minute",
    xp_system = "on",
}

local function read_copy(source)
    if type(source) ~= "table" then return source end
    local copy = {}
    for key, value in pairs(source) do copy[key] = read_copy(value) end
    return copy
end

function library.read_defaults()
    return read_copy(DEFAULTS)
end
