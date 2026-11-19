-- Copyright 2026 Vivian Voss. Code by Vivian Voss. Licensed under the BSD-3-Clause.
-- SPDX-License-Identifier: BSD-3-Clause
-- Scope: the numbers the game shows over a creature when it is hit, set in the face chosen in vga.ui's settings; the game reads the font at login, so the change shows after the next one.

-- {K0303}

DAMAGE_TEXT_FONT = select(3, LibVGA.read_face())
