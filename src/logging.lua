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
end

SMODS.current_mod.reset_game_globals = function(run_start)
    if run_start then
        PlayLog.log { type = "started", deck = G.GAME.selected_back_key.key, stake = G.P_CENTER_POOLS.Stake[G.GAME.stake].key, challenge = G.GAME.challenge }
    end
end

local SMODS_upgrade_poker_hands_ref = SMODS.upgrade_poker_hands
function SMODS.upgrade_poker_hands(args, ...)
    local ret = SMODS_upgrade_poker_hands_ref(args, ...)
    if args.from and args.from.config.center_key ~= "c_black_hole" then
        PlayLog.log { type = "leveled_up", hands = args.hands, card = args.from }
    end
    return ret
end

local cardarea_change_size_ref = CardArea.change_size
function CardArea:change_size(delta, ...)
    local ret = cardarea_change_size_ref(self, delta, ...)
    if PlayLog.get_area_name(self) then PlayLog.log { type = "area_size", area = self, amount = delta } end
    return ret
end
