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
-- TODO: Add 'group' to group log types for the config
-- TODO: Add localization for the types/groups for the config

PlayLog.LogType {
    key = "message",
    get_message = function(self, args)
        return args.text
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
        vars = center:loc_vars({},
                center.create_fake_card and center:create_fake_card() or
                { config = copy_table(center.config), ability = copy_table(center.config), fake_tag = true, fake_card = true }) or
            {}
    end
    if set == "Seal" then
        return "{T:" ..
            center_key ..
            "}" .. localize((vars.name_key or vars.key or center_key):lower() .. "_seal", "labels")
    end
    if set == "Booster" then vars.set = "Other" end
    local name_text = localize { type = "name_text", key = vars.name_key or vars.key or center_key, set = vars.name_set or vars.set or set }
    if vars.vars then
        name_text = PlayLog.fill_vars(name_text, vars.vars)
    end
    return "{T:" .. center_key .. "}" .. name_text .. "{}"
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
    if type(card) == "table" and card.key then return format_center_from_key(card.key) end
    if card.is and card:is(Blind) then return format_center_from_key(card.config.blind.key) end
    if type(card) ~= "table" or not (card.config or {}).center then return "ERROR" end
    if card.playing_card or card.config.center.set == "Default" or card.config.center.set == "Enhanced" then -- TODO: other than figuring how to pass the values/modifiers to the UI, how are no rank/suit cards displayed?
        return PlayLog.localize_rank_of_suit(card.base.value, card.base.suit)
    end

    local center = card.config.center
    local vars = {}
    card.fake_card = true
    if center.loc_vars then
        vars = center:loc_vars({}, card) or {}
    end
    card.fake_card = nil
    if card.config.center.set == "Booster" then vars.set = "Other" end
    local name_text = localize { type = "name_text", key = vars.name_key or vars.key or card.config.center.key, set = vars.name_set or vars.set or card.config.center.set }
    if vars.vars then
        name_text = PlayLog.fill_vars(name_text, vars.vars)
    end
    return "{T:" .. card.config.center.key .. "}" .. name_text .. "{}"
end

local function format_exact_playing_card(card)
    if not card then return "ERROR" end
    local card_text = format_card(card)
    if type(card) ~= 'table' or not card.base then
        return card_text
    end
    local tooltip_ref = PlayLog.store_card_tooltip_payload and PlayLog.store_card_tooltip_payload(card)
    if not tooltip_ref then
        return card_text
    end
    return "{T:" .. tooltip_ref .. "}" .. tostring(card_text or "") .. "{}"
end
local function format_exact_playing_card_list(list, color)
    if not list then return "ERROR" end
    local card_list = {}
    local start_string = color and "{C:" .. color .. "}" or ''
    local end_string = color and "{}" or ''
    for _, card in ipairs(list or {}) do
        local card_text = format_exact_playing_card(card)
        local has_native_markup = type(card_text) == 'string' and (card_text:find("{C:", 1, true) or card_text:find("{T:", 1, true))
        card_list[#card_list + 1] = has_native_markup and card_text or (start_string .. card_text .. end_string)
    end
    return card_list
end

local function format_card_list(list, color)
    if not list then return "ERROR" end
    local card_list = {}
    local start_string = color and "{C:" .. color .. "}" or ''
    local end_string = color and "{}" or ''
    for _, card in ipairs(list or {}) do
        local card_text = format_card(card)
        local has_native_markup = type(card_text) == 'string' and (card_text:find("{C:", 1, true) or card_text:find("{T:", 1, true))
        card_list[#card_list + 1] = has_native_markup and card_text or (start_string .. card_text .. end_string)
    end
    return card_list
end

PlayLog.LogType {
    key = "started",
    get_message = function(self, args)
        if args.challenge then
            return PlayLog.localize("started_challenge",
                { localize(args.challenge, 'challenge_names'), PlayLog.loc_list(format_exact_playing_card_list(args.modifiers,
                    "attention")) })
        end
        return PlayLog.localize("started", { PlayLog.loc_list(format_exact_playing_card_list(args.modifiers, "attention")) })
    end
}

PlayLog.LogType {
    key = "resume",
    get_message = function(self, args)
        return PlayLog.localize("resumed")
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
        return PlayLog.localize("creates",
            { format_card(args.card), PlayLog.loc_list(format_exact_playing_card_list(args.created, "attention")) })
    end
}

PlayLog.LogType {
    key = "destroys",
    get_message = function(self, args)
        return PlayLog.localize("destroys",
            { format_card(args.card), PlayLog.loc_list(format_exact_playing_card_list(args.destroyed, "attention")) })
    end
}

PlayLog.LogType {
    key = "copies",
    get_message = function(self, args)
        if args.copied_to then
            return PlayLog.localize("copies_into",
                { format_card(args.card), PlayLog.loc_list(format_exact_playing_card_list(args.copied, "attention")),
                    PlayLog.loc_list(format_exact_playing_card_list(args.copied_to, "attention")) })
        end
        return PlayLog.localize("copies",
            { format_card(args.card), PlayLog.loc_list(format_exact_playing_card_list(args.copied, "attention")) })
    end
}

PlayLog.LogType {
    key = "added",
    get_message = function(self, args)
        if args.area then
            return PlayLog.localize("added_to",
                { args.cards and PlayLog.loc_list(format_exact_playing_card_list(args.cards, "attention")) or format_card(args.card),
                    PlayLog.get_area_name(args.area) })
        end
        return PlayLog.localize("added",
            { args.cards and PlayLog.loc_list(format_exact_playing_card_list(args.cards, "attention")) or format_card(args.card) })
    end
}

PlayLog.LogType {
    key = "added_to_shop",
    get_message = function(self, args)
        return PlayLog.localize("added_to_shop",
            { format_card(args.card), PlayLog.loc_list(format_card_list(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "converts",
    get_message = function(self, args)
        local conversion
        if args.enhancement then
            conversion = format_center_from_key(args.enhancement)
        elseif args.suit then
            conversion = "{C:" .. args.suit:lower() .. "}" .. localize(args.suit, "suits_plural") .. "{}"
        elseif args.rank then
            conversion = localize(args.rank, "ranks")
        end

        return PlayLog.localize("converts",
            { format_card(args.card), PlayLog.loc_list(format_exact_playing_card_list(args.converted, "attention")), conversion or
            "ERROR" })
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
                conversion = "{C:" .. args.suits[i]:lower() .. "}" .. localize(args.suits[i], "suits_plural") .. "{}"
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
            conversion = format_center_from_key(args.seal)
        elseif args.sticker then
            conversion = localize(args.sticker, "labels")
        end

        return PlayLog.localize("applied",
            { format_card(args.card), PlayLog.loc_list(format_exact_playing_card_list(args.applied, "attention")), conversion or
            "ERROR" })
    end
}

PlayLog.LogType {
    key = "money",
    get_message = function(self, args)
        if args.amount < 0 then
            return PlayLog.localize("money_taken",
                args.card and { format_card(args.card), math.abs(args.amount) } or { math.abs(args.amount) })
        end
        return PlayLog.localize("money", args.card and { format_card(args.card), args.amount } or { args.amount })
    end
}

PlayLog.LogType {
    key = "money_altered",
    get_message = function(self, args)
        return PlayLog.localize("money_altered", { args.previous, args.current })
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
        local old_hover = args.old_level_func or 'hand_level_snapshot_old'
        local new_hover = args.new_level_func or 'hand_level_snapshot_new'
        local arrow_hover = args.arrow_func or 'hand_level_snapshot_arrow'

        local levels_text = localize('k_level_prefix') .. "{F:" .. old_hover .. "}{C:red}"
            .. tostring(args.old_level or "?") .. "{}{} {F:" .. arrow_hover .. "}->{} {F:" .. new_hover .. "}{C:red}"
            .. tostring(args.new_level or "?") .. "{}{}"
        if args.old_level and args.new_level and args.new_level < args.old_level then
            return PlayLog.localize("hand_level_down", { localize(args.poker_hand, 'poker_hands'), levels_text })
        end
        return PlayLog.localize("hand_level_up", { localize(args.poker_hand, 'poker_hands'), levels_text })
    end
}

PlayLog.LogType {
    key = "leveled_up",
    get_message = function(self, args)
        local hand_list = {}
        if #G.handlist == #args.poker_hands then
            hand_list[#hand_list + 1] = PlayLog.localize("all_hands")
        else
            for _, hand in ipairs(args.poker_hands) do
                hand_list[#hand_list + 1] = "{C:attention}" .. localize(hand, 'poker_hands') .. "{}"
            end
        end
        return PlayLog.localize("leveled_up", { format_card(args.card), PlayLog.loc_list(hand_list) })
    end
}

PlayLog.LogType {
    key = "leveled_down",
    get_message = function(self, args)
        local hand_list = {}
        if #G.handlist == #args.poker_hands then
            hand_list[#hand_list + 1] = PlayLog.localize("all_hands")
        else
            for _, hand in ipairs(args.poker_hands) do
                hand_list[#hand_list + 1] = "{C:attention}" .. localize(hand, 'poker_hands') .. "{}"
            end
        end
        return PlayLog.localize("leveled_down", { format_card(args.card), PlayLog.loc_list(hand_list) })
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
            { PlayLog.get_area_name(args.area), args.old_size, args.new_size })
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
    key = "use",
    get_message = function(self, args)
        return PlayLog.localize("used", { format_card(args.card) })
    end
}

PlayLog.LogType {
    key = "booster_opened",
    get_message = function(self, args)
        return PlayLog.localize("booster_opened",
            { format_card(args.booster), PlayLog.loc_list(format_exact_playing_card_list(args.cards, "attention")) })
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

PlayLog.LogType {
    key = "options",
    get_message = function(self, args)
        return PlayLog.localize("mod_options", { args.mod, PlayLog.loc_list(args.options) })
    end
}

PlayLog.LogType {
    key = "reroll_shop",
    get_message = function(self, args)
        return PlayLog.localize("reroll_shop",
            { args.amount, PlayLog.loc_list(format_exact_playing_card_list(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "reroll_shop_into",
    get_message = function(self, args)
        return PlayLog.localize("reroll_shop_into",
            { PlayLog.loc_list(format_exact_playing_card_list(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "starting_shop",
    get_message = function(self, args)
        return PlayLog.localize("starting_shop",
            { PlayLog.loc_list(format_exact_playing_card_list(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "ending_shop",
    get_message = function(self, args)
        return PlayLog.localize("ending_shop")
    end
}

PlayLog.LogType {
    key = "tag_applied",
    get_message = function(self, args)
        return PlayLog.localize("tag_applied", { format_card(args.tag) })
    end
}

PlayLog.LogType {
    key = "reroll_boss",
    get_message = function(self, args)
        return PlayLog.localize("reroll_boss", { format_card(args.old_boss), format_card(args.new_boss) })
    end
}

PlayLog.LogType {
    key = "hand_played",
    get_message = function(self, args)
        return PlayLog.localize("hand_played",
            { localize(args.poker_hand, "poker_hands"), PlayLog.loc_list(format_exact_playing_card_list(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "hand_played_as",
    get_message = function(self, args)
        return PlayLog.localize("hand_played_as", { localize(args.poker_hand, "poker_hands") })
    end
}

PlayLog.LogType {
    key = "hand_scored",
    get_message = function(self, args)
        return PlayLog.localize("hand_scored", { args.amount, args.score, args.to_beat })
    end
}

PlayLog.LogType {
    key = "discarded",
    get_message = function(self, args)
        return PlayLog.localize("discarded",
            { PlayLog.loc_list(format_exact_playing_card_list(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "hand_drawn",
    get_message = function(self, args)
        return PlayLog.localize("hand_drawn",
            { PlayLog.loc_list(format_exact_playing_card_list(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "score_to_beat",
    get_message = function(self, args)
        return PlayLog.localize("score_to_beat", { args.amount })
    end
}

PlayLog.LogType {
    key = "debuffed_hand",
    get_message = function(self, args)
        return PlayLog.localize("debuffed_hand", { localize(args.poker_hand, "poker_hands") })
    end
}

PlayLog.LogType {
    key = "selected_card",
    get_message = function(self, args)
        return PlayLog.localize("selected_card",
            { format_card(args.card), PlayLog.loc_list(format_exact_playing_card_list(args.cards, "attention")) })
    end
}
