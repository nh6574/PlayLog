-- MAIN API

---Logs to the Play Log
---@param args string|LogTypeT
function PlayLog.log(args)
    if type(args) == "string" then args = { type = "message", text = args } end
    assert(args and args.type and PlayLog.LogTypes[args.type], "PlayLog.log was called without a valid type")
    if PlayLog.is_log_type_enabled and not PlayLog.is_log_type_enabled(args.type) then
        return
    end
    PlayLog.log_event(PlayLog.LogTypes[args.type]:get_message(args), args.vars)
end
