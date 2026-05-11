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
    if card.playing_card or card.config.center.set == "Default" or card.config.center.set == "Enhanced" then
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
        local has_native_markup = type(card_text) == 'string' and
            (card_text:find("{C:", 1, true) or card_text:find("{T:", 1, true))
        card_list[#card_list + 1] = has_native_markup and card_text or (start_string .. card_text .. end_string)
    end
    return card_list
end

---Formats a list of objects or strings into the PlayLog format
---@param list (Card|Blind|Tag|SMODS.Center|SMODS.Seal|SMODS.Blind|SMODS.Tag|table|string)[] List of objects to parse, strings that are object keys get parsed correctly
---@param default_color string? Default color if type is not found in Balatro's localization format
---@return string|table
PlayLog.format_objects = function(list, default_color)
    return format_exact_playing_card_list(list, default_color)
end

---Formats an object or string into the PlayLog format
---@param object Card|Blind|Tag|SMODS.Center|SMODS.Seal|SMODS.Blind|SMODS.Tag|table|string Object to parse, strings that are object keys get parsed correctly
---@return string|table
PlayLog.format_object = function(object, default_color)
    return format_exact_playing_card(object)
end

PlayLog.LogType {
    key = "started",
    get_message = function(self, args)
        if args.challenge then
            return PlayLog.localize("started_challenge",
                { localize(args.challenge, 'challenge_names'), PlayLog.loc_list(PlayLog.format_objects(
                    args.modifiers,
                    "attention")) })
        end
        return PlayLog.localize("started",
            { PlayLog.loc_list(PlayLog.format_objects(args.modifiers, "attention")) })
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
        return PlayLog.localize("selected_blind", { PlayLog.format_object(args.blind) })
    end
}

PlayLog.LogType {
    key = "defeated_blind",
    get_message = function(self, args)
        return PlayLog.localize("defeated_blind", { PlayLog.format_object(args.blind) })
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
                { PlayLog.format_object(args.blind), PlayLog.format_object(args.tag) })
        end
        return PlayLog.localize("skip_blind", { PlayLog.format_object(args.blind) })
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
            { PlayLog.format_object(args.card), PlayLog.loc_list(PlayLog.format_objects(args.created, "attention")) })
    end
}

PlayLog.LogType {
    key = "destroys",
    get_message = function(self, args)
        return PlayLog.localize("destroys",
            { PlayLog.format_object(args.card), PlayLog.loc_list(PlayLog.format_objects(args.destroyed, "attention")) })
    end
}

PlayLog.LogType {
    key = "copies",
    get_message = function(self, args)
        if args.copied_to then
            return PlayLog.localize("copies_into",
                { PlayLog.format_object(args.card), PlayLog.loc_list(PlayLog.format_objects(args.copied, "attention")),
                    PlayLog.loc_list(PlayLog.format_objects(args.copied_to, "attention")) })
        end
        return PlayLog.localize("copies",
            { PlayLog.format_object(args.card), PlayLog.loc_list(PlayLog.format_objects(args.copied, "attention")) })
    end
}

PlayLog.LogType {
    key = "added",
    get_message = function(self, args)
        if args.area then
            return PlayLog.localize("added_to",
                { args.cards and PlayLog.loc_list(PlayLog.format_objects(args.cards, "attention")) or
                PlayLog.format_object(args.card),
                    PlayLog.get_area_name(args.area) })
        end
        return PlayLog.localize("added",
            { args.cards and PlayLog.loc_list(PlayLog.format_objects(args.cards, "attention")) or
            PlayLog.format_object(args.card) })
    end
}

PlayLog.LogType {
    key = "added_to_shop",
    get_message = function(self, args)
        return PlayLog.localize("added_to_shop",
            { PlayLog.format_object(args.card), PlayLog.loc_list(PlayLog.format_objects(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "converts",
    get_message = function(self, args)
        local conversion = args.conversion
        if args.enhancement then
            conversion = PlayLog.format_object(args.enhancement)
        elseif args.suit then
            conversion = "{C:" .. args.suit:lower() .. "}" .. localize(args.suit, "suits_plural") .. "{}"
        elseif args.rank then
            conversion = localize(args.rank, "ranks")
        end

        return PlayLog.localize("converts",
            { PlayLog.format_object(args.card), PlayLog.loc_list(PlayLog.format_objects(args.converted, "attention")),
                conversion or
                "ERROR" })
    end
}

PlayLog.LogType {
    key = "converts_multiple",
    get_message = function(self, args)
        local conversions = args.conversions or {}
        for i, card in ipairs(args.converted) do
            local conversion
            if args.enhancements then
                conversion = PlayLog.format_object(args.enhancements[i])
            elseif args.suits then
                conversion = "{C:" .. args.suits[i]:lower() .. "}" .. localize(args.suits[i], "suits_plural") .. "{}"
            elseif args.ranks then
                conversion = localize(args.ranks[i], "ranks")
            end
            conversions[#conversions + 1] = PlayLog.localize("converts_individual",
                { PlayLog.format_object(card), conversion or "ERROR" })
        end

        return PlayLog.localize("converts_multiple",
            { PlayLog.format_object(args.card), PlayLog.loc_list(conversions) })
    end
}

PlayLog.LogType {
    key = "applied",
    get_message = function(self, args)
        local conversion = args.conversion
        if args.edition then
            conversion = PlayLog.format_object(args.edition)
        elseif args.seal then
            conversion = PlayLog.format_object(args.seal)
        elseif args.sticker then
            conversion = localize(args.sticker, "labels")
        end

        return PlayLog.localize("applied",
            { PlayLog.format_object(args.card), PlayLog.loc_list(PlayLog.format_objects(args.applied, "attention")),
                conversion or
                "ERROR" })
    end
}

PlayLog.LogType {
    key = "removed_modifier",
    get_message = function(self, args)
        local conversion = args.conversion
        if args.edition then
            conversion = PlayLog.format_object(args.edition)
        elseif args.seal then
            conversion = PlayLog.format_object(args.seal)
        elseif args.sticker then
            conversion = localize(args.sticker, "labels")
        elseif args.enhancement then
            conversion = PlayLog.format_object(args.enhancement)
        end
        return PlayLog.localize("removed_modifier",
            { PlayLog.format_object(args.card),
                PlayLog.loc_list(PlayLog.format_objects(args.targets, "attention")),
                conversion })
    end
}

PlayLog.LogType {
    key = "money",
    get_message = function(self, args)
        if args.amount < 0 then
            return PlayLog.localize("money_taken",
                args.card and { PlayLog.format_object(args.card), math.abs(args.amount) } or { math.abs(args.amount) })
        end
        return PlayLog.localize("money",
            args.card and { PlayLog.format_object(args.card), args.amount } or { args.amount })
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
        return PlayLog.localize("noped", { PlayLog.format_object(args.card) })
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
        return PlayLog.localize("leveled_up", { PlayLog.format_object(args.card), PlayLog.loc_list(hand_list) })
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
        return PlayLog.localize("leveled_down", { PlayLog.format_object(args.card), PlayLog.loc_list(hand_list) })
    end
}

PlayLog.LogType {
    key = "change_area_size",
    get_message = function(self, args)
        if args.amount < 0 then
            return PlayLog.localize("change_area_size_neg",
                { PlayLog.format_object(args.card), PlayLog.get_area_name(args.area), math.abs(args.amount) })
        end
        return PlayLog.localize("change_area_size",
            { PlayLog.format_object(args.card), PlayLog.get_area_name(args.area), args.amount })
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
        return PlayLog.localize("sell", { PlayLog.format_object(args.card), args.amount })
    end
}

PlayLog.LogType {
    key = "buy",
    get_message = function(self, args)
        return PlayLog.localize("buy", { PlayLog.format_object(args.card), args.amount })
    end
}

PlayLog.LogType {
    key = "use",
    get_message = function(self, args)
        return PlayLog.localize("used", { PlayLog.format_object(args.card) })
    end
}

PlayLog.LogType {
    key = "booster_opened",
    get_message = function(self, args)
        return PlayLog.localize("booster_opened",
            { PlayLog.format_object(args.booster), PlayLog.loc_list(PlayLog.format_objects(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "booster_skipped",
    get_message = function(self, args)
        return PlayLog.localize("booster_skipped", { PlayLog.format_object(args.booster) })
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
            { args.amount, PlayLog.loc_list(PlayLog.format_objects(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "reroll_shop_into",
    get_message = function(self, args)
        return PlayLog.localize("reroll_shop_into",
            { PlayLog.loc_list(PlayLog.format_objects(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "starting_shop",
    get_message = function(self, args)
        return PlayLog.localize("starting_shop",
            { PlayLog.loc_list(PlayLog.format_objects(args.cards, "attention")) })
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
        return PlayLog.localize("tag_applied", { PlayLog.format_object(args.tag) })
    end
}

PlayLog.LogType {
    key = "reroll_boss",
    get_message = function(self, args)
        return PlayLog.localize("reroll_boss",
            { PlayLog.format_object(args.old_boss), PlayLog.format_object(args.new_boss) })
    end
}

PlayLog.LogType {
    key = "hand_played",
    get_message = function(self, args)
        return PlayLog.localize("hand_played",
            { localize(args.poker_hand, "poker_hands"), PlayLog.loc_list(PlayLog.format_objects(args.cards,
                "attention")) })
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
            { PlayLog.loc_list(PlayLog.format_objects(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "hand_drawn",
    get_message = function(self, args)
        return PlayLog.localize("hand_drawn",
            { PlayLog.loc_list(PlayLog.format_objects(args.cards, "attention")) })
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
            { PlayLog.format_object(args.card), PlayLog.loc_list(PlayLog.format_objects(args.cards, "attention")) })
    end
}

PlayLog.LogType {
    key = "changed_sell_cost",
    get_message = function(self, args)
        return PlayLog.localize("changed_sell_cost",
            { PlayLog.format_object(args.card), args.previous, args.current })
    end
}

PlayLog.LogType {
    key = "target_changed",
    get_message = function(self, args)
        return PlayLog.localize("target_changed",
            { PlayLog.format_object(args.card), PlayLog.loc_list(PlayLog.format_objects(args.targets, "attention")) })
    end
}

PlayLog.LogType {
    key = "blind_disabled",
    get_message = function(self, args)
        return PlayLog.localize("blind_disabled",
            { PlayLog.format_object(args.blind) })
    end
}

PlayLog.LogType {
    key = "saved",
    get_message = function(self, args)
        return PlayLog.localize("saved",
            { PlayLog.format_object(args.card) })
    end
}

PlayLog.LogType {
    key = "eaten",
    get_message = function(self, args)
        return PlayLog.localize(args.food_type or "eaten",
            { PlayLog.format_object(args.card) })
    end
}

PlayLog.LogType {
    key = "rental",
    get_message = function(self, args)
        return PlayLog.localize("rental",
            { PlayLog.format_object(args.card), args.amount })
    end
}

PlayLog.LogType {
    key = "perishable",
    get_message = function(self, args)
        return PlayLog.localize("perishable",
            { PlayLog.format_object(args.card), args.amount })
    end
}

PlayLog.LogType {
    key = "perished",
    get_message = function(self, args)
        return PlayLog.localize("perished",
            { PlayLog.format_object(args.card) })
    end
}

PlayLog.LogType {
    key = "scale",
    get_message = function(self, args)
        args.infer_colour = args.infer_colour or "none"
        local colour = "{C:attention}"
        local should_be_x
        if args.infer_colour then
            local inferred_colours = {
                mult = "mult",
                chips = "chips",
                dollars = "money",
                extra_value = "money"
            }
            local inferred_borders = {
                caino_xmult = "mult",
                xmult = "mult",
                x_mult = "mult",
                Xmult = "mult",
                xchips = "chips",
                x_chips = "chips",
                Xchips = "chips"
            }
            if inferred_colours[args.infer_colour] then
                colour = "{C:" .. inferred_colours[args.infer_colour] .. "}"
            end
            if inferred_borders[args.infer_colour] then
                should_be_x = true
                colour = "{X:" .. inferred_borders[args.infer_colour] .. ",C:white}"
            end
        end
        local colour_end = colour and "{}" or ""
        local format_value = function(value)
            return colour .. (should_be_x and "X" or (value > 0 and "+" or '')) .. value .. colour_end
        end
        if not args.previous or not args.current then
            return PlayLog.localize("scale_by",
                { PlayLog.format_object(args.card), format_value(args.amount) })
        end
        return PlayLog.localize("scale",
            { PlayLog.format_object(args.card),
                format_value(args.previous), format_value(args.current) })
    end
}

PlayLog.LogType {
    key = "reset",
    get_message = function(self, args)
        return PlayLog.localize("reset",
            { PlayLog.format_object(args.card) })
    end
}
