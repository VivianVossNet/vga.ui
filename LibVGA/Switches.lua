-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: The game's settings an element switches while it runs: each player's own value kept once under the element's key before it is changed, a setting this game does not know left alone, and every one restored when the game logs out.

-- {K0350} {K0373}

local library = LibVGA

function library.update_switches(key, values)
    LibVGASettings[key] = LibVGASettings[key] or {}
    local kept = LibVGASettings[key]
    for name, value in pairs(values) do
        local own = GetCVar(name)
        if own ~= nil then
            if kept[name] == nil then kept[name] = own end
            SetCVar(name, value)
        end
    end
end

function library.update_switches_back(key)
    for name, own in pairs(LibVGASettings[key] or {}) do
        SetCVar(name, own)
    end
    LibVGASettings[key] = nil
end
