-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: vga.ui's cursor trail, to find the pointer again amid bright effects: while it moves, small pixel cubes in white, gold and orange tumble away behind it, turning, falling and fading, a few sparks flashing between them; off unless switched on in the settings.

-- {K0334} {K0335}

local library = LibVGA
local PIECES, STEP, FALL = 48, 5, 160
local CUBES = { { 1, 1, 1 }, { 0.973, 0.89, 0.627 }, { 0.894, 0.718, 0.314 }, { 0.976, 0.565, 0.188 } }
local trail = CreateFrame("Frame", nil, UIParent)
trail:SetFrameStrata("TOOLTIP")
trail:SetAllPoints()
trail:EnableMouse(false)
trail.pieces, trail.next = {}, 1

for index = 1, PIECES do
    local piece = trail:CreateTexture(nil, "OVERLAY")
    piece:SetBlendMode("ADD")
    piece.life = 0
    piece:Hide()
    trail.pieces[index] = piece
end

local function update_piece(piece, elapsed)
    piece.life = piece.life - elapsed
    if piece.life <= 0 then
        piece:Hide()
        return
    end
    local share = piece.life / piece.span
    piece.speed_y = piece.speed_y - FALL * elapsed
    piece.x, piece.y = piece.x + piece.speed_x * elapsed, piece.y + piece.speed_y * elapsed
    piece.turn = piece.turn + piece.spin * elapsed
    piece:ClearAllPoints()
    piece:SetPoint("CENTER", UIParent, "BOTTOMLEFT", piece.x, piece.y)
    piece:SetRotation(piece.turn)
    local size = piece.size * (0.3 + 0.7 * share)
    piece:SetSize(size, size)
    local flash = piece.spark and (0.55 + 0.45 * math.sin(piece.life * 60)) or 1
    piece:SetAlpha(share * flash)
end

local function write_piece(x, y, away_x, away_y, spark)
    local piece = trail.pieces[trail.next]
    trail.next = trail.next % PIECES + 1
    local unit = library.read_size(-6)
    local colour = spark and CUBES[1] or CUBES[math.random(#CUBES)]
    piece:SetTexture(spark and library.media .. "Star" or "Interface\\Buttons\\WHITE8X8")
    piece:SetVertexColor(colour[1], colour[2], colour[3], 1)
    piece.spark = spark
    piece.size = spark and unit * (2 + math.random() * 2) or unit * (0.8 + math.random() * 1.2)
    piece.span = 0.35 + math.random() * 0.35
    piece.life = piece.span
    piece.x, piece.y = x, y
    piece.speed_x = away_x * (40 + math.random() * 60) + (math.random() - 0.5) * 70
    piece.speed_y = away_y * (40 + math.random() * 60) + (math.random() - 0.3) * 70
    piece.turn, piece.spin = math.random() * math.pi, (math.random() - 0.5) * 14
    piece:Show()
end

local function write_burst(x, y)
    local moved_x, moved_y = x - trail.x, y - trail.y
    local length = math.max(math.sqrt(moved_x * moved_x + moved_y * moved_y), 1)
    local away_x, away_y = -moved_x / length, -moved_y / length
    for _ = 1, 2 do write_piece(x, y, away_x, away_y, false) end
    if math.random() < 0.35 then write_piece(x, y, away_x, away_y, true) end
end

local function update_trail(_, elapsed)
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    if not trail.x or math.abs(x - trail.x) + math.abs(y - trail.y) >= STEP then
        if trail.x then write_burst(x, y) end
        trail.x, trail.y = x, y
    end
    for _, piece in ipairs(trail.pieces) do
        if piece:IsShown() then update_piece(piece, elapsed) end
    end
end

local function update_cursor()
    local on = library.read_cursor_trail()
    trail:SetScript("OnUpdate", on and update_trail or nil)
    trail.x = nil
    if not on then
        for _, piece in ipairs(trail.pieces) do piece:Hide() end
    end
end

library.create_element("cursor", { update = update_cursor })
