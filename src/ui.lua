-- UI (hi its love2d edition)
local PLAYLOG_ROWS_PER_FRAME = 20
local PLAYLOG_ROW_HEIGHT = 22
local PLAYLOG_TOGGLE_KEY = 'f8'
local PLAYLOG_SCALE = 0.75
local PLAYLOG_SLIDE_SPEED = 10
local pl_tooltip_card = nil
local playlog_mousemoved_ref = nil
local pl_cursor_cache = {}
local pl_cursor_current = nil
local pl_log_store = PlayLog.log_store
local pl_raw_mouse_pos = love.mouse.getPosition
love.mouse.getPosition = function()
    local rx, ry = pl_raw_mouse_pos()
    if G and not G.OVERLAY_MENU and (G.playlog_slide or 0) > 0.2 and G.playlog_panel_rect then
        local r = G.playlog_panel_rect
        if rx >= r.x and rx <= r.x + r.w and ry >= r.y and ry <= r.y + r.h then
            return -1, -1
        end
    end
    return rx, ry
end

local function pl_set_cursor(cursor_name)
    if pl_cursor_current == cursor_name then return end
    if cursor_name then
        if not pl_cursor_cache[cursor_name] then
            pl_cursor_cache[cursor_name] = love.mouse.getSystemCursor(cursor_name)
        end
        love.mouse.setCursor(pl_cursor_cache[cursor_name])
    else
        love.mouse.setCursor()
    end
    pl_cursor_current = cursor_name
end

local function pl_is_run_active()
    return G and G.STAGE and G.STAGES and G.STAGE == G.STAGES.RUN
end

local function pl_clamp(value, minv, maxv)
    if value < minv then return minv end
    if value > maxv then return maxv end
    return value
end

local function pl_get_slide_side()
    local side = PlayLog.config and PlayLog.config.panel_slide_side or nil
    if side == 'left' or side == 'right' or side == 'top' or side == 'bottom' then
        return side
    end
    return 'right'
end

local function pl_get_nearest_slide_side(panel_x, panel_y, panel_w, panel_h, screen_w, screen_h)
    local left_dist = panel_x
    local right_dist = screen_w - (panel_x + panel_w)
    local top_dist = panel_y
    local bottom_dist = screen_h - (panel_y + panel_h)
    local nearest_side = 'left'
    local nearest_dist = left_dist
    if right_dist < nearest_dist then
        nearest_side = 'right'
        nearest_dist = right_dist
    end
    if top_dist < nearest_dist then
        nearest_side = 'top'
        nearest_dist = top_dist
    end
    if bottom_dist < nearest_dist then
        nearest_side = 'bottom'
    end
    return nearest_side
end

local function pl_get_default_open_panel_pos(sw, sh, panel_w, panel_h)
    local x = sw - panel_w - 18
    local y = math.max(10, math.floor(sh * 0.22))
    x = pl_clamp(x, 0, sw - panel_w)
    y = pl_clamp(y, 0, sh - panel_h)
    return x, y
end

local function pl_plain_from_segments(segments)
    return pl_log_store.plain_from_segments(segments)
end

local function pl_restore_log_from_file()
    return pl_log_store.restore_from_game()
end

local function pl_append_rich_segments_to_file(segments)
    return pl_log_store.append_rich_segments(segments)
end

local function pl_ensure_log_file_initialized()
    return pl_log_store.ensure_log_file_initialized()
end

local function pl_copy_log_to_clipboard()
    local lines = G.playlog_plain_entries or {}
    local text = table.concat(lines, "\n")
    text = text .. "\n\n" .. getDebugInfoForCrash()
    if love and love.system and love.system.setClipboardText then
        love.system.setClipboardText(text)
        G.playlog_copy_feedback_t = 1.2
        return true
    end
    return false
end

local function pl_snap_panel_height(panel_h, min_h, max_h)
    local chrome_h = 54
    local rows = math.max(1, math.floor(((panel_h - chrome_h) / PLAYLOG_ROW_HEIGHT) + 0.5))
    return pl_clamp(rows * PLAYLOG_ROW_HEIGHT + chrome_h, min_h, max_h)
end

local function pl_get_func_payload(func_ref)
    if type(func_ref) ~= 'string' or func_ref == '' then return nil, nil end
    local base_name, payload_id = func_ref:match('^([^@]+)@(.+)$')
    if not base_name then
        return func_ref, nil
    end
    local payloads = G and G.GAME and G.GAME.playlog_func_payloads
    local payload = payloads and payloads[payload_id] or nil
    return base_name, payload
end

local function pl_get_render_segment_text(seg)
    if type(seg) ~= 'table' then return tostring(seg or '') end
    local seg_text = tostring(seg.text or '')
    local func_name, payload = pl_get_func_payload(seg.func)
    if func_name ~= 'playlog_time' then
        return seg_text
    end
    local entry_time = type(payload) == 'table' and tonumber(payload.entry_time) or nil
    if not entry_time then
        return seg_text
    end
    local formats = PlayLog.CLOCK_FORMATS or {}
    if #formats < 1 then
        return seg_text
    end
    local idx = math.floor(tonumber(PlayLog.config and PlayLog.config.time_format_index) or 4)
    if idx < 1 or idx > #formats then
        idx = math.min(4, #formats)
    end
    local selected = formats[idx] or formats[1]
    if not selected then
        return seg_text
    end
    return PlayLog.get_formatted_time({
        time = entry_time,
        format_string = selected.format_string,
        no_leading_zero = selected.no_leading_zero,
    })
end

local function pl_get_card_snapshot_payload(tooltip_key)
    if not PlayLog.get_card_tooltip_payload then return nil end
    return PlayLog.get_card_tooltip_payload(tooltip_key)
end

local function pl_get_card_front_from_snapshot(snapshot)
    if type(snapshot) ~= 'table' or not G or not G.P_CARDS then return nil end
    if snapshot.front_key and G.P_CARDS[snapshot.front_key] then
        return G.P_CARDS[snapshot.front_key]
    end
    local snapshot_suit = tostring(snapshot.suit or '')
    local snapshot_value = tostring(snapshot.value or '')
    local snapshot_id = tonumber(snapshot.id)
    for _, front in pairs(G.P_CARDS) do
        if type(front) == 'table' then
            local front_suit = tostring(front.suit or front.suit_nominal or '')
            local front_value = tostring(front.value or front.rank or '')
            local front_id = tonumber(front.id or front.nominal)
            if snapshot_suit ~= '' and snapshot_value ~= '' and front_suit == snapshot_suit and front_value == snapshot_value then
                return front
            end
            if snapshot_suit ~= '' and snapshot_id and front_suit == snapshot_suit and front_id == snapshot_id then
                return front
            end
        end
    end
    return nil
end

local function pl_build_snapshot_display_card(snapshot)
    if type(snapshot) ~= 'table' or not G or not G.P_CENTERS then return nil end
    local center = G.P_CENTERS[snapshot.center_key or 'c_base'] or G.P_CENTERS.c_base
    if not center then return nil end
    local front = pl_get_card_front_from_snapshot(snapshot)
    local ok, display_card = pcall(Card, 0, 0, G.CARD_W / 1.2, G.CARD_H / 1.2, front, center)
    if not ok or not display_card then return nil end
    display_card.no_ui = true
    display_card.no_shadow = true
    display_card.playing_card = true
    display_card.base = display_card.base or {}
    if snapshot.suit then display_card.base.suit = snapshot.suit end
    if snapshot.value then display_card.base.value = snapshot.value end
    if snapshot.id then display_card.base.id = snapshot.id end
    if snapshot.edition_key and G.P_CENTERS[snapshot.edition_key] then
        pcall(function() display_card:set_edition(snapshot.edition_key, true, true) end)
    end
    if snapshot.seal_key and G.P_SEALS and G.P_SEALS[snapshot.seal_key] then
        pcall(function() display_card:set_seal(snapshot.seal_key, true, true) end)
    end
    return display_card, center
end

local function pl_draw_rich_segments(segments, x, y, max_x, mouse_x, mouse_y, line_step)
    if not segments then return nil, 1 end
    local draw_x = x
    local draw_y = y
    local step = line_step or PLAYLOG_ROW_HEIGHT
    local lines = 1
    local hovered_tooltip = nil
    local font = love.graphics.getFont()
    local scale = PLAYLOG_SCALE
    local function try_wrap(needed_w)
        if max_x and draw_x + needed_w > max_x and draw_x > x then
            draw_x = x
            draw_y = draw_y + step
            lines = lines + 1
        end
    end
    local function draw_text_chunk(seg_text, c, seg_tooltip, seg_scale, seg_bg, seg_underline, seg_strike, seg_func)
        local draw_scale = scale * (seg_scale or 1)
        local seg_h = font:getHeight() * draw_scale
        local words = {}
        for word in seg_text:gmatch("%S+") do words[#words + 1] = word end
        local space_w = font:getWidth(" ") * draw_scale

        if #words == 0 then
            draw_x = draw_x + font:getWidth(seg_text) * draw_scale
            return
        end

        local first_word = true
        for _, word in ipairs(words) do
            local prefix = (not first_word or seg_text:sub(1, 1) == " ") and " " or ""
            local token = prefix .. word
            local token_w = font:getWidth(token) * draw_scale
            try_wrap(token_w)
            if seg_bg then
                love.graphics.setColor(seg_bg[1] or 0, seg_bg[2] or 0, seg_bg[3] or 0, seg_bg[4] or 0.35)
                love.graphics.rectangle("fill", draw_x, draw_y, token_w, seg_h)
            end
            love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
            love.graphics.print(token, draw_x, draw_y, nil, draw_scale, draw_scale)
            if seg_underline then
                love.graphics.setColor(seg_underline[1] or 1, seg_underline[2] or 1, seg_underline[3] or 1,
                    seg_underline[4] or 1)
                love.graphics.rectangle("fill", draw_x, draw_y + seg_h - 2, token_w, 1)
            end
            if seg_strike then
                love.graphics.setColor(seg_strike[1] or 1, seg_strike[2] or 1, seg_strike[3] or 1, seg_strike[4] or 1)
                love.graphics.rectangle("fill", draw_x, draw_y + seg_h * 0.55, token_w, 1)
            end
            if (seg_tooltip or seg_func) and not G.OVERLAY_MENU then
                if mouse_x >= draw_x and mouse_x <= (draw_x + token_w)
                    and mouse_y >= draw_y and mouse_y <= (draw_y + seg_h) then
                    hovered_tooltip = {
                        key = seg_tooltip or ("__func:" .. tostring(seg_func or "unknown")),
                        func = seg_func,
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
    local def_r, def_g, def_b, def_a = pl_col('header_text', 0.88, 0.88, 0.88, 1)
    for i = 1, #segments do
        local seg = segments[i]
        local seg_text = pl_get_render_segment_text(seg)
        if seg_text ~= "" then
            local c = seg.colour or { def_r, def_g, def_b, def_a }
            local seg_scale = tonumber(seg.scale) or 1
            local start_idx = 1
            while true do
                local nl = seg_text:find("\n", start_idx, true)
                if not nl then
                    draw_text_chunk(
                        seg_text:sub(start_idx),
                        c,
                        seg.tooltip,
                        seg_scale,
                        seg.bg_colour,
                        seg.underline_colour,
                        seg.strikethrough_colour,
                        seg.func
                    )
                    break
                end

                draw_text_chunk(
                    seg_text:sub(start_idx, nl - 1),
                    c,
                    seg.tooltip,
                    seg_scale,
                    seg.bg_colour,
                    seg.underline_colour,
                    seg.strikethrough_colour,
                    seg.func
                )
                draw_x = x
                draw_y = draw_y + step
                lines = lines + 1
                start_idx = nl + 1
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

function PlayLog.create_tooltip_UIBox(nodes, func)
    local ret = {
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
                nodes = nodes
            },
        }
    }
    if func and PlayLog.FUNCS and PlayLog.FUNCS[func] then
        ret = PlayLog.FUNCS[func](ret)
    end
    return ret
end

local function pl_build_func_tooltip_definition(hovered)
    if not hovered or not hovered.func then return nil end
    local function_name = tostring(hovered.func or "")
    if function_name == "" then return nil end
    local callback_payload = hovered.func_payload
    if callback_payload == nil then
        local base_name, payload_id = function_name:match('^([^@]+)@(.+)$')
        if base_name and payload_id then
            function_name = base_name
            local raw = G and G.GAME and G.GAME.playlog_func_payloads and G.GAME.playlog_func_payloads[payload_id]
            if raw ~= nil then
                callback_payload = copy_table and copy_table(raw) or raw
            end
        end
    end
    local callback = PlayLog.FUNCS and PlayLog.FUNCS[function_name]
    local callback_result = nil
    if type(callback) == 'function' then
        local ok, res = pcall(callback, callback_payload, hovered)
        if ok then callback_result = res end
    end
    if type(callback_result) == 'table' and callback_result.definition then
        return callback_result.definition
    end
    if callback_result and type(callback_result) ~= 'string' and type(callback_result) ~= 'table' then
        callback_result = tostring(callback_result)
    end
    if type(callback_result) == 'string' then
        callback_result = { text = callback_result }
    end
    local is_table = type(callback_result) == 'table'
    local show_title = not (is_table and callback_result.title == false)
    local title_text = show_title and tostring((is_table and callback_result.title) or function_name) or nil
    local title_colour = (is_table and callback_result.title_colour) or G.C.WHITE
    local title_scale = tonumber(is_table and callback_result.title_scale) or 0.52
    local title_rows = show_title and {
        {
            {
                n = G.UIT.T,
                config = {
                    text = title_text,
                    scale = title_scale,
                    colour = title_colour,
                    shadow = (callback_result and callback_result.title_shadow ~= false) or (not callback_result) or true,
                    align = 'cm',
                }
            }
        }
    } or nil
    local body_rows = {}
    local bg_colour = nil
    if is_table and type(callback_result.text) == 'string' then
        local txt_scale = tonumber(callback_result.scale) or 0.44
        local txt_colour = callback_result.colour or G.C.UI.TEXT_DARK
        bg_colour = callback_result.background_colour or callback_result.bg_colour
        local txt_shadow = callback_result.shadow ~= false
        local txt_node = {
            n = G.UIT.T,
            config = {
                text = callback_result.text,
                scale = txt_scale,
                colour = txt_colour,
                shadow = txt_shadow,
                align = 'cm',
            }
        }
        body_rows[#body_rows + 1] = { txt_node }
    elseif is_table and type(callback_result.rows) == 'table' then
        body_rows = callback_result.rows
    else
        body_rows[#body_rows + 1] = {
            {
                n = G.UIT.T,
                config = {
                    text = "No tooltip UI returned",
                    scale = 0.44,
                    colour = G.C.UI.TEXT_DARK,
                    shadow = true,
                    align = 'cm',
                }
            }
        }
    end
    if bg_colour then
        body_rows.background_colour = bg_colour
    end
    local body_node = desc_from_rows(body_rows)
    local card_nodes = {}
    if title_rows then card_nodes[#card_nodes + 1] = desc_from_rows(title_rows, true) end
    card_nodes[#card_nodes + 1] = body_node
    return PlayLog.create_tooltip_UIBox({
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
                            nodes = card_nodes
                        }
                    }
                }
            }
        }
    })
end

local function pl_get_card_badges(card)
    local badges_to_add = {}
    local card_set = card.ability.set or "None"
    if card_set == "Back" then return {} end
    if (card_set ~= 'Locked' and card_set ~= 'Undiscovered' and card_set ~= 'Default') or card.debuff then
        badges_to_add.card_type = card_set
    end
    if card.ability.set == 'Joker' and card.bypass_discovery_ui then
        badges_to_add.force_rarity = true
    end
    if card.edition then
        if card.edition.card_limit then
            badges_to_add[#badges_to_add + 1] = SMODS.Edition.get_card_limit_key(card)
        else
            badges_to_add[#badges_to_add + 1] = (card.edition.type == 'holo' and 'holographic' or card.edition.type)
        end
    end
    if card.seal then badges_to_add[#badges_to_add + 1] = string.lower(card.seal) .. '_seal' end
    if card.ability.eternal then badges_to_add[#badges_to_add + 1] = 'eternal' end
    if card.ability.perishable then
        badges_to_add[#badges_to_add + 1] = 'perishable'
    end
    if card.ability.rental then badges_to_add[#badges_to_add + 1] = 'rental' end
    if card.pinned then badges_to_add[#badges_to_add + 1] = 'pinned_left' end
    for k, v in ipairs(SMODS.Sticker.obj_buffer) do
        if card.ability[v] and not SMODS.Stickers[v].hide_badge then
            badges_to_add[#badges_to_add + 1] = v
        end
    end
    local debuffed = card.debuff
    local card_type_colour = get_type_colour(card.config.center or card.config, card)
    local card_type_text_colour = SMODS.get_card_type_text_colour(card_set, card.config.center or card.config, card)
    local card_type = localize('k_' .. string.lower(card_set))
    if card_set == 'Joker' or (badges_to_add and badges_to_add.force_rarity) then
        card_type = SMODS.Rarity:get_rarity_badge(card.config.center.rarity)
    end
    if card_set == 'Enhanced' then card_type = localize { type = 'name_text', key = card.config.center.key, set = 'Enhanced' } end
    card_type = (debuffed and card_set ~= 'Enhanced') and localize('k_debuffed') or card_type

    local badges = {}
    local obj = card.config.center
    if badges_to_add.card_type or badges_to_add.force_rarity then
        if obj and (obj.set_card_type_badge or obj.type and obj.type.set_card_type_badge) then
            if obj.type and type(obj.type.set_card_type_badge) == 'function' then
                obj.type:set_card_type_badge(obj, card, badges)
            end
            if type(obj.set_card_type_badge) == 'function' then
                obj:set_card_type_badge(card, badges)
            end
        else
            badges[#badges + 1] = create_badge(
                ((card.ability.name == 'Pluto' or card.ability.name == 'Ceres' or card.ability.name == 'Eris') and localize('k_dwarf_planet')) or
                (card.ability.name == 'Planet X' and localize('k_planet_q') or card_type), card_type_colour,
                card_type_text_colour, 1.2)
        end
    end
    if obj and obj.set_badges and type(obj.set_badges) == 'function' then
        obj:set_badges(card, badges)
    end
    if badges_to_add then
        for k, v in ipairs(badges_to_add) do
            if v:sub(v:len() - 14) == '_SMODS_INTERNAL' then
                if v:sub(1, 9) == 'negative_' then v = 'negative' else v = v:sub(1, v:find('_', v:find('_') + 1) - 1) end
            end
            badges[#badges + 1] = create_badge(localize(v, "labels"), get_badge_colour(v), SMODS.get_badge_text_colour(v))
        end
    end
    return badges
end

local function pl_draw_hover_tooltip(hovered)
    if not hovered or not (hovered.key or hovered.func) then
        pl_remove_tooltip_card()
        return
    end
    local is_func = hovered.func ~= nil and tostring(hovered.func) ~= ""
    local card_snapshot = not is_func and pl_get_card_snapshot_payload(hovered.key) or nil
    local snapshot_center = card_snapshot and G and G.P_CENTERS and G.P_CENTERS[card_snapshot.center_key or 'c_base'] or
        nil
    local center = G.P_CENTERS and
        ((is_func and (G.P_CENTERS.j_joker or G.P_CENTERS.c_base)) or G.P_CENTERS[hovered.key])
    if not center and snapshot_center then
        center = snapshot_center
    end
    local is_seal = false
    if not is_func and not center and G and G.P_SEALS then
        local seal = G.P_SEALS[hovered.key]
            or (SMODS and SMODS.Seal and G.P_SEALS[SMODS.Seal.badge_to_key[hovered.key] or ''])
        if seal then
            center = seal; is_seal = true
        end
    end
    local is_tag = false
    if not is_func and not center then
        local tag = G.P_TAGS[hovered.key]
        if tag then
            center = tag; is_tag = true
        end
    end
    local is_blind = false
    if not is_func and not center then
        local blind = G.P_BLINDS[hovered.key]
        if blind then
            center = blind; is_blind = true
        end
    end
    local is_stake = false
    if not is_func and not center then
        local stake = G.P_STAKES[hovered.key]
        if stake then
            center = stake; is_stake = true
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
    local tooltip_gap = math.max(5 * sy, (hovered.h or 0) * sy * 0.35)

    local function pl_get_tooltip_size()
        local tooltip_w = card_w
        local tooltip_h = card_h
        if pl_tooltip_card and pl_tooltip_card.children and pl_tooltip_card.children.playlog_box
            and pl_tooltip_card.children.playlog_box.T then
            local box_t = pl_tooltip_card.children.playlog_box.T
            tooltip_w = math.max(tooltip_w, tonumber(box_t.w) or tooltip_w)
            tooltip_h = math.max(tooltip_h, tonumber(box_t.h) or tooltip_h)
        end
        return tooltip_w, tooltip_h
    end

    local function pl_get_tooltip_pos()
        local tooltip_w, tooltip_h = pl_get_tooltip_size()
        local x = anchor_x - tooltip_w * 0.5
        local y = anchor_y + tooltip_gap
        local flipped = false

        if x < 0.08 then x = 0.08 end
        if x + tooltip_w > room_w - 0.08 then x = room_w - tooltip_w - 0.08 end

        if y + tooltip_h > room_h - 0.08 then
            y = (hovered.y * sy) - tooltip_h - tooltip_gap
            flipped = true
        end
        if y < 0.08 then y = 0.08 end
        return x, y, flipped
    end

    local function pl_apply_tooltip_position()
        local x, y, flipped = pl_get_tooltip_pos()
        local tooltip_w, _ = pl_get_tooltip_size()
        if pl_tooltip_card and pl_tooltip_card.T then
            pl_tooltip_card.T.x = x + tooltip_w * 0.5
            local y_offset = card_h * 0.5
            pl_tooltip_card.T.y = y + (flipped and -y_offset or y_offset)
        end
    end

    local x, y = pl_get_tooltip_pos()

    local card_center = (is_seal or is_blind or is_stake or is_tag or center.set == 'Edition')
        and (G.P_CENTERS.j_joker or G.P_CENTERS.c_base)
        or center
    local hover_identity = hovered.key or ("__func:" .. tostring(hovered.func or ""))
    if not pl_tooltip_card or pl_tooltip_card._pl_key ~= hover_identity then
        pl_remove_tooltip_card()
        pl_tooltip_card = Card(x + card_w / 2, y + card_h / 2, G.CARD_W * 0.55, G.CARD_H * 0.55, nil, card_center, nil)
        pl_tooltip_card._pl_key = hover_identity
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

    pl_apply_tooltip_position()
    pl_tooltip_card.T.r = 0

    pl_tooltip_card.states.hover.can = false
    if pl_tooltip_card.children and pl_tooltip_card.children.info then
        if pl_tooltip_card.children.info.remove then
            pcall(function() pl_tooltip_card.children.info:remove() end)
        end
        pl_tooltip_card.children.info = nil
    end
    if not pl_tooltip_card.children.playlog_box then
        local display_card
        local tooltip_source_card = pl_tooltip_card
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
        PlayLog.no_info_queue = true
        local vars, main_start, main_end = pl_tooltip_card:generate_UIBox_ability_table(true)
        if is_tag then
            local tag = Tag(hovered.key)
            _, display_card = tag:generate_UI()
            vars = tag:get_uibox_table(nil, true)
        end
        if not display_card and card_snapshot then
            local snapshot_card, snapshot_card_center = pl_build_snapshot_display_card(card_snapshot)
            if snapshot_card then
                display_card = snapshot_card
                tooltip_source_card = snapshot_card
                center = snapshot_card_center or center
                target.key = center.key
                target.set = center.set
                vars, main_start, main_end = snapshot_card:generate_UIBox_ability_table(true)
            end
        end
        local ui_card = tooltip_source_card
        if ui_card == pl_tooltip_card and center.create_fake_card then
            ui_card = center:create_fake_card()
        end
        generate_card_ui(center, full_UI_table, vars,
            center.set or (is_seal and 'Seal'), {}, nil, main_start, main_end,
            ui_card)
        PlayLog.no_info_queue = nil

        if center.set == "Back" then
            local temp_back = Back(center)
            PlayLog.back_generate_ui = true
            description = temp_back:generate_UI()
            PlayLog.back_generate_ui = nil
        end

        if type(full_UI_table.name) == "string" then full_UI_table.name = nil end

        local no_name

        if card_snapshot and card_snapshot.suit and card_snapshot.value then
            if not card_snapshot.should_hide_front then
                local suit_key = tostring(card_snapshot.suit or '')
                local rank_text = localize(card_snapshot.value, 'ranks')
                local suit_text = localize(card_snapshot.suit, 'suits_plural')
                local full_name = PlayLog.localize('rank_of_suit', { rank_text, suit_text })
                local suit_colour = G and G.C and G.C.SUITS and G.C.SUITS[suit_key]
                full_UI_table.name = {
                    {
                        n = G.UIT.T,
                        config = {
                            text = full_name,
                            scale = 0.5,
                            colour = suit_colour or G.C.WHITE,
                            vert = false,
                        }
                    }
                }
            else
                no_name = true
            end
        end

        if not no_name and not full_UI_table.name or type(full_UI_table.name) ~= 'table' then
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

        local blind_name, blind_desc
        if is_blind then
            display_card = SMODS.create_sprite(0, 0, 1, 1, SMODS.get_atlas(center.atlas) or 'blind_chips', center.pos)
            local blind_ui = create_UIBox_blind_popup(center, true)
            blind_name = blind_ui.nodes[1]
            blind_desc = blind_ui.nodes[2]
        end

        if is_stake then
            display_card = SMODS.create_sprite(0, 0, 1, 1, SMODS.get_atlas(center.atlas), center.pos)
            description = {}
            localize { type = 'descriptions', key = center.key, set = center.set, nodes = description }
        end

        if not display_card and not is_func then
            display_card = Card(0, 0, G.CARD_W / 1.2, G.CARD_H / 1.2, nil, card_center)
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
        end

        local card_nodes
        if not is_func then
            card_nodes = {}
            if not no_name then
                card_nodes[#card_nodes + 1] = blind_name or
                    (type(full_UI_table.name) == 'table' and full_UI_table.name and {
                        n = G.UIT.R,
                        config = { align = "cm", padding = 0.07, r = 0.1, colour = G.C.CLEAR },
                        nodes = full_UI_table.name
                    } or nil) or desc_from_rows(name, true)
            end

            card_nodes[#card_nodes + 1] = blind_desc or desc_from_rows(description)

            if full_UI_table.joy_consumable then -- supporting my own mod :3
                table.insert(card_nodes, 2, desc_from_rows(full_UI_table.joy_consumable))
            end

            if full_UI_table.multi_box then
                for i, box in ipairs(full_UI_table.multi_box) do
                    box.background_colour = box.background_colour or
                        full_UI_table.box_colours and full_UI_table.box_colours[i + 1] or nil
                    if full_UI_table.box_starts and full_UI_table.box_starts[i] then
                        table.insert(box, 1, full_UI_table.box_starts[i])
                    end
                    if full_UI_table.box_ends and full_UI_table.box_ends[i] then
                        table.insert(box,
                            full_UI_table.box_ends[i])
                    end
                    table.insert(card_nodes, desc_from_rows(box))
                end
            end


            local badges = (display_card.ability or {}).set and pl_get_card_badges(display_card) or {}
            SMODS.create_mod_badges(center, badges)
            if display_card.base then
                SMODS.create_mod_badges(SMODS.Ranks[display_card.base.value], badges)
                SMODS.create_mod_badges(SMODS.Suits[display_card.base.suit], badges)
            end
            if display_card.config and display_card.config.tag then
                SMODS.create_mod_badges(SMODS.Tags[display_card.config.tag.key], badges)
            end

            if badges[1] then
                table.insert(card_nodes, {
                    n = G.UIT.R,
                    config = { align = "cm", padding = 0.03 },
                    nodes = badges
                })
            end
            badges.mod_set = nil
        end

        local func_definition = nil
        if is_func then
            func_definition = pl_build_func_tooltip_definition(hovered)
        end

        pl_tooltip_card.children.playlog_box = UIBox {
            definition = (is_func and func_definition) or PlayLog.create_tooltip_UIBox({
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
                                    nodes = card_nodes
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
            }, hovered.func),
            config = {
                align = "cm",
                offset = { x = 0, y = 0 },
                major = pl_tooltip_card,
                instance_type = "POPUP"
            }
        }
        pl_apply_tooltip_position()
    end

    if pl_tooltip_card.update then
        pl_tooltip_card:update(0)
    end
    pl_apply_tooltip_position()

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
    local min_w = 320
    local min_h = 220
    local max_w = math.max(min_w, sw - 20)
    local max_h = math.max(min_h, sh - 20)
    local panel_w = pl_clamp(tonumber(PlayLog.config.panel_w) or math.min(420, sw - 36), min_w, max_w)
    local raw_panel_h = pl_clamp(tonumber(PlayLog.config.panel_h) or math.min(420, math.floor(sh * 0.70)), min_h, max_h)
    local panel_h = pl_snap_panel_height(raw_panel_h, min_h, max_h)
    local slide = G.playlog_slide or 0
    local slide_side = pl_get_slide_side()
    local default_x, default_y = pl_get_default_open_panel_pos(sw, sh, panel_w, panel_h)
    local target_x = pl_clamp(default_x + (G.playlog_drag_dx or 0), 0, sw - panel_w)
    local target_y = pl_clamp(default_y + (G.playlog_drag_dy or 0), 0, sh - panel_h)
    local hidden_x = target_x
    local hidden_y = target_y
    if slide_side == 'left' then
        hidden_x = -panel_w - 20
    elseif slide_side == 'right' then
        hidden_x = sw + 20
    elseif slide_side == 'top' then
        hidden_y = -panel_h - 20
    elseif slide_side == 'bottom' then
        hidden_y = sh + 20
    end
    local panel_x = hidden_x + (target_x - hidden_x) * slide
    local panel_y = hidden_y + (target_y - hidden_y) * slide
    panel_x = pl_clamp(panel_x, -panel_w - 20, sw + 20)
    panel_y = pl_clamp(panel_y, -panel_h - 20, sh + 20)
    local header_h = 28
    local content_x = panel_x + 14
    local content_y = panel_y + header_h + 10
    local content_w = panel_w - 36
    local content_h = panel_h - header_h - 22
    local button_w = 36
    local button_h = 36
    local button_x = sw - button_w - 12
    local button_y = sh - button_h - 100
    local cfg_btn_w = 28
    local cfg_btn_h = 18
    local cfg_btn_x = panel_x + panel_w - 40
    local cfg_btn_y = panel_y + 5
    local copy_btn_w = 34
    local copy_btn_h = 18
    local copy_btn_x = cfg_btn_x - copy_btn_w - 4
    local copy_btn_y = cfg_btn_y
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
        cfg_btn_x = cfg_btn_x,
        cfg_btn_y = cfg_btn_y,
        cfg_btn_w = cfg_btn_w,
        cfg_btn_h = cfg_btn_h,
        copy_btn_x = copy_btn_x,
        copy_btn_y = copy_btn_y,
        copy_btn_w = copy_btn_w,
        copy_btn_h = copy_btn_h,
        resize_corner = 14,
        resize_edge = 6,
        resize_tl_x = panel_x,
        resize_tl_y = panel_y,
        resize_tr_x = panel_x + panel_w - 14,
        resize_tr_y = panel_y,
        resize_bl_x = panel_x,
        resize_bl_y = panel_y + panel_h - 14,
        resize_br_x = panel_x + panel_w - 14,
        resize_br_y = panel_y + panel_h - 14,
        resize_l_x = panel_x,
        resize_l_y = panel_y + 14,
        resize_l_w = 6,
        resize_l_h = math.max(10, panel_h - 28),
        resize_r_x = panel_x + panel_w - 6,
        resize_r_y = panel_y + 14,
        resize_r_w = 6,
        resize_r_h = math.max(10, panel_h - 28),
        resize_t_x = panel_x + 14,
        resize_t_y = panel_y,
        resize_t_w = math.max(10, panel_w - 28),
        resize_t_h = 6,
        resize_b_x = panel_x + 14,
        resize_b_y = panel_y + panel_h - 6,
        resize_b_w = math.max(10, panel_w - 28),
        resize_b_h = 6,
    }
end

local function pl_get_visible_rows(layout)
    layout = layout or pl_get_layout()
    return math.max(1, math.floor((layout.content_h - 4) / PLAYLOG_ROW_HEIGHT))
end

local function pl_measure_rich_segments(segments, max_width)
    if not segments then return 1 end
    local font = love.graphics.getFont()
    local base_scale = PLAYLOG_SCALE
    local draw_x = 0
    local lines = 1

    local function try_wrap(needed_w)
        if max_width and draw_x + needed_w > max_width and draw_x > 0 then
            draw_x = 0
            lines = lines + 1
        end
    end

    local function measure_text_chunk(seg_text, seg_scale)
        local draw_scale = base_scale * (seg_scale or 1)
        local words = {}
        for word in seg_text:gmatch("%S+") do words[#words + 1] = word end
        local space_w = font:getWidth(" ") * draw_scale

        if #words == 0 then
            draw_x = draw_x + font:getWidth(seg_text) * draw_scale
            return
        end

        local first_word = true
        for _, word in ipairs(words) do
            local prefix = (not first_word or seg_text:sub(1, 1) == " ") and " " or ""
            local token = prefix .. word
            local token_w = font:getWidth(token) * draw_scale
            try_wrap(token_w)
            draw_x = draw_x + token_w
            first_word = false
        end
        if seg_text:sub(-1) == " " then
            draw_x = draw_x + space_w
        end
    end

    for i = 1, #segments do
        local seg = segments[i]
        local seg_text = pl_get_render_segment_text(seg)
        if seg_text ~= "" then
            local seg_scale = tonumber(seg.scale) or 1
            local start_idx = 1
            while true do
                local nl = seg_text:find("\n", start_idx, true)
                if not nl then
                    measure_text_chunk(seg_text:sub(start_idx), seg_scale)
                    break
                end
                measure_text_chunk(seg_text:sub(start_idx, nl - 1), seg_scale)
                draw_x = 0
                lines = lines + 1
                start_idx = nl + 1
            end
        end
    end

    return math.max(1, lines)
end

local function pl_get_entry_max_scale(entry)
    if not entry or not entry.segments then return 1 end
    local max_scale = 1
    for i = 1, #entry.segments do
        local seg = entry.segments[i]
        local s = tonumber(seg and seg.scale) or 1
        if s > max_scale then max_scale = s end
    end
    return max_scale
end

local function pl_get_entry_lines(entry, layout)
    if not entry then return 1 end
    local wrap_w = math.max(1, (layout and layout.content_w or 1) - 10)
    local fmt_idx = math.floor(tonumber(PlayLog.config and PlayLog.config.time_format_index) or 4)
    if entry._pl_line_w ~= wrap_w or entry._pl_time_fmt_idx ~= fmt_idx then
        entry._pl_line_w = wrap_w
        entry._pl_time_fmt_idx = fmt_idx
        entry._pl_lines = pl_measure_rich_segments(entry.segments, wrap_w)
    end
    return entry._pl_lines or 1
end

local function pl_get_entry_units(entry, layout)
    local lines = pl_get_entry_lines(entry, layout)
    local max_scale = pl_get_entry_max_scale(entry)
    return math.max(1, lines * max_scale)
end

local function pl_get_total_lines(layout)
    local total_lines = 0
    local entries = (G and G.playlog_entries) or {}
    for i = 1, #entries do
        total_lines = total_lines + pl_get_entry_units(entries[i], layout)
    end
    return math.max(1, total_lines)
end

local function pl_get_max_shift(layout)
    return math.max(pl_get_total_lines(layout) - pl_get_visible_rows(layout), 0)
end

local function pl_get_time_format_index()
    local formats = PlayLog.CLOCK_FORMATS or {}
    if #formats == 0 then return 1 end
    local idx = math.floor(tonumber(PlayLog.config and PlayLog.config.time_format_index) or 4)
    if idx < 1 or idx > #formats then
        idx = math.min(4, #formats)
    end
    return idx
end

local function pl_cycle_time_format(delta)
    local formats = PlayLog.CLOCK_FORMATS or {}
    if #formats == 0 then return end
    local idx = pl_get_time_format_index()
    idx = ((idx - 1 + (delta or 1)) % #formats) + 1
    PlayLog.config.time_format_index = idx
    pl_save_config()
end

local function pl_get_display_time_for_entry(entry_time)
    local formats = PlayLog.CLOCK_FORMATS or {}
    local selected = formats[pl_get_time_format_index()] or formats[1]
    if not selected then
        return PlayLog.get_formatted_time({ time = entry_time, format_string = '%I:%M:%S %p', no_leading_zero = true })
    end
    return PlayLog.get_formatted_time({
        time = entry_time,
        format_string = selected.format_string,
        no_leading_zero = selected.no_leading_zero,
    })
end

local function pl_get_full_date_for_entry(entry_time)
    return PlayLog.get_formatted_time({ time = entry_time, format_string = '%Y/%m/%d %H:%M:%S' })
end

function pl_enqueue_rich_log(raw_body)
    G.playlog_pending_entries = G.playlog_pending_entries or {}
    G.playlog_plain_entries = G.playlog_plain_entries or {}
    local entry_time = os.time()
    local time_text = pl_get_display_time_for_entry(entry_time)
    local full_time_text = pl_get_full_date_for_entry(entry_time)
    local time_payload_ref = PlayLog.store_func_payload('playlog_time', {
        full_date = full_time_text,
        entry_time = entry_time,
    }) or 'playlog_time'
    local message_text = raw_body
    local loc_vars = nil
    if type(raw_body) == 'table' then
        message_text = raw_body.text or raw_body.message or raw_body.raw_text or ""
        loc_vars = raw_body.loc_vars or raw_body.vars
    end
    local raw_text = "{F:" ..
        tostring(time_payload_ref) .. ",C:inactive}" .. time_text .. "{} " .. tostring(message_text or "")
    local segments = PlayLog.parse_text(raw_text, loc_vars)
    local plain_line = pl_plain_from_segments(segments)
    G.playlog_plain_entries[#G.playlog_plain_entries + 1] = plain_line
    pl_append_rich_segments_to_file(segments)

    G.playlog_pending_entries[#G.playlog_pending_entries + 1] = {
        segments = segments
    }
end

PlayLog.log_event = function(raw_body, loc_vars)
    if loc_vars and type(raw_body) ~= 'table' then
        raw_body = { text = raw_body, loc_vars = loc_vars }
    end
    pl_enqueue_rich_log(raw_body)
end

local function pl_autofollow_tail_on_add(added_units, layout)
    if added_units <= 0 or not G.playlog_scroll_shift then return end
    if G.playlog_scroll_shift > 0 then
        G.playlog_scroll_shift = G.playlog_scroll_shift + added_units
    end
    G.playlog_scroll_shift = pl_clamp(G.playlog_scroll_shift, 0, pl_get_max_shift(layout))
end

local function pl_flush_queue(max_rows)
    local queue = G.playlog_pending_entries
    if not queue then return 0 end
    local start_idx = G.playlog_pending_start or 1
    local last_idx = #queue
    if start_idx > last_idx then return 0 end
    local end_idx = math.min(start_idx + max_rows - 1, last_idx)
    local added = 0
    local added_units = 0
    local layout = pl_get_layout()
    for i = start_idx, end_idx do
        local entry = queue[i]
        if entry then
            G.playlog_entries[#G.playlog_entries + 1] = entry
            added = added + 1
            added_units = added_units + pl_get_entry_units(entry, layout)
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
    pl_autofollow_tail_on_add(added_units, layout)
    return added
end

local function pl_draw_config_content(layout)
    local cx     = layout.content_x
    local cy_raw = layout.content_y
    local cw     = layout.content_w
    local ch     = layout.content_h
    local btn_w  = math.floor((cw - 10) / 2)
    local btn_h  = 40
    local gap    = 6
    local mx, my = pl_raw_mouse_pos()
    local total_cfg_h = 26 + math.ceil(#PLAYLOG_THEMES / 2) * (btn_h + gap)
        + (6 + 30) + (6 + 30) + (6 + 30) + (6 + 30)
        + (8 + 18)
        + #pl_hex_fields * (28 + 5)
    local max_cfg_scroll = math.max(0, total_cfg_h - ch)
    G.playlog_cfg_scroll     = pl_clamp(G.playlog_cfg_scroll or 0, 0, max_cfg_scroll)
    G.playlog_cfg_scroll_max = max_cfg_scroll
    G.playlog_cfg_content_rect = { x = cx, y = cy_raw, w = cw, h = ch }
    local scroll = G.playlog_cfg_scroll
    local cy = cy_raw - scroll
    love.graphics.setColor(pl_col('header_text', 0.95, 0.73, 0.25, 1))
    love.graphics.print(PlayLog.localize("select_theme", nil, "playlog_ui"), cx, cy + 4, nil, 0.80, 0.80)
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
        love.graphics.print(PlayLog.localize(theme.name, nil, "playlog_themes"), bx + 8, by + 15, nil, 0.82, 0.82)
        if active then
            love.graphics.setColor(b[1], b[2], b[3], 0.9)
            love.graphics.circle("fill", bx + btn_w - 10, by + btn_h - 10, 4)
        end
    end
    local time_cfg_y = cy + 26 + math.ceil(#PLAYLOG_THEMES / 2) * (btn_h + gap) + 8
    local time_btn_w = cw
    local time_btn_h = 30
    local time_btn_hov = pl_point_in_rect(mx, my, cx, time_cfg_y, time_btn_w, time_btn_h)
    local selected_idx = pl_get_time_format_index()
    local selected_fmt = (PlayLog.CLOCK_FORMATS and PlayLog.CLOCK_FORMATS[selected_idx]) or nil
    local sample_text = selected_fmt and PlayLog.get_formatted_time(selected_fmt) or "--:--"
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", cx, time_cfg_y, time_btn_w, time_btn_h, 4, 4)
    local br1, br2, br3 = pl_col('border', 0.95, 0.73, 0.25, 1)
    love.graphics.setColor(br1, br2, br3, time_btn_hov and 0.75 or 0.35)
    love.graphics.rectangle("line", cx, time_cfg_y, time_btn_w, time_btn_h, 4, 4)
    love.graphics.setColor(0.65, 0.65, 0.65, 1)
    love.graphics.print(PlayLog.localize("time_format", nil, "playlog_ui"), cx + 8, time_cfg_y + 2, nil, 0.62, 0.62)
    love.graphics.setColor(1, 1, 1, 0.82)
    love.graphics.print("< " .. sample_text .. " >", cx + 8, time_cfg_y + 13, nil, 0.72, 0.72)
    G.playlog_time_format_rect = { x = cx, y = time_cfg_y, w = time_btn_w, h = time_btn_h }
    local alpha_cfg_y = time_cfg_y + time_btn_h + 6
    local alpha_btn_w = cw
    local alpha_btn_h = 30
    local alpha_hov = pl_point_in_rect(mx, my, cx, alpha_cfg_y, alpha_btn_w, alpha_btn_h)
    local panel_bg = PlayLog.config.panel_bg or { 0.10, 0.10, 0.17, 0.97 }
    local panel_alpha = pl_clamp(tonumber(panel_bg[4]) or 0.97, 0.20, 1)
    local alpha_ratio = (panel_alpha - 0.20) / 0.80
    local alpha_percent = math.floor(panel_alpha * 100 + 0.5)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", cx, alpha_cfg_y, alpha_btn_w, alpha_btn_h, 4, 4)
    love.graphics.setColor(br1, br2, br3, alpha_hov and 0.75 or 0.35)
    love.graphics.rectangle("line", cx, alpha_cfg_y, alpha_btn_w, alpha_btn_h, 4, 4)
    love.graphics.setColor(0.65, 0.65, 0.65, 1)
    love.graphics.print(PlayLog.localize("log_opacity", nil, "playlog_ui"), cx + 8, alpha_cfg_y + 2, nil, 0.62, 0.62)
    love.graphics.setColor(1, 1, 1, 0.82)
    love.graphics.print(tostring(alpha_percent) .. "%", cx + alpha_btn_w - 44, alpha_cfg_y + 2, nil, 0.62, 0.62)
    local alpha_bar_x = cx + 8
    local alpha_bar_y = alpha_cfg_y + 16
    local alpha_bar_w = alpha_btn_w - 16
    local alpha_bar_h = 8
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.rectangle("fill", alpha_bar_x, alpha_bar_y, alpha_bar_w, alpha_bar_h, 3, 3)
    love.graphics.setColor(br1, br2, br3, 0.85)
    love.graphics.rectangle("fill", alpha_bar_x, alpha_bar_y, alpha_bar_w * alpha_ratio, alpha_bar_h, 3, 3)
    local knob_x = alpha_bar_x + alpha_bar_w * alpha_ratio
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", knob_x, alpha_bar_y + alpha_bar_h * 0.5, 5)
    G.playlog_alpha_rect = { x = alpha_bar_x, y = alpha_bar_y, w = alpha_bar_w, h = alpha_bar_h }

    local log_types_btn_y = alpha_cfg_y + alpha_btn_h + 6
    local log_types_btn_h = 30
    local log_types_hov = pl_point_in_rect(mx, my, cx, log_types_btn_y, cw, log_types_btn_h)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", cx, log_types_btn_y, cw, log_types_btn_h, 4, 4)
    love.graphics.setColor(br1, br2, br3, log_types_hov and 0.75 or 0.35)
    love.graphics.rectangle("line", cx, log_types_btn_y, cw, log_types_btn_h, 4, 4)
    love.graphics.setColor(0.65, 0.65, 0.65, 1)
    love.graphics.print(PlayLog.localize("log_types", nil, "playlog_ui"), cx + 8, log_types_btn_y + 2, nil, 0.62, 0.62)
    love.graphics.setColor(1, 1, 1, 0.82)
    love.graphics.print(PlayLog.localize("open_log_type_selection", nil, "playlog_ui"), cx + 8, log_types_btn_y + 13, nil,
        0.72, 0.72)
    G.playlog_log_types_btn_rect = { x = cx, y = log_types_btn_y, w = cw, h = log_types_btn_h }

    local shorten_btn_y = log_types_btn_y + log_types_btn_h + 6
    local shorten_btn_h = 30
    local shorten_hov = pl_point_in_rect(mx, my, cx, shorten_btn_y, cw, shorten_btn_h)
    local shorten_enabled = PlayLog.config.shorten_playing_cards and true or false
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", cx, shorten_btn_y, cw, shorten_btn_h, 4, 4)
    love.graphics.setColor(br1, br2, br3, shorten_hov and 0.75 or 0.35)
    love.graphics.rectangle("line", cx, shorten_btn_y, cw, shorten_btn_h, 4, 4)
    love.graphics.setColor(0.65, 0.65, 0.65, 1)
    love.graphics.print(PlayLog.localize("shorten_playing_cards", nil, "playlog_ui"), cx + 8, shorten_btn_y + 2, nil,
        0.62, 0.62)
    love.graphics.setColor(1, 1, 1, 0.82)
    love.graphics.print(shorten_enabled and PlayLog.localize("toggle_on", nil, "playlog_ui") or
        PlayLog.localize("toggle_off", nil, "playlog_ui"), cx + 8, shorten_btn_y + 13, nil, 0.72, 0.72)
    G.playlog_shorten_cards_rect = { x = cx, y = shorten_btn_y, w = cw, h = shorten_btn_h }

    --hex input section
    local rows = math.ceil(#PLAYLOG_THEMES / 2)
    local hex_y = shorten_btn_y + shorten_btn_h + 8
    love.graphics.setColor(pl_col('header_text', 0.95, 0.73, 0.25, 0.7))
    love.graphics.print(PlayLog.localize("custom_colours", nil, "playlog_ui"), cx, hex_y, nil, 0.68, 0.68)
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
        love.graphics.print(PlayLog.localize("colour_" .. field.key, nil, "playlog_ui"), cx + swatch_w + 8, fy + 2, nil,
            0.62, 0.62)
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
    if max_cfg_scroll > 0 then
        local sb_w = 4
        local sb_x = cx + cw - sb_w
        local sb_y = cy_raw
        local sb_h = ch
        love.graphics.setColor(1, 1, 1, 0.08)
        love.graphics.rectangle("fill", sb_x, sb_y, sb_w, sb_h, 2, 2)
        local ratio   = ch / math.max(total_cfg_h, 1)
        local knob_h  = math.max(16, sb_h * ratio)
        local t       = scroll / max_cfg_scroll
        local knob_y  = sb_y + (sb_h - knob_h) * t
        local sbr1, sbr2, sbr3 = pl_col('scrollbar_knob', 0.95, 0.73, 0.25, 1)
        love.graphics.setColor(sbr1, sbr2, sbr3, 0.85)
        love.graphics.rectangle("fill", sb_x, knob_y, sb_w, knob_h, 2, 2)
    end
end

local function pl_draw_button(layout)
    local mx, my = pl_raw_mouse_pos()
    local hovered = not G.OVERLAY_MENU and pl_point_in_rect(mx, my, layout.button_x, layout.button_y, layout.button_w, layout.button_h) 
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
    love.graphics.print(PlayLog.localize("log_button", nil, "playlog_ui"), layout.button_x + 4, layout.button_y + 10, nil,
        0.72, 0.72)
end

local function pl_draw_panel(layout)
    local slide = G.playlog_slide or 0
    if (not G.playlog_visible) and slide <= 0.001 then
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
    love.graphics.print(PlayLog.localize("header", nil, "playlog_ui"), layout.panel_x + 14, layout.panel_y + 7, nil, 0.82,
        0.82)
    --drag handle dots
    local hdr_cx = layout.panel_x + layout.panel_w * 0.5
    local hdr_cy = layout.panel_y + layout.header_h * 0.5
    local mx0, my0 = pl_raw_mouse_pos()
    local header_hov = pl_point_in_rect(mx0, my0, layout.panel_x, layout.panel_y, layout.panel_w, layout.header_h)
        and not pl_point_in_rect(mx0, my0, layout.cfg_btn_x, layout.cfg_btn_y, layout.cfg_btn_w, layout.cfg_btn_h)
        and not pl_point_in_rect(mx0, my0, layout.copy_btn_x, layout.copy_btn_y, layout.copy_btn_w, layout.copy_btn_h)
    local resize_tl_hov = pl_point_in_rect(mx0, my0, layout.resize_tl_x, layout.resize_tl_y, layout.resize_corner,
        layout.resize_corner)
    local resize_tr_hov = pl_point_in_rect(mx0, my0, layout.resize_tr_x, layout.resize_tr_y, layout.resize_corner,
        layout.resize_corner)
    local resize_bl_hov = pl_point_in_rect(mx0, my0, layout.resize_bl_x, layout.resize_bl_y, layout.resize_corner,
        layout.resize_corner)
    local resize_br_hov = pl_point_in_rect(mx0, my0, layout.resize_br_x, layout.resize_br_y, layout.resize_corner,
        layout.resize_corner)
    local resize_l_hov = pl_point_in_rect(mx0, my0, layout.resize_l_x, layout.resize_l_y, layout.resize_l_w,
        layout.resize_l_h)
    local resize_r_hov = pl_point_in_rect(mx0, my0, layout.resize_r_x, layout.resize_r_y, layout.resize_r_w,
        layout.resize_r_h)
    local resize_t_hov = pl_point_in_rect(mx0, my0, layout.resize_t_x, layout.resize_t_y, layout.resize_t_w,
        layout.resize_t_h)
    local resize_b_hov = pl_point_in_rect(mx0, my0, layout.resize_b_x, layout.resize_b_y, layout.resize_b_w,
        layout.resize_b_h)
    love.graphics.setColor(pl_col('header_text', 0.95, 0.73, 0.25, header_hov and 0.6 or 0.25))
    for _, dot in ipairs({ { -8, 0 }, { 0, 0 }, { 8, 0 } }) do
        love.graphics.circle("fill", hdr_cx + dot[1], hdr_cy, 2)
    end
    if not G.OVERLAY_MENU then
        if resize_tl_hov or resize_br_hov or G.playlog_resize_mode == 'tl' or G.playlog_resize_mode == 'br' then
            pl_set_cursor("sizenwse")
        elseif resize_tr_hov or resize_bl_hov or G.playlog_resize_mode == 'tr' or G.playlog_resize_mode == 'bl' then
            pl_set_cursor("sizenesw")
        elseif resize_l_hov or resize_r_hov or G.playlog_resize_mode == 'left' or G.playlog_resize_mode == 'right' then
            pl_set_cursor("sizewe")
        elseif resize_t_hov or resize_b_hov or G.playlog_resize_mode == 'top' or G.playlog_resize_mode == 'bottom' then
            pl_set_cursor("sizens")
        elseif header_hov or G.playlog_panel_dragging then
            pl_set_cursor("sizeall")
        else
            pl_set_cursor(nil)
        end
    else
        pl_set_cursor(nil)
    end
    local cfg_open = G.playlog_config_open
    local cfg_hov = pl_point_in_rect(mx0, my0, layout.cfg_btn_x, layout.cfg_btn_y, layout.cfg_btn_w, layout.cfg_btn_h)
    local copy_hov = pl_point_in_rect(mx0, my0, layout.copy_btn_x, layout.copy_btn_y, layout.copy_btn_w,
        layout.copy_btn_h)
    love.graphics.setColor(pl_col('border', 0.95, 0.73, 0.25, cfg_open and 0.9 or (cfg_hov and 0.7 or 0.35)))
    love.graphics.rectangle("fill", layout.cfg_btn_x, layout.cfg_btn_y, layout.cfg_btn_w, layout.cfg_btn_h, 4, 4)
    love.graphics.setColor(0, 0, 0, cfg_open and 0.8 or 0.6)
    love.graphics.print(PlayLog.localize(cfg_open and "log_button" or "config_button", nil, "playlog_ui"),
        layout.cfg_btn_x + 2, layout.cfg_btn_y + 2, nil, 0.70, 0.70)
    love.graphics.setColor(pl_col('border', 0.95, 0.73, 0.25, copy_hov and 0.8 or 0.45))
    love.graphics.rectangle("fill", layout.copy_btn_x, layout.copy_btn_y, layout.copy_btn_w, layout.copy_btn_h, 4, 4)
    love.graphics.setColor(0, 0, 0, 0.7)
    local copied = (G.playlog_copy_feedback_t or 0) > 0
    love.graphics.print(PlayLog.localize(copied and "copy_ok" or "copy", nil, "playlog_ui"), layout.copy_btn_x + 4,
        layout.copy_btn_y + 2, nil, 0.66, 0.66)
    if copied then
        love.graphics.setColor(pl_col('header_text', 0.95, 0.73, 0.25, 0.9))
        local copied_scale = 0.60
        local copied_text = PlayLog.localize("copied", nil, "playlog_ui")
        local font = love.graphics.getFont()
        local copied_w = font:getWidth(copied_text) * copied_scale
        local title_w = font:getWidth(PlayLog.localize("header", nil, "playlog_ui")) * 0.82
        local lane_pad = 8
        local dots_half_span = 18
        local left_min_x = layout.panel_x + 14 + title_w + lane_pad
        local left_max_x = hdr_cx - dots_half_span - copied_w
        local right_min_x = hdr_cx + dots_half_span
        local right_max_x = layout.copy_btn_x - copied_w - lane_pad
        local copied_x
        if right_max_x >= right_min_x then
            copied_x = right_min_x
        elseif left_max_x >= left_min_x then
            copied_x = left_max_x
        else
            local min_x = layout.panel_x + 14 + title_w + lane_pad
            local max_x = layout.copy_btn_x - copied_w - lane_pad
            copied_x = pl_clamp(hdr_cx - copied_w * 0.5, min_x, max_x)
        end
        love.graphics.print(copied_text, copied_x, layout.panel_y + 7, nil, copied_scale, copied_scale)
    end
    --resize handle (bottom-right)
    local br1, br2, br3 = pl_col('border', 0.95, 0.73, 0.25, 1)
    local resize_hov = resize_tl_hov or resize_tr_hov or resize_bl_hov or resize_br_hov
        or resize_l_hov or resize_r_hov or resize_t_hov or resize_b_hov
    love.graphics.setColor(br1, br2, br3, resize_hov and 0.9 or 0.45)
    local rx, ry = layout.resize_br_x, layout.resize_br_y
    love.graphics.setLineWidth(1)
    love.graphics.line(rx + 4, ry + 12, rx + 12, ry + 4)
    love.graphics.line(rx + 7, ry + 12, rx + 12, ry + 7)
    love.graphics.line(rx + 10, ry + 12, rx + 12, ry + 10)
    --content area: slide between log (left) and config (right)
    local cslide = G.playlog_config_slide or 0
    local cw = layout.content_w
    love.graphics.setScissor(layout.content_x, layout.content_y, layout.content_w, layout.content_h)
    local total_lines = pl_get_total_lines(layout)
    local visible_rows = pl_get_visible_rows(layout)
    local max_shift = pl_get_max_shift(layout)
    local shift = pl_clamp(G.playlog_scroll_shift or max_shift, 0, max_shift)
    G.playlog_scroll_shift = max_shift > 0 and shift or nil
    local mx, my = pl_raw_mouse_pos()
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
        local line_skip = shift
        for i = 1, #G.playlog_entries do
            local entry = G.playlog_entries[i]
            if entry then
                local lines_used = pl_get_entry_lines(entry, layout)
                local entry_scale = pl_get_entry_max_scale(entry)
                local entry_units = math.max(1, lines_used * entry_scale)
                local line_step = PLAYLOG_ROW_HEIGHT * entry_scale
                if line_skip >= entry_units then
                    line_skip = line_skip - entry_units
                    goto continue_log_entry
                elseif line_skip > 0 then
                    line_skip = 0
                end

                local block_h = lines_used * line_step
                if y + block_h > (layout.content_y + layout.content_h) then break end

                row_idx = row_idx + 1
                if row_idx % 2 == 0 then
                    love.graphics.setColor(1, 1, 1, 0.03)
                    love.graphics.rectangle("fill", layout.content_x - 6, y - 1, layout.content_w + 8, block_h)
                end
                --only do hover detection when fully settled
                local seg_mx = cslide == 0 and mx or -9999
                local maybe_hovered = pl_draw_rich_segments(entry.segments, layout.content_x, y,
                    layout.content_x + layout.content_w - 10, seg_mx, my, line_step)
                if maybe_hovered then hovered_tooltip = maybe_hovered end
                y = y + block_h
            end
            ::continue_log_entry::
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
        local ratio = visible_rows / math.max(total_lines, visible_rows)
        local knob_h = math.max(20, layout.scrollbar_h * ratio)
        local t = shift / max_shift
        local knob_y = layout.scrollbar_y + (layout.scrollbar_h - knob_h) * t
        love.graphics.setColor(pl_col('scrollbar_knob', 0.95, 0.73, 0.25, 0.85))
        love.graphics.rectangle("fill", layout.scrollbar_x, knob_y, layout.scrollbar_w, knob_h, 3, 3)
    end
end

local function pl_set_visible(is_visible)
    local next_visible = is_visible and true or false
    G.playlog_visible = next_visible
    if PlayLog.config.log_open ~= next_visible then
        PlayLog.config.log_open = next_visible
        pl_save_config()
    end
    if not G.playlog_visible then
        G.playlog_hovered_tooltip = nil
    end
end

--testing the funcs
PlayLog.FUNCS = PlayLog.FUNCS or {}
PlayLog.FUNCS['pl_test_string'] = function(payload, hovered)
    return "Plain string return — title defaults to func name"
end

PlayLog.FUNCS['pl_test_text_only'] = function(payload, hovered)
    return { text = "Table return with only .text set" }
end

PlayLog.FUNCS['pl_test_custom_title'] = function(payload, hovered)
    return { title = "Custom Title", text = "Body text here" }
end

PlayLog.FUNCS['pl_test_no_title'] = function(payload, hovered)
    return { title = false, text = "Title is hidden (title = false)" }
end

PlayLog.FUNCS['pl_test_title_colour'] = function(payload, hovered)
    return {
        title        = "Red Title",
        title_colour = G.C.RED,
        text         = "title_colour = G.C.RED",
    }
end

PlayLog.FUNCS['pl_test_title_scale'] = function(payload, hovered)
    return {
        title       = "Big Title",
        title_scale = 0.72,
        text        = "title_scale = 0.72",
    }
end

PlayLog.FUNCS['pl_test_body_colour'] = function(payload, hovered)
    return {
        text   = "Body text in green",
        colour = G.C.GREEN,
    }
end

PlayLog.FUNCS['pl_test_body_bg'] = function(payload, hovered)
    return {
        text      = "Body text with blue pill background",
        colour    = G.C.WHITE,
        bg_colour = G.C.BLUE,
    }
end

PlayLog.FUNCS['pl_test_body_scale'] = function(payload, hovered)
    return {
        text  = "Body at scale 0.62",
        scale = 0.62,
    }
end

PlayLog.FUNCS['pl_test_all_options'] = function(payload, hovered)
    return {
        title        = "All Options",
        title_colour = G.C.GOLD,
        title_scale  = 0.65,
        text         = "gold title, mult bg, white body, scale 0.55",
        colour       = G.C.WHITE,
        bg_colour    = G.C.MULT,
        scale        = 0.55,
    }
end

PlayLog.FUNCS['pl_test_rows'] = function(payload, hovered)
    return {
        title = "Rows Return",
        rows = {
            { { n = G.UIT.T, config = { text = "Row 1: chips", scale = 0.44, colour = G.C.CHIPS, shadow = true, align = 'cm' } } },
            { { n = G.UIT.T, config = { text = "Row 2: mult", scale = 0.10, colour = G.C.MULT, shadow = true, align = 'cm' } } },
            { { n = G.UIT.T, config = { text = "Row 3: money", scale = 0.80, colour = G.C.MONEY, shadow = true, align = 'cm' } } },
        }
    }
end

PlayLog.FUNCS['pl_test_payload'] = function(payload, hovered)
    if not payload then return { title = false, text = "no payload" } end
    return {
        title  = "Payload Demo",
        text   = "chips: " .. tostring(payload.chips) .. "  mult: " .. tostring(payload.mult),
        colour = G.C.CHIPS,
    }
end

PlayLog.FUNCS['pl_test_no_shadow'] = function()
    return {
        title = "No Shadow Test",
        title_shadow = false,
        shadow = false,
        text = "Both title and text have no shadow",
        colour = G.C.RED,
    }
end

G.FUNCS.playlog_open_log = function(e)
    --Editions
    pl_enqueue_rich_log("Card got {T:e_foil}Foil{} edition")
    pl_enqueue_rich_log("Card got {T:e_holo}Holographic{} edition")
    pl_enqueue_rich_log("Card got {T:e_polychrome}Polychrome{} edition")
    pl_enqueue_rich_log("Card got {T:e_negative}Negative{} edition")
    --Enhancements
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
    --Tarots
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
    --Planets
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
    --Spectrals
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
    --Jokers
    pl_enqueue_rich_log("{C:attention}{T:j_joker}Joker{} is in play")
    pl_enqueue_rich_log("{C:attention}{T:j_misprint}Misprint{} is in play")
    pl_enqueue_rich_log("{C:attention}{T:j_blueprint}Blueprint{} copying {T:j_joker}Joker{}")
    pl_enqueue_rich_log("{C:attention}{T:j_brainstorm}Brainstorm{} copying {T:j_blueprint}Blueprint{}")
    --Style tests
    pl_enqueue_rich_log("[STYLE] {C:attention,s:1.15}C + s in one block{}")
    pl_enqueue_rich_log(
        "[STYLE] scale ladder: {s:0.55}0.55{} {s:0.70}0.70{} {s:0.85}0.85{} {s:1.00}1.00{} {s:1.20}1.20{} {s:1.45}1.45{} {s:1.80}1.80{}")
    pl_enqueue_rich_log(
        "[STYLE] {s:0.60,C:inactive}tiny{} {s:1.00,C:white}normal{} {s:1.60,C:attention}LARGE{} {s:2.10,C:red}HUGE{}")
    pl_enqueue_rich_log("[STYLE] {C:green,u:green}underline{} + {C:red,st:red}strikethrough{}")
    pl_enqueue_rich_log("[STYLE] {X:mult,C:white} X 3 {} label with background")
    pl_enqueue_rich_log("[STYLE] chained: {C:tarot}{T:c_fool}C then T{} | combined: {C:tarot,T:c_fool}C+T{}")
    pl_enqueue_rich_log("[STYLE] multiline test:\n{C:blue}line 1{}\n{C:green}line 2{}\n{C:red}line 3{}")
    pl_enqueue_rich_log({
        text = "[STYLE] {V:1}V text{} {B:2,V:3}B+V combo{}",
        loc_vars = {
            vars = {
                colours = {
                    { 1.00, 0.40, 0.40, 1.00 },
                    { 1.00, 0.85, 0.10, 1.00 },
                    { 0.05, 0.05, 0.05, 1.00 },
                }
            }
        }
    })
    pl_enqueue_rich_log({
        text = "[STYLE] swap demo: {B:1,V:2}LEFT{} {B:2,V:1}RIGHT{}",
        loc_vars = {
            vars = {
                colours = {
                    { 0.15, 0.35, 1.00, 1.00 },
                    { 1.00, 0.30, 0.55, 1.00 },
                }
            }
        }
    })
    pl_enqueue_rich_log({
        text = "[STYLE] wiki vars: {B:1,V:2}#1#{B:2,V:1}#2#{}",
        loc_vars = {
            vars = {
                'Spa',
                'rts',
                colours = {
                    G.C.SUITS.Spades,
                    G.C.SUITS.Hearts,
                }
            }
        }
    })
    --more func-y tests
    pl_enqueue_rich_log("{F:pl_test_string}[FUNC string]{}")
    pl_enqueue_rich_log("{F:pl_test_text_only}[FUNC text only]{}")
    pl_enqueue_rich_log("{F:pl_test_custom_title}[FUNC custom title]{}")
    pl_enqueue_rich_log("{F:pl_test_no_title}[FUNC no title]{}")
    pl_enqueue_rich_log("{F:pl_test_title_colour}[FUNC title colour]{}")
    pl_enqueue_rich_log("{F:pl_test_title_scale}[FUNC title scale]{}")
    pl_enqueue_rich_log("{F:pl_test_body_colour}[FUNC body colour]{}")
    pl_enqueue_rich_log("{F:pl_test_body_bg}[FUNC body bg]{}")
    pl_enqueue_rich_log("{F:pl_test_body_scale}[FUNC body scale]{}")
    pl_enqueue_rich_log("{F:pl_test_no_shadow}[FUNC no shadow]{}")
    pl_enqueue_rich_log("{F:pl_test_all_options}[FUNC all options]{}")
    pl_enqueue_rich_log("{F:pl_test_rows}[FUNC rows]{}")
    local payload_ref = PlayLog.store_func_payload('pl_test_payload', { chips = 150, mult = 8 })
    if payload_ref then
        pl_enqueue_rich_log("{F:" .. payload_ref .. "}[FUNC payload]{}")
    end
end

local game_start_run_ref = Game.start_run
function Game:start_run(args)
    game_start_run_ref(self, args)
    pl_log_store.prepare_start_run()
    G.playlog_entries         = {}
    G.playlog_pending_entries = {}
    G.playlog_pending_start   = 1
    G.playlog_plain_entries   = {}
    G.playlog_visible         = PlayLog.config.log_open ~= false
    G.playlog_slide           = 0
    G.playlog_config_open     = false
    G.playlog_config_slide    = 0
    G.playlog_hex_active      = nil
    G.playlog_hex_input       = nil
    G.playlog_picker          = nil
    G.playlog_hovered_tooltip = nil
    G.playlog_copy_feedback_t = 0
    pl_restore_log_from_file()
    if G and G.GAME then
        G.GAME.playlog_log_initialized = nil
    end
    pl_ensure_log_file_initialized()
    pl_remove_tooltip_card()
end

local function pl_use_lang_font()
    local pl_font_key = G.SETTINGS.language
    if not PlayLog._cached_fonts then PlayLog._cached_fonts = {} end
    if not PlayLog._cached_fonts[pl_font_key] then
        local font_size = G.LANG.font.render_scale * G.LANG.font.FONTSCALE
        PlayLog._cached_fonts[pl_font_key] = love.graphics.newFont(G.LANG.font.file, font_size)
    end
    love.graphics.setFont(PlayLog._cached_fonts[pl_font_key])
end

local game_update_ref = Game.update
function Game:update(dt)
    local ret = game_update_ref(self, dt)
    if pl_is_run_active() then
        pl_use_lang_font()
        if (G.playlog_copy_feedback_t or 0) > 0 then
            G.playlog_copy_feedback_t = math.max(0, (G.playlog_copy_feedback_t or 0) - dt)
        end
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
    local prev_font = love.graphics.getFont()
    pl_use_lang_font()
    local layout = pl_get_layout()
    G.playlog_panel_rect = { x = layout.panel_x, y = layout.panel_y, w = layout.panel_w, h = layout.panel_h }
    if (G.playlog_slide or 0) > 0.01 then
        pl_draw_panel(layout)
    else
        pl_set_cursor(nil)
    end
    pl_draw_button(layout)
    local active_tooltip = G.playlog_hovered_tooltip
    if not active_tooltip then
        pl_remove_tooltip_card()
    end
    if (G.playlog_slide or 0) > 0.5 then
        pl_draw_hover_tooltip(active_tooltip)
    end
    love.graphics.setFont(prev_font)
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
        if G.playlog_picker and key == 'escape' then
            G.playlog_picker = nil
            return
        end
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
    if not pl_is_run_active() or G.OVERLAY_MENU then
        return playlog_mousepressed_ref(x, y, button, istouch, presses)
    end
    local layout = pl_get_layout()
    if button == 1 then
        if pl_point_in_rect(x, y, layout.button_x, layout.button_y, layout.button_w, layout.button_h) then
            pl_set_visible(not G.playlog_visible)
        elseif G.playlog_visible and (
                pl_point_in_rect(x, y, layout.resize_tl_x, layout.resize_tl_y, layout.resize_corner, layout.resize_corner)
                or pl_point_in_rect(x, y, layout.resize_tr_x, layout.resize_tr_y, layout.resize_corner, layout.resize_corner)
                or pl_point_in_rect(x, y, layout.resize_bl_x, layout.resize_bl_y, layout.resize_corner, layout.resize_corner)
                or pl_point_in_rect(x, y, layout.resize_br_x, layout.resize_br_y, layout.resize_corner, layout.resize_corner)
                or pl_point_in_rect(x, y, layout.resize_l_x, layout.resize_l_y, layout.resize_l_w, layout.resize_l_h)
                or pl_point_in_rect(x, y, layout.resize_r_x, layout.resize_r_y, layout.resize_r_w, layout.resize_r_h)
                or pl_point_in_rect(x, y, layout.resize_t_x, layout.resize_t_y, layout.resize_t_w, layout.resize_t_h)
                or pl_point_in_rect(x, y, layout.resize_b_x, layout.resize_b_y, layout.resize_b_w, layout.resize_b_h)
            ) then
            G.playlog_panel_resizing = true
            if pl_point_in_rect(x, y, layout.resize_tl_x, layout.resize_tl_y, layout.resize_corner, layout.resize_corner) then
                G.playlog_resize_mode = 'tl'
            elseif pl_point_in_rect(x, y, layout.resize_tr_x, layout.resize_tr_y, layout.resize_corner, layout.resize_corner) then
                G.playlog_resize_mode = 'tr'
            elseif pl_point_in_rect(x, y, layout.resize_bl_x, layout.resize_bl_y, layout.resize_corner, layout.resize_corner) then
                G.playlog_resize_mode = 'bl'
            elseif pl_point_in_rect(x, y, layout.resize_br_x, layout.resize_br_y, layout.resize_corner, layout.resize_corner) then
                G.playlog_resize_mode = 'br'
            elseif pl_point_in_rect(x, y, layout.resize_l_x, layout.resize_l_y, layout.resize_l_w, layout.resize_l_h) then
                G.playlog_resize_mode = 'left'
            elseif pl_point_in_rect(x, y, layout.resize_r_x, layout.resize_r_y, layout.resize_r_w, layout.resize_r_h) then
                G.playlog_resize_mode = 'right'
            elseif pl_point_in_rect(x, y, layout.resize_t_x, layout.resize_t_y, layout.resize_t_w, layout.resize_t_h) then
                G.playlog_resize_mode = 'top'
            else
                G.playlog_resize_mode = 'bottom'
            end
            G.playlog_resize_start_x = x
            G.playlog_resize_start_y = y
            G.playlog_resize_base_w = layout.panel_w
            G.playlog_resize_base_h = layout.panel_h
            G.playlog_resize_base_dx = G.playlog_drag_dx or 0
            G.playlog_resize_base_dy = G.playlog_drag_dy or 0
        elseif G.playlog_visible and pl_point_in_rect(x, y, layout.copy_btn_x, layout.copy_btn_y, layout.copy_btn_w, layout.copy_btn_h) then
            pl_copy_log_to_clipboard()
        elseif G.playlog_visible and pl_point_in_rect(x, y, layout.cfg_btn_x, layout.cfg_btn_y, layout.cfg_btn_w, layout.cfg_btn_h) then
            --CFG header button: toggles config panel, or closes picker back to list
            if G.playlog_picker then
                G.playlog_picker = nil
            else
                G.playlog_config_open = not G.playlog_config_open
            end
        elseif G.playlog_visible and pl_point_in_rect(x, y, layout.panel_x, layout.panel_y, layout.panel_w, layout.header_h) then
            --header drag: start dragging the panel
            G.playlog_panel_dragging = true
            G.playlog_drag_start_x   = x
            G.playlog_drag_start_y   = y
            G.playlog_drag_base_dx   = G.playlog_drag_dx or 0
            G.playlog_drag_base_dy   = G.playlog_drag_dy or 0
        elseif G.playlog_config_open then
            local pk = G.playlog_picker
            if pk then
                if pk.mode == 'log_types' then
                    if pk._back_rect and pl_point_in_rect(x, y, pk._back_rect.x, pk._back_rect.y, pk._back_rect.w, pk._back_rect.h) then
                        G.playlog_picker = nil
                    elseif pk._group_rects then
                        local group_handled = false
                        for _, rect in ipairs(pk._group_rects) do
                            if pl_point_in_rect(x, y, rect.x, rect.y, rect.w, rect.h) then
                                if PlayLog.toggle_log_type_group_enabled then
                                    PlayLog.toggle_log_type_group_enabled(rect.group)
                                end
                                group_handled = true
                                break
                            end
                        end
                        if group_handled then
                        elseif pk._type_rects then
                            for _, rect in ipairs(pk._type_rects) do
                                if pl_point_in_rect(x, y, rect.x, rect.y, rect.w, rect.h) then
                                    if PlayLog.toggle_log_type_enabled then
                                        PlayLog.toggle_log_type_enabled(rect.key)
                                    end
                                    break
                                end
                            end
                        end
                    elseif pk._type_rects then
                        for _, rect in ipairs(pk._type_rects) do
                            if pl_point_in_rect(x, y, rect.x, rect.y, rect.w, rect.h) then
                                if PlayLog.toggle_log_type_enabled then
                                    PlayLog.toggle_log_type_enabled(rect.key)
                                end
                                break
                            end
                        end
                    end
                else
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
                end
            else
                local handled_cfg_click = false
                if G.playlog_time_format_rect and pl_point_in_rect(x, y,
                        G.playlog_time_format_rect.x,
                        G.playlog_time_format_rect.y,
                        G.playlog_time_format_rect.w,
                        G.playlog_time_format_rect.h) then
                    pl_cycle_time_format(1)
                    handled_cfg_click = true
                end
                if (not handled_cfg_click) and G.playlog_alpha_rect and pl_point_in_rect(x, y,
                        G.playlog_alpha_rect.x,
                        G.playlog_alpha_rect.y,
                        G.playlog_alpha_rect.w,
                        G.playlog_alpha_rect.h) then
                    local ratio = pl_clamp((x - G.playlog_alpha_rect.x) / math.max(G.playlog_alpha_rect.w, 1), 0, 1)
                    PlayLog.config.panel_bg = PlayLog.config.panel_bg or { 0.10, 0.10, 0.17, 0.97 }
                    PlayLog.config.panel_bg[4] = 0.20 + ratio * 0.80
                    pl_save_config()
                    G.playlog_alpha_dragging = true
                    handled_cfg_click = true
                end
                if (not handled_cfg_click) and G.playlog_log_types_btn_rect and pl_point_in_rect(x, y,
                        G.playlog_log_types_btn_rect.x,
                        G.playlog_log_types_btn_rect.y,
                        G.playlog_log_types_btn_rect.w,
                        G.playlog_log_types_btn_rect.h) then
                    G.playlog_picker = { mode = 'log_types', scroll = 0 }
                    handled_cfg_click = true
                end
                if (not handled_cfg_click) and G.playlog_shorten_cards_rect and pl_point_in_rect(x, y,
                        G.playlog_shorten_cards_rect.x,
                        G.playlog_shorten_cards_rect.y,
                        G.playlog_shorten_cards_rect.w,
                        G.playlog_shorten_cards_rect.h) then
                    PlayLog.config.shorten_playing_cards = not (PlayLog.config.shorten_playing_cards and true or false)
                    pl_save_config()
                    handled_cfg_click = true
                end
                --swatch opens picker
                if (not handled_cfg_click) and G.playlog_hex_rects then
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
                --theme buttons
                if (not handled_cfg_click) and G.playlog_theme_rects then
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
        -- if pl_point_in_rect(x, y, layout.button_x, layout.button_y, layout.button_w, layout.button_h) then
        --     G.FUNCS.playlog_open_log(nil)
        -- end
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

playlog_mousemoved_ref = love.mousemoved
function love.mousemoved(x, y, dx, dy)
    if pl_is_run_active() and not G.OVERLAY_MENU then
        --panel resize
        if G.playlog_panel_resizing then
            local sw, sh = love.graphics.getDimensions()
            local min_w = 320
            local min_h = 220
            local max_w = math.max(min_w, sw - 20)
            local max_h = math.max(min_h, sh - 20)
            local mode = G.playlog_resize_mode or 'br'
            local dxm = x - (G.playlog_resize_start_x or x)
            local dym = y - (G.playlog_resize_start_y or y)
            local base_w = G.playlog_resize_base_w or 420
            local base_h = G.playlog_resize_base_h or 320
            local base_dx = G.playlog_resize_base_dx or 0
            local base_dy = G.playlog_resize_base_dy or 0
            local new_w = base_w
            local new_h = base_h
            local new_dx = base_dx
            local new_dy = base_dy
            if mode == 'right' or mode == 'tr' or mode == 'br' then
                new_w = pl_clamp(base_w + dxm, min_w, max_w)
                new_dx = base_dx + (new_w - base_w)
            elseif mode == 'left' or mode == 'tl' or mode == 'bl' then
                new_w = pl_clamp(base_w - dxm, min_w, max_w)
            end
            if mode == 'bottom' or mode == 'bl' or mode == 'br' then
                new_h = pl_snap_panel_height(base_h + dym, min_h, max_h)
            elseif mode == 'top' or mode == 'tl' or mode == 'tr' then
                new_h = pl_snap_panel_height(base_h - dym, min_h, max_h)
                new_dy = base_dy - (new_h - base_h)
            end
            PlayLog.config.panel_w = new_w
            PlayLog.config.panel_h = new_h
            G.playlog_drag_dx = new_dx
            G.playlog_drag_dy = new_dy
            G.playlog_resize_dirty = true
        end
        --panel drag
        if G.playlog_panel_dragging then
            G.playlog_drag_dx = G.playlog_drag_base_dx + (x - G.playlog_drag_start_x)
            G.playlog_drag_dy = G.playlog_drag_base_dy + (y - G.playlog_drag_start_y)
        end
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
        if G.playlog_alpha_dragging and G.playlog_alpha_rect then
            local ratio = pl_clamp((x - G.playlog_alpha_rect.x) / math.max(G.playlog_alpha_rect.w, 1), 0, 1)
            PlayLog.config.panel_bg = PlayLog.config.panel_bg or { 0.10, 0.10, 0.17, 0.97 }
            PlayLog.config.panel_bg[4] = 0.20 + ratio * 0.80
            G.playlog_alpha_dirty = true
        end
    end
    return playlog_mousemoved_ref(x, y, dx, dy)
end

local playlog_mousereleased_ref = love.mousereleased
function love.mousereleased(x, y, button)
    if pl_is_run_active() then
        local was_dragging = G.playlog_panel_dragging
        local was_resizing = G.playlog_panel_resizing
        if G.playlog_picker then
            G.playlog_picker._dragging = nil
        end
        local was_alpha_dragging = G.playlog_alpha_dragging
        G.playlog_panel_dragging = nil
        G.playlog_panel_resizing = nil
        G.playlog_alpha_dragging = nil
        G.playlog_resize_mode = nil
        if was_resizing and G.playlog_resize_dirty then
            pl_save_config()
            G.playlog_resize_dirty = nil
        end
        if was_dragging or was_resizing then
            local layout = pl_get_layout()
            local sw, sh = love.graphics.getDimensions()
            local nearest_side = pl_get_nearest_slide_side(layout.panel_x, layout.panel_y, layout.panel_w, layout.panel_h,
                sw, sh)
            if PlayLog.config.panel_slide_side ~= nearest_side then
                PlayLog.config.panel_slide_side = nearest_side
                pl_save_config()
            end
        end
        if was_alpha_dragging and G.playlog_alpha_dirty then
            pl_save_config()
            G.playlog_alpha_dirty = nil
        end
    end
    return playlog_mousereleased_ref(x, y, button)
end

local playlog_wheelmoved_ref = love.wheelmoved
function love.wheelmoved(x, y)
    if not pl_is_run_active() or G.OVERLAY_MENU then
        return playlog_wheelmoved_ref(x, y)
    end
    local mx, my = pl_raw_mouse_pos()
    local layout = pl_get_layout()
    local pk = G.playlog_picker
    if G.playlog_visible and pk and pk.mode == 'log_types' and pk._list_rect
        and pl_point_in_rect(mx, my, pk._list_rect.x, pk._list_rect.y, pk._list_rect.w, pk._list_rect.h) then
        local step = 20
        local max_scroll = tonumber(pk._scroll_max) or 0
        pk.scroll = pl_clamp((tonumber(pk.scroll) or 0) - y * step, 0, max_scroll)
        return playlog_wheelmoved_ref(x, y)
    end
    local cfg_slide = G.playlog_config_slide or 0
    if G.playlog_visible and cfg_slide > 0.5 and not pk
        and G.playlog_cfg_content_rect
        and pl_point_in_rect(mx, my, G.playlog_cfg_content_rect.x, G.playlog_cfg_content_rect.y,
            G.playlog_cfg_content_rect.w, G.playlog_cfg_content_rect.h) then
        local max_cfg = G.playlog_cfg_scroll_max or 0
        if max_cfg > 0 then
            G.playlog_cfg_scroll = pl_clamp((G.playlog_cfg_scroll or 0) - y * 20, 0, max_cfg)
        end
        return playlog_wheelmoved_ref(x, y)
    end
    if G.playlog_visible and pl_point_in_rect(mx, my, layout.panel_x, layout.panel_y, layout.panel_w, layout.panel_h) then
        local max_shift = pl_get_max_shift(layout)
        if max_shift > 0 then
            local step = 2
            G.playlog_scroll_shift = pl_clamp((G.playlog_scroll_shift or 0) - y * step, 0, max_shift)
        end
    end
    playlog_wheelmoved_ref(x, y)
end
