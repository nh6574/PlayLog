-- GENERAL LOGS
PlayLog.temp = {}

SMODS.current_mod.calculate = function(self, context)
    if context.card_added then
        local card = context.card
        if not card then return end
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "added", card = card, area = card.area }
                return true
            end
        }))
    end

    if context.tag_added then
        local tag = context.tag_added.key
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "added", card = tag }
                return true
            end
        }))
    end

    if context.tag_triggered then
        local tag = context.tag_triggered.key
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "tag_applied", tag = tag }
                return true
            end
        }))
    end

    if context.poker_hand_changed then
        local scoring_name = context.scoring_name
        local old_level, new_level = context.old_level, context.new_level
        local card = context.card
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "hand_level_up", hand = scoring_name, old_level = old_level, new_level = new_level, card = card }
                return true
            end
        }))
    end

    if context.playing_card_added then
        local cards = context.cards
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "added", cards = cards, area = (cards[1] or {}).area }
                return true
            end
        }))
    end

    if context.using_consumeable then
        PlayLog.log { type = "use", card = context.consumeable }
    end

    if context.reroll_shop then
        local cost = context.cost
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "reroll_shop", amount = cost, cards = G.shop_jokers.cards }
                return true
            end
        }))
    end

    if context.setting_blind then
        PlayLog.log { type = "selected_blind", blind = G.GAME.blind.config.blind.key }
        PlayLog.log { type = "start_round", round = G.GAME.round }
    end

    if context.end_of_round and context.game_over == false then
        PlayLog.log { type = "defeated_blind", blind = G.GAME.blind.config.blind.key }
    end

    if context.selling_card then
        PlayLog.log { type = "sell", card = context.card, amount = context.card.sell_cost }
    end

    if context.buying_card then
        PlayLog.log { type = "buy", card = context.card, amount = context.card.cost }
    end

    if context.open_booster then
        local card = context.card
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "booster_opened", booster = card, cards = G.pack_cards.cards }
                return true
            end
        }))
    end

    if context.starting_shop then
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "starting_shop", cards = PlayLog.get_shop_area_cards() }
                return true
            end
        }))
    end

    if context.ending_shop then
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "ending_shop" }
                return true
            end
        }))
    end

    if context.skipping_booster then
        PlayLog.log { type = "booster_skipped", booster = context.booster.key }
    end

    if context.ante_change then
        local ante_change = context.ante_change
        local ante_end = context.ante_end
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "start_ante", ante = G.GAME.round_resets.ante + ante_change, modified = not ante_end and ante_change }
                return true
            end
        }))
    end

    if context.pre_discard then
        local cards = context.full_hand
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "discarded", cards = cards }
                return true
            end
        }))
    end

    if context.hand_drawn then
        local cards = context.hand_drawn
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "hand_drawn", cards = cards }
                return true
            end
        }))
    end

    if context.press_play then
        local text, _ = G.FUNCS.get_poker_hand_info(G.hand.highlighted)
        PlayLog.played_hand = text
        PlayLog.log { type = "hand_played", cards = G.hand.highlighted, poker_hand = text }
    end

    if context.before then
        local scoring_name = context.scoring_name
        G.E_MANAGER:add_event(Event({
            func = function()
                if PlayLog.played_hand and scoring_name ~= PlayLog.played_hand then
                    PlayLog.log { type = "hand_played_as", poker_hand = scoring_name }
                end
                PlayLog.played_hand = nil
                return true
            end
        }))
    end

    if context.after then
        local amount = SMODS.calculate_round_score()
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "hand_scored", amount = amount, score = G.GAME.chips }
                return true
            end
        }))
    end
end

SMODS.current_mod.reset_game_globals = function(run_start)
    if run_start then
        if PlayLog.log_store and PlayLog.log_store.begin_new_run then
            PlayLog.log_store.begin_new_run()
        end
        PlayLog.log { type = "started", modifiers = PlayLog.get_run_modifiers(), challenge = G.GAME.challenge }
        PlayLog.run_options()
        PlayLog.log { type = "start_ante", ante = G.GAME.round_resets.ante }
    end
end

---Called at the start of the run, hook for adding logs
function PlayLog.run_options()
    -- Example:
    -- PlayLog.log { type = "options", mod = localize { type = 'name_text', set = 'Mod', key = "PlayLog" }, options = {"Log", "Only Mult Jokers", "Funky Mode"}  }
    -- This will say "PlayLog: Log, Only Mult Jokers and Funky Mode enabled"
end

local SMODS_upgrade_poker_hands_ref = SMODS.upgrade_poker_hands
function SMODS.upgrade_poker_hands(args, ...)
    local ret = SMODS_upgrade_poker_hands_ref(args, ...)
    if args.from and args.from.config.center_key ~= "c_black_hole" then
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "leveled_up", hands = args.hands, card = args.from.key or args.from }
                return true
            end
        }))
    end
    return ret
end

local cardarea_change_size_ref = CardArea.change_size
function CardArea:change_size(delta, ...)
    local ret = cardarea_change_size_ref(self, delta, ...)
    if PlayLog.get_area_name(self) then PlayLog.log { type = "area_size", area = self, amount = delta } end
    return ret
end

local win_game_ref = win_game
function win_game(...)
    PlayLog.log { type = "win" }
    return win_game_ref(...)
end

local change_shop_size_ref = change_shop_size
function change_shop_size(mod, ...)
    local ret = change_shop_size_ref(mod, ...)

    G.E_MANAGER:add_event(Event({
        func = function()
            PlayLog.log { type = "area_size", area = G.shop_jokers, amount = mod }
            if mod > 0 and G.shop_jokers then
                PlayLog.log { type = "reroll_shop_into", cards = G.shop_jokers.cards }
            end
            return true
        end
    }))

    return ret
end

local smods_change_voucher_limit_ref = SMODS.change_voucher_limit
function SMODS.change_voucher_limit(mod, ...)
    local ret = smods_change_voucher_limit_ref(mod, ...)
    G.E_MANAGER:add_event(Event({
        func = function()
            PlayLog.log { type = "area_size", area = G.shop_vouchers, amount = mod }
            if mod > 0 and G.shop_vouchers then
                PlayLog.log { type = "reroll_shop_into", cards = G.shop_vouchers.cards }
            end
            return true
        end
    }))
    return ret
end

local smods_change_booster_limit_ref = SMODS.change_booster_limit
function SMODS.change_booster_limit(mod, ...)
    local ret = smods_change_booster_limit_ref(mod, ...)
    G.E_MANAGER:add_event(Event({
        func = function()
            PlayLog.log { type = "area_size", area = G.shop_booster, amount = mod }
            if mod > 0 and G.shop_booster then
                PlayLog.log { type = "reroll_shop_into", cards = G.shop_booster.cards }
            end
            return true
        end
    }))
    return ret
end

local game_start_run_ref = Game.start_run
function Game:start_run(args, ...)
    local ret = game_start_run_ref(self, args, ...)

    if args.savetext then
        PlayLog.log { type = "resume" }
    end
    return ret
end

local g_funcs_reroll_boss = G.FUNCS.reroll_boss
G.FUNCS.reroll_boss = function(e)
    local old_boss = G.GAME.round_resets.blind_choices.Boss
    g_funcs_reroll_boss(e)
    G.E_MANAGER:add_event(Event({
        func = function()
            PlayLog.log { type = "reroll_boss", old_boss = old_boss, new_boss = G.GAME.round_resets.blind_choices.Boss }
            return true
        end
    }))
end
