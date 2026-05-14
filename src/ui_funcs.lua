PlayLog.FUNCS = PlayLog.FUNCS or {}

PlayLog.FUNCS.playlog_time = function(payload)
    if type(payload) == 'table' and type(payload.entry_time) == 'number' then
        local formats = PlayLog.CLOCK_FORMATS or {}
        local title = PlayLog.localize("log_time", nil, "playlog_ui")
        local idx = math.floor(tonumber(PlayLog.config and PlayLog.config.time_format_index) or 4)
        if #formats < 1 then
            return {
                title = title,
                text = PlayLog.get_formatted_time({ time = payload.entry_time, format_string = '%Y/%m/%d %H:%M:%S' })
            }
        end
        if idx < 1 or idx > #formats then
            idx = math.min(4, #formats)
        end
        local selected = formats[idx] or formats[1]
        local date_part = PlayLog.get_formatted_time({ time = payload.entry_time, format_string = '%Y/%m/%d' })
        local time_part = PlayLog.get_formatted_time({
            time = payload.entry_time,
            format_string = selected.format_string,
            no_leading_zero = selected.no_leading_zero,
        })
        return {
            title = title,
            text = tostring(date_part) .. " " .. tostring(time_part)
        }
    end
    if type(payload) == 'table' and type(payload.full_date) == 'string' and payload.full_date ~= '' then
        return {
            title = title,
            text = payload.full_date
        }
    end
    return {
        title = title,
        text = PlayLog.get_formatted_time({ format_string = '%Y/%m/%d %H:%M:%S' })
    }
end
