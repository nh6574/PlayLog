-- MAIN API

function PlayLog.log(args)
    args = args or {}
    PlayLog.log_event(PlayLog.LogTypes[args.type]:get_message(args), args.vars)
end
