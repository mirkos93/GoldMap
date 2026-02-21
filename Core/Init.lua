local addonName, GoldMap = ...
GoldMap = GoldMap or {}
_G.GoldMap = GoldMap
GoldMap.Evaluator = GoldMap.Evaluator or {}
if type(GoldMap.Evaluator.Init) ~= "function" then
  GoldMap.Evaluator._isFallback = true
  function GoldMap.Evaluator:Init()
    self.initialized = true
  end
end
if type(GoldMap.Evaluator.EvaluateMobByID) ~= "function" then
  GoldMap.Evaluator._isFallback = true
  function GoldMap.Evaluator:EvaluateMobByID()
    return nil
  end
end
GoldMap.GatherEvaluator = GoldMap.GatherEvaluator or {}
if type(GoldMap.GatherEvaluator.Init) ~= "function" then
  function GoldMap.GatherEvaluator:Init()
    self.initialized = true
  end
end
if type(GoldMap.GatherEvaluator.EvaluateNodeByID) ~= "function" then
  function GoldMap.GatherEvaluator:EvaluateNodeByID()
    return nil
  end
end

GoldMap.addonName = addonName
GoldMap.version = "0.1.3-beta"

GoldMapData = GoldMapData or {}

GoldMap.defaults = {
  filters = {
    showMobTargets = true,
    showGatherTargets = true,
    showHerbTargets = true,
    showOreTargets = true,
    minDropRate = 0,
    maxDropRate = 100,
    gatherMinDropRate = 0,
    gatherMaxDropRate = 100,
    minMobLevel = 1,
    maxMobLevel = 63,
    hideRareMobs = false,
    difficultyScope = "ANY",
    minDifficultyTier = 1,
    maxDifficultyTier = 5,
    onlyKillableForPlayer = true,
    filterMode = "ALL",
    minEVGold = 0,
    maxEVGold = 999999,
    gatherMinEVGold = 0,
    gatherMaxEVGold = 999999,
    minItemPriceGold = 0,
    gatherMinItemPriceGold = 0,
    minReliabilityTier = 0,
    gatherMinReliabilityTier = 0,
    minSellSpeedTier = 0,
    gatherMinSellSpeedTier = 0,
    minQuality = 1,
    gatherMinQuality = 1,
    showNoPricePins = true,
  },
  ui = {
    showPins = true,
    showMinimapPins = true,
    hideMinimapButton = false,
    showItemTooltipMarket = true,
    filterSimpleMode = true,
    maxTooltipItems = 6,
    maxVisiblePins = 2500,
    minimapMaxPins = 80,
    minimapRange = 0.035,
    minimapIconSize = 14,
    worldMobPinSpacing = 16,
    worldHerbPinSpacing = 28,
    worldOrePinSpacing = 22,
    minimapMobPinSpacing = 12,
    minimapHerbPinSpacing = 18,
    minimapOrePinSpacing = 14,
  },
  scanner = {
    useAuctionatorData = true,
    auctionatorMaxAgeDays = 7,
    staleSeconds = 6 * 60 * 60,
    scanAdvisorEnabled = true,
    advisorIntervalMinutes = 10,
    advisorNotifyCooldownMinutes = 45,
    advisorYellowHours = 12,
    advisorRedHours = 24,
    advisorYellowStaleRatio = 0.30,
    advisorRedStaleRatio = 0.55,
    advisorYellowMissingRatio = 0.20,
    advisorRedMissingRatio = 0.40,
  },
  customPresets = {},
  debug = {
    enabled = false,
    luaErrors = false,
  },
  meta = {
    welcomeSeen = false,
  },
}

GoldMap.listeners = {}
GoldMap.media = {
  icon64Base = "Interface\\AddOns\\GoldMap\\Media\\Icons\\BLP\\64\\",
  icon512Base = "Interface\\AddOns\\GoldMap\\Media\\Icons\\BLP\\512\\",
}

GoldMap.media.icons = {
  pinBase = "goldmap-pin-base.blp",
  pinSelected = "goldmap-pin-selected.blp",
  nodeHerb = "goldmap-node-herb.blp",
  nodeOre = "goldmap-node-ore.blp",
  valueHigh = "goldmap-value-high.blp",
  uiSearch = "goldmap-ui-search.blp",
  uiInfo = "goldmap-ui-info.blp",
  qualityCommon = "goldmap-badge-quality-common.blp",
  qualityUncommon = "goldmap-badge-quality-uncommon.blp",
  qualityRare = "goldmap-badge-quality-rare.blp",
  qualityEpic = "goldmap-badge-quality-epic.blp",
}

function GoldMap:GetIconPath(iconKey, size)
  local filename = self.media.icons[iconKey]
  if not filename then
    return nil
  end
  if size == 512 then
    return self.media.icon512Base .. filename
  end
  return self.media.icon64Base .. filename
end

local function CopyDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      target[key] = target[key] or {}
      CopyDefaults(target[key], value)
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

function GoldMap:InitializeSavedVariables()
  local hadHerbTargets = GoldMapDB and GoldMapDB.filters and GoldMapDB.filters.showHerbTargets ~= nil
  local hadOreTargets = GoldMapDB and GoldMapDB.filters and GoldMapDB.filters.showOreTargets ~= nil

  GoldMapDB = GoldMapDB or {}
  CopyDefaults(GoldMapDB, self.defaults)
  self.db = GoldMapDB

  GoldMapPriceCache = GoldMapPriceCache or {
    items = {},
    revision = 0,
    lastScanAt = 0,
  }

  if self.db and self.db.filters and self.db.filters.showNoPricePins == false then
    local itemCount = 0
    if GoldMapPriceCache and GoldMapPriceCache.items then
      for _ in pairs(GoldMapPriceCache.items) do
        itemCount = itemCount + 1
        break
      end
    end
    if itemCount == 0 then
      self.db.filters.showNoPricePins = true
    end
  end

  -- This addon always filters to attackable farm targets.
  -- Keep the setting hard-locked for stability and UX simplicity.
  if self.db and self.db.filters then
    self.db.filters.onlyKillableForPlayer = true
    self.db.filters.hideRareMobs = self.db.filters.hideRareMobs == true
  end

  if self.db and self.db.scanner then
    self.db.scanner.useAuctionatorData = true
    self.db.scanner.auctionatorMaxAgeDays = math.max(0, math.min(14, math.floor(tonumber(self.db.scanner.auctionatorMaxAgeDays) or 7)))
    self.db.scanner.scanAdvisorEnabled = self.db.scanner.scanAdvisorEnabled ~= false
    self.db.scanner.advisorIntervalMinutes = math.max(2, math.min(60, math.floor(tonumber(self.db.scanner.advisorIntervalMinutes) or 10)))
    self.db.scanner.advisorNotifyCooldownMinutes = math.max(5, math.min(180, math.floor(tonumber(self.db.scanner.advisorNotifyCooldownMinutes) or 45)))
    self.db.scanner.advisorYellowHours = math.max(6, math.min(72, math.floor(tonumber(self.db.scanner.advisorYellowHours) or 12)))
    self.db.scanner.advisorRedHours = math.max(self.db.scanner.advisorYellowHours, math.min(120, math.floor(tonumber(self.db.scanner.advisorRedHours) or 24)))
    self.db.scanner.advisorYellowStaleRatio = math.max(0.05, math.min(0.95, tonumber(self.db.scanner.advisorYellowStaleRatio) or 0.30))
    self.db.scanner.advisorRedStaleRatio = math.max(self.db.scanner.advisorYellowStaleRatio, math.min(0.99, tonumber(self.db.scanner.advisorRedStaleRatio) or 0.55))
    self.db.scanner.advisorYellowMissingRatio = math.max(0.05, math.min(0.95, tonumber(self.db.scanner.advisorYellowMissingRatio) or 0.20))
    self.db.scanner.advisorRedMissingRatio = math.max(self.db.scanner.advisorYellowMissingRatio, math.min(0.99, tonumber(self.db.scanner.advisorRedMissingRatio) or 0.40))
  end

  if self.db and self.db.filters and self.db.meta and not self.db.meta.gatherSplitMigrated then
    local gatherEnabled = self.db.filters.showGatherTargets ~= false
    if not hadHerbTargets then
      self.db.filters.showHerbTargets = gatherEnabled
    end
    if not hadOreTargets then
      self.db.filters.showOreTargets = gatherEnabled
    end
    self.db.meta.gatherSplitMigrated = true
  end

  self:SetLuaDebugEnabled(self.db.debug.luaErrors)
end

function GoldMap:GetFilters()
  return self.db and self.db.filters or self.defaults.filters
end

function GoldMap:IsGatherProfessionEnabled(profession, filters)
  filters = filters or self:GetFilters()
  local gatherEnabled = filters.showGatherTargets ~= false
  local herbEnabled = filters.showHerbTargets
  local oreEnabled = filters.showOreTargets

  if herbEnabled == nil then
    herbEnabled = gatherEnabled
  end
  if oreEnabled == nil then
    oreEnabled = gatherEnabled
  end

  if profession == "HERBALISM" then
    return herbEnabled ~= false
  end
  if profession == "MINING" then
    return oreEnabled ~= false
  end

  return (herbEnabled ~= false) or (oreEnabled ~= false)
end

function GoldMap:GetEvaluator()
  local evaluator = self and self.Evaluator
  if type(evaluator) ~= "table" or type(evaluator.EvaluateMobByID) ~= "function" then
    return nil
  end

  if evaluator._isFallback then
    local now = GetTime and GetTime() or 0
    if not self._fallbackEvaluatorWarningAt or (now - self._fallbackEvaluatorWarningAt) > 30 then
      self._fallbackEvaluatorWarningAt = now
      self:Printf("Evaluator module unavailable. Pins and tooltip evaluation are temporarily disabled.")
    end
    return nil
  end

  if not evaluator.initialized and type(evaluator.Init) == "function" then
    local ok, err = pcall(evaluator.Init, evaluator)
    if not ok then
      self:Debugf("Evaluator lazy init failed: %s", tostring(err))
      return nil
    end
  end

  return evaluator
end

function GoldMap:GetGatherEvaluator()
  local evaluator = self and self.GatherEvaluator
  if type(evaluator) ~= "table" or type(evaluator.EvaluateNodeByID) ~= "function" then
    return nil
  end

  if not evaluator.initialized and type(evaluator.Init) == "function" then
    local ok, err = pcall(evaluator.Init, evaluator)
    if not ok then
      self:Debugf("GatherEvaluator lazy init failed: %s", tostring(err))
      return nil
    end
  end

  return evaluator
end

function GoldMap:SetFilter(key, value)
  local filters = self:GetFilters()
  if key == "onlyKillableForPlayer" then
    value = true
  end
  if key == "showGatherTargets" then
    local enabled = value ~= false
    filters.showHerbTargets = enabled
    filters.showOreTargets = enabled
  elseif key == "showHerbTargets" then
    filters.showGatherTargets = (value ~= false) or (filters.showOreTargets ~= false)
  elseif key == "showOreTargets" then
    filters.showGatherTargets = (filters.showHerbTargets ~= false) or (value ~= false)
  end
  filters[key] = value
  self:NotifyFiltersChanged()
end

function GoldMap:NotifyFiltersChanged()
  if self.Evaluator and self.Evaluator.cache then
    wipe(self.Evaluator.cache)
  end
  if self.GatherEvaluator and self.GatherEvaluator.cache then
    wipe(self.GatherEvaluator.cache)
  end

  self:SendMessage("FILTERS_CHANGED")

  if self.WorldMapPins and self.WorldMapPins.RequestRefresh then
    self.WorldMapPins:RequestRefresh()
  end

  if self.MinimapPins and self.MinimapPins.RequestRefresh then
    self.MinimapPins:RequestRefresh()
  end

  if self.UnitOverlay and self.UnitOverlay.RefreshAll then
    self.UnitOverlay:RefreshAll()
  end

  if self.MobTooltip and self.MobTooltip.RefreshUnitTooltip then
    self.MobTooltip:RefreshUnitTooltip()
  end
end

function GoldMap:RegisterMessage(message, handler)
  self.listeners[message] = self.listeners[message] or {}
  table.insert(self.listeners[message], handler)
end

function GoldMap:SendMessage(message, ...)
  if not self.listeners[message] then
    return
  end

  for _, handler in ipairs(self.listeners[message]) do
    local ok, err = pcall(handler, ...)
    if not ok then
      geterrorhandler()("GoldMap message handler failed: " .. tostring(err))
    end
  end
end

function GoldMap:Printf(fmt, ...)
  local msg = string.format(fmt, ...)
  DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37GoldMap|r: " .. msg)
end

function GoldMap:Debugf(fmt, ...)
  if not self.db or not self.db.debug or not self.db.debug.enabled then
    return
  end
  local msg = string.format(fmt, ...)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66d9ffGoldMap Debug|r: " .. msg)
end

function GoldMap:SetDebugEnabled(enabled)
  self.db.debug.enabled = enabled and true or false
  self:Printf("Debug %s", self.db.debug.enabled and "enabled" or "disabled")
  if self.PinTooltip and self.PinTooltip.RefreshIfShown then
    self.PinTooltip:RefreshIfShown()
  end
end

function GoldMap:IsDebugEnabled()
  return self.db and self.db.debug and self.db.debug.enabled
end

function GoldMap:SetLuaDebugEnabled(enabled)
  local value = enabled and "1" or "0"
  if SetCVar then
    SetCVar("scriptErrors", value)
  end
  if self.db and self.db.debug then
    self.db.debug.luaErrors = enabled and true or false
  end
end

function GoldMap:IsLuaDebugEnabled()
  if GetCVar then
    return GetCVar("scriptErrors") == "1"
  end
  return self.db and self.db.debug and self.db.debug.luaErrors
end

function GoldMap:GetSecondsSinceLastScan()
  if not GoldMap.AHCache then
    return nil
  end
  local lastScanAt = GoldMap.AHCache:GetLastScanAt()
  if not lastScanAt or lastScanAt <= 0 then
    return nil
  end
  return math.max(0, GetServerTime() - lastScanAt)
end

function GoldMap:FormatAge(seconds)
  if not seconds then
    return "never"
  end
  if seconds < 60 then
    return string.format("%ds ago", seconds)
  end
  if seconds < 3600 then
    return string.format("%dm ago", math.floor(seconds / 60))
  end
  return string.format("%dh ago", math.floor(seconds / 3600))
end
