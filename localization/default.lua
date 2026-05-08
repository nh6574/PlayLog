return {
    descriptions = {
        Mod = {
            PlayLog = {
                name = "PlayLog",
                text = {
                    "Adds a log to the game"
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

            -- Others
            all_hands = "all hands",

            -- Logging
            creates = "{C:attention}#1#{} created {C:attention}#2#",
            destroys = "{C:attention}#1#{} destroyed {C:attention}#2#",
            added = "{C:attention}#1#{} added",
            added_to = "{C:attention}#1#{} added to {C:attention}#2#",
            converts = "{C:attention}#1#{} turned #2# into {C:attention}#3#",
            converts_multiple = "{C:attention}#1#{} turned #2#",
            converts_individual = "#1# into {C:attention}#2#",
            applied = "{C:attention}#1#{} has applied {C:attention}#3#{} to #2#",
            copies = "{C:attention}#1#{} copied {C:attention}#2#",
            copies_into = "{C:attention}#1#{} turned {C:attention}#3#{} into {C:attention}#2#{}",
            money = "{C:attention}#1#{} gave {C:money}$#2#{}",
            money_taken = "{C:attention}#1#{} took {C:money}$#2#{}",
            noped = "{C:attention}#1#{} noped!",
            hand_level_up = "{C:attention}#1#{} leveled up lvl.{C:red}#2#{} -> {C:red}#3#",
            leveled_up = "{C:attention}#1#{} leveled up #2#",
            area_size = "{C:attention}#1#{} size changed: {C:red}#2#{} -> {C:red}#3#{}",
            change_area_size = "{C:attention}#1#{} increased {C:attention}#2#{} size by {C:green}#3#",
            change_area_size_neg = "{C:attention}#1#{} reduced {C:attention}#2#{} size by {C:green}#3#",
        }
    }
}
