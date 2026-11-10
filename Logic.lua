local addonName, ns = ...

-- Pure functions only: no WoW API calls, so they can be tested outside the client.

-- Lowest target level that can receive this rank.
function ns.MinTargetLevel(rank)
    local need = rank.level - ns.LEVEL_GAP
    if need < 1 then
        need = 1
    end
    return need
end

-- Index of the highest rank the player knows, or nil.
-- isKnown(spellID, rank) is supplied by the caller. If the client reports
-- only the top rank as known (ranks folded into one spell), every rank
-- below it still counts, because the scan stops at the first hit from the top.
function ns.HighestKnownIndex(buff, isKnown)
    for i = #buff.ranks, 1, -1 do
        local rank = buff.ranks[i]
        if isKnown(rank.id, rank) then
            return i
        end
    end
    return nil
end

-- Chooses the rank to cast.
--   maxKnown    : result of HighestKnownIndex
--   targetLevel : number, or nil when the client would not reveal it
-- Returns rankIndex (nil means "cast nothing") and a reason code:
--   "unknown" player knows no rank of this buff
--   "nolevel" level hidden; falls back to the highest known rank
--   "high"    UnitLevel returned -1 (far above you); highest known rank
--   "fit"     highest known rank the target can receive
--   "toolow"  target too low for every known rank
function ns.PickRankIndex(buff, maxKnown, targetLevel)
    if not maxKnown then
        return nil, "unknown"
    end
    if targetLevel == nil then
        return maxKnown, "nolevel"
    end
    if targetLevel < 0 then
        return maxKnown, "high"
    end
    for i = maxKnown, 1, -1 do
        if targetLevel >= ns.MinTargetLevel(buff.ranks[i]) then
            return i, "fit"
        end
    end
    return nil, "toolow"
end
