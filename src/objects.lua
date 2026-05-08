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
    inject = function(self, i) end
}

PlayLog.LogType {
    key = "message",
    get_message = function(self, args)
        return PlayLog.fill_vars(args.text, args.vars)
    end
}

local function format_center_from_key(center_key)
    local center = G.P_CENTERS[center_key] or G.P_SEALS[center_key] or G.P_BLINDS[center_key] or G.P_TAGS[center_key] or
        G.P_STAKES[center_key]
    local set = center.set or (G.P_SEALS[center_key] and "Seal") or (G.P_BLINDS[center_key] and "Blind") or
        (G.P_TAGS[center_key] and "Tag") or (G.P_STAKES[center_key] and "Stake")
    if not center then return "ERROR" end
    local vars = {}
    if center.loc_vars then
        vars = center:loc_vars({}, center:create_fake_card()) or {}
    end
    if set == "Seal" then
        return "{T:" ..
            center_key ..
            "}" .. localize((vars.name_key or vars.key or center_key):lower() .. "_seal", "labels")
    end
    if set == "Booster" then vars.set = "Other" end
    return "{T:" ..
        center_key ..
        "}" ..
        localize { type = "name_text", key = vars.name_key or vars.key or center_key, set = vars.name_set or vars.set or set } ..
        "{}"
end

--TODO: Handle card information properly instead of this
local function format_card(card)
    if not card then return "ERROR" end
    if type(card) == "string" then
        if G.P_CENTERS[card] or G.P_SEALS[card] or G.P_BLINDS[card] or G.P_TAGS[card] or G.P_STAKES[card] then
            return format_center_from_key(card)
        end
        return card
    end
    if card.playing_card then -- TODO: other than figuring how to pass the values/modifiers to the UI, how are no rank/suit cards displayed?
        return PlayLog.localize_rank_of_suit(card.base.value, card.base.suit)
    end

    local center = card.config.center
    local vars = {}
    if center.loc_vars then
        vars = center:loc_vars({}, center:create_fake_card()) or {}
    end
    if card.config.center.set == "Booster" then vars.set = "Other" end
    return "{T:" ..
        card.config.center.key ..
        "}" ..
        localize { type = "name_text", key = vars.name_key or vars.key or card.config.center.key, set = vars.name_set or vars.set or card.config.center.set } ..
        "{}"
end

local function format_card_list(list)
    if not list then return "ERROR" end
    local card_list = {}
    for _, card in ipairs(list or {}) do
        card_list[#card_list + 1] = format_card(card)
    end
    return card_list
end

PlayLog.LogType {
    key = "started",
    get_message = function(self, args)
        local deck = format_center_from_key(args.deck)
        local stake = format_center_from_key(args.stake)
        if args.challenge then
            return PlayLog.localize("started_challenge",
                { localize(args.challenge, 'challenge_names'), deck, stake })
        end
        return PlayLog.localize("started", { deck, stake })
    end
}

PlayLog.LogType {
    key = "selected_blind",
    get_message = function(self, args)
        return PlayLog.localize("selected_blind", { format_center_from_key(args.blind) })
    end
}

PlayLog.LogType {
    key = "defeated_blind",
    get_message = function(self, args)
        return PlayLog.localize("defeated_blind", { format_center_from_key(args.blind) })
    end
}

PlayLog.LogType {
    key = "cash_out",
    get_message = function(self, args)
        return PlayLog.localize("cash_out", { args.amount })
    end
}

PlayLog.LogType {
    key = "skip_blind",
    get_message = function(self, args)
        if args.tag then
            return PlayLog.localize("skip_blind_for",
                { format_center_from_key(args.blind), format_center_from_key(args.tag) })
        end
        return PlayLog.localize("skip_blind", { format_center_from_key(args.blind) })
    end
}

PlayLog.LogType {
    key = "start_round",
    get_message = function(self, args)
        return PlayLog.localize("start_round", { args.round })
    end
}

PlayLog.LogType {
    key = "start_ante",
    get_message = function(self, args)
        if args.modified then
            return PlayLog.localize("ante_modified", { args.ante, args.ante + args.modified })
        end
        return PlayLog.localize("start_ante", { args.ante })
    end
}

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
            return PlayLog.localize("added_to",
                { args.cards and PlayLog.loc_list(format_card_list(args.cards)) or format_card(args.card), PlayLog
                    .get_area_name(args.area) })
        end
        return PlayLog.localize("added",
            { args.cards and PlayLog.loc_list(format_card_list(args.cards)) or format_card(args.card) })
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
            conversion = localize(args.seal:lower() .. "_seal", "labels")
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
        if args.amount < 0 then
            return PlayLog.localize("money_taken", { format_card(args.card), math.abs(args.amount) })
        end
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
    key = "hand_level_up",
    get_message = function(self, args)
        return PlayLog.localize("hand_level_up", { localize(args.hand, 'poker_hands'), args.old_level, args.new_level })
    end
}

PlayLog.LogType {
    key = "leveled_up",
    get_message = function(self, args)
        local hand_list = {}
        if #G.handlist == #args.hands then
            hand_list[#hand_list + 1] = PlayLog.localize("all_hands")
        else
            for _, hand in ipairs(args.hands) do
                hand_list[#hand_list + 1] = "{C:attention}" .. localize(hand, 'poker_hands') .. "{}"
            end
        end
        return PlayLog.localize("leveled_up", { format_card(args.card), PlayLog.loc_list(hand_list) })
    end
}

PlayLog.LogType {
    key = "change_area_size",
    get_message = function(self, args)
        if args.amount < 0 then
            return PlayLog.localize("change_area_size_neg",
                { format_card(args.card), PlayLog.get_area_name(args.area), math.abs(args.amount) })
        end
        return PlayLog.localize("change_area_size",
            { format_card(args.card), PlayLog.get_area_name(args.area), args.amount })
    end
}

PlayLog.LogType {
    key = "area_size",
    get_message = function(self, args)
        return PlayLog.localize("area_size",
            { PlayLog.get_area_name(args.area),
                args.old_size or args.area.config.card_limit - (args.amount or 0),
                args.new_size or args.area.config.card_limit })
    end
}

PlayLog.LogType {
    key = "sell",
    get_message = function(self, args)
        return PlayLog.localize("sell", { format_card(args.card), args.amount })
    end
}

PlayLog.LogType {
    key = "buy",
    get_message = function(self, args)
        return PlayLog.localize("buy", { format_card(args.card), args.amount })
    end
}

PlayLog.LogType {
    key = "booster_opened",
    get_message = function(self, args)
        return PlayLog.localize("booster_opened",
            { format_card(args.booster), PlayLog.loc_list(format_card_list(args.cards)) })
    end
}

PlayLog.LogType {
    key = "booster_skipped",
    get_message = function(self, args)
        return PlayLog.localize("booster_skipped", { format_card(args.booster) })
    end
}

PlayLog.LogType {
    key = "win",
    get_message = function(self, args)
        return PlayLog.localize("win")
    end
}

PlayLog.LogType {
    key = "lost",
    get_message = function(self, args)
        return PlayLog.localize(args.endless and "lost_endless" or "lost")
    end
}
