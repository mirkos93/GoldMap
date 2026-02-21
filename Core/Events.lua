local addonName, GoldMap = ...
GoldMap = GoldMap or {}

local frame = CreateFrame("Frame")

local function SafeInit(moduleTable, moduleLabel)
  if not moduleTable or type(moduleTable.Init) ~= "function" then
    GoldMap:Printf("%s module is unavailable.", moduleLabel or "Unknown")
    return
  end

  local ok, err = pcall(moduleTable.Init, moduleTable)
  if not ok then
    GoldMap:Printf("%s init failed: %s", moduleLabel or "Unknown", tostring(err))
  end
end

local function InitializeRuntime()
  SafeInit(GoldMap.AHCache, "AHCache")
  SafeInit(GoldMap.Evaluator, "Evaluator")
  SafeInit(GoldMap.GatherEvaluator, "GatherEvaluator")
  SafeInit(GoldMap.Scanner, "Scanner")
  SafeInit(GoldMap.ScanAdvisor, "ScanAdvisor")
  SafeInit(GoldMap.Options, "Options")
  SafeInit(GoldMap.FilterPanel, "FilterPanel")
  SafeInit(GoldMap.Welcome, "Welcome")
  SafeInit(GoldMap.MinimapButton, "MinimapButton")
  SafeInit(GoldMap.WorldMapButton, "WorldMapButton")
  SafeInit(GoldMap.MobTooltip, "MobTooltip")
  SafeInit(GoldMap.ItemTooltip, "ItemTooltip")
  SafeInit(GoldMap.UnitOverlay, "UnitOverlay")
  SafeInit(GoldMap.WorldMapPins, "WorldMapPins")
  SafeInit(GoldMap.MinimapPins, "MinimapPins")

  GoldMap:NotifyFiltersChanged()
  C_Timer.After(1.0, function()
    GoldMap.Welcome:Show(false)
  end)
end

local function SlashCommand(msg)
  local command = string.lower((msg or ""):match("^%s*(.-)%s*$"))

  if command == "scan" then
    if GoldMap.Scanner and GoldMap.Scanner.StartSeedScan then
      GoldMap.Scanner:StartSeedScan(true)
    else
      GoldMap:Printf("Scanner module unavailable.")
    end
    return
  end

  if command == "filters" then
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
      ToggleWorldMap()
    end
    GoldMap.FilterPanel:ShowPanel(true)
    return
  end

  if command == "refresh" then
    GoldMap.WorldMapPins:RequestRefresh()
    if GoldMap.MinimapPins then
      GoldMap.MinimapPins:RequestRefresh()
    end
    GoldMap:NotifyFiltersChanged()
    return
  end

  if command == "advisor" then
    if GoldMap.ScanAdvisor and GoldMap.ScanAdvisor.CheckNow then
      GoldMap.ScanAdvisor:CheckNow(true)
    else
      GoldMap:Printf("Scan advisor module unavailable.")
    end
    return
  end

  if command == "stop" then
    GoldMap:Printf("No background scanner is running. GoldMap syncs from Auctionator on demand.")
    return
  end

  if command == "debug" then
    GoldMap:SetDebugEnabled(not GoldMap:IsDebugEnabled())
    return
  end

  if command == "welcome" then
    GoldMap.Welcome:Show(true)
    return
  end

  if command == "luadebug" then
    GoldMap:SetLuaDebugEnabled(not GoldMap:IsLuaDebugEnabled())
    GoldMap:Printf("Lua debug %s", GoldMap:IsLuaDebugEnabled() and "enabled" or "disabled")
    return
  end

  GoldMap.Options:Open()
end

frame:SetScript("OnEvent", function(_, eventName, ...)
  if eventName == "ADDON_LOADED" then
    local loadedAddon = ...
    if loadedAddon ~= addonName then
      return
    end
    GoldMap:InitializeSavedVariables()
    return
  end

  if eventName == "PLAYER_LOGIN" then
    InitializeRuntime()
    return
  end

  if eventName == "AUCTION_HOUSE_SHOW" then
    GoldMap:SendMessage("AH_OPENED")
    return
  end

  if eventName == "AUCTION_HOUSE_CLOSED" then
    GoldMap:SendMessage("AH_CLOSED")
    return
  end

  if eventName == "MODIFIER_STATE_CHANGED" then
    local key = ...
    if key == "LSHIFT" or key == "RSHIFT" then
      if GoldMap.PinTooltip and GoldMap.PinTooltip.RefreshIfShown then
        GoldMap.PinTooltip:RefreshIfShown()
      end
    end
    return
  end

end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")

SLASH_GOLDMAP1 = "/goldmap"
SLASH_GOLDMAP2 = "/gmfarm"
SlashCmdList.GOLDMAP = SlashCommand
