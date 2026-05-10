-- MAIN API

function PlayLog.log(args)
    assert(args and args.type and PlayLog.LogTypes[args.type], "PlayLog.log was called without a valid type")
    PlayLog.log_event(PlayLog.LogTypes[args.type]:get_message(args), args.vars)
end
