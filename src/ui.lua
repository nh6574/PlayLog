-- UI (hi its love2d edition)
local PLAYLOG_VISIBLE_ROWS = 16
local PLAYLOG_ROWS_PER_FRAME = 20
local PLAYLOG_ROW_HEIGHT = 22
local PLAYLOG_TOGGLE_KEY = 'f8'
local PLAYLOG_SCALE = 0.75
local PLAYLOG_SLIDE_SPEED = 10
local pl_tooltip_card = nil

local function pl_is_run_active()
    return G and G.STAGE and G.STAGES and G.STAGE == G.STAGES.RUN
end

local function pl_clamp(value, minv, maxv)
    if value < minv then return minv end
    if value > maxv then return maxv end
    return value
end

local function pl_draw_rich_segments(segments, x, y, max_x, mouse_x, mouse_y)
    if not segments then return nil, 1 end
    local draw_x = x
    local draw_y = y
    local lines = 1
    local hovered_tooltip = nil
    local font = love.graphics.getFont()
    local scale = PLAYLOG_SCALE
    local seg_h = font:getHeight() * scale
    local function try_wrap(needed_w)
        if max_x and draw_x + needed_w > max_x and draw_x > x then
            draw_x = x
            draw_y = draw_y + PLAYLOG_ROW_HEIGHT
            lines = lines + 1
        end
    end
    local def_r, def_g, def_b, def_a = pl_col('header_text', 0.88, 0.88, 0.88, 1)
    for i = 1, #segments do
        local seg = segments[i]
        local seg_text = seg.text or ""
        if seg_text ~= "" then
            local c = seg.colour or { def_r, def_g, def_b, def_a }
            local words = {}
            for word in seg_text:gmatch("%S+") do words[#words + 1] = word end
            local space_w = font:getWidth(" ") * scale

            if #words == 0 then
                draw_x = draw_x + font:getWidth(seg_text) * scale
            else
                local first_word = true
                for wi, word in ipairs(words) do
                    local prefix = (not first_word or seg_text:sub(1, 1) == " ") and " " or ""
                    local token = prefix .. word
                    local token_w = font:getWidth(token) * scale
                    try_wrap(token_w)
                    love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
                    love.graphics.print(token, draw_x, draw_y, nil, scale, scale)
                    if seg.tooltip then
                        if mouse_x >= draw_x and mouse_x <= (draw_x + token_w)
                            and mouse_y >= draw_y and mouse_y <= (draw_y + seg_h) then
                            hovered_tooltip = {
                                key = seg.tooltip,
                                x = draw_x,
                                y = draw_y,
                                w = token_w,
                                h = seg_h,
                            }
                            love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, 0.35)
                            love.graphics.rectangle("fill", draw_x, draw_y + seg_h - 2, token_w, 2)
                        end
                    end
                    draw_x = draw_x + token_w
                    first_word = false
                end
                if seg_text:sub(-1) == " " then
                    draw_x = draw_x + space_w
                end
            end
        end
    end

    return hovered_tooltip, lines
end

local function pl_remove_tooltip_card()
    if pl_tooltip_card then
        if pl_tooltip_card.children and pl_tooltip_card.children.info then
            if pl_tooltip_card.children.info.remove then
                pcall(function() pl_tooltip_card.children.info:remove() end)
            end
            pl_tooltip_card.children.info = nil
        end
        if pl_tooltip_card.remove then
            pcall(function() pl_tooltip_card:remove() end)
        end
    end
    pl_tooltip_card = nil
end

local function pl_draw_hover_tooltip(hovered)
    if not hovered or not hovered.key then
        pl_remove_tooltip_card()
        return
    end

    local center = G and G.P_CENTERS and G.P_CENTERS[hovered.key]
    local is_seal = false
    if not center and G and G.P_SEALS then
        local seal = G.P_SEALS[hovered.key]
            or (SMODS and SMODS.Seal and G.P_SEALS[SMODS.Seal.badge_to_key[hovered.key] or ''])
        if seal then
            center = seal; is_seal = true
        end
    end
    if not center then return end
    if not G or not G.ROOM or not G.ROOM.T then return end

    local card_w = G.CARD_W * 0.55
    local card_h = G.CARD_H * 0.55
    local sw, sh = love.graphics.getDimensions()
    local room_w = G.ROOM.T.w or sw
    local room_h = G.ROOM.T.h or sh
    local sx = room_w / math.max(sw, 1)
    local sy = room_h / math.max(sh, 1)

    local anchor_x = (hovered.x + hovered.w * 0.5) * sx
    local anchor_y = (hovered.y + hovered.h) * sy

    local x = anchor_x - card_w * 0.5
    local y = anchor_y - (12 * sy)

    if x < 0.08 then x = 0.08 end
    if x + card_w > room_w - 0.08 then x = room_w - card_w - 0.08 end

    if y + card_h > room_h - 0.08 then
        y = (hovered.y * sy) - card_h - (12 * sy)
    end
    if y < 0.08 then y = 0.08 end

    local card_center = (is_seal or center.set == 'Edition')
        and (G.P_CENTERS.j_joker or G.P_CENTERS.c_base)
        or center
    if not pl_tooltip_card or pl_tooltip_card._pl_key ~= hovered.key then
        pl_remove_tooltip_card()
        pl_tooltip_card = Card(x + card_w / 2, y + card_h / 2, G.CARD_W * 0.55, G.CARD_H * 0.55, nil, card_center, nil)
        pl_tooltip_card._pl_key = hovered.key
        pl_tooltip_card.no_graveyard = true
        pl_tooltip_card.states = pl_tooltip_card.states or {}
        pl_tooltip_card.states.hover = pl_tooltip_card.states.hover or {}
        pl_tooltip_card.states.click = pl_tooltip_card.states.click or {}
        pl_tooltip_card.states.drag = pl_tooltip_card.states.drag or {}
        pl_tooltip_card.states.hover.can = true
        pl_tooltip_card.states.click.can = false
        pl_tooltip_card.states.drag.can = false
        pl_tooltip_card.ability = pl_tooltip_card.ability or {}
        pl_tooltip_card.ability.temporary = true
        pl_tooltip_card.ambient_tilt = 0
    end
    pl_tooltip_card.T.r = 0

    pl_tooltip_card.states.hover.can = false
    if pl_tooltip_card.children and pl_tooltip_card.children.info then
        if pl_tooltip_card.children.info.remove then
            pcall(function() pl_tooltip_card.children.info:remove() end)
        end
        pl_tooltip_card.children.info = nil
    end
    if not pl_tooltip_card.children.playlog_box then
        local name = {}
        local description = {}
        local target = {
            type = 'descriptions',
            key = center.key,
            set = center.set,
            nodes = description,
            vars = { colours = {} }
        }
        local res = {}
        local full_UI_table = { main = description, info = {}, type = {}, name = nil, badges = nil }
        if is_seal or center.consumeable or center.set == 'Edition' or center.set == 'Enhanced' then
            PlayLog.no_info_queue = true
            generate_card_ui(center, full_UI_table, nil,
                center.set or (is_seal and 'Seal'), {})
            PlayLog.no_info_queue = nil
        elseif center.loc_vars and type(center.loc_vars) == 'function' then
            res = center:loc_vars({}, card) or {}
            target.vars = res.vars or target.vars
            target.key = res.key or target.key
            target.set = res.set or target.set
            target.scale = res.scale
            target.text_colour = res.text_colour
        else
            local vars, main_start, main_end = pl_tooltip_card:generate_UIBox_ability_table(true)
            target.vars = vars or target.vars
            res.main_start = main_start
            res.main_end = main_end
        end
        if res.main_start then description[#description + 1] = res.main_start end
        if not (is_seal or center.consumeable or center.set == 'Edition' or center.set == 'Enhanced') then
            localize(target)
        end
        if res.main_end then description[#description + 1] = res.main_end end

        if type(full_UI_table.name) == "string" then full_UI_table.name = nil end

        if not full_UI_table.name then
            if is_seal then
                if type(center.name) == 'string' and center.name ~= '' then
                    name[#name + 1] = { { n = G.UIT.T, config = { text = center.name, scale = 0.5, colour = G.C.WHITE, vert = false } } }
                else
                    localize { type = 'name', set = center.set or 'Seal', key = center.key, nodes = name, vars = {} }
                end
            else
                localize { type = 'name', set = res.name_set or target.set, key = res.name_key or target.key, nodes = name, vars = res.name_vars or target.vars or {} }
            end
        end

        local display_card = Card(0, 0, G.CARD_W / 1.2, G.CARD_H / 1.2, nil, card_center)
        display_card.no_ui = true
        display_card.no_shadow = true
        if center.set == 'Edition' then
            pcall(function() display_card:set_edition(center.key, true, true) end)
        elseif is_seal then
            local seal_key = (SMODS and SMODS.Seal and SMODS.Seal.badge_to_key[hovered.key]) or hovered.key
            if G.P_SEALS and G.P_SEALS[seal_key] then
                pcall(function() display_card:set_seal(seal_key, true, true) end)
            end
        end

        pl_tooltip_card.children.playlog_box = UIBox {
            definition = {
                n = G.UIT.ROOT,
                config = {
                    align = "cm",
                    padding = 0.1,
                    r = 0.12,
                    emboss = 0.1,
                    colour = PlayLog.config.border or lighten(G.C.JOKER_GREY, 0.5)
                },
                nodes = {
                    {
                        n = G.UIT.R,
                        config = { align = "cm", minw = 1, colour = PlayLog.config.panel_bg or adjust_alpha(darken(G.C.BLACK, 0.1), 0.8), r = 0.1 },
                        nodes = {
                            {
                                n = G.UIT.C,
                                config = { align = "cm", colour = G.C.CLEAR },
                                nodes = {
                                    {
                                        n = G.UIT.R,
                                        config = { padding = 0.05, r = 0.12, colour = G.C.CLEAR, emboss = 0.07 },
                                        nodes = {
                                            {
                                                n = G.UIT.R,
                                                config = { align = "cm", padding = 0.07, r = 0.1, colour = G.C.CLEAR },
                                                nodes = {
                                                    full_UI_table.name and {
                                                        n = G.UIT.R,
                                                        config = { align = "cm", padding = 0.07, r = 0.1, colour = G.C.CLEAR },
                                                        nodes = full_UI_table.name
                                                    } or desc_from_rows(name, true),
                                                    desc_from_rows(description)
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            {
                                n = G.UIT.C,
                                config = { align = "cm", r = 0.2, padding = 0.05, minw = 1, colour = G.C.CLEAR },
                                nodes = {
                                    {
                                        n = G.UIT.O,
                                        config = { object = display_card }
                                    }
                                }
                            },
                        }
                    },
                }
            },
            config = {
                align = "cm",
                offset = { x = 0, y = 0 },
                major = pl_tooltip_card,
                instance_type = "POPUP"
            }
        }
    end

    if pl_tooltip_card.update then
        pl_tooltip_card:update(0)
    end

    love.graphics.push("all")
    love.graphics.setCanvas({ love.graphics.getCanvas(), stencil = true })
    love.graphics.setScissor()
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    G.OVERLAY_TUTORIAL = true
    if pl_tooltip_card.translate_container then
        pl_tooltip_card:translate_container()
    end
    if pl_tooltip_card.draw then
        --pl_tooltip_card:draw()
    elseif pl_tooltip_card.draw_ui then
        pl_tooltip_card:draw_ui()
    elseif pl_tooltip_card.render then
        pl_tooltip_card:render()
    end

    G.OVERLAY_TUTORIAL = nil
    love.graphics.pop()
end

local function pl_get_layout()
    local sw, sh = love.graphics.getDimensions()
    local panel_w = math.min(420, sw - 36)
    local panel_h = math.min(420, math.floor(sh * 0.70))
    local slide = G.playlog_slide or 0
    local slide_offset = (1 - slide) * (panel_w + 20)
    local panel_x = math.floor(sw - panel_w - 18 + slide_offset)
    local panel_y = math.max(10, math.floor(sh * 0.22))
    if panel_y + panel_h > sh - 10 then panel_y = sh - panel_h - 10 end
    local header_h = 28
    local content_x = panel_x + 14
    local content_y = panel_y + header_h + 10
    local content_w = panel_w - 36
    local content_h = panel_h - header_h - 22
    local button_w = 36
    local button_h = 36
    local button_x = sw - button_w - 12
    local button_y = sh - button_h - 100
    return {
        panel_x = panel_x,
        panel_y = panel_y,
        panel_w = panel_w,
        panel_h = panel_h,
        header_h = header_h,
        content_x = content_x,
        content_y = content_y,
        content_w = content_w,
        content_h = content_h,
        button_x = button_x,
        button_y = button_y,
        button_w = button_w,
        button_h = button_h,
        scrollbar_x = panel_x + panel_w - 12,
        scrollbar_y = content_y,
        scrollbar_w = 6,
        scrollbar_h = content_h,
        cfg_btn_x = panel_x + panel_w - 40,
        cfg_btn_y = panel_y + 5,
        cfg_btn_w = 28,
        cfg_btn_h = 18,
    }
end

local function pl_get_max_shift()
    return math.max(#G.playlog_entries - PLAYLOG_VISIBLE_ROWS, 0)
end

local function pl_enqueue_rich_log(raw_body)
    G.playlog_pending_entries = G.playlog_pending_entries or {}
    local time_text = PlayLog.get_formatted_time(PlayLog.CLOCK_FORMATS[4])
    local raw_text = "{C:inactive}" .. time_text .. " " .. tostring(raw_body or "")

    G.playlog_pending_entries[#G.playlog_pending_entries + 1] = {
        segments = PlayLog.parse_text(raw_text)
    }
end

PlayLog.log_event = function(raw_body)
    pl_enqueue_rich_log(raw_body)
end

local function pl_autofollow_tail_on_add(added)
    if added <= 0 or not G.playlog_scroll_shift then return end
    if G.playlog_scroll_shift > 0 then
        G.playlog_scroll_shift = G.playlog_scroll_shift + added
    end
    G.playlog_scroll_shift = pl_clamp(G.playlog_scroll_shift, 0, pl_get_max_shift())
end

local function pl_flush_queue(max_rows)
    local queue = G.playlog_pending_entries
    if not queue then return 0 end
    local start_idx = G.playlog_pending_start or 1
    local last_idx = #queue
    if start_idx > last_idx then return 0 end
    local end_idx = math.min(start_idx + max_rows - 1, last_idx)
    local added = 0
    for i = start_idx, end_idx do
        local entry = queue[i]
        if entry then
            G.playlog_entries[#G.playlog_entries + 1] = entry
            added = added + 1
        end
    end
    G.playlog_pending_start = end_idx + 1
    if G.playlog_pending_start > 128 and G.playlog_pending_start > (#queue / 2) then
        local compacted = {}
        for i = G.playlog_pending_start, #queue do
            compacted[#compacted + 1] = queue[i]
        end
        G.playlog_pending_entries = compacted
        G.playlog_pending_start = 1
    end
    pl_autofollow_tail_on_add(added)
    return added
end

local function pl_draw_config_content(layout)
    local cx     = layout.content_x
    local cy     = layout.content_y
    local cw     = layout.content_w
    local btn_w  = math.floor((cw - 10) / 2)
    local btn_h  = 40
    local gap    = 6
    local mx, my = love.mouse.getPosition()
    --title
    love.graphics.setColor(pl_col('header_text', 0.95, 0.73, 0.25, 1))
    love.graphics.print("SELECT THEME", cx, cy + 4, nil, 0.80, 0.80)
    G.playlog_theme_rects = {}
    for i, theme in ipairs(PLAYLOG_THEMES) do
        local col                = (i - 1) % 2
        local row                = math.floor((i - 1) / 2)
        local bx                 = cx + col * (btn_w + gap)
        local by                 = cy + 26 + row * (btn_h + gap)
        local hov                = mx >= bx and mx <= bx + btn_w and my >= by and my <= by + btn_h
        G.playlog_theme_rects[i] = { x = bx, y = by, w = btn_w, h = btn_h }
        local function cols_eq(a, b)
            return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
        end
        local active = cols_eq(PlayLog.config.panel_bg, theme.panel_bg)
            and cols_eq(PlayLog.config.border, theme.border)
            and cols_eq(PlayLog.config.header_text, theme.header_text)
        love.graphics.setColor(theme.panel_bg[1], theme.panel_bg[2], theme.panel_bg[3], 0.95)
        love.graphics.rectangle("fill", bx, by, btn_w, btn_h, 6, 6)
        local b = theme.border
        love.graphics.setColor(b[1], b[2], b[3], 0.85)
        love.graphics.rectangle("fill", bx + 2, by + 2, btn_w - 4, 8, 4, 4)
        love.graphics.setColor(b[1], b[2], b[3], hov and 1 or (active and 0.9 or 0.5))
        love.graphics.setLineWidth(hov and 2.5 or (active and 2 or 1.5))
        love.graphics.rectangle("line", bx, by, btn_w, btn_h, 6, 6)
        love.graphics.setLineWidth(1)
        local ht = theme.header_text
        love.graphics.setColor(ht[1], ht[2], ht[3], 1)
        love.graphics.print(theme.name, bx + 8, by + 15, nil, 0.82, 0.82)
        if active then
            love.graphics.setColor(b[1], b[2], b[3], 0.9)
            love.graphics.circle("fill", bx + btn_w - 10, by + btn_h - 10, 4)
        end
    end
    --hex input section
    local rows = math.ceil(#PLAYLOG_THEMES / 2)
    local hex_y = cy + 26 + rows * (btn_h + gap) + 10
    love.graphics.setColor(pl_col('header_text', 0.95, 0.73, 0.25, 0.7))
    love.graphics.print("CUSTOM COLORS  (click swatch to open picker)", cx, hex_y, nil, 0.68, 0.68)
    hex_y = hex_y + 18
    G.playlog_hex_rects = {}
    local field_h = 28
    local swatch_w = 22
    for i, field in ipairs(pl_hex_fields) do
        local fy = hex_y + (i - 1) * (field_h + 5)
        local cur_col = PlayLog.config[field.key]
        local swatch_hov = pl_point_in_rect(mx, my, cx, fy + 2, swatch_w, field_h - 4)
        --swatch for color selection
        if cur_col then
            love.graphics.setColor(cur_col[1], cur_col[2], cur_col[3], 1)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
        end
        love.graphics.rectangle("fill", cx, fy + 2, swatch_w, field_h - 4, 3, 3)
        if swatch_hov then
            love.graphics.setColor(1, 1, 1, 0.35)
            love.graphics.rectangle("line", cx, fy + 2, swatch_w, field_h - 4, 3, 3)
        end
        -- field info
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("fill", cx + swatch_w + 4, fy, cw - swatch_w - 4, field_h, 4, 4)
        local br1, br2, br3 = pl_col('border', 0.95, 0.73, 0.25, 1)
        love.graphics.setColor(br1, br2, br3, 0.25)
        love.graphics.rectangle("line", cx + swatch_w + 4, fy, cw - swatch_w - 4, field_h, 4, 4)
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.print(field.label, cx + swatch_w + 8, fy + 2, nil, 0.62, 0.62)
        love.graphics.setColor(1, 1, 1, 0.75)
        love.graphics.print("#" .. pl_rgb_to_hex(cur_col), cx + swatch_w + 8, fy + 13, nil, 0.78, 0.78)
        G.playlog_hex_rects[i] = {
            x = cx,
            y = fy + 2,
            w = swatch_w,
            h = field_h - 4,
            key = field.key,
            label = field
                .label
        }
    end
end

local function pl_draw_button(layout)
    local mx, my = love.mouse.getPosition()
    local hovered = pl_point_in_rect(mx, my, layout.button_x, layout.button_y, layout.button_w, layout.button_h)
    local is_open = G.playlog_visible
    --shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", layout.button_x + 2, layout.button_y + 3, layout.button_w, layout.button_h, 9, 9)
    --body
    if hovered then
        love.graphics.setColor(pl_col('button_hover_bg', 0.95, 0.73, 0.25, 1))
    elseif is_open then
        love.graphics.setColor(pl_col('button_active_bg', 0.18, 0.18, 0.28, 0.97))
    else
        love.graphics.setColor(pl_col('button_bg', 0.14, 0.14, 0.22, 0.97))
    end
    love.graphics.rectangle("fill", layout.button_x, layout.button_y, layout.button_w, layout.button_h, 9, 9)
    --border
    love.graphics.setColor(pl_col('border', 0.95, 0.73, 0.25, hovered and 1 or 0.5))
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", layout.button_x, layout.button_y, layout.button_w, layout.button_h, 9, 9)
    love.graphics.setLineWidth(1)
    --icon
    love.graphics.setColor(hovered and 0.1 or 1, hovered and 0.1 or 1, hovered and 0.1 or 1, 1)
    love.graphics.print("LOG", layout.button_x + 4, layout.button_y + 10, nil, 0.72, 0.72)
end

local function pl_draw_panel(layout)
    if not G.playlog_visible then
        G.playlog_hovered_tooltip = nil
        return
    end
    --drop shadow
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", layout.panel_x + 4, layout.panel_y + 5, layout.panel_w, layout.panel_h, 10, 10)
    --panel body
    love.graphics.setColor(pl_col('panel_bg', 0.10, 0.10, 0.17, 0.97))
    love.graphics.rectangle("fill", layout.panel_x, layout.panel_y, layout.panel_w, layout.panel_h, 10, 10)
    --gold border
    love.graphics.setColor(pl_col('border', 0.95, 0.73, 0.25, 0.85))
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", layout.panel_x, layout.panel_y, layout.panel_w, layout.panel_h, 10, 10)
    love.graphics.setLineWidth(1)
    --header bar
    love.graphics.setColor(pl_col('header_tint', 0.95, 0.73, 0.25, 0.18))
    love.graphics.rectangle("fill", layout.panel_x + 2, layout.panel_y + 2, layout.panel_w - 4, layout.header_h, 9, 9)
    --header separator line
    love.graphics.setColor(pl_col('border', 0.95, 0.73, 0.25, 0.45))
    love.graphics.setLineWidth(1)
    love.graphics.line(layout.panel_x + 10, layout.panel_y + layout.header_h + 2,
        layout.panel_x + layout.panel_w - 10, layout.panel_y + layout.header_h + 2)
    --header title
    love.graphics.setColor(pl_col('header_text', 0.95, 0.73, 0.25, 1))
    love.graphics.print("PLAY LOG", layout.panel_x + 14, layout.panel_y + 7, nil, 0.82, 0.82)
    --config toggle button in header
    local cfg_open = G.playlog_config_open
    local mx0, my0 = love.mouse.getPosition()
    local cfg_hov = pl_point_in_rect(mx0, my0, layout.cfg_btn_x, layout.cfg_btn_y, layout.cfg_btn_w, layout.cfg_btn_h)
    love.graphics.setColor(pl_col('border', 0.95, 0.73, 0.25, cfg_open and 0.9 or (cfg_hov and 0.7 or 0.35)))
    love.graphics.rectangle("fill", layout.cfg_btn_x, layout.cfg_btn_y, layout.cfg_btn_w, layout.cfg_btn_h, 4, 4)
    love.graphics.setColor(0, 0, 0, cfg_open and 0.8 or 0.6)
    love.graphics.print(cfg_open and "LOG" or "CFG", layout.cfg_btn_x + 2, layout.cfg_btn_y + 2, nil, 0.70, 0.70)
    --content area: slide between log (left) and config (right)
    local cslide = G.playlog_config_slide or 0
    local cw = layout.content_w
    love.graphics.setScissor(layout.content_x, layout.content_y, layout.content_w, layout.content_h)
    local total = #G.playlog_entries
    local max_shift = pl_get_max_shift()
    local shift = pl_clamp(G.playlog_scroll_shift or max_shift, 0, pl_get_max_shift())
    G.playlog_scroll_shift = max_shift > 0 and shift or nil
    local first = shift
    local last = math.max(1, first + PLAYLOG_VISIBLE_ROWS + 1)
    local mx, my = love.mouse.getPosition()
    local hovered_tooltip = nil
    local y = layout.content_y
    local row_idx = 0
    --log panel: translate left as config slides in
    local log_x_off = math.floor(-cslide * (cw + 20))
    local cfg_x_off = math.floor((1 - cslide) * (cw + 20))
    --draw log entries (shifted left during config slide)
    if cslide < 0.99 then
        love.graphics.push()
        love.graphics.translate(log_x_off, 0)
        for i = first, last do
            local entry = G.playlog_entries[i]
            if entry then
                row_idx = row_idx + 1
                if row_idx % 2 == 0 then
                    love.graphics.setColor(1, 1, 1, 0.03)
                    love.graphics.rectangle("fill", layout.content_x - 6, y - 1, layout.content_w + 8, PLAYLOG_ROW_HEIGHT)
                end
                --only do hover detection when fully settled
                local seg_mx = cslide == 0 and mx or -9999
                local maybe_hovered, lines_used = pl_draw_rich_segments(entry.segments, layout.content_x, y,
                    layout.content_x + layout.content_w - 10, seg_mx, my)
                if maybe_hovered then hovered_tooltip = maybe_hovered end
                y = y + (lines_used or 1) * PLAYLOG_ROW_HEIGHT
                if y > (layout.content_y + layout.content_h - PLAYLOG_ROW_HEIGHT) then break end
            end
        end
        love.graphics.pop()
    end
    --draw config content (slides in from the right)
    if cslide > 0.01 then
        love.graphics.push()
        love.graphics.translate(cfg_x_off, 0)
        if G.playlog_picker then
            pl_draw_picker(layout)
        else
            pl_draw_config_content(layout)
        end
        love.graphics.pop()
    end
    love.graphics.setScissor()
    G.playlog_hovered_tooltip = hovered_tooltip
    --scrollbar
    if max_shift > 0 then
        love.graphics.setColor(1, 1, 1, 0.08)
        love.graphics.rectangle("fill", layout.scrollbar_x, layout.scrollbar_y, layout.scrollbar_w, layout.scrollbar_h, 3,
            3)
        local ratio = PLAYLOG_VISIBLE_ROWS / math.max(total, PLAYLOG_VISIBLE_ROWS)
        local knob_h = math.max(20, layout.scrollbar_h * ratio)
        local t = shift / max_shift
        local knob_y = layout.scrollbar_y + (layout.scrollbar_h - knob_h) * t
        love.graphics.setColor(pl_col('scrollbar_knob', 0.95, 0.73, 0.25, 0.85))
        love.graphics.rectangle("fill", layout.scrollbar_x, knob_y, layout.scrollbar_w, knob_h, 3, 3)
    end
end

local function pl_set_visible(is_visible)
    G.playlog_visible = is_visible and true or false
    if not G.playlog_visible then
        G.playlog_hovered_tooltip = nil
    end
end

G.FUNCS.playlog_open_log = function(e)
    -- Editions
    pl_enqueue_rich_log("Card got {T:e_foil}Foil{} edition")
    pl_enqueue_rich_log("Card got {T:e_holo}Holographic{} edition")
    pl_enqueue_rich_log("Card got {T:e_polychrome}Polychrome{} edition")
    pl_enqueue_rich_log("Card got {T:e_negative}Negative{} edition")
    -- Enhancements
    pl_enqueue_rich_log("Card enhanced to {T:m_mult}Mult Card{}")
    pl_enqueue_rich_log("Card enhanced to {T:m_wild}Wild Card{}")
    pl_enqueue_rich_log("Card enhanced to {T:m_glass}Glass Card{}")
    pl_enqueue_rich_log("Card enhanced to {T:m_steel}Steel Card{}")
    pl_enqueue_rich_log("Card enhanced to {T:m_stone}Stone Card{}")
    pl_enqueue_rich_log("Card enhanced to {T:m_gold}Gold Card{}")
    pl_enqueue_rich_log("Card enhanced to {T:m_lucky}Lucky Card{}")
    -- Seals
    pl_enqueue_rich_log("Card got {T:gold_seal}Gold Seal{}")
    pl_enqueue_rich_log("Card got {T:red_seal}Red Seal{}")
    pl_enqueue_rich_log("Card got {T:blue_seal}Blue Seal{}")
    pl_enqueue_rich_log("Card got {T:purple_seal}Purple Seal{}")
    -- Tarots
    pl_enqueue_rich_log("{C:tarot}{T:c_fool}The Fool{} copied last used card")
    pl_enqueue_rich_log("{C:tarot}{T:c_high_priestess}The High Priestess{} created 2 planets")
    pl_enqueue_rich_log("{C:tarot}{T:c_magician}The Magician{} enhanced 2 cards to {T:m_lucky}Lucky{}")
    pl_enqueue_rich_log("{C:tarot}{T:c_emperor}The Emperor{} created 2 tarots")
    pl_enqueue_rich_log("{C:tarot}{T:c_strength}Strength{} swapped ranks on 2 cards")
    pl_enqueue_rich_log("{C:tarot}{T:c_hermit}The Hermit{} doubled money")
    pl_enqueue_rich_log("{C:tarot}{T:c_wheel_of_fortune}Wheel of Fortune{} gave {T:e_foil}Foil{} to a joker")
    pl_enqueue_rich_log("{C:tarot}{T:c_temperance}Temperance{} collected joker value")
    pl_enqueue_rich_log("{C:tarot}{T:c_hanged_man}The Hanged Man{} destroyed 2 cards")
    pl_enqueue_rich_log("{C:tarot}{T:c_death}Death{} converted a card")
    pl_enqueue_rich_log("{C:tarot}{T:c_star}The Star{} converted 3 cards to {C:spades}Spades{}")
    pl_enqueue_rich_log("{C:tarot}{T:c_judgement}Judgement{} created a random joker")
    pl_enqueue_rich_log("{C:tarot}{T:c_world}The World{} converted 3 cards to {C:hearts}Hearts{}")
    -- Planets
    pl_enqueue_rich_log("{C:planet}{T:c_pluto}Pluto{} leveled up {C:attention}High Card{}")
    pl_enqueue_rich_log("{C:planet}{T:c_mercury}Mercury{} leveled up {C:attention}Pair{}")
    pl_enqueue_rich_log("{C:planet}{T:c_uranus}Uranus{} leveled up {C:attention}Two Pair{}")
    pl_enqueue_rich_log("{C:planet}{T:c_venus}Venus{} leveled up {C:attention}Three of a Kind{}")
    pl_enqueue_rich_log("{C:planet}{T:c_saturn}Saturn{} leveled up {C:attention}Straight{}")
    pl_enqueue_rich_log("{C:planet}{T:c_jupiter}Jupiter{} leveled up {C:attention}Flush{}")
    pl_enqueue_rich_log("{C:planet}{T:c_mars}Mars{} leveled up {C:attention}Full House{}")
    pl_enqueue_rich_log("{C:planet}{T:c_neptune}Neptune{} leveled up {C:attention}Four of a Kind{}")
    pl_enqueue_rich_log("{C:planet}{T:c_earth}Earth{} leveled up {C:attention}Straight Flush{}")
    pl_enqueue_rich_log("{C:planet}{T:c_eris}Eris{} leveled up {C:attention}Five of a Kind{}")
    -- Spectrals
    pl_enqueue_rich_log("{C:spectral}{T:c_familiar}Familiar{} destroyed a card and added 3 enhanced cards")
    pl_enqueue_rich_log("{C:spectral}{T:c_grim}Grim{} destroyed a card and added 2 Aces")
    pl_enqueue_rich_log("{C:spectral}{T:c_incantation}Incantation{} destroyed a card and added 4 numbered cards")
    pl_enqueue_rich_log("{C:spectral}{T:c_talisman}Talisman{} added a {T:gold_seal}Gold Seal{}")
    pl_enqueue_rich_log("{C:spectral}{T:c_aura}Aura{} added an edition to a card")
    pl_enqueue_rich_log("{C:spectral}{T:c_wraith}Wraith{} created a rare joker")
    pl_enqueue_rich_log("{C:spectral}{T:c_sigil}Sigil{} converted all cards to one suit")
    pl_enqueue_rich_log("{C:spectral}{T:c_ouija}Ouija{} converted all cards to one rank")
    pl_enqueue_rich_log("{C:spectral}{T:c_ectoplasm}Ectoplasm{} added {T:e_negative}Negative{} to a joker")
    pl_enqueue_rich_log("{C:spectral}{T:c_immolate}Immolate{} destroyed 5 cards for {C:money}$20{}")
    pl_enqueue_rich_log("{C:spectral}{T:c_ankh}Ankh{} copied a joker")
    pl_enqueue_rich_log("{C:spectral}{T:c_deja_vu}Deja Vu{} added a {T:red_seal}Red Seal{}")
    pl_enqueue_rich_log("{C:spectral}{T:c_hex}Hex{} added {T:e_polychrome}Polychrome{} to a joker")
    pl_enqueue_rich_log("{C:spectral}{T:c_trance}Trance{} added a {T:blue_seal}Blue Seal{}")
    pl_enqueue_rich_log("{C:spectral}{T:c_medium}Medium{} added a {T:purple_seal}Purple Seal{}")
    pl_enqueue_rich_log("{C:spectral}{T:c_cryptid}Cryptid{} made 2 copies of a card")
    -- Jokers
    pl_enqueue_rich_log("{C:attention}{T:j_joker}Joker{} is in play")
    pl_enqueue_rich_log("{C:attention}{T:j_misprint}Misprint{} is in play")
    pl_enqueue_rich_log("{C:attention}{T:j_blueprint}Blueprint{} copying {T:j_joker}Joker{}")
    pl_enqueue_rich_log("{C:attention}{T:j_brainstorm}Brainstorm{} copying {T:j_blueprint}Blueprint{}")
end

local game_start_run_ref = Game.start_run
function Game:start_run(args)
    game_start_run_ref(self, args)
    G.playlog_entries         = {}
    G.playlog_pending_entries = {}
    G.playlog_pending_start   = 1
    G.playlog_visible         = true
    G.playlog_slide           = 0
    G.playlog_config_open     = false
    G.playlog_config_slide    = 0
    G.playlog_hex_active      = nil
    G.playlog_hex_input       = nil
    G.playlog_picker          = nil
    G.playlog_hovered_tooltip = nil
    pl_remove_tooltip_card()
end

local game_update_ref = Game.update
function Game:update(dt)
    local ret = game_update_ref(self, dt)
    if pl_is_run_active() then
        pl_flush_queue(PLAYLOG_ROWS_PER_FRAME)
        -- panel slide
        local target = G.playlog_visible and 1 or 0
        local current = G.playlog_slide or 0
        local next_val = current + (target - current) * math.min(1, PLAYLOG_SLIDE_SPEED * dt)
        if math.abs(next_val - target) < 0.002 then next_val = target end
        G.playlog_slide = next_val
        if next_val == 0 then
            pl_remove_tooltip_card()
            G.playlog_hovered_tooltip = nil
        end
        -- config panel slide
        local cfg_target = G.playlog_config_open and 1 or 0
        local cfg_cur = G.playlog_config_slide or 0
        local cfg_next = cfg_cur + (cfg_target - cfg_cur) * math.min(1, PLAYLOG_SLIDE_SPEED * dt)
        if math.abs(cfg_next - cfg_target) < 0.002 then cfg_next = cfg_target end
        G.playlog_config_slide = cfg_next
    end
    return ret
end

function PlayLog.draw()
    if not pl_is_run_active() then return end
    local layout = pl_get_layout()

    if (G.playlog_slide or 0) > 0.01 then
        pl_draw_panel(layout)
    end
    pl_draw_button(layout)
    local active_tooltip = G.playlog_hovered_tooltip
    if not active_tooltip then
        pl_remove_tooltip_card()
    end
    if (G.playlog_slide or 0) > 0.5 then
        pl_draw_hover_tooltip(active_tooltip)
    end
end

if not love.mousepressed then
    function love.mousepressed(x, y, button, istouch, presses) end
end
if not love.keypressed then
    function love.keypressed(key, scancode, isrepeat) end
end

local playlog_keypressed_ref = love.keypressed
function love.keypressed(key, scancode, isrepeat)
    if pl_is_run_active() then
        local pk = G.playlog_picker
        if pk and pk.hex_focus then
            if key == 'return' or key == 'kpenter' then
                local col = pl_hex_to_rgb(pk.hex_input or "")
                if col then
                    local h, s, v = pl_rgb_to_hsv(col[1], col[2], col[3])
                    pk.h, pk.s, pk.v = h, s, v
                    pl_picker_apply()
                end
                pk.hex_focus = false
                pk.hex_input = nil
            elseif key == 'backspace' then
                local s = pk.hex_input or ""
                pk.hex_input = s:sub(1, math.max(0, #s - 1))
            else
                local kp_map = {
                    kp0 = '0',
                    kp1 = '1',
                    kp2 = '2',
                    kp3 = '3',
                    kp4 = '4',
                    kp5 = '5',
                    kp6 = '6',
                    kp7 = '7',
                    kp8 =
                    '8',
                    kp9 = '9'
                }
                local char = kp_map[key] or key:upper()
                if #char == 1 and char:match("^[0-9A-F]$") then
                    local s = pk.hex_input or ""
                    if #s < 6 then
                        pk.hex_input = s .. char
                    end
                end
            end
            return
        end
        if G.playlog_hex_active then
            if key == 'return' or key == 'kpenter' then
                local col = pl_hex_to_rgb(G.playlog_hex_input or "")
                if col then
                    local cfg_key = G.playlog_hex_active
                    PlayLog.config[cfg_key] = col
                    if cfg_key == 'border' then
                        PlayLog.config.header_tint    = { col[1], col[2], col[3], 0.18 }
                        PlayLog.config.scrollbar_knob = { col[1], col[2], col[3], 0.85 }
                    end
                    pl_save_config()
                end
                G.playlog_hex_active = nil
                G.playlog_hex_input  = nil
            elseif key == 'escape' then
                G.playlog_hex_active = nil
                G.playlog_hex_input  = nil
            elseif key == 'backspace' then
                local s = G.playlog_hex_input or ""
                G.playlog_hex_input = s:sub(1, math.max(0, #s - 1))
            else
                local kp_map = {
                    kp0 = '0',
                    kp1 = '1',
                    kp2 = '2',
                    kp3 = '3',
                    kp4 = '4',
                    kp5 = '5',
                    kp6 = '6',
                    kp7 = '7',
                    kp8 =
                    '8',
                    kp9 = '9'
                }
                local char = kp_map[key] or key:upper()
                if #char == 1 and char:match("^[0-9A-F]$") then
                    local s = G.playlog_hex_input or ""
                    if #s < 6 then G.playlog_hex_input = s .. char end
                end
            end
            return
        end
        if not isrepeat and key == PLAYLOG_TOGGLE_KEY then
            pl_set_visible(not G.playlog_visible)
        end
    end
    return playlog_keypressed_ref(key, scancode, isrepeat)
end

if not love.textinput then
    function love.textinput(t) end
end
local playlog_textinput_ref = love.textinput
function love.textinput(t)
    return playlog_textinput_ref(t)
end

local playlog_mousepressed_ref = love.mousepressed
function love.mousepressed(x, y, button, istouch, presses)
    if not pl_is_run_active() then
        return playlog_mousepressed_ref(x, y, button, istouch, presses)
    end
    local layout = pl_get_layout()
    if button == 1 then
        if pl_point_in_rect(x, y, layout.button_x, layout.button_y, layout.button_w, layout.button_h) then
            pl_set_visible(not G.playlog_visible)
        elseif G.playlog_visible and pl_point_in_rect(x, y, layout.cfg_btn_x, layout.cfg_btn_y, layout.cfg_btn_w, layout.cfg_btn_h) then
            -- CFG header button: toggles config panel, or closes picker back to list
            if G.playlog_picker then
                G.playlog_picker = nil
            else
                G.playlog_config_open = not G.playlog_config_open
            end
        elseif G.playlog_config_open then
            local pk = G.playlog_picker
            if pk then
                if pk._back_rect and pl_point_in_rect(x, y, pk._back_rect.x, pk._back_rect.y, pk._back_rect.w, pk._back_rect.h) then
                    G.playlog_picker = nil
                elseif pk._hex_rect and pl_point_in_rect(x, y, pk._hex_rect.x, pk._hex_rect.y, pk._hex_rect.w, pk._hex_rect.h) then
                    pk.hex_focus = true
                    pk.hex_input = nil
                elseif pk._sq_rect and pl_point_in_rect(x, y, pk._sq_rect.x, pk._sq_rect.y, pk._sq_rect.w, pk._sq_rect.h) then
                    pk.hex_focus = false
                    pk.hex_input = nil
                    local nx = pl_clamp((x - pk._sq_rect.x) / pk._sq_rect.w, 0, 1)
                    local ny = pl_clamp((y - pk._sq_rect.y) / pk._sq_rect.h, 0, 1)
                    pk.s = nx; pk.v = 1 - ny
                    pk._dragging = 'sv'
                    pl_picker_apply()
                elseif pk._hbar_rect and pl_point_in_rect(x, y, pk._hbar_rect.x, pk._hbar_rect.y, pk._hbar_rect.w, pk._hbar_rect.h) then
                    pk.hex_focus = false
                    pk.hex_input = nil
                    pk.h = pl_clamp((x - pk._hbar_rect.x) / pk._hbar_rect.w, 0, 1) * 360
                    pk._dragging = 'hue'
                    pl_picker_apply()
                end
            else
                -- swatch opens picker
                if G.playlog_hex_rects then
                    for i, rect in ipairs(G.playlog_hex_rects) do
                        if pl_point_in_rect(x, y, rect.x, rect.y, rect.w, rect.h) then
                            local cur = PlayLog.config[rect.key]
                            local h, s, v = 0, 0, 1
                            if cur then h, s, v = pl_rgb_to_hsv(cur[1], cur[2], cur[3]) end
                            G.playlog_picker = { key = rect.key, label = rect.label, h = h, s = s, v = v }
                            break
                        end
                    end
                end
                -- theme buttons
                if G.playlog_theme_rects then
                    for i, rect in ipairs(G.playlog_theme_rects) do
                        if pl_point_in_rect(x, y, rect.x, rect.y, rect.w, rect.h) then
                            pl_apply_theme(PLAYLOG_THEMES[i])
                            break
                        end
                    end
                end
            end
        end
    elseif button == 2 then
        if pl_point_in_rect(x, y, layout.button_x, layout.button_y, layout.button_w, layout.button_h) then
            G.FUNCS.playlog_open_log(nil)
        end
    end
    playlog_mousepressed_ref(x, y, button, istouch, presses)
end

if not love.wheelmoved then
    function love.wheelmoved(x, y) end
end

if not love.mousemoved then
    function love.mousemoved(x, y, dx, dy) end
end

if not love.mousereleased then
    function love.mousereleased(x, y, button) end
end

local playlog_mousemoved_ref = love.mousemoved
function love.mousemoved(x, y, dx, dy)
    if pl_is_run_active() then
        local pk = G.playlog_picker
        if pk and pk._dragging then
            pk.hex_focus = false
            pk.hex_input = nil
            if pk._dragging == 'sv' and pk._sq_rect then
                pk.s = pl_clamp((x - pk._sq_rect.x) / pk._sq_rect.w, 0, 1)
                pk.v = 1 - pl_clamp((y - pk._sq_rect.y) / pk._sq_rect.h, 0, 1)
                pl_picker_apply()
            elseif pk._dragging == 'hue' and pk._hbar_rect then
                pk.h = pl_clamp((x - pk._hbar_rect.x) / pk._hbar_rect.w, 0, 1) * 360
                pl_picker_apply()
            end
        end
    end
    return playlog_mousemoved_ref(x, y, dx, dy)
end

local playlog_mousereleased_ref = love.mousereleased
function love.mousereleased(x, y, button)
    if pl_is_run_active() and G.playlog_picker then
        G.playlog_picker._dragging = nil
    end
    return playlog_mousereleased_ref(x, y, button)
end

local playlog_wheelmoved_ref = love.wheelmoved
function love.wheelmoved(x, y)
    if not pl_is_run_active() then
        return playlog_wheelmoved_ref(x, y)
    end
    local mx, my = love.mouse.getPosition()
    local layout = pl_get_layout()
    if G.playlog_visible and pl_point_in_rect(mx, my, layout.panel_x, layout.panel_y, layout.panel_w, layout.panel_h) then
        local max_shift = pl_get_max_shift()
        if max_shift > 0 then
            local step = 2
            G.playlog_scroll_shift = pl_clamp((G.playlog_scroll_shift or 0) - y * step, 0, max_shift)
        end
    end
    playlog_wheelmoved_ref(x, y)
end
