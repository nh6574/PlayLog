return {
    descriptions = {
        Mod = {
            PlayLog = {
                name = "PlayLog",
                text = {
                    "Adds a log to the game",
                    " ",
                    "Icon by {C:attention}J8-Bit"
                }
            }
        },
    },
    misc = {
        playlog = {
            -- Formatting
            separator = "#1#, #2#",
            end_separator = "#1# and #2#",
            rank_of_suit = "#1# of #2#",

            -- Areas
            joker_area = "joker slots",
            consumable_area = "consumable slots",
            hand_area = "hand",
            deck_area = "deck",
            shop_jokers_area = "shop",
            shop_vouchers_area = "voucher shop",
            shop_boosters_area = "booster shop",

            -- Others
            all_hands = "all hands",

            -- Logging
            started = "Started game on #1#",
            started_challenge = "Started {C:attention}#1#{} challenge on #2#",
            resumed = "Resumed game",
            mod_options = "{C:attention}#1#{}: #2# enabled",
            selected_blind = "Selected #1#",
            defeated_blind = "Defeated #1#",
            blind_disabled = "#1# disabled",
            skip_blind = "Skipped #1#",
            skip_blind_for = "Skipped #1# for #2#",
            start_round = "Started {C:attention}round #1#{}",
            start_ante = "Started {C:attention}Ante #1#{}",
            ante_modified = "{C:attention}Ante{} changed {C:red}#1#{} -> {C:red}#2#{}",
            cash_out = "{C:money}$#1#{} cash out",
            creates = "{C:attention}#1#{} created #2#",
            destroys = "{C:attention}#1#{} destroyed #2#",
            used = "{C:attention}#1#{} used",
            starting_shop = "Started {C:attention}shop{}\nShop contains: #1#",
            ending_shop = "Ended {C:attention}shop{}",
            reroll_shop = "Rerolled {C:attention}shop{} for {C:money}$#1#{} to #2#",
            reroll_shop_into = "Rerolled into: #1#",
            added = "{C:attention}#1#{} added",
            added_to = "{C:attention}#1#{} added to {C:attention}#2#",
            added_to_shop = "{C:attention}#1#{} added {C:attention}#2#{} to the {C:attention}shop{}",
            converts = "{C:attention}#1#{} turned #2# into {C:attention}#3#",
            converts_multiple = "{C:attention}#1#{} turned #2#",
            converts_individual = "#1# into {C:attention}#2#",
            applied = "{C:attention}#1#{} has applied {C:attention}#3#{} to #2#",
            removed_modifier = "{C:attention}#1#{} has removed {C:attention}#3#{} from #2#",
            copies = "{C:attention}#1#{} copied #2#",
            copies_into = "{C:attention}#1#{} turned #3# into #2#",
            money = "{C:attention}#1#{} gave {C:money}$#2#{}",
            money_taken = "{C:attention}#1#{} took {C:money}$#2#{}",
            noped = "{C:attention}#1#{} noped!",
            hand_level_up = "{C:attention}#1#{} leveled up #2#",
            hand_level_down = "{C:attention}#1#{} leveled down #2#",
            leveled_up = "{C:attention}#1#{} leveled up #2#",
            leveled_down = "{C:attention}#1#{} leveled down #2#",
            area_size = "{C:attention}#1#{} size changed: {C:red}#2#{} -> {C:red}#3#{}",
            change_area_size = "{C:attention}#1#{} increased {C:attention}#2#{} size by {C:green}#3#",
            change_area_size_neg = "{C:attention}#1#{} reduced {C:attention}#2#{} size by {C:green}#3#",
            sell = "Sold {C:attention}#1#{} for {C:money}$#2#{}",
            buy = "Bought {C:attention}#1#{} for {C:money}$#2#{}",
            booster_opened = "Opened {C:attention}#1#{} that contains #2#",
            booster_skipped = "Skipped {C:attention}#1#{}",
            win = "Won game!",
            lost = "Lost game!",
            lost_endless = "Lost Endless Mode!",
            tag_applied = "{C:attention}#1#{} applied",
            reroll_boss = "Rerolled boss {C:attention}#1#{} -> {C:attention}#2#{}",
            hand_played = "Played {C:attention}#1#{}\nHand contains: #2#",
            hand_played_as = "Hand evaluated as {C:attention}#1#{}",
            hand_scored =
            "Hand scored: {C:attention}#1#{}\nCurrent score: {C:attention}#2#{} | Score to beat: {C:attention}#3#{}",
            score_to_beat = "Score to beat: {C:attention}#1#{}",
            discarded = "Discarded #1#",
            hand_drawn = "Drawn #1#",
            money_altered = "{C:money}$#1#{} -> {C:money}$#2#{}",
            debuffed_hand = "{C:attention}#1#{} not allowed. Hand did not score",
            selected_card = "{C:attention}#1#{} selected #2#",
            changed_sell_cost = "{C:attention}#1#{}'s sell cost changed {C:red}#2#{} -> {C:red}#3#{}",
            target_changed = "{C:attention}#1#{}'s target changed to #2#",
            saved = "Saved by {C:attention}#1#{}",
            eaten = "{C:attention}#1#{} eaten!",
            extinct = "{C:attention}#1#{} extinct!",
            melted = "{C:attention}#1#{} melted!",
            drank = "{C:attention}#1#{} drank!",
            rental = "Paid {C:money}$#2#{} in rent for {C:attention}#1#",
            perishable = "{C:attention}#1#{} perishes in {C:attention}#2#{}",
            perished = "{C:attention}#1#{} perished!"
        }
    }
}
