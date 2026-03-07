local addonName, ns = ...

local configFrame = nil
local minimapButton = nil
local minimapText = nil
local statusIndicator = nil

-- Minimap button positioning
local function UpdateMinimapButtonPosition()
    if not minimapButton then return end
    local db = DominosHoldToCastFixDB
    if not db or not db.minimap then return end
    local angle = math.rad(db.minimap.angle or 220)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "DominosHoldToCastFixMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(21, 21)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("CENTER", 0, 1)

    local text = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 1)
    text:SetText("HC")
    text:SetTextColor(0.5, 0.5, 0.5) -- starts dim, updated by UpdateActiveState
    minimapText = text

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Dominos HoldToCastFix")
        local htcf = ns.HoldToCastFix
        local active = htcf and htcf.bindingsActive
        if active then
            GameTooltip:AddLine("Status: Active", 0, 1, 0)
        elseif htcf.bar1Paged then
            GameTooltip:AddLine("Status: Vehicle/Override", 1, 0.7, 0)
        else
            GameTooltip:AddLine("Status: Inactive", 1, 0.4, 0)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to open config", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click to toggle on/off", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Click handlers
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ns.ToggleConfig()
        elseif button == "RightButton" then
            local db = DominosHoldToCastFixDB
            if db then
                db.enabled = not db.enabled
                ns.HoldToCastFix:ApplyBindings()
                local state = db.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
                print("|cff00ff00DominosHoldToCastFix:|r " .. state)
                ns.UpdateActiveState()
            end
        end
    end)

    -- Dragging
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self.isDragging = true
    end)
    btn:SetScript("OnDragStop", function(self)
        self.isDragging = false
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        local db = DominosHoldToCastFixDB
        if db and db.minimap then
            db.minimap.angle = angle
        end
        UpdateMinimapButtonPosition()
    end)
    btn:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.atan2(cy - my, cx - mx)
            local radius = 80
            local x = math.cos(angle) * radius
            local y = math.sin(angle) * radius
            self:ClearAllPoints()
            self:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end
    end)

    minimapButton = btn
    UpdateMinimapButtonPosition()

    local db = DominosHoldToCastFixDB
    if db and db.minimap and db.minimap.show then
        btn:Show()
    else
        btn:Hide()
    end
end

-- Called from Core.lua Initialize after saved vars are loaded
function ns.InitMinimapButton()
    CreateMinimapButton()
end

function ns.SetMinimapButtonShown(show)
    if not minimapButton then return end
    if show then
        minimapButton:Show()
    else
        minimapButton:Hide()
    end
end

-- Updates both minimap icon and config panel to reflect active binding state
function ns.UpdateActiveState()
    local htcf = ns.HoldToCastFix
    local active = htcf and htcf.bindingsActive
    local bar1Paged = htcf and htcf.bar1Paged
    local pendingUpdate = htcf and htcf.pendingUpdate
    local bar1Page = htcf and htcf.bar1Page or 1

    -- Minimap icon: gold when active, dim grey when inactive
    if minimapText then
        if active or pendingUpdate then
            minimapText:SetTextColor(1, 0.82, 0)
        else
            minimapText:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    -- Config panel status indicator
    if statusIndicator then
        local db = DominosHoldToCastFixDB

        if db and not db.enabled then
            statusIndicator:SetText("|cffff0000Disabled|r")
        elseif active then
            if bar1Page > 1 then
                statusIndicator:SetText("|cff00ff00Active|r |cff00ccff(page " .. bar1Page .. ")|r")
            else
                statusIndicator:SetText("|cff00ff00Active|r")
            end
        elseif pendingUpdate then
            statusIndicator:SetText("|cffffaa00Pending|r - restoring after combat")
        elseif bar1Paged then
            statusIndicator:SetText("|cffffaa00Inactive|r (vehicle/override)")
        else
            statusIndicator:SetText("|cffffaa00Inactive|r")
        end
    end
end

local function CreateConfigPanel()
    local frame = CreateFrame("Frame", "DominosHoldToCastFixConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(260, 240)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.TitleBg:SetHeight(30)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -3)
    frame.title:SetText("Dominos HoldToCastFix")

    local db = DominosHoldToCastFixDB

    -- Enable checkbox
    local enableCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 10, -10)
    enableCheck.text:SetText("Enabled")
    enableCheck.text:SetFontObject("GameFontNormal")
    enableCheck:SetChecked(db.enabled)
    enableCheck:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked()
        ns.HoldToCastFix:ApplyBindings()
    end)
    frame.enableCheck = enableCheck

    -- Minimap icon checkbox
    local minimapCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, 2)
    minimapCheck.text:SetText("Show Minimap Icon")
    minimapCheck.text:SetFontObject("GameFontNormal")
    minimapCheck:SetChecked(db.minimap and db.minimap.show or false)
    minimapCheck:SetScript("OnClick", function(self)
        if not db.minimap then db.minimap = {} end
        db.minimap.show = self:GetChecked()
        ns.SetMinimapButtonShown(db.minimap.show)
    end)
    frame.minimapCheck = minimapCheck

    -- Description
    local desc = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 4, -4)
    desc:SetPoint("RIGHT", frame.InsetBg, "RIGHT", -10, 0)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.7, 0.7, 0.7)
    desc:SetText("Routes Bar 1 keybinds to Blizzard's native ActionButtons, enabling Press and Hold Casting.\n\nOnly Bar 1 is supported — other bars use Lua-only binding commands that don't support hold-to-cast.")

    -- Status indicator
    statusIndicator = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusIndicator:SetPoint("BOTTOMLEFT", frame.InsetBg, "BOTTOMLEFT", 14, 40)
    statusIndicator:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -14, 40)
    statusIndicator:SetJustifyH("CENTER")
    statusIndicator:SetWordWrap(true)

    -- Apply button
    local applyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    applyBtn:SetSize(100, 24)
    applyBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
    applyBtn:SetText("Apply")
    applyBtn:SetScript("OnClick", function()
        ns.HoldToCastFix:ApplyBindings()
        print("|cff00ff00DominosHoldToCastFix:|r Bindings re-applied")
    end)

    -- Debug button
    local debugBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    debugBtn:SetSize(70, 24)
    debugBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    debugBtn:SetText("Debug")
    debugBtn:SetScript("OnClick", function()
        ns.ToggleDebug()
    end)

    frame:SetScript("OnShow", function()
        enableCheck:SetChecked(db.enabled)
        minimapCheck:SetChecked(db.minimap and db.minimap.show or false)
        ns.UpdateActiveState()
    end)

    return frame
end

-- =============================================================
-- Debug Panel
-- =============================================================
local debugFrame = nil
local debugText = nil
local debugScrollChild = nil

local function FormatState(val)
    if val == nil then return "|cff888888nil|r" end
    if val == true then return "|cff00ff00true|r" end
    if val == false then return "|cffff4444false|r" end
    return "|cffffffff" .. tostring(val) .. "|r"
end

-- Generates debug info lines. When plain=true, strips color codes for clipboard.
local function BuildDebugLines(plain)
    local htcf = ns.HoldToCastFix
    if not htcf then return {"(no data)"} end

    local lines = {}
    local function L(text) lines[#lines + 1] = text end

    local function S(val)
        if plain then return tostring(val) end
        return FormatState(val)
    end

    -- Version info
    local version = C_AddOns.GetAddOnMetadata("DominosHoldToCastFix", "Version") or "?"
    L("DominosHoldToCastFix v" .. version)
    if Dominos and Dominos.version then
        L("Dominos v" .. tostring(Dominos.version))
    end
    L("")

    -- Core states
    L("=== Core State ===")
    L("enabled:           " .. S(DominosHoldToCastFixDB and DominosHoldToCastFixDB.enabled))
    L("bindingsActive:    " .. S(htcf.bindingsActive))
    L("bar1Paged:         " .. S(htcf.bar1Paged))
    L("bar1Page:          " .. S(htcf.bar1Page))
    L("pendingUpdate:     " .. S(htcf.pendingUpdate))
    L("stateDriverActive: " .. S(htcf.stateDriverActive))
    L("InCombatLockdown:  " .. S(InCombatLockdown()))
    L("")

    -- State driver attribute
    local sf = htcf.stateFrame
    if sf then
        local raw = sf:GetAttribute("state-htcfpage")
        L("=== State Driver ===")
        L("state-htcfpage:    " .. S(raw) .. "  type=" .. type(raw))
        L("tostring:          " .. S(tostring(raw)))
    end
    L("")

    -- Binding frame
    L("=== Binding Frame ===")
    local bf1 = htcf.bindingFrameBar1
    if bf1 then
        L("bar1 owner:   " .. (bf1:GetName() or "anon"))
    end

    -- Sample bar1 bindings: check first 4 ACTIONBUTTON slots
    L("")
    L("=== Bar1 Bindings (sample) ===")
    for i = 1, 4 do
        local cmd = "ACTIONBUTTON" .. i
        local keys = {GetBindingKey(cmd)}
        local keyStr = #keys > 0 and table.concat(keys, ", ") or "none"
        local action = GetBindingAction(keys[1] or "", true) or ""
        local overrideInfo = ""
        if keys[1] and action ~= "" then
            overrideInfo = " -> " .. action
        end
        L("  " .. cmd .. ": [" .. keyStr .. "]" .. overrideInfo)
    end
    L("")

    -- Event log
    L("=== Event Log ===")
    local log = htcf.debugLog or {}
    if #log == 0 then
        L("  (empty)")
    else
        for i = 1, #log do
            L("  " .. log[i])
        end
    end

    return lines
end

-- Colorize a plain line for display (adds section header colors etc.)
local function ColorizeLine(line)
    if line:match("^===") then
        return "|cffffcc00" .. line .. "|r"
    end
    line = line:gsub("(%s)(true)(%s*)", "%1|cff00ff00%2|r%3")
    line = line:gsub("(%s)(true)$", "%1|cff00ff00%2|r")
    line = line:gsub("(%s)(false)(%s*)", "%1|cffff4444%2|r%3")
    line = line:gsub("(%s)(false)$", "%1|cffff4444%2|r")
    line = line:gsub("(%s)(nil)(%s*)", "%1|cff888888%2|r%3")
    line = line:gsub("(%s)(nil)$", "%1|cff888888%2|r")
    return line
end

function ns.RefreshDebugPanel()
    if not debugFrame or not debugFrame:IsShown() then return end

    local lines = BuildDebugLines(false)
    local colorized = {}
    for i, line in ipairs(lines) do
        colorized[i] = ColorizeLine(line)
    end

    debugText:SetText(table.concat(colorized, "\n"))
    debugScrollChild:SetHeight(debugText:GetStringHeight() + 20)
end

-- Copy popup: shows an editable text box with plain-text debug info
local copyFrame = nil

local function ShowCopyPopup()
    if not copyFrame then
        local f = CreateFrame("Frame", "DominosHoldToCastFixCopyFrame", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(480, 400)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("FULLSCREEN_DIALOG")

        f.TitleBg:SetHeight(30)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        f.title:SetPoint("TOP", f.TitleBg, "TOP", 0, -3)
        f.title:SetText("Copy Debug Info")

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", f.InsetBg, "TOPLEFT", 10, -6)
        hint:SetTextColor(0.7, 0.7, 0.7)
        hint:SetText("Press Ctrl+A then Ctrl+C to copy")

        local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", f.InsetBg, "TOPLEFT", 8, -22)
        scrollFrame:SetPoint("BOTTOMRIGHT", f.InsetBg, "BOTTOMRIGHT", -26, 6)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(true)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetWidth(scrollFrame:GetWidth() - 10)
        editBox:SetScript("OnEscapePressed", function() f:Hide() end)
        scrollFrame:SetScrollChild(editBox)

        f.editBox = editBox
        copyFrame = f
    end

    local lines = BuildDebugLines(true)
    local text = table.concat(lines, "\n")

    copyFrame.editBox:SetText(text)
    copyFrame:Show()
    copyFrame.editBox:HighlightText()
    copyFrame.editBox:SetFocus()
end

ns.ShowCopyPopup = ShowCopyPopup

local function CreateDebugPanel(parent)
    local frame = CreateFrame("Frame", "DominosHoldToCastFixDebugFrame", parent, "BasicFrameTemplateWithInset")
    frame:SetSize(360, parent:GetHeight())
    frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", -1, 0)
    frame:SetMovable(false)
    frame:EnableMouse(true)
    frame:SetFrameStrata("DIALOG")

    frame.TitleBg:SetHeight(30)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -3)
    frame.title:SetText("Debug")

    -- Copy button at bottom-left
    local copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    copyBtn:SetSize(70, 22)
    copyBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
    copyBtn:SetText("Copy")
    copyBtn:SetScript("OnClick", function() ns.ShowCopyPopup() end)

    -- Refresh button at bottom-right
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(70, 22)
    refreshBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function() ns.RefreshDebugPanel() end)

    -- Scroll frame, anchored above buttons
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 8, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -26, 30)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() - 4)
    scrollChild:SetHeight(1) -- will be resized by content
    scrollFrame:SetScrollChild(scrollChild)
    debugScrollChild = scrollChild

    local text = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 4, -4)
    text:SetPoint("RIGHT", scrollChild, "RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetSpacing(2)
    debugText = text

    -- Auto-refresh on show
    frame:SetScript("OnShow", function()
        frame:SetHeight(parent:GetHeight())
        scrollChild:SetWidth(scrollFrame:GetWidth() - 4)
        ns.RefreshDebugPanel()
    end)

    -- Live-update timer while visible
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.5 then
            self.elapsed = 0
            ns.RefreshDebugPanel()
        end
    end)

    return frame
end

function ns.ToggleDebug()
    if not configFrame then
        configFrame = CreateConfigPanel()
    end
    if not debugFrame then
        debugFrame = CreateDebugPanel(configFrame)
        debugFrame:Hide()
    end
    if debugFrame:IsShown() then
        debugFrame:Hide()
    else
        if not configFrame:IsShown() then
            configFrame:Show()
        end
        debugFrame:Show()
    end
end

function ns.ToggleConfig()
    if not configFrame then
        configFrame = CreateConfigPanel()
    end
    if configFrame:IsShown() then
        configFrame:Hide()
        if debugFrame then debugFrame:Hide() end
    else
        configFrame:Show()
    end
end
