local addonName, ns = ...

-- A friendly target can receive a buff rank only when its level is at least
-- the rank's trainer level minus LEVEL_GAP. This is the 1.12 rule; retest it
-- on the Forever build in front of you.
ns.LEVEL_GAP = 10

-- Ranks are listed lowest to highest, so ranks[i] is "Rank i".
-- id    = spell ID from the 1.12 data. Run /cbuffs probe to confirm each
--         ID exists and is known on your build.
-- level = trainer level for that rank.
-- label = fallback text when the client has not cached the spell name yet.
-- Only buffs with more than one rank are listed: single-rank buffs
-- (Blessing of Kings, Blessing of Salvation, Unending Breath) have nothing
-- to choose between.
ns.BUFFS = {
    PRIEST = {
        { key = "fortitude", label = "Power Word: Fortitude", ranks = {
            { id = 1243,  level = 1 },
            { id = 1244,  level = 12 },
            { id = 1245,  level = 24 },
            { id = 2791,  level = 36 },
            { id = 10937, level = 48 },
            { id = 10938, level = 60 },
        } },
        { key = "spirit", label = "Divine Spirit", ranks = {
            { id = 14752, level = 30 },
            { id = 14818, level = 40 },
            { id = 14819, level = 50 },
            { id = 27841, level = 60 },
        } },
        { key = "shadowprot", label = "Shadow Protection", ranks = {
            { id = 976,   level = 30 },
            { id = 10957, level = 42 },
            { id = 10958, level = 56 },
        } },
    },

    MAGE = {
        { key = "intellect", label = "Arcane Intellect", ranks = {
            { id = 1459,  level = 1 },
            { id = 1460,  level = 14 },
            { id = 1461,  level = 28 },
            { id = 10156, level = 42 },
            { id = 10157, level = 56 },
        } },
        { key = "dampen", label = "Dampen Magic", ranks = {
            { id = 604,   level = 12 },
            { id = 8450,  level = 24 },
            { id = 8451,  level = 36 },
            { id = 10173, level = 48 },
            { id = 10174, level = 60 },
        } },
        { key = "amplify", label = "Amplify Magic", ranks = {
            { id = 1008,  level = 18 },
            { id = 8455,  level = 30 },
            { id = 10169, level = 42 },
            { id = 10170, level = 54 },
        } },
    },

    DRUID = {
        { key = "wild", label = "Mark of the Wild", ranks = {
            { id = 1126, level = 1 },
            { id = 5232, level = 10 },
            { id = 6756, level = 20 },
            { id = 5234, level = 30 },
            { id = 8907, level = 40 },
            { id = 9884, level = 50 },
            { id = 9885, level = 60 },
        } },
        { key = "thorns", label = "Thorns", ranks = {
            { id = 467,  level = 6 },
            { id = 782,  level = 14 },
            { id = 1075, level = 24 },
            { id = 8914, level = 34 },
            { id = 9756, level = 44 },
            { id = 9910, level = 54 },
        } },
    },

    PALADIN = {
        { key = "might", label = "Blessing of Might", ranks = {
            { id = 19740, level = 4 },
            { id = 19834, level = 12 },
            { id = 19835, level = 22 },
            { id = 19836, level = 32 },
            { id = 19837, level = 42 },
            { id = 19838, level = 52 },
            { id = 25291, level = 60 },
        } },
        { key = "wisdom", label = "Blessing of Wisdom", ranks = {
            { id = 19742, level = 14 },
            { id = 19850, level = 24 },
            { id = 19852, level = 34 },
            { id = 19853, level = 44 },
            { id = 19854, level = 54 },
            { id = 25290, level = 60 },
        } },
        { key = "light", label = "Blessing of Light", ranks = {
            { id = 19977, level = 40 },
            { id = 19978, level = 50 },
            { id = 19979, level = 60 },
        } },
        { key = "sanctuary", label = "Blessing of Sanctuary", ranks = {
            { id = 20911, level = 30 },
            { id = 20912, level = 40 },
            { id = 20913, level = 50 },
            { id = 20914, level = 60 },
        } },
    },
}

-- Most buttons any class needs; Bindings.xml defines this many key bindings.
ns.MAX_BUTTONS = 4
