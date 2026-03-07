local addonName, ns = ...

local DominosHoldToCastFix = CreateFrame("Frame", "DominosHoldToCastFixFrame", UIParent)
ns.HoldToCastFix = DominosHoldToCastFix

-- Separate binding frames: bar1 needs its own so the state driver can clear
-- only bar1 bindings when bar1 pages away (vehicles, dragonriding)
-- without wiping other bars' bindings.
-- bar1 frame MUST be secure (SecureFrameTemplate) so ClearBindings() works
-- in the restricted execution environment of secure handlers during combat.
local bindingFrameBar1 = CreateFrame("Frame", "DominosHoldToCastFixBindingOwnerBar1", UIParent, "SecureFrameTemplate")
DominosHoldToCastFix.bindingFrameBar1 = bindingFrameBar1

-- Secure handler frame for combat-safe paging detection (bar1 only)
local stateFrame = CreateFrame("Frame", "DominosHoldToCastFixStateDriver", UIParent, "SecureHandlerStateTemplate")
stateFrame:SetFrameRef("bindingFrame", bindingFrameBar1)
DominosHoldToCastFix.stateFrame = stateFrame

-- Mapping: Dominos bar number -> keybind target prefix
local barToBindTarget = {
    [1]  = "ACTIONBUTTON",
    [3]  = "MULTIACTIONBAR3BUTTON",
    [4]  = "MULTIACTIONBAR4BUTTON",
    [5]  = "MULTIACTIONBAR2BUTTON",
    [6]  = "MULTIACTIONBAR1BUTTON",
    [12] = "MULTIACTIONBAR5BUTTON",
    [13] = "MULTIACTIONBAR6BUTTON",
    [14] = "MULTIACTIONBAR7BUTTON",
}
ns.barToBindTarget = barToBindTarget

-- Only bar 1 supports hold-to-cast with Dominos.
-- Non-bar-1 bars use MULTIACTIONBAR*BUTTON binding commands which are Lua-driven
-- (not engine-level TryUseActionButton), so they don't support hold-to-cast
-- re-triggering. Additionally, Dominos removes Blizzard buttons from
-- bar.actionButtons, breaking the Lua handlers entirely.
ns.supportedBars = {1}

ns.barToBlizzButton = {
    [1]  = "ActionButton",
    [3]  = "MultiBarBottomRightButton",
    [4]  = "MultiBarRightButton",
    [5]  = "MultiBarBottomLeftButton",
    [6]  = "MultiBarLeftButton",
    [12] = "MultiBar5Button",
    [13] = "MultiBar6Button",
    [14] = "MultiBar7Button",
}

local defaults = {
    enabled = true,
    bars = { [1] = true },
    minimap = { show = false, angle = 220 },
}

DominosHoldToCastFix.pendingUpdate = false
DominosHoldToCastFix.bindingsActive = false
DominosHoldToCastFix.stateDriverActive = false
DominosHoldToCastFix.bar1Paged = false
DominosHoldToCastFix.bar1Page = 1

-- Debug event log (ring buffer, newest at end)
local DEBUG_LOG_MAX = 40
DominosHoldToCastFix.debugLog = {}

local function DebugLog(msg)
    local log = DominosHoldToCastFix.debugLog
    local ts = format("%.1f", GetTime() % 10000)
    log[#log + 1] = ts .. "  " .. msg
    if #log > DEBUG_LOG_MAX then
        table.remove(log, 1)
    end
    if ns.RefreshDebugPanel then ns.RefreshDebugPanel() end
end
ns.DebugLog = DebugLog

local function HasBar1Enabled()
    local db = DominosHoldToCastFixDB
    return db and db.bars and db.bars[1] or false
end

local function HasAnyNonBar1Enabled()
    return false
end

-- Build paging condition string for bar1 state driver.
-- Returns actual page numbers for tracking.
-- Vehicle/override/possess return 0 (bindings cleared).
-- Form paging returns actual page numbers; the engine-side page
-- is handled by ActionBarController.
local function GetPagingConditions()
    local conditions = ""

    -- Vehicle/override/possess: return 0 (clear bindings for these)
    if GetOverrideBarIndex then
        conditions = conditions .. "[overridebar] 0; "
    end
    if GetVehicleBarIndex then
        conditions = conditions .. "[vehicleui] 0; [possessbar] 0; "
    end

    -- Bonus bar form paging (Druid forms, Rogue stealth, etc.)
    conditions = conditions .. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; "

    -- Temp shapeshift bar (quest transformations, etc.)
    if GetTempShapeshiftBarIndex then
        conditions = conditions .. format("[shapeshift] %d; ", GetTempShapeshiftBarIndex())
    end

    -- Manual bar switching
    conditions = conditions .. "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "

    -- Rogue Shadow Dance / special bonusbar:5
    conditions = conditions .. "[bonusbar:5] 11; "

    -- Default: page 1
    conditions = conditions .. "1"

    DebugLog("PagingConditions: " .. conditions)
    return conditions
end

-- Secure handler: manages bar1 paging.
-- For vehicle/override (page == 0), clears bindings and lets Dominos handle.
-- For form paging (page >= 1), bindings stay active — the engine-side page
-- is updated by ActionBarController so ACTIONBUTTON bindings fire correctly.
stateFrame:SetAttribute("_onstate-htcfpage", [[
    local page = tonumber(newstate)

    if not page or page == 0 then
        -- Vehicle/override/possess: clear bindings
        local bf = self:GetFrameRef("bindingFrame")
        if bf then
            bf:ClearBindings()
        end
    end

    self:CallMethod("OnSecureStateChanged")
]])

-- Lua callback: handles bar1 paging state changes.
-- page == 0: vehicle/override — bindings cleared by secure handler
-- page >= 1: normal or form — bindings stay active, engine handles paging
function stateFrame:OnSecureStateChanged()
    local page = tonumber(self:GetAttribute("state-htcfpage")) or 0
    DebugLog("StateChanged: page=" .. tostring(page) .. " combat=" .. tostring(InCombatLockdown()))

    DominosHoldToCastFix.bar1Page = page

    if page == 0 then
        -- Vehicle/override/possess: bindings cleared by secure handler
        DominosHoldToCastFix.bar1Paged = true
        DominosHoldToCastFix.bindingsActive = HasAnyNonBar1Enabled()
        DebugLog("  -> bar1Paged=true (vehicle/override), active=" .. tostring(DominosHoldToCastFix.bindingsActive))
    else
        if DominosHoldToCastFix.bar1Paged then
            -- Returning from vehicle/override — need to restore bar1 bindings
            DominosHoldToCastFix.bar1Paged = false
            if InCombatLockdown() then
                DominosHoldToCastFix.pendingUpdate = true
                DominosHoldToCastFix.bindingsActive = HasAnyNonBar1Enabled()
                DebugLog("  -> returning from vehicle, DEFERRED (combat), page=" .. page)
            else
                ClearOverrideBindings(bindingFrameBar1)
                DominosHoldToCastFix:SetBar1Bindings()
                DebugLog("  -> returning from vehicle, bindings restored, page=" .. page)
            end
        else
            -- Normal form switch: bindings stay active, engine pages ACTIONBUTTON
            DominosHoldToCastFix.bindingsActive = true
            DebugLog("  -> page=" .. page .. ", hold-to-cast active")
        end
    end

    if ns.UpdateActiveState then ns.UpdateActiveState() end
end

-- Apply bindings for bar1 only (used when bar1 returns from vehicle/override)
function DominosHoldToCastFix:SetBar1Bindings()
    local db = DominosHoldToCastFixDB
    if not db or not db.enabled or not db.bars or not db.bars[1] then return end

    local bindPrefix = barToBindTarget[1]
    if not bindPrefix then return end

    for i = 1, 12 do
        local bindCommand = bindPrefix .. i
        local keys = {GetBindingKey(bindCommand)}
        for _, key in ipairs(keys) do
            if key and key ~= "" then
                SetOverrideBinding(bindingFrameBar1, true, key, bindCommand)
            end
        end
    end
    self.bindingsActive = true
    if ns.UpdateActiveState then ns.UpdateActiveState() end
end

-- Apply bindings for all enabled bars
function DominosHoldToCastFix:SetBindings()
    local db = DominosHoldToCastFixDB
    if not db or not db.enabled or not db.bars then return end

    local anyActive = false

    for _, barNum in ipairs(ns.supportedBars) do
        if db.bars[barNum] then
            local bindPrefix = barToBindTarget[barNum]
            if bindPrefix then
                local bf = bindingFrameBar1
                for i = 1, 12 do
                    local bindCommand = bindPrefix .. i
                    local keys = {GetBindingKey(bindCommand)}
                    for _, key in ipairs(keys) do
                        if key and key ~= "" then
                            SetOverrideBinding(bf, true, key, bindCommand)
                        end
                    end
                end
                anyActive = true
            end
        end
    end

    self.bindingsActive = anyActive
    if ns.UpdateActiveState then ns.UpdateActiveState() end
end

function DominosHoldToCastFix:ApplyBindings()
    if InCombatLockdown() then
        self.pendingUpdate = true
        DebugLog("ApplyBindings: DEFERRED (combat)")
        return
    end

    DebugLog("ApplyBindings: clearing all")
    ClearOverrideBindings(bindingFrameBar1)
    self.bindingsActive = false
    self.bar1Paged = false
    self.bar1Page = 1

    local db = DominosHoldToCastFixDB
    if not db or not db.enabled then
        self:DisableStateDriver()
        DebugLog("ApplyBindings: disabled, done")
        if ns.UpdateActiveState then ns.UpdateActiveState() end
        return
    end

    -- Always teardown/rebuild state driver to pick up fresh conditions
    self:DisableStateDriver()
    self:SetBindings()
    self:EnableStateDriver()
    DebugLog("ApplyBindings: done, active=" .. tostring(self.bindingsActive) .. " page=" .. tostring(self.bar1Page))
end

function DominosHoldToCastFix:EnableStateDriver()
    local db = DominosHoldToCastFixDB
    if not db or not db.enabled then return end

    if HasBar1Enabled() then
        self.stateDriverActive = true
        local conds = GetPagingConditions()
        DebugLog("EnableStateDriver: registering")
        RegisterStateDriver(stateFrame, "htcfpage", conds)
    else
        self:DisableStateDriver()
    end
end

function DominosHoldToCastFix:DisableStateDriver()
    if self.stateDriverActive then
        UnregisterStateDriver(stateFrame, "htcfpage")
        self.stateDriverActive = false
    end
end

-- Re-register form paging events on Blizzard's ActionBarController.
-- Dominos may disable some ActionBarController events; re-registering
-- ensures the engine-side action bar page updates correctly for
-- Druid forms (etc.), making ACTIONBUTTON bindings fire the right slot.
local function EnableBlizzardFormPaging()
    local controller = _G.ActionBarController
    if not controller then return end
    controller:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    controller:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    DebugLog("EnableBlizzardFormPaging: registered events on ActionBarController")
end

function DominosHoldToCastFix:Initialize()
    if not DominosHoldToCastFixDB then
        DominosHoldToCastFixDB = {}
    end
    local DB = DominosHoldToCastFixDB

    -- Migrate from old single-bar format to multi-bar
    if DB.bar ~= nil then
        if DB.bars == nil then
            DB.bars = { [DB.bar] = true }
        end
        DB.bar = nil
    end

    -- Apply defaults for missing keys
    for k, v in pairs(defaults) do
        if DB[k] == nil then
            if type(v) == "table" then
                DB[k] = CopyTable(v)
            else
                DB[k] = v
            end
        end
    end

    if Dominos then
        hooksecurefunc(Dominos, "UPDATE_BINDINGS", function()
            DebugLog("Hook: Dominos:UPDATE_BINDINGS fired")
            DominosHoldToCastFix:ApplyBindings()
        end)
    end

    -- Let Blizzard's ActionBarController handle engine-side form paging
    EnableBlizzardFormPaging()

    if ns.InitMinimapButton then
        ns.InitMinimapButton()
    end

    self:ApplyBindings()
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.initialized = true
end

DominosHoldToCastFix:RegisterEvent("PLAYER_LOGIN")
DominosHoldToCastFix:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        self:Initialize()
        DebugLog("PLAYER_LOGIN: initialized")
    elseif event == "PLAYER_ENTERING_WORLD" then
        if self.initialized then
            DebugLog("PLAYER_ENTERING_WORLD: re-applying bindings")
            EnableBlizzardFormPaging()
            self:ApplyBindings()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        DebugLog("REGEN_ENABLED: pending=" .. tostring(self.pendingUpdate))
        if self.pendingUpdate then
            self.pendingUpdate = false
            self:ApplyBindings()
        end
    end
end)

SLASH_DOMINOSHOLDTOCASTFIX1 = "/dominoshold"
SLASH_DOMINOSHOLDTOCASTFIX2 = "/dhtcf"
SlashCmdList["DOMINOSHOLDTOCASTFIX"] = function()
    if ns.ToggleConfig then
        ns.ToggleConfig()
    end
end
