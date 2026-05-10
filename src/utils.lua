--- UTILS

-- Modified from SystemClock <3
PlayLog.CLOCK_FORMATS = {
    { format_string = '%I:%M %p',    no_leading_zero = true },
    { format_string = '%I:%M',       no_leading_zero = true },
    { format_string = '%H:%M',       no_leading_zero = false },
    { format_string = '%I:%M:%S %p', no_leading_zero = true },
    { format_string = '%I:%M:%S',    no_leading_zero = true },
    { format_string = '%H:%M:%S',    no_leading_zero = false }
}
function PlayLog.get_formatted_time(args)
    args = type(args) == "table" and copy_table(args) or {}
    args.time = args.time or os.time()
    if args.hour_offset and tonumber(args.hour_offset) then
        args.time = args.time + tonumber(args.hour_offset) * 3600
    end

    local formatted_time = os.date(args.format_string, args.time)

    if args.no_leading_zero then
        formatted_time = tostring(formatted_time):gsub("^0", "")
    end
    return formatted_time
end

local function copy_colour(colour)
    if not colour then return { 1, 1, 1, 1 } end
    return {
        colour[1] or 1,
        colour[2] or 1,
        colour[3] or 1,
        colour[4] or 1,
    }
end

local function try_as_colour(value)
    if type(value) ~= 'table' then return nil end
    if tonumber(value[1]) and tonumber(value[2]) and tonumber(value[3]) then
        return copy_colour(value)
    end
    return nil
end

local pl_func_payload_counter = 0
local function pl_store_payload(prefix, payload)
    if type(prefix) ~= 'string' or prefix == '' then return nil end
    pl_func_payload_counter = pl_func_payload_counter + 1
    local payload_id = tostring(os.time()) .. '_' .. tostring(pl_func_payload_counter)
    G.GAME = G.GAME or {}
    G.GAME.playlog_func_payloads = type(G.GAME.playlog_func_payloads) == 'table' and G.GAME.playlog_func_payloads or {}
    G.GAME.playlog_func_payloads[payload_id] = copy_table and copy_table(payload) or payload
    return prefix .. '@' .. payload_id
end

local function pl_extract_payload_id(ref, expected_prefix)
    if type(ref) ~= 'string' or ref == '' then return nil end
    local prefix, payload_id = ref:match('^([^@]+)@(.+)$')
    if not prefix or not payload_id then return nil end
    if expected_prefix and prefix ~= expected_prefix then return nil end
    return payload_id, prefix
end

local function pl_get_payload(ref, expected_prefix)
    local payload_id = pl_extract_payload_id(ref, expected_prefix)
    if not payload_id then return nil end
    local payloads = G and G.GAME and G.GAME.playlog_func_payloads
    return payloads and payloads[payload_id] or nil
end

local function pl_get_card_front_key(card)
    if type(card) ~= 'table' then return nil end
    local direct_key = card.front_key or (card.config and (card.config.card_key or card.config.front_key))
    if direct_key and G and G.P_CARDS and G.P_CARDS[direct_key] then
        return direct_key
    end
    local front = card.config and (card.config.card or card.config.front)
    if front and G and G.P_CARDS then
        for front_key, front_value in pairs(G.P_CARDS) do
            if front_value == front then
                return front_key
            end
        end
    end
    return nil
end

local function pl_get_card_edition_key(card)
    if type(card) ~= 'table' then return nil end
    local edition = card.edition or (card.ability and card.ability.edition) or (card.config and card.config.edition)
    if type(edition) == 'string' then
        return edition
    end
    if type(edition) ~= 'table' then return nil end
    if type(edition.key) == 'string' then return edition.key end
    if edition.foil then return 'e_foil' end
    if edition.holo then return 'e_holo' end
    if edition.polychrome then return 'e_polychrome' end
    if edition.negative then return 'e_negative' end
    return nil
end

local function pl_get_card_seal_key(card)
    if type(card) ~= 'table' then return nil end
    local seal = card.seal or (card.ability and card.ability.seal) or (card.config and card.config.seal)
    if type(seal) ~= 'string' or seal == '' then return nil end
    if G and G.P_SEALS and G.P_SEALS[seal] then return seal end
    if SMODS and SMODS.Seal and SMODS.Seal.badge_to_key and SMODS.Seal.badge_to_key[seal] then
        return SMODS.Seal.badge_to_key[seal]
    end
    local lowered = seal:lower()
    if G and G.P_SEALS and G.P_SEALS[lowered] then return lowered end
    local with_suffix = lowered:find('_seal$', 1, false) and lowered or (lowered .. '_seal')
    if G and G.P_SEALS and G.P_SEALS[with_suffix] then return with_suffix end
    return nil
end

local function get_blind_runtime_colour(center, key)
    local blind_key = tostring((center and center.key) or key or '')
    local blind_key_lower = blind_key:lower()

    if type(mix_colours) == 'function' and G and G.C and G.C.BLACK then
        if blind_key_lower == 'bl_small' and G.C.BLUE then
            return copy_colour(mix_colours(G.C.BLUE, G.C.BLACK, 0.6))
        end
        if blind_key_lower == 'bl_big' and G.C.ORANGE then
            return copy_colour(mix_colours(G.C.ORANGE, G.C.BLACK, 0.6))
        end
    end
    if center then
        local boss_colour = try_as_colour(center.boss_colour)
            or try_as_colour(center.boss_color)
        if boss_colour then return boss_colour end

        local from_center = try_as_colour(center.colour)
            or try_as_colour(center.color)
        if from_center then return from_center end
    end
    return nil
end

local function get_balatro_colour(tag, fallback)
    local key = tostring(tag or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if key == "" then return fallback end
    if G and G.ARGS and G.ARGS.LOC_COLOURS and G.ARGS.LOC_COLOURS[key] then
        return copy_colour(G.ARGS.LOC_COLOURS[key])
    end
    local lower = key:lower()
    if G and G.ARGS and G.ARGS.LOC_COLOURS and G.ARGS.LOC_COLOURS[lower] then
        return copy_colour(G.ARGS.LOC_COLOURS[lower])
    end
    local upper = key:upper()
    if G and G.C and G.C[upper] then
        return copy_colour(G.C[upper])
    end
    if G and G.C and G.C[key] then
        return copy_colour(G.C[key])
    end
    return fallback
end

local function get_indexed_colour(index, fallback, vars)
    local cleaned_index = tostring(index or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local idx = tonumber(cleaned_index)
    if not idx then return fallback end
    idx = math.floor(idx)
    if vars and type(vars.colours) == 'table' and vars.colours[idx] then
        return copy_colour(vars.colours[idx])
    end
    return fallback
end

local function get_tooltip_colour(tooltip_key, fallback)
    if not tooltip_key then return fallback end
    local key = tostring(tooltip_key)
    local center = G and G.P_CENTERS and G.P_CENTERS[key]
    local source_set = center and center.set or nil
    if not center and G and G.P_SEALS then
        local seal_key = key
        if SMODS and SMODS.Seal and SMODS.Seal.badge_to_key then
            seal_key = SMODS.Seal.badge_to_key[key] or key
        end
        center = G.P_SEALS[seal_key]
        if center then source_set = 'Seal' end
    end
    if not center and G and G.P_BLINDS then
        center = G.P_BLINDS[key]
        if center then source_set = 'Blind' end
    end
    if not center and G and G.P_TAGS then
        center = G.P_TAGS[key]
        if center then source_set = 'Tag' end
    end
    if not center and G and G.P_STAKES then
        center = G.P_STAKES[key]
        if center then source_set = 'Stake' end
    end
    if center then
        if source_set == 'Blind' then
            local blind_colour = get_blind_runtime_colour(center, key)
            if blind_colour then return blind_colour end
        end
        if type(center.colour) == 'table' then
            return copy_colour(center.colour)
        end
        if type(center.color) == 'table' then
            return copy_colour(center.color)
        end
        if type(center.boss_colour) == 'table' then
            return copy_colour(center.boss_colour)
        end
        if type(center.boss_color) == 'table' then
            return copy_colour(center.boss_color)
        end
        if center.loc_colour then
            return copy_colour(center.loc_colour)
        end
        if center.key then
            local by_center_key = get_balatro_colour(center.key, nil)
            if by_center_key then return by_center_key end
        end
        local by_tooltip_key = get_balatro_colour(key, nil)
        if by_tooltip_key then return by_tooltip_key end
        local set_key = center.set or source_set
        if set_key and G and G.C and G.C.SECONDARY_SET and G.C.SECONDARY_SET[set_key] then
            return copy_colour(G.C.SECONDARY_SET[set_key])
        end
        if set_key and G and G.C and G.C[string.upper(set_key)] then
            return copy_colour(G.C[string.upper(set_key)])
        end
    end
    local seal_name = key:lower()
    if seal_name:find("gold") then return get_balatro_colour("gold", fallback) end
    if seal_name:find("red") then return get_balatro_colour("red", fallback) end
    if seal_name:find("blue") then return get_balatro_colour("blue", fallback) end
    if seal_name:find("purple") then return get_balatro_colour("purple", fallback) end

    return fallback
end

function PlayLog.store_func_payload(func_name, payload)
    return pl_store_payload(func_name, payload)
end

function PlayLog.store_card_tooltip_payload(card)
    if type(card) ~= 'table' or not card.base then return nil end
    local center = card.config and card.config.center or nil
    local snapshot = {
        center_key = center and center.key or 'c_base',
        suit = card.base.suit,
        value = card.base.value,
        id = card.base.id,
        front_key = pl_get_card_front_key(card),
        edition_key = pl_get_card_edition_key(card),
        seal_key = pl_get_card_seal_key(card),
    }
    return pl_store_payload('playlog_card_snapshot', snapshot)
end

function PlayLog.get_card_tooltip_payload(ref)
    return pl_get_payload(ref, 'playlog_card_snapshot')
end

function PlayLog.parse_text(raw_text, loc_vars)
    local default_colour = copy_colour((G and G.C and G.C.UI and G.C.UI.TEXT_DARK) or { 0.08, 0.08, 0.08, 0.95 })
    local active_colour = copy_colour(default_colour)
    local active_bg = nil
    local active_tooltip = nil
    local active_func = nil
    local active_scale = 1
    local active_underline = nil
    local active_strike = nil
    local is_colored = false
    local segments = {}
    local active_bg_mode = nil
    local function push_segment(seg_text)
        if seg_text == "" then return end
        if active_bg_mode == 'X' then
            seg_text = seg_text:gsub("%s+", "")
            if seg_text == "" then return end
        end
        segments[#segments + 1] = {
            text = seg_text,
            colour = is_colored and copy_colour(active_colour) or nil,
            plain = not is_colored,
            tooltip = active_tooltip,
            bg_colour = active_bg and copy_colour(active_bg) or nil,
            scale = active_scale,
            underline_colour = active_underline and copy_colour(active_underline) or nil,
            strikethrough_colour = active_strike and copy_colour(active_strike) or nil,
            func = active_func
        }
    end
    local i = 1
    local text = tostring(raw_text or "")
    text = text:gsub("\\n", "\n")
    text = text:gsub("/n", "\n")
    local vars = type(loc_vars) == 'table' and (loc_vars.vars or loc_vars) or nil
    if type(vars) == 'table' then
        text = text:gsub("#(%d+)#", function(n)
            local idx = tonumber(n)
            local value = idx and vars[idx] or nil
            if value ~= nil then
                return tostring(value)
            end
            return "#" .. n .. "#"
        end)
    end
    while i <= #text do
        local open = text:find("{", i, true)
        if not open then
            local tail = text:sub(i)
            push_segment(tail)
            break
        end
        if open > i then
            push_segment(text:sub(i, open - 1))
        end
        local close = text:find("}", open + 1, true)
        if not close then
            push_segment(text:sub(open))
            break
        end
        local tag = text:sub(open + 1, close - 1)
        if tag == "" then
            active_colour = copy_colour(default_colour)
            active_bg = nil
            active_bg_mode = nil
            active_tooltip = nil
            active_scale = 1
            active_underline = nil
            active_strike = nil
            active_func = nil
            is_colored = false
        else
            local var_colour_idx = tag:match("V:([^,%}]+)")
            local colour_key = tag:match("C:([^,%}]+)")
            if var_colour_idx then
                active_colour = get_indexed_colour(var_colour_idx, active_colour, vars)
                is_colored = true
            elseif colour_key then
                active_colour = get_balatro_colour(colour_key, active_colour)
                is_colored = true
            end
            local var_bg_idx = tag:match("B:([^,%}]+)")
            local bg_key = tag:match("X:([^,%}]+)")
            if var_bg_idx then
                active_bg = get_indexed_colour(var_bg_idx, active_bg or active_colour, vars)
                active_bg_mode = 'B'
            elseif bg_key then
                active_bg = get_balatro_colour(bg_key, active_bg or active_colour)
                active_bg_mode = 'X'
            end
            local tooltip_key = tag:match("T:([^,%}]+)")
            if tooltip_key then
                active_tooltip = tooltip_key
                if not var_colour_idx and not colour_key then
                    local tooltip_colour = get_tooltip_colour(tooltip_key, active_colour)
                    if tooltip_colour then
                        active_colour = tooltip_colour
                        is_colored = true
                    end
                end
            end
            local func_tooltip_key = tag:match("F:([^,%}]+)")
            if func_tooltip_key then
                active_func = func_tooltip_key
            end
            local scale_key = tag:match("s:([^,%}]+)")
            if scale_key then
                local parsed_scale = tonumber(scale_key)
                if parsed_scale and parsed_scale > 0 then
                    active_scale = parsed_scale
                end
            end
            local underline_key = tag:match("u:([^,%}]+)")
            if underline_key then
                active_underline = get_balatro_colour(underline_key, active_colour)
            end
            local strike_key = tag:match("st:([^,%}]+)")
            if strike_key then
                active_strike = get_balatro_colour(strike_key, active_colour)
            end
        end
        i = close + 1
    end
    return segments
end

---Fills the variables in formatted text
---@param text string
---@param vars table
---@return string?
function PlayLog.fill_vars(text, vars)
    if not text or not vars then return text end
    local ret, _ = text:gsub("#(%d+)#", function(i)
        return vars[tonumber(i)] or "nil"
    end)

    return ret
end

---Returns a localized list of values
---@param values table
---@return string
function PlayLog.loc_list(values)
    if not values or #values == 0 then return "ERROR" end
    if #values == 1 then return tostring(values[1]) end

    local text = tostring(values[1])
    for i = 2, #values - 1 do
        text = PlayLog.localize("separator", { text, values[i] })
    end

    text = PlayLog.localize("end_separator", { text, values[#values] })

    return text
end

---Returns a formatted string from the PlayLog localization
---@param key string
---@param vars table?
---@return string
function PlayLog.localize(key, vars)
    local text = G.localization.misc.playlog[key]
    if not text then return "ERROR" end
    vars = vars or {}

    return PlayLog.fill_vars(text, vars)
end

---Gets the localized name of the area
---@param area CardArea|table
---@return string?
function PlayLog.get_area_name(area)
    local area_names = {
        [G.jokers] = "joker_area",
        [G.consumeables] = "consumable_area",
        [G.hand] = "hand_area",
        [G.deck] = "deck_area",
    }
    if G.shop_jokers then area_names[G.shop_jokers] = "shop_jokers_area" end
    if G.shop_vouchers then area_names[G.shop_vouchers] = "shop_vouchers_area" end
    if G.shop_booster then area_names[G.shop_booster] = "shop_boosters_area" end
    return area_names[area] and PlayLog.localize(area_names[area]) or nil
end

---Localize "rank of suit"
---@param rank string rank key (value)
---@param suit string suit key
---@return string
function PlayLog.localize_rank_of_suit(rank, suit)
    local rank_text = localize(rank, 'ranks')
    local suit_text = localize(suit, 'suits_plural')
    local full_text = PlayLog.localize("rank_of_suit", { rank_text, suit_text })
    local suit_key = tostring(suit or ''):lower()
    if suit_key ~= '' then
        return "{C:" .. suit_key .. "}" .. tostring(full_text) .. "{}"
    end
    return full_text
end

---Returns current deck and stake, and sleeve if available. Hook to add more modifiers
---@return table
function PlayLog.get_run_modifiers()
    local modifiers = { G.GAME.selected_back_key.key, G.P_CENTER_POOLS.Stake[G.GAME.stake].key }
    if G.GAME.selected_sleeve then table.insert(modifiers, 2, G.GAME.selected_sleeve) end -- Card Sleeves mod compat
    return modifiers
end

---Returns the shop areas. Hook to add more
---@return table
function PlayLog.get_shop_areas()
    return { G.shop_jokers, G.shop_vouchers, G.shop_booster }
end

---Returns all cards in the shop areas
---@return table
function PlayLog.get_shop_area_cards()
    local areas = PlayLog.get_shop_areas()
    local cards = {}
    for _, area in ipairs(areas) do
        for _, card in ipairs(area.cards or {}) do
            cards[#cards + 1] = card
        end
    end
    return cards
end
