-- UI (hi its love2d edition)

local PLAYLOG_VISIBLE_ROWS = 16
local PLAYLOG_ROWS_PER_FRAME = 20
local PLAYLOG_ROW_HEIGHT = 20
local PLAYLOG_TOGGLE_KEY = 'f8'
local pl_tooltip_card = nil

local function pl_is_run_active()
    return G and G.STAGE and G.STAGES and G.STAGE == G.STAGES.RUN
end

local function pl_clamp(value, minv, maxv)
    if value < minv then return minv end
    if value > maxv then return maxv end
    return value
end

local function pl_draw_rich_segments(segments, x, y, mouse_x, mouse_y)
    if not segments then return nil end

    local draw_x = x
    local hovered_tooltip = nil
    local font = love.graphics.getFont()
    for i = 1, #segments do
        local seg = segments[i]
        local seg_text = seg.text or ""
        if seg_text ~= "" then
            local c = seg.colour or { 1, 1, 1, 1 }
            love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
            love.graphics.print(seg_text, draw_x, y, nil, 0.7, 0.7)
            if seg.tooltip then
                local seg_w = font:getWidth(seg_text) * 0.7
                local seg_h = font:getHeight() * 0.7
                if mouse_x >= draw_x and mouse_x <= (draw_x + seg_w) and mouse_y >= y and mouse_y <= (y + seg_h) then
                    hovered_tooltip = {
                        key = seg.tooltip,
                        x = draw_x,
                        y = y,
                        w = seg_w,
                        h = seg_h,
                    }
                    love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, 0.35)
                    love.graphics.rectangle("fill", draw_x, y + seg_h - 2, seg_w, 2)
                end
            end
            draw_x = draw_x + font:getWidth(seg_text) * 0.7
        end
    end

    return hovered_tooltip
end

local function pl_point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= (rx + rw) and py >= ry and py <= (ry + rh)
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

    if not pl_tooltip_card or not pl_tooltip_card.config or not pl_tooltip_card.config.center or pl_tooltip_card.config.center.key ~= hovered.key then
        pl_remove_tooltip_card()
        pl_tooltip_card = Card(x + card_w / 2, y + card_h / 2, G.CARD_W * 0.55, G.CARD_H * 0.55, nil, center, nil)
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
        if center.loc_vars and type(center.loc_vars) == 'function' then
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
        localize { type = 'name', set = res.name_set or target.set, key = res.name_key or target.key, nodes = name, vars = res.name_vars or target.vars or {} }
        if res.main_start then
            description[#description + 1] = res.main_start
        end

        localize(target)
        if res.main_end then
            description[#description + 1] = res.main_end
        end

        local display_card = Card(0, 0, G.CARD_W / 1.2, G.CARD_H / 1.2, nil, pl_tooltip_card.config.center)
        display_card.no_ui = true
        display_card.no_shadow = true

        pl_tooltip_card.children.playlog_box = UIBox {
            definition = {
                n = G.UIT.ROOT,
                config = {
                    align = "cm",
                    padding = 0.1,
                    r = 0.12,
                    emboss = 0.1,
                    colour = lighten(G.C.JOKER_GREY, 0.5)
                },
                nodes = {
                    {
                        n = G.UIT.R,
                        config = { align = "cm", minw = 1, colour = adjust_alpha(darken(G.C.BLACK, 0.1), 0.8), r = 0.1 },
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
                                                    desc_from_rows(name, true),
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
    local panel_w = 420
    local panel_h = 390
    local panel_x = sw - panel_w - 18
    local panel_y = math.floor(sh * 0.24)
    local content_x = panel_x + 14
    local content_y = panel_y + 16
    local content_w = panel_w - 40
    local content_h = panel_h - 32
    local button_w = 34
    local button_h = 34
    local button_x = sw - button_w - 12
    local button_y = sh - button_h - 100
    return {
        panel_x = panel_x,
        panel_y = panel_y,
        panel_w = panel_w,
        panel_h = panel_h,
        content_x = content_x,
        content_y = content_y,
        content_w = content_w,
        content_h = content_h,
        button_x = button_x,
        button_y = button_y,
        button_w = button_w,
        button_h = button_h,
        scrollbar_x = panel_x + panel_w - 14,
        scrollbar_y = panel_y + 10,
        scrollbar_w = 8,
        scrollbar_h = panel_h - 20,
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

local function pl_draw_button(layout)
    local mx, my = love.mouse.getPosition()
    local hovered = pl_point_in_rect(mx, my, layout.button_x, layout.button_y, layout.button_w, layout.button_h)
    love.graphics.setColor(0.12, 0.68, 0.84, hovered and 1 or 0.92)
    love.graphics.rectangle("fill", layout.button_x, layout.button_y, layout.button_w, layout.button_h, 8, 8)
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("line", layout.button_x, layout.button_y, layout.button_w, layout.button_h, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("L", layout.button_x + 12, layout.button_y + 8)
end

local function pl_draw_panel(layout)
    if not G.playlog_visible then
        G.playlog_hovered_tooltip = nil
        return
    end
    love.graphics.setColor(0.85, 0.2, 0.2, 0.95)
    love.graphics.rectangle("fill", layout.panel_x, layout.panel_y, layout.panel_w, layout.panel_h, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.97)
    love.graphics.rectangle("fill", layout.panel_x + 4, layout.panel_y + 4, layout.panel_w - 8, layout.panel_h - 8, 7, 7)
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
    for i = first, last do
        local entry = G.playlog_entries[i]
        if entry then
            local maybe_hovered = pl_draw_rich_segments(entry.segments, layout.content_x, y, mx, my)
            if maybe_hovered then hovered_tooltip = maybe_hovered end
            y = y + PLAYLOG_ROW_HEIGHT
            if y > (layout.content_y + layout.content_h - PLAYLOG_ROW_HEIGHT) then
                break
            end
        end
    end
    love.graphics.setScissor()
    G.playlog_hovered_tooltip = hovered_tooltip
    if max_shift > 0 then
        love.graphics.setColor(0.7, 0.15, 0.15, 0.35)
        love.graphics.rectangle("fill", layout.scrollbar_x, layout.scrollbar_y, layout.scrollbar_w, layout.scrollbar_h, 4,
            4)
        local ratio = PLAYLOG_VISIBLE_ROWS / math.max(total, PLAYLOG_VISIBLE_ROWS)
        local knob_h = math.max(18, layout.scrollbar_h * ratio)
        local t = shift / max_shift
        local knob_y = layout.scrollbar_y + (layout.scrollbar_h - knob_h) * t
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.rectangle("fill", layout.scrollbar_x, knob_y, layout.scrollbar_w, knob_h, 4, 4)
    end
end

local function pl_set_visible(is_visible)
    G.playlog_visible = is_visible and true or false
    if not G.playlog_visible then
        G.playlog_hovered_tooltip = nil
        pl_remove_tooltip_card()
    end
end

G.FUNCS.playlog_open_log = function(e)
    pl_enqueue_rich_log(
        "{C:attention}{T:j_misprint}High Priestess{} created {C:planet}{T:c_pluto}Pluto{} and {C:planet}{T:c_mars}Mars{}")
end

local game_start_run_ref = Game.start_run
function Game:start_run(args)
    game_start_run_ref(self, args)
    G.playlog_entries = {}
    G.playlog_pending_entries = {}
    G.playlog_pending_start = 1
    G.playlog_visible = true
    G.playlog_hovered_tooltip = nil
    pl_remove_tooltip_card()
end

local game_update_ref = Game.update
function Game:update(dt)
    local ret = game_update_ref(self, dt)
    if pl_is_run_active() then
        pl_flush_queue(PLAYLOG_ROWS_PER_FRAME)
    end
    return ret
end

function PlayLog.draw()
    if not pl_is_run_active() then return end
    local layout = pl_get_layout()
    pl_draw_panel(layout)
    pl_draw_button(layout)
    local active_tooltip = G.playlog_hovered_tooltip
    if not active_tooltip then
        pl_remove_tooltip_card()
    end
    pl_draw_hover_tooltip(active_tooltip)
end

if not love.mousepressed then
    function love.mousepressed(x, y, button, istouch, presses) end
end
if not love.keypressed then
    function love.keypressed(key, scancode, isrepeat) end
end

local playlog_keypressed_ref = love.keypressed
function love.keypressed(key, scancode, isrepeat)
    if pl_is_run_active() and not isrepeat and key == PLAYLOG_TOGGLE_KEY then
        pl_set_visible(not G.playlog_visible)
    end
    return playlog_keypressed_ref(key, scancode, isrepeat)
end

local playlog_mousepressed_ref = love.mousepressed
function love.mousepressed(x, y, button, istouch, presses)
    if not pl_is_run_active() then
        return playlog_mousepressed_ref(x, y, button, istouch, presses)
    end
    local layout = pl_get_layout()
    if button == 1 then
        if pl_point_in_rect(x, y, layout.button_x, layout.button_y, layout.button_w, layout.button_h) then
            G.FUNCS.playlog_open_log(nil)
        elseif pl_point_in_rect(x, y, layout.panel_x, layout.panel_y, layout.panel_w, layout.panel_h) then
            G.playlog_visible = true
        end
    elseif button == 2 then
        if pl_point_in_rect(x, y, layout.button_x, layout.button_y, layout.button_w, layout.button_h) then
            pl_set_visible(not G.playlog_visible)
        end
    end
    playlog_mousepressed_ref(x, y, button, istouch, presses)
end

if not love.wheelmoved then
    function love.wheelmoved(x, y) end
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
