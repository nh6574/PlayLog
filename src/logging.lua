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
end
