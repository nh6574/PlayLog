-- PlayLog config: themes, color system, HSV picker
PlayLog.config = PlayLog.config or {}

function pl_col(key, r, g, b, a)
    local c = PlayLog.config[key]
    if c then return c[1], c[2], c[3], c[4] or 1 end
    return r, g, b, a
end

--Built-in themes. Add entries to PLAYLOG_THEMES to register custom ones.
do
    local function c(hex, a)
        hex = hex:gsub("^#", "")
        local r = tonumber(hex:sub(1,2), 16) / 255
        local g = tonumber(hex:sub(3,4), 16) / 255
        local b = tonumber(hex:sub(5,6), 16) / 255
        return { r, g, b, a }
    end
    -- alpha constants used across every theme
    local BG, ACC, TINT, TEXT, KNOB = 0.97, 0.85, 0.18, 1.0, 0.85
    local function theme(name, bg, accent, text)
        return {
            name          = name,
            panel_bg      = c(bg,     BG),
            border        = c(accent, ACC),
            header_tint   = c(accent, TINT),
            header_text   = c(text,   TEXT),
            scrollbar_knob= c(accent, KNOB),
        }
    end
    PLAYLOG_THEMES = PLAYLOG_THEMES or {
        theme("Gold",   "#1A1A2B", "#F2BA40", "#F2BA40"),
        theme("Purple", "#1A0F2E", "#B766F2", "#D18CFF"),
        theme("Green",  "#0F241A", "#4DE680", "#66F28C"),
        theme("Red",    "#290F0F", "#F24747", "#FF7373"),
        theme("Blue",   "#0F1A33", "#47ADFA", "#73C7FF"),
        theme("Mono",   "#1A1A1A", "#D9D9D9", "#FFFFFF"),
    }
end

local PL_CONFIG_KEYS = { 'panel_bg', 'border', 'header_tint', 'header_text', 'scrollbar_knob' }

function pl_save_config()
    PlayLog.mod.config = PlayLog.config
    SMODS.save_mod_config(PlayLog.mod)
end

function pl_load_config()

end

function pl_apply_theme(theme)
    for _, key in ipairs(PL_CONFIG_KEYS) do
        PlayLog.config[key] = theme[key]
    end
    pl_save_config()
end
if not PlayLog.config.panel_bg then
    pl_apply_theme(PLAYLOG_THEMES[1])
end
if type(PlayLog.config.time_format_index) ~= 'number' then
    PlayLog.config.time_format_index = 4
    pl_save_config()
end

--Color conversion helpers
function pl_hex_to_rgb(hex)
    hex = hex:gsub("^#", "")
    if #hex == 3 then
        hex = hex:sub(1,1):rep(2) .. hex:sub(2,2):rep(2) .. hex:sub(3,3):rep(2)
    end
    if #hex ~= 6 then return nil end
    local r = tonumber(hex:sub(1,2), 16)
    local g = tonumber(hex:sub(3,4), 16)
    local b = tonumber(hex:sub(5,6), 16)
    if not r or not g or not b then return nil end
    return { r/255, g/255, b/255, 1 }
end

function pl_rgb_to_hex(c)
    if not c then return "------" end
    local r = math.floor((c[1] or 0) * 255 + 0.5)
    local g = math.floor((c[2] or 0) * 255 + 0.5)
    local b = math.floor((c[3] or 0) * 255 + 0.5)
    return string.format("%02X%02X%02X", r, g, b)
end

function pl_hsv_to_rgb(h, s, v)
    h = h % 360
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0
    if     h < 60  then r,g,b = c,x,0
    elseif h < 120 then r,g,b = x,c,0
    elseif h < 180 then r,g,b = 0,c,x
    elseif h < 240 then r,g,b = 0,x,c
    elseif h < 300 then r,g,b = x,0,c
    else                r,g,b = c,0,x end
    return r+m, g+m, b+m
end

function pl_rgb_to_hsv(r, g, b)
    local maxc = math.max(r,g,b)
    local minc = math.min(r,g,b)
    local v = maxc
    local s = maxc == 0 and 0 or (maxc - minc) / maxc
    local h = 0
    if maxc ~= minc then
        local d = maxc - minc
        if     maxc == r then h = ((g-b)/d) % 6
        elseif maxc == g then h = (b-r)/d + 2
        else                   h = (r-g)/d + 4 end
        h = h * 60
    end
    return h, s, v
end

function pl_point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= (rx + rw) and py >= ry and py <= (ry + rh)
end

--Fields shown in the config panel (swatch + label goes to open picker)
pl_hex_fields = {
    { key = 'panel_bg',    label = 'Background' },
    { key = 'border',      label = 'Border / Accent' },
    { key = 'header_text', label = 'Text' },
}

function pl_picker_apply()
    local pk = G.playlog_picker
    if not pk then return end
    local r, g, b = pl_hsv_to_rgb(pk.h, pk.s, pk.v)
    local col = { r, g, b, 1 }
    PlayLog.config[pk.key] = col
    if pk.key == 'border' then
        PlayLog.config.header_tint    = { r, g, b, 0.18 }
        PlayLog.config.scrollbar_knob = { r, g, b, 0.85 }
    end
    pl_save_config()
end

function pl_draw_picker(layout)
    local pk = G.playlog_picker
    if not pk then return end
    local cx = layout.content_x
    local cy = layout.content_y
    local cw = layout.content_w

    local sq_w   = cw - 4
    local sq_h   = math.floor(sq_w * 0.55)
    local hbar_h = 16
    local pad    = 8
    local sq_x   = cx
    local sq_y   = cy + 24
    local hbar_x = cx
    local hbar_y = sq_y + sq_h + pad
    --back button
    local mx, my = love.mouse.getPosition()
    local back_hov = pl_point_in_rect(mx, my, cx, cy, 60, 18)
    love.graphics.setColor(pl_col('border', 0.95, 0.73, 0.25, back_hov and 0.9 or 0.5))
    love.graphics.rectangle("fill", cx, cy, 60, 18, 3, 3)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print("< BACK", cx + 4, cy + 2, nil, 0.70, 0.70)
    --title
    love.graphics.setColor(pl_col('header_text', 0.95, 0.73, 0.25, 1))
    love.graphics.print("EDITING: " .. (pk.label or pk.key), cx + 68, cy + 3, nil, 0.72, 0.72)
    --SV square: vertical strips so hue update is correct across the full gradient
    do
        love.graphics.setColor(1, 1, 1, 1)  --reset tint so vertex colors are unaffected
        local sv_steps = 32
        local strip_w  = sq_w / sv_steps
        local verts    = {}
        for j = 0, sv_steps do
            local s_j = j / sv_steps
            local tr, tg, tb = pl_hsv_to_rgb(pk.h, s_j, 1)
            verts[#verts + 1] = { sq_x + j * strip_w, sq_y,        0, 0, tr, tg, tb, 1 }
            verts[#verts + 1] = { sq_x + j * strip_w, sq_y + sq_h, 0, 1, 0,  0,  0,  1 }
        end
        love.graphics.draw(love.graphics.newMesh(verts, "strip", "static"))
    end
    --SV cursor dot
    local dot_x = sq_x + pk.s * sq_w
    local dot_y = sq_y + (1 - pk.v) * sq_h
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.circle("line", dot_x, dot_y, 7)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("line", dot_x, dot_y, 6)
    do
        local hue_steps = 24
        local hseg_w = sq_w / hue_steps
        local hverts = {}
        for i = 0, hue_steps do
            local rr, rg, rb = pl_hsv_to_rgb(i / hue_steps * 360, 1, 1)
            hverts[#hverts+1] = { hbar_x + i * hseg_w, hbar_y,          0, 0, rr, rg, rb, 1 }
            hverts[#hverts+1] = { hbar_x + i * hseg_w, hbar_y + hbar_h, 0, 1, rr, rg, rb, 1 }
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(love.graphics.newMesh(hverts, "strip", "static"))
    end
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", hbar_x, hbar_y, sq_w, hbar_h, 2, 2)
    --hue cursor needle
    local hcur_x = hbar_x + (pk.h / 360) * sq_w
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.line(hcur_x, hbar_y - 2, hcur_x, hbar_y + hbar_h + 2)
    love.graphics.setLineWidth(1)
    --hex input row
    local hex_y   = hbar_y + hbar_h + pad
    local input_w = 120
    local pr, pg, pb = pl_hsv_to_rgb(pk.h, pk.s, pk.v)
    --preview swatch
    love.graphics.setColor(pr, pg, pb, 1)
    love.graphics.rectangle("fill", cx, hex_y, 36, 26, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("line", cx, hex_y, 36, 26, 4, 4)
    --hex input box
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", cx + 42, hex_y, input_w, 26, 4, 4)
    local hex_valid = pl_hex_to_rgb(pk.hex_input or "") ~= nil
    local br1, br2, br3 = pl_col('border', 0.95, 0.73, 0.25, 1)
    love.graphics.setColor(br1, br2, br3, pk.hex_focus and 0.95 or 0.35)
    love.graphics.setLineWidth(pk.hex_focus and 1.5 or 1)
    love.graphics.rectangle("line", cx + 42, hex_y, input_w, 26, 4, 4)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.55, 0.55, 0.55, 1)
    love.graphics.print("#", cx + 46, hex_y + 5, nil, 0.80, 0.80)
    if pk.hex_focus then
        love.graphics.setColor(hex_valid and 0.40 or 0.95, hex_valid and 0.95 or 0.40, 0.40, 1)
    else
        love.graphics.setColor(1, 1, 1, 0.9)
    end
    local cur_blink = math.floor(love.timer.getTime() * 2) % 2 == 0
    local displayed_hex = pk.hex_focus
        and (pk.hex_input or "")
        or ((pk.hex_input and pk.hex_input ~= "") and pk.hex_input or pl_rgb_to_hex({pr, pg, pb}))
    love.graphics.print(
        displayed_hex .. (pk.hex_focus and (cur_blink and "_" or " ") or ""),
        cx + 56, hex_y + 5, nil, 0.80, 0.80)
    if not pk.hex_focus then
        love.graphics.setColor(0.55, 0.55, 0.55, 0.7)
        love.graphics.print("click to type hex", cx + 42 + input_w + 8, hex_y + 7, nil, 0.65, 0.65)
    end
    --store interactive rects for mouse handling
    pk._sq_rect   = { x = sq_x,   y = sq_y,   w = sq_w,   h = sq_h   }
    pk._hbar_rect = { x = hbar_x, y = hbar_y, w = sq_w,   h = hbar_h }
    pk._hex_rect  = { x = cx+42,  y = hex_y,  w = input_w, h = 26    }
    pk._back_rect = { x = cx,     y = cy,     w = 60,      h = 18    }
end
