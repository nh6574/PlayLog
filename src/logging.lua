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
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "added", card = context.tag_added.key }
                return true
            end
        }))
    end

    if context.poker_hand_changed then
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "hand_level_up", hand = context.scoring_name, old_level = context.old_level, new_level = context.new_level, card = context.card }
                return true
            end
        }))
    end

    if context.playing_card_added then
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "added", cards = context.cards, area = (context.cards[1] or {}).area }
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
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "booster_opened", booster = context.card, cards = G.pack_cards.cards }
                return true
            end
        }))
    end

    if context.skipping_booster then
        PlayLog.log { type = "booster_skipped", booster = context.booster.key }
    end

    if context.ante_change then
        PlayLog.log { type = "start_ante", ante = G.GAME.round_resets.ante + context.ante_change, modified = not context.ante_end and context.ante_change }
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
        PlayLog.log { type = "leveled_up", hands = args.hands, card = args.from.key or args.from }
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
