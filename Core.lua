local addonName, ns = ...

ns.version = "0.1.0"
if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
    ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or ns.version
end

-- Key binding labels (Bindings.xml). Buttons.lua renames them to the real
-- buff once your class is known.
BINDING_HEADER_CHEAPERBUFFS = "Cheaper Buffs"
for i = 1, ns.MAX_BUTTONS do
    _G["BINDING_NAME_CLICK CheaperBuffsButton" .. i .. ":LeftButton"] = "Buff button " .. i
end

local DEFAULTS = {
    locked = false,
    shown = true,
    mode = "id", -- "id" casts by spell ID; "name" casts "Name(Rank N)"
    point = { "CENTER", "UIParent", "CENTER", 0, -180 },
    welcomed = false,
}

local function CopyValue(v)
    if type(v) ~= "table" then
        return v
    end
    local t = {}
    for k, inner in pairs(v) do
        t[k] = CopyValue(inner)
    end
    return t
end

function ns.Print(msg)
    print("|cff66ccffCheaper Buffs|r: " .. tostring(msg))
end

-------------------------------------------------------------------------------
-- Secret values. Never compare, branch on, or print a value before this check.
-------------------------------------------------------------------------------
function ns.IsSecret(v)
    if type(issecretvalue) == "function" then
        return issecretvalue(v) and true or false
    end
    return false
end

-------------------------------------------------------------------------------
-- Combat queue. Anything that touches a protected frame (SetAttribute, Show,
-- Hide, SetPoint on the bar or its buttons) goes through here. Jobs are keyed
-- so ten target changes in combat collapse into one refresh afterwards.
-------------------------------------------------------------------------------
local queue, queueOrder = {}, {}

function ns.RunOutOfCombat(key, fn)
    if InCombatLockdown() then
        if not queue[key] then
            queueOrder[#queueOrder + 1] = key
        end
        queue[key] = fn
        return false
    end
    fn()
    return true
end

local function FlushQueue()
    local order, jobs = queueOrder, queue
    queueOrder, queue = {}, {}
    for i = 1, #order do
        local fn = jobs[order[i]]
        if fn then
            fn()
        end
    end
end

-------------------------------------------------------------------------------
-- Capability probes for spell knowledge. Each API is checked before use.
-------------------------------------------------------------------------------
local knownChecks = {}

local function AddKnownCheck(label, fn)
    knownChecks[#knownChecks + 1] = { label = label, fn = fn }
end

if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
    AddKnownCheck("C_SpellBook.IsSpellKnown", C_SpellBook.IsSpellKnown)
end
if type(IsSpellKnown) == "function" then
    AddKnownCheck("IsSpellKnown", IsSpellKnown)
end
if type(IsPlayerSpell) == "function" then
    AddKnownCheck("IsPlayerSpell", IsPlayerSpell)
end

function ns.KnownSources()
    if #knownChecks == 0 then
        return "none found; assuming every rank at or below your level is trained"
    end
    local names = {}
    for i = 1, #knownChecks do
        names[i] = knownChecks[i].label
    end
    return table.concat(names, ", ")
end

-- True if any available API says the player knows this spell.
-- pcall here only protects against a query erroring on an unknown ID;
-- it is never used around a protected action.
function ns.IsKnown(spellID, rank)
    if #knownChecks == 0 then
        local lvl = UnitLevel("player")
        if ns.IsSecret(lvl) or type(lvl) ~= "number" then
            return false
        end
        return rank ~= nil and rank.level <= lvl
    end
    for i = 1, #knownChecks do
        local ok, result = pcall(knownChecks[i].fn, spellID)
        if ok and not ns.IsSecret(result) and result then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Spell data helpers (C_Spell only; the old globals are gone).
-------------------------------------------------------------------------------
local requested = {}

function ns.RequestSpell(spellID)
    if requested[spellID] then
        return
    end
    requested[spellID] = true
    if C_Spell and type(C_Spell.RequestLoadSpellData) == "function" then
        C_Spell.RequestLoadSpellData(spellID)
    end
end

function ns.SpellName(spellID)
    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        local name = C_Spell.GetSpellName(spellID)
        if name then
            return name
        end
    end
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name then
            return info.name
        end
    end
    ns.RequestSpell(spellID)
    return nil
end

function ns.SpellSubtext(spellID)
    if C_Spell and type(C_Spell.GetSpellSubtext) == "function" then
        local sub = C_Spell.GetSpellSubtext(spellID)
        if sub and sub ~= "" then
            return sub
        end
    end
    return nil
end

function ns.SpellIcon(spellID)
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then
            return tex
        end
    end
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.iconID then
            return info.iconID
        end
    end
    ns.RequestSpell(spellID)
    return 134400 -- question mark icon
end

-- Value for the secure button's "spell" attribute.
function ns.SpellValue(buff, index)
    local id = buff.ranks[index].id
    if ns.db and ns.db.mode == "name" then
        local name, sub = ns.SpellName(id), ns.SpellSubtext(id)
        if name and sub then
            return name .. "(" .. sub .. ")"
        end
        ns.RequestSpell(id)
    end
    return id
end

-------------------------------------------------------------------------------
-- Who gets the buff, and how high is their level?
-------------------------------------------------------------------------------

-- Returns unit token and whether we are sure about it.
function ns.ChooseUnit()
    local exists = UnitExists("target")
    if ns.IsSecret(exists) then
        return "target", false
    end
    if not exists then
        return "player", true
    end
    local assist = UnitCanAssist("player", "target")
    if ns.IsSecret(assist) then
        return "target", false
    end
    if assist then
        return "target", true
    end
    return "player", true
end

-- Number, or nil when the level is secret or unreadable.
function ns.ReadUnitLevel(unit)
    local lvl = UnitLevel(unit)
    if ns.IsSecret(lvl) or type(lvl) ~= "number" then
        return nil
    end
    return lvl
end

function ns.ComputePlans()
    local unit, sure = ns.ChooseUnit()
    local level = ns.ReadUnitLevel(unit)
    local plans = { unit = unit, sure = sure, level = level }
    for i, button in ipairs(ns.buttons or {}) do
        local maxKnown = ns.HighestKnownIndex(button.buff, ns.IsKnown)
        local index, reason = ns.PickRankIndex(button.buff, maxKnown, level)
        plans[i] = {
            index = index,
            reason = reason,
            unit = unit,
            level = level,
            maxKnown = maxKnown,
        }
    end
    return plans
end

-------------------------------------------------------------------------------
-- Events: one frame, one handler table.
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local handlers = {}
ns.failedEvents = {}

frame:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if handler then
        handler(...)
    end
end)

function handlers.ADDON_LOADED(name)
    if name ~= addonName then
        return
    end
    if type(CheaperBuffsDB) ~= "table" then
        CheaperBuffsDB = {}
    end
    for k, v in pairs(DEFAULTS) do
        if CheaperBuffsDB[k] == nil then
            CheaperBuffsDB[k] = CopyValue(v)
        end
    end
    if CheaperBuffsDB.mode ~= "id" and CheaperBuffsDB.mode ~= "name" then
        CheaperBuffsDB.mode = "id"
    end
    ns.db = CheaperBuffsDB
    frame:UnregisterEvent("ADDON_LOADED")
end

function handlers.PLAYER_LOGIN()
    ns.db = ns.db or CopyValue(DEFAULTS)
    ns.RunOutOfCombat("build", ns.Build)
end

function handlers.PLAYER_ENTERING_WORLD()
    ns.Refresh()
end

function handlers.PLAYER_TARGET_CHANGED()
    ns.Refresh()
end

function handlers.UNIT_LEVEL(unit)
    if ns.IsSecret(unit) or unit == "target" or unit == "player" then
        ns.Refresh()
    end
end

function handlers.PLAYER_LEVEL_UP()
    ns.Refresh()
end

function handlers.SPELLS_CHANGED()
    if ns.built then
        ns.RunOutOfCombat("layout", ns.Layout)
    end
    ns.Refresh()
end

function handlers.SPELL_DATA_LOAD_RESULT(spellID, success)
    if success then
        requested[spellID] = nil
        ns.Refresh()
    end
end

function handlers.PLAYER_REGEN_ENABLED()
    FlushQueue()
    ns.Refresh()
end

function handlers.PLAYER_REGEN_DISABLED()
    ns.Refresh() -- repaint so stale markers appear as soon as anything changes
end

-- Registering an event the client does not know throws, so probe each one.
for event in pairs(handlers) do
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok then
        ns.failedEvents[#ns.failedEvents + 1] = event
    end
end

-------------------------------------------------------------------------------
-- /cbuffs probe: everything this addon assumes, checked on your build.
-------------------------------------------------------------------------------
local function Lookup(path)
    local node = _G
    for part in string.gmatch(path, "[^%.]+") do
        if type(node) ~= "table" then
            return nil
        end
        node = node[part]
    end
    return node
end

local PROBE_APIS = {
    "C_Spell.GetSpellInfo", "C_Spell.GetSpellName", "C_Spell.GetSpellSubtext",
    "C_Spell.GetSpellTexture", "C_Spell.RequestLoadSpellData", "C_Spell.DoesSpellExist",
    "C_Spell.GetSpellLevelLearned", "C_SpellBook.IsSpellKnown", "IsSpellKnown",
    "IsPlayerSpell", "issecretvalue", "UnitLevel", "UnitCanAssist", "InCombatLockdown",
}

function ns.Probe()
    local P = ns.Print
    local version, build, _, iface = GetBuildInfo()
    P(("Client %s build %s, interface %s. Addon %s."):format(
        tostring(version), tostring(build), tostring(iface), tostring(ns.version)))
    P(("WOW_PROJECT_ID=%s  MAINLINE=%s  CLASSIC=%s  CAMELOT=%s"):format(
        tostring(WOW_PROJECT_ID), tostring(WOW_PROJECT_MAINLINE),
        tostring(WOW_PROJECT_CLASSIC), tostring(WOW_PROJECT_CAMELOT)))

    local missing = {}
    for _, path in ipairs(PROBE_APIS) do
        if type(Lookup(path)) ~= "function" then
            missing[#missing + 1] = path
        end
    end
    P("Missing APIs: " .. (#missing > 0 and table.concat(missing, ", ") or "none"))
    P("Known-spell checks: " .. ns.KnownSources())
    if #ns.failedEvents > 0 then
        P("Events the client refused: " .. table.concat(ns.failedEvents, ", "))
    end

    local _, class = UnitClass("player")
    if ns.IsSecret(class) then
        P("Your class token came back secret; cannot pick a buff list.")
        return
    end
    local buffs = ns.BUFFS[class]
    if not buffs then
        P("No multi-rank buffs listed for " .. tostring(class) .. ".")
        return
    end

    local levelLearned = Lookup("C_Spell.GetSpellLevelLearned")
    local doesExist = Lookup("C_Spell.DoesSpellExist")
    for _, buff in ipairs(buffs) do
        P("|cffffd100" .. buff.label .. "|r")
        for i, rank in ipairs(buff.ranks) do
            local exists = "?"
            if type(doesExist) == "function" then
                exists = doesExist(rank.id) and "exists" or "NO SUCH SPELL"
            end
            local apiLevel = ""
            if type(levelLearned) == "function" then
                local ok, lvl = pcall(levelLearned, rank.id)
                if ok and not ns.IsSecret(lvl) then
                    apiLevel = " api lvl " .. tostring(lvl)
                end
            end
            P(("  R%d id %d %s, %s, sub '%s', table lvl %d%s"):format(
                i, rank.id, exists,
                ns.IsKnown(rank.id, rank) and "known" or "not known",
                tostring(ns.SpellSubtext(rank.id)), rank.level, apiLevel))
        end
    end

    local unit, sure = ns.ChooseUnit()
    local lvl = ns.ReadUnitLevel(unit)
    P(("Buff target: %s%s, level %s"):format(
        unit, sure and "" or " (client hid whether it is friendly)",
        lvl and tostring(lvl) or "hidden"))
end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
local function Help()
    local P = ns.Print
    P("v" .. ns.version .. " commands (/cbuffs or /cheaperbuffs):")
    P("  lock | unlock  - stop or allow dragging the bar by its header")
    P("  show | hide    - show or hide the bar")
    P("  reset          - move the bar back to the default spot")
    P("  mode id | name - cast by spell ID (default) or by 'Name(Rank N)'")
    P("  probe          - check this addon's assumptions on your client build")
end

SLASH_CHEAPERBUFFS1 = "/cbuffs"
SLASH_CHEAPERBUFFS2 = "/cheaperbuffs"
SlashCmdList.CHEAPERBUFFS = function(msg)
    local cmd, arg = string.match(string.lower(msg or ""), "^%s*(%S*)%s*(%S*)")
    if not ns.db then
        ns.Print("Not loaded yet.")
        return
    end
    if cmd == "lock" or cmd == "unlock" then
        ns.db.locked = (cmd == "lock")
        if ns.SetLocked then
            ns.SetLocked(ns.db.locked)
        end
        ns.Print(ns.db.locked and "Bar locked." or "Bar unlocked. Drag the header to move it.")
    elseif cmd == "show" or cmd == "hide" then
        ns.db.shown = (cmd == "show")
        if ns.built then
            if not ns.RunOutOfCombat("layout", ns.Layout) then
                ns.Print("In combat; the bar will change when combat ends.")
            end
        end
    elseif cmd == "reset" then
        ns.db.point = CopyValue(DEFAULTS.point)
        if ns.built then
            ns.RunOutOfCombat("position", ns.RestorePosition)
        end
        ns.Print("Position reset.")
    elseif cmd == "mode" then
        if arg == "id" or arg == "name" then
            ns.db.mode = arg
            if ns.built then
                ns.RunOutOfCombat("apply", ns.ApplyAll)
            end
            ns.Print("Casting by " .. (arg == "id" and "spell ID." or "name and rank."))
        else
            ns.Print("Mode is '" .. ns.db.mode .. "'. Use: /cbuffs mode id  or  /cbuffs mode name")
        end
    elseif cmd == "probe" then
        ns.Probe()
    else
        Help()
    end
end
