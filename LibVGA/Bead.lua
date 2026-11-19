-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: LibVGA's bead, as the quest tracker's difficulty dot first drew it: a disc in exactly the colour asked for, a white light at its upper left and a faint shade at its lower right laid over it; shared by every element that marks something with a small round sign.

-- {K0390} {K0416}

local library = LibVGA

function library.create_bead(parent, layer, level)
    local bead = parent:CreateTexture(nil, layer, nil, level)
    bead:SetTexture(library.media .. "Disc")
    bead.shade = parent:CreateTexture(nil, layer, nil, level + 1)
    bead.shade:SetTexture(library.media .. "BeadShade")
    bead.shade:SetAllPoints(bead)
    bead.light = parent:CreateTexture(nil, layer, nil, level + 2)
    bead.light:SetTexture(library.media .. "BeadLight")
    bead.light:SetAllPoints(bead)
    return bead
end

function library.update_bead_shown(bead, shown)
    bead:SetShown(shown)
    bead.shade:SetShown(shown)
    bead.light:SetShown(shown)
end
