-- Classes and objects and stuff

SMODS.current_mod.prefix_config = {
    key = false
}

PlayLog.LogTypes = {}
PlayLog.LogType = SMODS.GameObject:extend {
    obj_table = PlayLog.LogTypes,
    obj_buffer = {},
    required_params = {
        'key',
        'get_message'
    },
    get_message = function(self, args)
        return "ERROR"
    end,
    inject = function(self, i)

    end
}

PlayLog.LogType {
    key = "message",
    get_message = function(self, args)
        return PlayLog.fill_vars(args.text, args.vars)
    end
}

--TODO: Handle card information properly instead of this
local function format_card(card)
    if not card then return "ERROR" end
    if type(card) == "string" then return card end
    if card.playing_card then -- TODO: other than figuring how to pass the values/modifiers to the UI, how are no rank/suit cards displayed?
        return PlayLog.localize_rank_of_suit(card.base.value, card.base.suit)
    end
    return "{T:" ..
        card.config.center.key ..
        "}" .. localize { type = "name_text", key = card.config.center.key, set = card.config.center.set } .. "{}"
end

local function format_card_list(list)
    if not list then return "ERROR" end
    local card_list = {}
    for _, card in ipairs(list or {}) do
        card_list[#card_list + 1] = format_card(card)
    end
    return card_list
end

local function format_center_from_key(center_key)
    local center = G.P_CENTERS[center_key]
    if not center then return "ERROR" end
    return "{T:" ..
        center_key ..
        "}" .. localize { type = "name_text", key = center_key, set = center.set } .. "{}"
end

PlayLog.LogType {
    key = "creates",
    get_message = function(self, args)
        return PlayLog.localize("creates", { format_card(args.card), PlayLog.loc_list(format_card_list(args.created)) })
    end
}

PlayLog.LogType {
    key = "destroys",
    get_message = function(self, args)
        return PlayLog.localize("destroys",
            { format_card(args.card), PlayLog.loc_list(format_card_list(args.destroyed)) })
    end
}

PlayLog.LogType {
    key = "copies",
    get_message = function(self, args)
        if args.copied_to then
            return PlayLog.localize("copies_into",
                { format_card(args.card), PlayLog.loc_list(format_card_list(args.copied)),
                    PlayLog.loc_list(format_card_list(args.copied_to)) })
        end
        return PlayLog.localize("copies", { format_card(args.card), PlayLog.loc_list(format_card_list(args.copied)) })
    end
}

PlayLog.LogType {
    key = "added",
    get_message = function(self, args)
        if args.area then
            return PlayLog.localize("added_to", { format_card(args.card), PlayLog.get_area_name(args.area) })
        end
        return PlayLog.localize("added", { format_card(args.card) })
    end
}

PlayLog.LogType {
    key = "converts",
    get_message = function(self, args)
        local conversion
        if args.enhancement then
            conversion = format_center_from_key(args.enhancement)
        elseif args.suit then
            conversion = localize(args.suit, "suits_plural")
        elseif args.rank then
            conversion = localize(args.rank, "ranks")
        end

        return PlayLog.localize("converts",
            { format_card(args.card), PlayLog.loc_list(format_card_list(args.converted)), conversion or "ERROR" })
    end
}

PlayLog.LogType {
    key = "converts_multiple",
    get_message = function(self, args)
        local conversions = {}
        for i, card in ipairs(args.converted) do
            local conversion
            if args.enhancements then
                conversion = format_center_from_key(args.enhancements[i])
            elseif args.suits then
                conversion = localize(args.suits[i], "suits_plural")
            elseif args.ranks then
                conversion = localize(args.ranks[i], "ranks")
            end
            conversions[#conversions + 1] = PlayLog.localize("converts_individual",
                { format_card(card), conversion or "ERROR" })
        end

        return PlayLog.localize("converts_multiple",
            { format_card(args.card), PlayLog.loc_list(conversions) })
    end
}

PlayLog.LogType {
    key = "applied",
    get_message = function(self, args)
        local conversion
        if args.edition then
            conversion = format_center_from_key(args.edition)
        elseif args.seal then
            conversion = localize { type = 'name_text', key = args.seal:lower() .. "_seal", set = "Seal" }
        elseif args.sticker then
            conversion = localize(args.sticker, "labels")
        end

        return PlayLog.localize("applied",
            { format_card(args.card), PlayLog.loc_list(format_card_list(args.applied)), conversion or "ERROR" })
    end
}

PlayLog.LogType {
    key = "money",
    get_message = function(self, args)
        return PlayLog.localize("money", { format_card(args.card), args.amount })
    end
}

PlayLog.LogType {
    key = "noped",
    get_message = function(self, args)
        return PlayLog.localize("noped", { format_card(args.card) })
    end
}

PlayLog.LogType {
    key = "noped",
    get_message = function(self, args)
        return PlayLog.localize("noped", { format_card(args.card) })
    end
}
