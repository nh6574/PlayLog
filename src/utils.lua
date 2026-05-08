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
    if not center and G and G.P_SEALS then
        local seal_key = key
        if SMODS and SMODS.Seal and SMODS.Seal.badge_to_key then
            seal_key = SMODS.Seal.badge_to_key[key] or key
        end
        center = G.P_SEALS[seal_key]
    end
    if center then
        if center.loc_colour then
            return copy_colour(center.loc_colour)
        end
        local set_key = center.set
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

function PlayLog.parse_text(raw_text, loc_vars)
    local default_colour = copy_colour((G and G.C and G.C.UI and G.C.UI.TEXT_DARK) or { 0.08, 0.08, 0.08, 0.95 })
    local active_colour = copy_colour(default_colour)
    local active_bg = nil
    local active_tooltip = nil
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
        [G.deck] = "deck_area"
    }
    return area_names[area] and PlayLog.localize(area_names[area]) or nil
end

---Localize "rank of suit"
---@param rank string rank key (value)
---@param suit string suit key
---@return string
function PlayLog.localize_rank_of_suit(rank, suit)
    return PlayLog.localize("rank_of_suit",
        {
            localize(rank, 'ranks'),
            localize(suit, 'suits_plural'),
        })
end
