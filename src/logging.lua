-- GENERAL LOGS
PlayLog.temp = {}

local function pl_snapshot_hand_state(hand_state)
    if type(hand_state) ~= 'table' then return nil end
    local level = tonumber(hand_state.level)
    local chips = tonumber(hand_state.chips)
    local mult = tonumber(hand_state.mult)

    if chips == nil then
        local s_chips = tonumber(hand_state.s_chips)
        local l_chips = tonumber(hand_state.l_chips)
        if s_chips and l_chips and level then
            chips = s_chips + l_chips * math.max(level - 1, 0)
        end
    end

    if mult == nil then
        local s_mult = tonumber(hand_state.s_mult)
        local l_mult = tonumber(hand_state.l_mult)
        if s_mult and l_mult and level then
            mult = s_mult + l_mult * math.max(level - 1, 0)
        end
    end

    return {
        level = level,
        chips = chips,
        mult = mult,
    }
end

local function pl_capture_all_hand_snapshots()
    if not (G and G.GAME and G.GAME.hands) then return end
    PlayLog.temp = type(PlayLog.temp) == 'table' and PlayLog.temp or {}
    PlayLog.temp.hand_snapshots = {}
    local hand_list = (G and G.handlist) or {}
    for i = 1, #hand_list do
        local hand_key = hand_list[i]
        local snap = pl_snapshot_hand_state(G.GAME.hands[hand_key])
        if snap then
            PlayLog.temp.hand_snapshots[hand_key] = snap
        end
    end
end

local function pl_ensure_hand_snapshots()
    PlayLog.temp = type(PlayLog.temp) == 'table' and PlayLog.temp or {}
    if type(PlayLog.temp.hand_snapshots) ~= 'table' or next(PlayLog.temp.hand_snapshots) == nil then
        pl_capture_all_hand_snapshots()
    end
end

local function pl_build_hand_level_snapshot(payload)
    payload = type(payload) == 'table' and payload or {}
    local hand_key = payload.hand or ''
    local hand_name = (hand_key ~= '' and localize(hand_key, 'poker_hands')) or hand_key or '?'
    local view_mode = tostring(payload.view or 'both')
    local old_level = payload.old_level or '?'
    local new_level = payload.new_level or '?'
    local old_chips = tonumber(payload.old_chips)
    local new_chips = tonumber(payload.new_chips)
    local old_mult = tonumber(payload.old_mult)
    local new_mult = tonumber(payload.new_mult)
    local function fmt(v)
        return v ~= nil and tostring(type(v) == "number" and number_format(v, 1000000) or v) or '?'
    end
    local function T(text, colour, scale)
        return {
            n = G.UIT.T,
            config = { text = text, scale = scale or 0.4, colour = colour, shadow = true }
        }
    end
    local function pill(text, bg_colour, scale)
        return {
            n = G.UIT.C,
            config = { align = 'cm', colour = bg_colour, r = 0.12, padding = 0.07 },
            nodes = { T(text, G.C.WHITE, scale or 0.4) }
        }
    end
    local function spacer()
        return {
            n = G.UIT.C,
            config = { align = 'cm', colour = G.C.CLEAR, minw = 0.06 },
            nodes = {}
        }
    end
    local function stat_row(level, chips, mult)
        return {
            {
                n = G.UIT.C,
                config = { align = "cm", padding = 0.01, r = 0.1, colour = G.C.HAND_LEVELS[math.min(7, tonumber(level))], minw = 1.5, outline = 0.8, outline_colour = G.C.WHITE },
                nodes = {
                    { n = G.UIT.T, config = { text = localize('k_level_prefix') .. level, scale = 0.5, colour = G.C.UI.TEXT_DARK } }
                }
            },
            spacer(),
            {
                n = G.UIT.C,
                config = { align = "cm", padding = 0.05, colour = G.C.BLACK, r = 0.1 },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cr", padding = 0.01, r = 0.1, colour = G.C.CHIPS, minw = 1.1 },
                        nodes = {
                            { n = G.UIT.T, config = { text = fmt(chips), scale = 0.45, colour = G.C.UI.TEXT_LIGHT } },
                            { n = G.UIT.B, config = { w = 0.08, h = 0.01 } }
                        }
                    },
                    { n = G.UIT.T, config = { text = "X", scale = 0.45, colour = G.C.MULT } },
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.01, r = 0.1, colour = G.C.MULT, minw = 1.1 },
                        nodes = {
                            { n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
                            { n = G.UIT.T, config = { text = fmt(mult), scale = 0.45, colour = G.C.UI.TEXT_LIGHT } }
                        }
                    }
                }
            }
        }
    end
    if view_mode == 'old' then
        return { title = hand_name, rows = { stat_row(old_level, old_chips, old_mult) } }
    elseif view_mode == 'new' then
        return { title = hand_name, rows = { stat_row(new_level, new_chips, new_mult) } }
    else
        local mult_delta = (tonumber(new_mult) or 0) - (tonumber(old_mult) or 0)
        local chip_delta = (tonumber(new_chips) or 0) - (tonumber(old_chips) or 0)
        local mult_sign = mult_delta > 0 and '+' or ''
        local chip_sign = chip_delta > 0 and '+' or ''
        return {
            title = hand_name,
            rows = {
                stat_row(old_level, old_chips, old_mult),
                stat_row(new_level, new_chips, new_mult),
                {
                    pill(chip_sign .. fmt(chip_delta) .. ' chips', G.C.CHIPS, 0.32),
                    spacer(),
                    pill(mult_sign .. fmt(mult_delta) .. ' mult', G.C.MULT, 0.32),
                },
            }
        }
    end
end

PlayLog.FUNCS.hand_level_snapshot_old = pl_build_hand_level_snapshot
PlayLog.FUNCS.hand_level_snapshot_new = pl_build_hand_level_snapshot
PlayLog.FUNCS.hand_level_snapshot_arrow = pl_build_hand_level_snapshot

--[[
    TODO: Logs missing:
    - Hand/discard amount changed (likely needs metatables)
]]

SMODS.current_mod.calculate = function(self, context)
    pl_ensure_hand_snapshots()

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
        local card = context.card
        local hand_key = context.scoring_name
        local old_level = context.old_level
        local new_level = context.new_level
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.temp = type(PlayLog.temp) == 'table' and PlayLog.temp or {}
                PlayLog.temp.hand_snapshots = type(PlayLog.temp.hand_snapshots) == 'table'
                    and PlayLog.temp.hand_snapshots or {}

                local old_state = PlayLog.temp.hand_snapshots[hand_key]
                local hand_now = (G and G.GAME and G.GAME.hands and G.GAME.hands[hand_key]) or nil
                local new_state = pl_snapshot_hand_state(hand_now) or {}
                if not old_state then
                    old_state = {
                        level = tonumber(old_level),
                        chips = tonumber(new_state.chips),
                        mult = tonumber(new_state.mult),
                    }
                end
                old_level = tonumber(old_state.level) or tonumber(old_level)
                new_level = tonumber(new_state.level) or tonumber(new_level)
                local old_chips = tonumber(old_state.chips)
                local new_chips = tonumber(new_state.chips)
                local old_mult = tonumber(old_state.mult)
                local new_mult = tonumber(new_state.mult)
                local common_payload = {
                    hand = hand_key,
                    old_level = old_level,
                    new_level = new_level,
                    old_chips = old_chips,
                    new_chips = new_chips,
                    old_mult = old_mult,
                    new_mult = new_mult,
                }
                local old_level_func = PlayLog.store_func_payload('hand_level_snapshot_old', {
                    hand = common_payload.hand,
                    view = 'old',
                    old_level = common_payload.old_level,
                    new_level = common_payload.new_level,
                    old_chips = common_payload.old_chips,
                    new_chips = common_payload.new_chips,
                    old_mult = common_payload.old_mult,
                    new_mult = common_payload.new_mult,
                })
                local new_level_func = PlayLog.store_func_payload('hand_level_snapshot_new', {
                    hand = common_payload.hand,
                    view = 'new',
                    old_level = common_payload.new_level,
                    new_level = common_payload.new_level,
                    old_chips = common_payload.old_chips,
                    new_chips = common_payload.new_chips,
                    old_mult = common_payload.old_mult,
                    new_mult = common_payload.new_mult,
                })
                local arrow_func = PlayLog.store_func_payload('hand_level_snapshot_arrow', {
                    hand = common_payload.hand,
                    view = 'both',
                    old_level = common_payload.old_level,
                    new_level = common_payload.new_level,
                    old_chips = common_payload.old_chips,
                    new_chips = common_payload.new_chips,
                    old_mult = common_payload.old_mult,
                    new_mult = common_payload.new_mult,
                })
                PlayLog.log {
                    type = "hand_level_up",
                    poker_hand = hand_key,
                    old_level = old_level,
                    new_level = new_level,
                    old_level_func = old_level_func,
                    new_level_func = new_level_func,
                    arrow_func = arrow_func,
                    card = card,
                }
                PlayLog.temp.hand_snapshots[hand_key] = {
                    level = new_level,
                    chips = new_chips,
                    mult = new_mult,
                }
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
        local blind_key = G.GAME.blind.config.blind.key
        PlayLog.log { type = "selected_blind", blind = blind_key }
        PlayLog.log { type = "start_round", round = G.GAME.round }
        PlayLog.log { type = "score_to_beat", amount = G.GAME.blind.chips }

        if blind_key == "bl_ox" then
            local desc = G.localization.descriptions.Blind.bl_ox.text
            local text = ""
            for i, line in ipairs(desc) do
                if type(line) == "string" then -- just to not break with modded localization changes
                    text = text .. line .. (i ~= #desc and " " or '')
                end
            end
            local handname = localize(G.GAME.current_round.most_played_poker_hand, "poker_hands")
            PlayLog.log { type = "message", text = text, vars = { handname } }
        end
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
        if context.card.cost ~= 0 then
            PlayLog.log { type = "buy", card = card, amount = context.card.cost }
        end
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
                PlayLog.log { type = "hand_scored", amount = amount, score = G.GAME.chips, to_beat = G.GAME.blind.chips }
                return true
            end
        }))
    end

    if context.money_altered then
        local amount = context.amount
        -- TODO: fix weird case with calling ease_dollars multiple times (the tooth...)
        if amount ~= 0 then
            G.E_MANAGER:add_event(Event({
                func = function()
                    G.E_MANAGER:add_event(Event({
                        func = function()
                            PlayLog.log { type = "money_altered", previous = G.GAME.dollars - amount, current = G.GAME.dollars }
                            return true
                        end
                    }))
                    return true
                end
            }))
        end
    end

    if context.debuffed_hand then
        local handname = context.scoring_name
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "debuffed_hand", poker_hand = handname }
                return true
            end
        }))
    end
end

SMODS.current_mod.reset_game_globals = function(run_start)
    if run_start then
        pl_capture_all_hand_snapshots()
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

local ease_hands_played_ref = ease_hands_played
function ease_hands_played(mod, instant, ...)
    local ret = ease_hands_played_ref(mod, instant, ...)
    if mod and mod > 0 then
        pl_capture_all_hand_snapshots()
    end
    return ret
end

local SMODS_upgrade_poker_hands_ref = SMODS.upgrade_poker_hands
function SMODS.upgrade_poker_hands(args, ...)
    local ret = SMODS_upgrade_poker_hands_ref(args, ...)
    if args.from and args.from.config.center_key ~= "c_black_hole" then
        G.E_MANAGER:add_event(Event({
            func = function()
                local from = args.from == G.GAME.blind.children.animatedSprite and G.GAME.blind or
                    type(args.from) == "table" and args.from.key or args.from

                PlayLog.log { type = (args.level_up or 1) > 0 and "leveled_up" or "leveled_down", poker_hands = args.hands, card = from }
                return true
            end
        }))
    end
    return ret
end

local cardarea_change_size_ref = CardArea.change_size
function CardArea:change_size(delta, ...)
    local ret = cardarea_change_size_ref(self, delta, ...)
    if PlayLog.get_area_name(self) then
        G.E_MANAGER:add_event(Event({
            func = function()
                PlayLog.log { type = "area_size", area = self, old_size = self.config.card_limit - delta, new_size = self.config.card_limit }
                return true
            end
        }))
    end
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

local blind_disable_ref = Blind.disable
function Blind:disable(...)
    if self.disabled then return blind_disable_ref(self, ...) end
    local ret = blind_disable_ref(self, ...)
    G.E_MANAGER:add_event(Event({
        func = function()
            PlayLog.log { type = "blind_disabled", blind = self.config.blind.key }
            return true
        end
    }))
    return ret
end
