PlayLog = {}

PlayLog.mod = SMODS.current_mod
PlayLog.config = SMODS.current_mod.config

assert(SMODS.current_mod.lovely,
    "Lovely modules were not loaded.\nMake sure your PlayLog folder is not nested (there should be a bunch of files in the PlayLog folder and not just another folder).")

assert(SMODS.load_file("src/utils.lua"))()
assert(SMODS.load_file("src/mod_info.lua"))()
assert(SMODS.load_file("src/config.lua"))()
assert(SMODS.load_file("src/ui.lua"))()
assert(SMODS.load_file("src/objects.lua"))()
assert(SMODS.load_file("src/api.lua"))()
assert(SMODS.load_file("src/logging.lua"))()
