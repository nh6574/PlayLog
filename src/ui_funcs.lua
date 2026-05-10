PlayLog.FUNCS = PlayLog.FUNCS or {}

PlayLog.FUNCS.playlog_time = function()
    return PlayLog.get_formatted_time({ format_string = '%Y/%m/%d %H:%M:%S' })
end
