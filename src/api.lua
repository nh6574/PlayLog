-- MAIN API

function PlayLog.log(args)
    args = args or {}
    pl_enqueue_rich_log(PlayLog.LogTypes[args.type]:get_message(args))
end
