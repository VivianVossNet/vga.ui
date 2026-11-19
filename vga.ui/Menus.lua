-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: Blizzard's context menus in vga.ui's widget look: the menu's own ground hidden, LibVGA's frame laid beneath its entries - rim, edge, rounded ground and the small gold corner - always at half opacity whatever the frames' ground, so a menu is always readable; its texts in Geologica, their colours kept.

-- {K0260} {K0338}

local library = LibVGA
local MENU_GROUND = 0.5
local skins = setmetatable({}, { __mode = "k" })
local ours = setmetatable({}, { __mode = "k" })

local function create_skin(menu)
    local skin = library.create_frame(nil, menu)
    skin:SetAllPoints()
    skin:SetFrameLevel(menu:GetFrameLevel())
    skin:EnableMouse(false)
    skin.corner:EnableMouse(false)
    for _, region in ipairs({ skin:GetRegions() }) do ours[region] = true end
    skins[menu] = skin
    return skin
end

local function update_texts(owner, depth)
    for _, region in ipairs({ owner:GetRegions() }) do
        if region:GetObjectType() == "FontString" and not ours[region] then
            local red, green, blue = region:GetTextColor()
            region:SetFontObject(library.read_font("body"))
            region:SetTextColor(red, green, blue)
        end
    end
    if depth > 0 then
        for _, child in ipairs({ owner:GetChildren() }) do update_texts(child, depth - 1) end
    end
end

local function update_menu(menu)
    local skin = skins[menu] or create_skin(menu)
    for _, region in ipairs({ menu:GetRegions() }) do
        if region:GetObjectType() == "Texture" then region:SetAlpha(0) end
    end
    library.update_frame(skin, MENU_GROUND)
    update_texts(menu, 4)
end

if EventRegistry then
    EventRegistry:RegisterCallback("MenuProxy.OnShow", function(_, menu)
        library.update_safely("menu", update_menu, menu)
    end, library)
end
