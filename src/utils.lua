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

function PlayLog.parse_text(raw_text)
    local default_colour = copy_colour((G and G.C and G.C.UI and G.C.UI.TEXT_DARK) or { 0.08, 0.08, 0.08, 0.95 })
    local active_colour = copy_colour(default_colour)
    local active_tooltip = nil
    local is_colored = false
    local segments = {}
    local i = 1
    local text = tostring(raw_text or "")
    while i <= #text do
        local open = text:find("{", i, true)
        if not open then
            local tail = text:sub(i)
            if tail ~= "" then
                segments[#segments + 1] = { text = tail, colour = is_colored and copy_colour(active_colour) or nil, plain = not is_colored, tooltip = active_tooltip }
            end
            break
        end
        if open > i then
            local plain = text:sub(i, open - 1)
            if plain ~= "" then
                segments[#segments + 1] = {
                    text = plain,
                    colour = is_colored and copy_colour(active_colour) or nil,
                    plain = not is_colored,
                    tooltip = active_tooltip
                }
            end
        end
        local close = text:find("}", open + 1, true)
        if not close then
            local rest = text:sub(open)
            segments[#segments + 1] = { text = rest, colour = is_colored and copy_colour(active_colour) or nil, plain = not is_colored, tooltip = active_tooltip }
            break
        end
        local tag = text:sub(open + 1, close - 1)
        if tag == "" then
            active_colour = copy_colour(default_colour)
            active_tooltip = nil
            is_colored = false
        else
            local colour_key = tag:match("C:([^,%}]+)")
            if colour_key then
                active_colour = get_balatro_colour(colour_key, active_colour)
                is_colored = true
            end

            local tooltip_key = tag:match("T:([^,%}]+)")
            if tooltip_key then
                active_tooltip = tooltip_key
            end
        end
        i = close + 1
    end
    return segments
end
