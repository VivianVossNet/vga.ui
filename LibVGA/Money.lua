-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: LibVGA's money as the accepted draft draws it (manual/view/vga-windows.html .money): gold, silver and copper, each figure followed by its coin, the coin centred on the figure's line, four draft pixels between figure and coin and twelve between the groups; leading empty groups left out, the copper always shown; shared by every element that shows money.

-- {K0258} {K0388} {K0403}

local library = LibVGA
local DRAFT_BASE = 13
local COINS = { { 10000, "CoinGold" }, { 100, "CoinSilver" }, { 1, "CoinCopper" } }

function library.create_money(parent, colour)
    local money = CreateFrame("Frame", nil, parent)
    money.groups = {}
    for index, coin in ipairs(COINS) do
        local group = { text = library.create_text(money, "body", colour), coin = money:CreateTexture(nil, "ARTWORK") }
        group.coin:SetTexture(library.media .. coin[2])
        money.groups[index] = group
    end
    return money
end

local function update_group(money, group, count, x)
    local scale = library.read_base() / DRAFT_BASE
    local size, near = math.floor(10 * scale + 0.5), math.floor(4 * scale + 0.5)
    group.text:SetFontObject(library.read_frame_font(money.kind or "body"))
    group.text:SetText(count)
    group.text:ClearAllPoints()
    group.text:SetPoint("TOPLEFT", money, "TOPLEFT", x, 0)
    group.coin:SetSize(size, size)
    group.coin:ClearAllPoints()
    group.coin:SetPoint("LEFT", group.text, "RIGHT", near, 0)
    return x + math.ceil(group.text:GetStringWidth()) + near + size
end

function library.update_money(money, copper)
    local apart = math.floor(12 * library.read_base() / DRAFT_BASE + 0.5)
    local left, x, shown = copper or 0, 0, false
    for index, coin in ipairs(COINS) do
        local group = money.groups[index]
        local count = math.floor(left / coin[1])
        left = left - count * coin[1]
        shown = shown or count > 0 or index == #COINS
        group.text:SetShown(shown)
        group.coin:SetShown(shown)
        if shown then x = update_group(money, group, count, x) + apart end
    end
    money:SetWidth(math.max(1, x - apart))
    money:SetHeight(math.ceil(money.groups[#COINS].text:GetStringHeight()))
end
