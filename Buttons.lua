local addonName, ns = ...

local SIZE, GAP, HEADER = 36, 4, 16

ns.buttons = {}

local REASON_TEXT = {
    fit = "Target level %d: Rank %d is the highest it can receive (needs level %d).",
    toolow = "Target level %d is too low for any rank you know. Rank 1 needs level %d. Clicking does nothing.",
    nolevel = "The client is hiding the target's level, so this uses your highest rank (Rank %d).",
    high = "Target is far above your level, so this uses your highest rank (Rank %d).",
    unknown = "You have not learned this spell.",
}

-------------------------------------------------------------------------------
-- Visuals (safe in combat: only textures and font strings change)
-------------------------------------------------------------------------------
local function UpdateVisual(button)
    local plan = button.wanted
    if not plan then
        return
    end
    local buff = button.buff
    local shownIndex = plan.index or plan.maxKnown or 1
    button.icon:SetTexture(ns.SpellIcon(buff.ranks[shownIndex].id))

    if plan.index then
        button.icon:SetDesaturated(false)
        if plan.reason == "nolevel" then
            button.rankText:SetText("R" .. plan.index .. "?")
            button.rankText:SetTextColor(1, 0.82, 0)
        else
            button.rankText:SetText("R" .. plan.index)
            button.rankText:SetTextColor(1, 1, 1)
        end
    else
        button.icon:SetDesaturated(true)
        button.rankText:SetText(plan.reason == "toolow" and "low" or "")
        button.rankText:SetTextColor(1, 0.25, 0.25)
    end

    local applied = button.applied
    button.isStale = (applied == nil) or applied.index ~= plan.index or applied.unit ~= plan.unit
    button.staleTex:SetShown(button.isStale)
end

local function UpdateHeader(plans)
    local text
    if plans.unit == "player" then
        text = "Self"
    elseif plans.level == nil then
        text = "Target Lv ?"
    elseif plans.level < 0 then
        text = "Target Lv ??"
    else
        text = "Target Lv " .. plans.level
    end
    if InCombatLockdown() then
        for _, button in ipairs(ns.buttons) do
            if button:IsShown() and button.isStale then
                text = text .. " |cffff5555(updates after combat)|r"
                break
            end
        end
    end
    ns.bar.headerText:SetText(text)
end

local function ShowTooltip(self)
    if ns.db and ns.db.hideTooltips then
        return
    end
    local plan, buff = self.wanted, self.buff
    if not plan then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local index = plan.index or plan.maxKnown or 1
    local id = buff.ranks[index].id
    if type(GameTooltip.SetSpellByID) == "function" then
        GameTooltip:SetSpellByID(id)
    else
        GameTooltip:SetText(ns.SpellName(id) or buff.label)
    end
    GameTooltip:AddLine(" ")

    local r = plan.reason
    if r == "fit" then
        GameTooltip:AddLine(REASON_TEXT.fit:format(plan.level, plan.index,
            ns.MinTargetLevel(buff.ranks[plan.index])), 0.6, 1, 0.6, true)
        if plan.maxKnown and plan.maxKnown > plan.index then
            GameTooltip:AddLine(("You know up to Rank %d; the lower rank costs less mana."):format(
                plan.maxKnown), 0.8, 0.8, 0.8, true)
        end
    elseif r == "toolow" then
        GameTooltip:AddLine(REASON_TEXT.toolow:format(plan.level,
            ns.MinTargetLevel(buff.ranks[1])), 1, 0.4, 0.4, true)
    elseif r == "nolevel" or r == "high" then
        GameTooltip:AddLine(REASON_TEXT[r]:format(plan.index), 1, 0.82, 0, true)
    else
        GameTooltip:AddLine(REASON_TEXT.unknown, 1, 0.4, 0.4, true)
    end

    GameTooltip:AddLine("Casts on: " .. (plan.unit == "player" and "yourself" or "your target"),
        0.8, 0.8, 0.8)
    if self.isStale and InCombatLockdown() then
        GameTooltip:AddLine("In combat this button keeps its earlier choice; it updates when combat ends.",
            1, 0.4, 0.4, true)
    end
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

-------------------------------------------------------------------------------
-- Protected work: only ever called through ns.RunOutOfCombat
-------------------------------------------------------------------------------
local function ApplyButton(button, plan)
    if plan.index then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", ns.SpellValue(button.buff, plan.index))
        button:SetAttribute("unit", plan.unit)
    else
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("unit", nil)
    end
    button.applied = { index = plan.index, unit = plan.unit }
end

function ns.ApplyAll()
    if not ns.built then
        return
    end
    local plans = ns.ComputePlans()
    for i, button in ipairs(ns.buttons) do
        button.wanted = plans[i]
        ApplyButton(button, plans[i])
        UpdateVisual(button)
    end
    UpdateHeader(plans)
end

function ns.RestorePosition()
    local p = ns.db.point
    ns.bar:SetScale(ns.db.scale) -- scale first: point offsets are in the bar's scaled units
    ns.bar:ClearAllPoints()
    ns.bar:SetPoint(p[1], UIParent, p[3], p[4], p[5])
end

-- Change scale but keep the bar's centre where it is on screen.
function ns.ApplyScale()
    local bar = ns.bar
    local old, new = bar:GetScale(), ns.db.scale
    local cx, cy = bar:GetCenter()
    bar:SetScale(new)
    if cx and cy and old and old > 0 then
        local x, y = cx * old / new, cy * old / new
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        ns.db.point = { "CENTER", "UIParent", "BOTTOMLEFT", x, y }
    end
end

function ns.Layout()
    local shown = 0
    for _, button in ipairs(ns.buttons) do
        button:ClearAllPoints()
        if ns.HighestKnownIndex(button.buff, ns.IsKnown) then
            button:SetPoint("TOPLEFT", ns.bar, "TOPLEFT", shown * (SIZE + GAP), -HEADER)
            button:Show()
            shown = shown + 1
        else
            button:Hide()
        end
    end
    local width = shown * (SIZE + GAP) - GAP
    if width < 120 then
        width = 120
    end
    ns.bar:SetSize(width, SIZE + HEADER)
    if shown > 0 and ns.db.shown then
        ns.bar:Show()
    else
        ns.bar:Hide()
    end
end

-------------------------------------------------------------------------------
-- Refresh: repaint now, apply attributes when allowed
-------------------------------------------------------------------------------
function ns.Refresh()
    if not ns.built then
        return
    end
    local plans = ns.ComputePlans()
    for i, button in ipairs(ns.buttons) do
        button.wanted = plans[i]
        UpdateVisual(button)
    end
    UpdateHeader(plans)
    ns.RunOutOfCombat("apply", ns.ApplyAll)
end

-------------------------------------------------------------------------------
-- Settings. Used by the options window and the slash commands alike.
-- Each returns true if the change happened now, false if it waits for
-- combat to end.
-------------------------------------------------------------------------------
local function ApplyLock()
    if not ns.bar then
        return
    end
    -- The header is not protected, so this is safe in combat.
    ns.bar.header:EnableMouse(not ns.db.locked)
    ns.bar.header.bg:SetShown(not ns.db.locked)
end

function ns.SetBarLocked(locked)
    ns.db.locked = locked and true or false
    ApplyLock()
    return true
end

-- Tooltips are not protected, so this always applies at once, even in combat.
function ns.SetHideTooltips(hide)
    ns.db.hideTooltips = hide and true or false
    if ns.db.hideTooltips and type(GameTooltip.GetOwner) == "function" then
        local owner = GameTooltip:GetOwner()
        for _, button in ipairs(ns.buttons) do
            if owner == button then
                GameTooltip:Hide()
                break
            end
        end
    end
    return true
end

function ns.SetBarShown(shown)
    ns.db.shown = shown and true or false
    if not ns.built then
        return true
    end
    return ns.RunOutOfCombat("layout", ns.Layout)
end

-- Snap to the slider step and keep inside the allowed range.
function ns.RoundScale(scale)
    scale = math.floor(scale / ns.SCALE_STEP + 0.5) * ns.SCALE_STEP
    if scale < ns.SCALE_MIN then
        return ns.SCALE_MIN
    elseif scale > ns.SCALE_MAX then
        return ns.SCALE_MAX
    end
    return scale
end

function ns.SetBarScale(scale)
    ns.db.scale = ns.RoundScale(scale)
    if not ns.built then
        return true
    end
    return ns.RunOutOfCombat("scale", ns.ApplyScale)
end

function ns.ResetBar()
    ns.db.point = ns.CopyValue(ns.DEFAULTS.point)
    ns.db.scale = ns.DEFAULTS.scale
    if not ns.built then
        return true
    end
    return ns.RunOutOfCombat("position", ns.RestorePosition)
end

-------------------------------------------------------------------------------
-- Build (out of combat, once, at PLAYER_LOGIN)
-------------------------------------------------------------------------------
local function CreateBar()
    local bar = CreateFrame("Frame", "CheaperBuffsBar", UIParent)
    bar:SetSize(120, SIZE + HEADER)
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:Hide()

    local header = CreateFrame("Frame", nil, bar)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER - 2)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if ns.db.locked then
            return
        end
        if InCombatLockdown() then
            ns.Print("You can't move the bar during combat.")
            return
        end
        bar:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        bar:SetUserPlaced(false) -- position lives in CheaperBuffsDB, not layout-local.txt
        local p, _, rp, x, y = bar:GetPoint(1)
        ns.db.point = { p, "UIParent", rp, x, y }
    end)

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetColorTexture(0.2, 0.5, 0.8, 0.35)

    bar.headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.headerText:SetPoint("LEFT", 2, 0)
    bar.headerText:SetJustifyH("LEFT")

    bar.header = header
    ns.bar = bar
end

local function CreateButton(index, buff)
    local name = "CheaperBuffsButton" .. index
    local button = CreateFrame("Button", name, ns.bar, "SecureActionButtonTemplate")
    button:SetSize(SIZE, SIZE)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button.buff = buff

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -1, 1)
    bg:SetPoint("BOTTOMRIGHT", 1, -1)
    bg:SetColorTexture(0, 0, 0, 0.85)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    button.staleTex = button:CreateTexture(nil, "OVERLAY")
    button.staleTex:SetAllPoints()
    button.staleTex:SetColorTexture(1, 0, 0, 0.35)
    button.staleTex:Hide()

    button.rankText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.rankText:SetPoint("BOTTOMRIGHT", -2, 2)

    -- OnEnter/OnLeave only; the template's OnClick is left alone.
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", HideTooltip)

    _G["BINDING_NAME_CLICK " .. name .. ":LeftButton"] = buff.label
    ns.buttons[index] = button
end

function ns.Build()
    if ns.built then
        return
    end
    local _, class = UnitClass("player")
    if ns.IsSecret(class) then
        return
    end
    local buffs = ns.BUFFS[class]
    if not buffs then
        return -- class has no multi-rank buffs; stay silent
    end

    CreateBar()
    for i = 1, math.min(#buffs, ns.MAX_BUTTONS) do
        CreateButton(i, buffs[i])
    end
    ns.built = true

    ns.RestorePosition()
    ApplyLock()
    ns.Layout()
    ns.ApplyAll()

    if not ns.db.welcomed then
        ns.db.welcomed = true
        ns.Print("Drag the bar's header to move it, then type /cbuffs lock. /cbuffs for help.")
    end
end
