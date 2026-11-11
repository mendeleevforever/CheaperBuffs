local addonName, ns = ...

local ICON = 136222
local panel

-------------------------------------------------------------------------------
-- Small widget builders. Plain frames and long-standing textures only, so the
-- window does not depend on Blizzard templates that move between builds.
-------------------------------------------------------------------------------
local function CreateCheck(parent, label, y, onToggle)
    local check = CreateFrame("CheckButton", nil, parent)
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", 14, y)
    check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 4, 1)
    text:SetText(label)
    check:SetHitRectInsets(0, -(text:GetStringWidth() + 8), 0, 0) -- label is clickable too

    check:SetScript("OnClick", function(self)
        onToggle(self:GetChecked() and true or false)
    end)
    return check
end

local function CreateScaleSlider(parent, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 18, y)

    local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(184, 16)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -2, -6)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetMinMaxValues(ns.SCALE_MIN, ns.SCALE_MAX)
    slider:SetValueStep(ns.SCALE_STEP)
    slider:SetObeyStepOnDrag(true)

    local low = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 2, -1)
    low:SetText(math.floor(ns.SCALE_MIN * 100 + 0.5) .. "%")
    local high = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", -2, -1)
    high:SetText(math.floor(ns.SCALE_MAX * 100 + 0.5) .. "%")

    slider.label = label
    return slider
end

-------------------------------------------------------------------------------
-- The options window
-------------------------------------------------------------------------------
local function SetNote(text)
    panel.note:SetText(text or "")
end

local function AfterChange(appliedNow)
    if appliedNow then
        SetNote(nil)
    else
        SetNote("|cffff5555In combat: this applies when combat ends.|r")
    end
end

local function SetScaleLabel(scale)
    scale = ns.RoundScale(scale)
    panel.scale.label:SetText(("Bar scale: %d%%"):format(math.floor(scale * 100 + 0.5)))
end

function ns.RefreshOptions()
    if not panel or not ns.db then
        return
    end
    panel.lock:SetChecked(ns.db.locked)
    panel.hide:SetChecked(not ns.db.shown)
    panel.tips:SetChecked(ns.db.hideTooltips)
    panel.updating = true
    panel.scale:SetValue(ns.db.scale)
    panel.updating = false
    SetScaleLabel(ns.db.scale)
    if not ns.built then
        SetNote("Your class has no multi-rank buffs, so there is no bar to adjust.")
    elseif not InCombatLockdown() then
        SetNote(nil)
    end
end

local function CreatePanel()
    panel = CreateFrame("Frame", "CheaperBuffsOptions", UIParent, "BackdropTemplate")
    panel:SetSize(220, 240)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    panel:Hide()

    -- Escape closes the window.
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "CheaperBuffsOptions")
    end

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 12, -10)
    icon:SetTexture(ICON)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    title:SetText("Cheaper Buffs " .. ns.version)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    panel.lock = CreateCheck(panel, "Lock bar", -40, function(checked)
        AfterChange(ns.SetBarLocked(checked))
    end)

    panel.hide = CreateCheck(panel, "Hide bar", -66, function(checked)
        AfterChange(ns.SetBarShown(not checked))
    end)

    panel.tips = CreateCheck(panel, "Hide bar tooltips", -92, function(checked)
        AfterChange(ns.SetHideTooltips(checked))
    end)
    panel.tips:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Hide bar tooltips")
        GameTooltip:AddLine("Stops the spell and rank tooltip from appearing when you hover over the bar's buttons.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    panel.tips:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(120, 22)
    reset:SetPoint("TOPLEFT", 16, -124)
    reset:SetText("Reset bar")
    reset:SetScript("OnClick", function()
        AfterChange(ns.ResetBar())
        ns.RefreshOptions()
    end)
    reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset bar")
        GameTooltip:AddLine("Moves the bar back to its starting spot and sets the scale to 100%.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    panel.scale = CreateScaleSlider(panel, -158)
    panel.scale:SetScript("OnValueChanged", function(self, value)
        SetScaleLabel(value)
        if panel.updating then
            return
        end
        AfterChange(ns.SetBarScale(value))
    end)

    panel.note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.note:SetPoint("BOTTOMLEFT", 14, 10)
    panel.note:SetPoint("BOTTOMRIGHT", -14, 10)
    panel.note:SetJustifyH("LEFT")

    panel:SetScript("OnShow", ns.RefreshOptions)
end

function ns.ToggleOptions(anchor)
    if not panel then
        CreatePanel()
    end
    if panel:IsShown() then
        panel:Hide()
        return
    end
    panel:ClearAllPoints()
    if anchor and type(anchor.GetCenter) == "function" and anchor:GetCenter() then
        panel:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", 0, 0)
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end
    panel:Show()
end

-------------------------------------------------------------------------------
-- Minimap button through LibDataBroker + LibDBIcon (embedded under Libs)
-------------------------------------------------------------------------------
local icon -- LibDBIcon instance

function ns.CreateMinimapButton()
    if icon or not LibStub then
        return
    end
    local ldb = LibStub("LibDataBroker-1.1", true)
    local dbicon = LibStub("LibDBIcon-1.0", true)
    if not ldb or not dbicon then
        ns.Print("Minimap libraries did not load; use /cbuffs options instead.")
        return
    end

    local launcher = ldb:NewDataObject(addonName, {
        type = "launcher",
        text = "Cheaper Buffs",
        icon = ICON,
        OnClick = function(clicked)
            ns.ToggleOptions(clicked)
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Cheaper Buffs " .. ns.version)
            tooltip:AddLine("Click: options", 1, 1, 1)
            tooltip:AddLine("Drag: move this button", 1, 1, 1)
        end,
    })
    if not launcher then
        return -- another copy already registered this name
    end
    dbicon:Register(addonName, launcher, ns.db.minimap)
    icon = dbicon
end

function ns.ToggleMinimapButton()
    if not icon then
        ns.Print("The minimap button is not available.")
        return
    end
    ns.db.minimap.hide = not ns.db.minimap.hide
    if ns.db.minimap.hide then
        icon:Hide(addonName)
        ns.Print("Minimap button hidden. Type /cbuffs minimap to bring it back.")
    else
        icon:Show(addonName)
        ns.Print("Minimap button shown.")
    end
end
