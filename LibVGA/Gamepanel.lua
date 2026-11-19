-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: vga.ui in the game's own settings, under AddOns: a page with a short line and the gold »vga.ui-Einstellungen öffnen …«, which closes the game's settings and opens ours.

-- {K0431}

local library = LibVGA
local panel

local function render_ours()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
    library.render_settings()
end

local function render_ours_safely()
    library.update_safely("game panel", render_ours)
end

local function update_panel()
    local pad = library.read_size(2)
    panel.title:SetFontObject(library.read_font("title"))
    panel.title:ClearAllPoints()
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -pad)
    panel.line:SetFontObject(library.read_font("body"))
    panel.line:ClearAllPoints()
    panel.line:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -library.read_size(-2))
    library.update_button(panel.open)
    panel.open:ClearAllPoints()
    panel.open:SetPoint("TOPLEFT", panel.line, "BOTTOMLEFT", 0, -pad)
end

local function update_panel_safely()
    library.update_safely("game panel", update_panel)
end

local function create_panel()
    local texts = library.texts
    panel = CreateFrame("Frame")
    panel.name = "vga.ui"
    panel.title = library.create_text(panel, "title", library.colours.gold)
    panel.title:SetText("vga.ui")
    panel.line = library.create_text(panel, "body", library.colours.ink)
    panel.line:SetText(texts.panel_line)
    panel.open = library.create_button(panel, texts.open_settings, "gold", render_ours_safely)
    panel:SetScript("OnShow", update_panel_safely)
    update_panel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() library.update_safely("game panel", create_panel) end)
