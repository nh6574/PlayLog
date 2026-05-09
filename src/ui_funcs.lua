PlayLog.FUNCS = {}

PlayLog.FUNCS.playlog_time = function()
    local full_text = PlayLog.get_formatted_time({ format_string = '%Y/%m/%d %H:%M:%S' })
    return PlayLog.create_tooltip_UIBox({
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
                                {
                                    n = G.UIT.O,
                                    config = {
                                        object = DynaText({
                                            string = full_text,
                                            colours = { G.C.UI.TEXT_INACTIVE },
                                            silent = true,
                                            no_bump = true,
                                            no_pop_in = true,
                                            maxw = 5,
                                            shadow = true,
                                            y_offset = 0,
                                            spacing = math.max(0, 0.32 * (17 - #full_text)),
                                            scale = (0.4 - 0.004 * #full_text)
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
    })
end
