-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: LibVGA's frame in the tooltip's look, its rim and ground down to nothing, its place kept with both its own point and the screen's it is measured from - a frame that grows, as the quest tracker, always by its upper corner on its side of the screen, so it grows down and towards the middle, a place kept otherwise moved once to that corner -, so it stands after a reload exactly where it was let go, fixed but in the edit mode - its own and Blizzard's, whose start and end it follows; while arranging, the handles stand above every element of the game's own; its own, begun by »Anordnen …«, shows a large »Fertig« in VGA's orange in the middle of the screen that ends it; a widget let go is placed freely or, as the settings say, on a grid of eight by eight pixels. A frame that grows towards the middle may keep its place by its outer corner, the upper right on the right half of the screen. Two, six and fifteen seconds after entering the world every placed frame is checked against its saved place and set back where it stands elsewhere, each drift written down for finding its cause, marked where setting it back changes nothing because the screen's edge holds the frame. A place is kept from the nearest edges: the screen is cut into nine fields - corners, edges, middle - and a frame keeps its distance to the edges of its field, the middle to the middle, the distance kept in the owner's screen units and grown or shrunk with the screen like every size, so on another screen it stands in the same relation; a place kept the old way, from the lower left corner, is turned once into the new.

-- {K0258} {K0299} {K0330} {K0334} {K0383} {K0426} {K0430} {K0446} {K0448}

local library = LibVGA
local colours = library.colours

function library.create_frame(name, parent, template)
    local frame = CreateFrame(template and "Button" or "Frame", name, parent or UIParent, template)
    frame.outline = library.create_surface(frame, "BACKGROUND", 0)
    frame.edge = library.create_surface(frame, "BACKGROUND", 1)
    frame.ground = library.create_surface(frame, "BACKGROUND", 2)
    frame.corner = library.create_corner(frame, false)
    return frame
end

function library.update_frame(frame, fixed)
    local radius = library.read_size(-2)
    local ground = fixed or library.read_ground(frame.ground_key or frame.place_key)
    library.update_surface(frame.outline, -2, radius + 2, colours.edge, colours.edge, ground)
    library.update_surface(frame.edge, -1, radius + 1, { 0, 0, 0 }, { 0, 0, 0 }, ground)
    library.update_surface(frame.ground, 0, radius, { 0.071, 0.075, 0.09 }, { 0.043, 0.047, 0.059 }, ground)
    library.update_corner(frame.corner)
end

local movers = {}
local GRIDS = { grid = 8, grid16 = 16 }
local DRIFT = 2
local MIGRATE_AT = 3

local function update_snapped(frame)
    local grid = GRIDS[LibVGASettings.alignment]
    if not grid then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (left and top) then return end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local snapped_left = math.floor(left * scale / grid + 0.5) * grid / scale
    local snapped_top = math.floor(top * scale / grid + 0.5) * grid / scale
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", snapped_left, snapped_top)
end

local function read_place(place)
    if #place >= 4 then return place[1], place[2], place[3], place[4] end
    local measured_from_foot = place[1]:find("^TOP") and place[3] > 0
    return place[1], measured_from_foot and "BOTTOMLEFT" or place[1], place[2], place[3]
end

local function update_place(frame)
    local place = LibVGASettings and LibVGASettings.places and LibVGASettings.places[frame.place_key]
    local spot = frame.place_default
    frame:ClearAllPoints()
    if place then
        local own, other, left, top = read_place(place)
        local share = own == other and library.read_screen_share() or 1
        frame:SetPoint(own, UIParent, other, left * share, top * share)
    else
        frame:SetPoint(spot[1], spot[2], spot[3], spot[4], spot[5])
    end
end

function library.update_places()
    if InCombatLockdown() then return end
    for _, mover in pairs(movers) do update_place(mover:GetParent()) end
end

local function read_scale_share(frame)
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function read_zone_point(frame)
    local share = read_scale_share(frame)
    local across, down = (frame:GetLeft() + frame:GetRight()) / 2 * share, (frame:GetTop() + frame:GetBottom()) / 2 * share
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local side = across < width / 3 and "LEFT" or across > width * 2 / 3 and "RIGHT" or ""
    if side == "" and frame.place_outer then side = across > width / 2 and "RIGHT" or "LEFT" end
    local level = down > height * 2 / 3 and "TOP" or down < height / 3 and "BOTTOM" or ""
    if frame.place_outer then level = "TOP" end
    local point = level .. side
    return point == "" and "CENTER" or point
end

local function read_screen_spot(point)
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local across = point:find("LEFT") and 0 or point:find("RIGHT") and width or width / 2
    local down = point:find("TOP") and height or point:find("BOTTOM") and 0 or height / 2
    return across, down
end

local function read_point_spot(frame, point)
    local across = point:find("LEFT") and frame:GetLeft() or point:find("RIGHT") and frame:GetRight() or (frame:GetLeft() + frame:GetRight()) / 2
    local down = point:find("TOP") and frame:GetTop() or point:find("BOTTOM") and frame:GetBottom() or (frame:GetTop() + frame:GetBottom()) / 2
    return across, down
end

local function read_saved_place(frame)
    local point, share = read_zone_point(frame), read_scale_share(frame)
    local across, down = read_point_spot(frame, point)
    local screen_across, screen_down = read_screen_spot(point)
    local screen = library.read_screen_share()
    return { point, point, math.floor((across - screen_across / share) / screen + 0.5), math.floor((down - screen_down / share) / screen + 0.5) }
end

local function update_drag_start(mover)
    local frame = mover:GetParent()
    if InCombatLockdown() then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if left and top then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    frame:StartMoving()
end

function library.create_place(frame, key, point, relative, x, y, relative_point)
    frame.place_key = key
    frame.place_default = { point, relative or UIParent, relative_point or point, x, y }
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    update_place(frame)
    local mover = CreateFrame("Frame", nil, frame)
    mover:SetAllPoints()
    mover:SetFrameStrata("FULLSCREEN")
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover.tint = mover:CreateTexture(nil, "OVERLAY")
    mover.tint:SetAllPoints()
    mover.tint:SetColorTexture(colours.gold[1], colours.gold[2], colours.gold[3], 0.18)
    mover:SetScript("OnDragStart", update_drag_start)
    mover:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        update_snapped(frame)
        LibVGASettings.places = LibVGASettings.places or {}
        LibVGASettings.places[key] = read_saved_place(frame)
    end)
    mover:Hide()
    movers[key] = mover
end

function library.update_places_back()
    if InCombatLockdown() then return end
    for _, mover in pairs(movers) do
        local frame = mover:GetParent()
        local spot = frame.place_default
        frame:ClearAllPoints()
        frame:SetPoint(spot[1], spot[2], spot[3], spot[4], spot[5])
    end
end

local done

local function update_done(shown)
    if not done and shown then
        done = library.create_button(UIParent, library.texts.done, "orange", function() library.update_edit(false) end)
        done:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    if not done then return end
    library.update_button(done)
    done:ClearAllPoints()
    done:SetPoint("CENTER", UIParent, "CENTER")
    done:SetShown(shown)
end

local function update_unit_watch(frame, on)
    if not frame.unit_watched then return end
    if on then
        UnregisterUnitWatch(frame)
        frame:Show()
    else
        RegisterUnitWatch(frame)
    end
end

function library.update_edit(on, own)
    if InCombatLockdown() then return end
    library.editing = on
    for _, mover in pairs(movers) do
        mover:SetShown(on)
        update_unit_watch(mover:GetParent(), on)
    end
    update_done(on and own or false)
end

local function update_from_blizzard_start()
    library.update_edit(true)
end

local function update_from_blizzard_end()
    library.update_edit(false)
end

if EventRegistry then
    EventRegistry:RegisterCallback("EditMode.Enter", update_from_blizzard_start, library)
    EventRegistry:RegisterCallback("EditMode.Exit", update_from_blizzard_end, library)
end

local function check_place(mover, moment)
    local frame = mover:GetParent()
    local place = LibVGASettings.places and LibVGASettings.places[frame.place_key]
    if not (place and #place >= 4 and frame:GetLeft()) then return end
    local across, down = read_point_spot(frame, place[1])
    local screen_across, screen_down = read_screen_spot(place[2])
    local share, screen = read_scale_share(frame), place[1] == place[2] and library.read_screen_share() or 1
    if math.abs(across - screen_across / share - place[3] * screen) <= DRIFT and math.abs(down - screen_down / share - place[4] * screen) <= DRIFT then return end
    update_place(frame)
    local again_across, again_down = read_point_spot(frame, place[1])
    local held = math.abs(again_across - across) <= DRIFT and math.abs(again_down - down) <= DRIFT
    LibVGASettings.measures = LibVGASettings.measures or {}
    local drifts = LibVGASettings.measures.place_drift or {}
    drifts[#drifts + 1] = string.format("%s at %d s: saved %s %d %d, stood %.0f %.0f%s", frame.place_key, moment, place[1], place[3], place[4], across, down, held and ", held there by the screen's edge" or "")
    LibVGASettings.measures.place_drift = drifts
end

local function check_places(moment)
    if InCombatLockdown() or library.editing then return end
    for _, mover in pairs(movers) do pcall(check_place, mover, moment) end
end

local function update_old_place(mover)
    local frame = mover:GetParent()
    local place = LibVGASettings.places and LibVGASettings.places[frame.place_key]
    local stale = place and (place[1] ~= place[2] or (frame.place_outer and not place[1]:find("^TOP")))
    if not (stale and #place >= 4 and frame:GetLeft()) then return end
    LibVGASettings.places[frame.place_key] = read_saved_place(frame)
    update_place(frame)
end

local function update_old_places()
    if InCombatLockdown() or library.editing then return end
    for _, mover in pairs(movers) do pcall(update_old_place, mover) end
end

local placed = CreateFrame("Frame")
placed:RegisterEvent("PLAYER_ENTERING_WORLD")
placed:SetScript("OnEvent", function()
    for _, moment in ipairs({ 2, 6, 15 }) do
        C_Timer.After(moment, function() check_places(moment) end)
    end
    C_Timer.After(MIGRATE_AT, update_old_places)
end)

