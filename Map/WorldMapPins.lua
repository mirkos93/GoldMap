local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.WorldMapPins = GoldMap.WorldMapPins or {}

local CONTINENT_ROOTS = {
  [1415] = true, -- Eastern Kingdoms
  [13] = true,   -- Eastern Kingdoms (parent)
  [1414] = true, -- Kalimdor
  [12] = true,   -- Kalimdor (parent)
}

local function ApplyPinHitRect(button, size)
  local iconSize = size or 16
  local inset = math.max(1, math.floor(iconSize * 0.22))
  button:SetHitRectInsets(inset, inset, inset, inset)
end

local function GetIconForPayload(payload)
  if not payload then
    return GoldMap:GetIconPath("pinBase", 64)
  end

  if payload.kind == "GATHER" and payload.node then
    return GoldMap.Ids:GetGatherNodeIconPath(payload.node.profession, 64)
  end

  return GoldMap:GetIconPath("pinBase", 64)
end

local function GetCandidateBucketType(candidate)
  if not candidate then
    return nil
  end
  if candidate.kind == "MOB" then
    return "MOB"
  end
  local profession = candidate.node and candidate.node.profession
  if profession == "HERBALISM" then
    return "HERB"
  elseif profession == "MINING" then
    return "ORE"
  end
  return "GATHER"
end

local function MakePin(parent)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(16, 16)
  button:EnableMouse(true)
  ApplyPinHitRect(button, 16)

  button.baseTexturePath = GoldMap:GetIconPath("pinBase", 64) or "Interface\\Buttons\\WHITE8X8"
  button.selectedTexturePath = GoldMap:GetIconPath("pinSelected", 64) or button.baseTexturePath

  local icon = button:CreateTexture(nil, "OVERLAY")
  icon:SetAllPoints()
  icon:SetTexture(button.baseTexturePath)
  button.icon = icon

  local valueHigh = button:CreateTexture(nil, "ARTWORK")
  valueHigh:SetSize(10, 10)
  valueHigh:SetPoint("TOPRIGHT", button, "TOPRIGHT", 3, 3)
  valueHigh:SetTexture(GoldMap:GetIconPath("valueHigh", 64) or "Interface\\Buttons\\WHITE8X8")
  valueHigh:Hide()
  button.valueHigh = valueHigh

  button:SetScript("OnEnter", function(self)
    GoldMap.PinTooltip:Show(self, self.payload)
  end)

  button:SetScript("OnLeave", function(self)
    GoldMap.PinTooltip:Hide()
  end)

  return button
end

function GoldMap.WorldMapPins:Init()
  if self.initialized then
    return
  end

  if not WorldMapFrame then
    UIParentLoadAddOn("Blizzard_WorldMap")
  end

  local canvas = WorldMapFrame and WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas() or nil
  if not canvas and WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
    canvas = WorldMapFrame.ScrollContainer.Child
  end

  if not WorldMapFrame or not canvas then
    GoldMap:Printf("World Map frame is unavailable; pins are disabled.")
    return
  end

  self.pinPool = {}
  self.activeCount = 0
  self.mapAtPositionCache = {}
  self.parentChainCache = {}
  self.projectedByMap = {}
  self.refreshThrottle = GoldMap.Throttle:New(0.15, function()
    self:RefreshNow()
  end)

  self.overlay = CreateFrame("Frame", "GoldMapWorldMapOverlay", canvas)
  self.overlay:SetAllPoints(canvas)
  self.overlay:SetFrameLevel(canvas:GetFrameLevel() + 50)
  self.overlay:SetFrameStrata("HIGH")
  self.overlay:EnableMouse(true)
  if self.overlay.SetPropagateMouseClicks then
    self.overlay:SetPropagateMouseClicks(true)
  end
  if self.overlay.SetPropagateMouseMotion then
    self.overlay:SetPropagateMouseMotion(true)
  end

  WorldMapFrame:HookScript("OnShow", function()
    self:RequestRefresh()
  end)

  if WorldMapFrame.SetMapID then
    hooksecurefunc(WorldMapFrame, "SetMapID", function()
      self:RequestRefresh()
    end)
  end

  GoldMap:RegisterMessage("FILTERS_CHANGED", function()
    self:RequestRefresh()
  end)

  GoldMap:RegisterMessage("PRICE_CACHE_UPDATED", function()
    self:RequestRefresh()
  end)
  GoldMap:RegisterMessage("GATHER_DATA_UPDATED", function()
    self:RequestRefresh()
  end)

  self.initialized = true
end

function GoldMap.WorldMapPins:AcquirePin()
  local pin = self.pinPool[self.activeCount + 1]
  if not pin then
    pin = MakePin(self.overlay)
    self.pinPool[self.activeCount + 1] = pin
  end
  self.activeCount = self.activeCount + 1
  pin:Show()
  return pin
end

function GoldMap.WorldMapPins:ReleaseAllPins()
  for _, pin in ipairs(self.pinPool) do
    pin:Hide()
    pin.payload = nil
    pin.tintR, pin.tintG, pin.tintB = nil, nil, nil
    if pin.valueHigh then
      pin.valueHigh:Hide()
    end
    if pin.icon and pin.baseTexturePath then
      pin.icon:SetTexture(pin.baseTexturePath)
      pin.icon:SetVertexColor(1, 1, 1, 1)
    end
    pin:ClearAllPoints()
  end
  self.activeCount = 0
end

function GoldMap.WorldMapPins:FinalizePins()
  for i = self.activeCount + 1, #self.pinPool do
    local pin = self.pinPool[i]
    pin:Hide()
    pin.payload = nil
    pin.tintR, pin.tintG, pin.tintB = nil, nil, nil
    if pin.valueHigh then
      pin.valueHigh:Hide()
    end
    if pin.icon and pin.baseTexturePath then
      pin.icon:SetTexture(pin.baseTexturePath)
      pin.icon:SetVertexColor(1, 1, 1, 1)
    end
  end
end

function GoldMap.WorldMapPins:GetCandidatePinSpacingPx(candidate)
  local ui = GoldMap.db and GoldMap.db.ui or {}
  if candidate and candidate.kind == "GATHER" then
    local profession = candidate.node and candidate.node.profession
    if profession == "HERBALISM" then
      return math.max(8, math.min(64, ui.worldHerbPinSpacing or 28))
    elseif profession == "MINING" then
      return math.max(8, math.min(64, ui.worldOrePinSpacing or 22))
    end
  end
  return math.max(8, math.min(64, ui.worldMobPinSpacing or 16))
end

function GoldMap.WorldMapPins:ColorForEV(evCopper)
  if not evCopper then
    return 0.62, 0.62, 0.62 -- gray
  end
  local evGold = evCopper / 10000
  if evGold >= 40 then
    return 1.00, 0.50, 0.00 -- orange
  elseif evGold >= 20 then
    return 0.64, 0.21, 0.93 -- purple
  elseif evGold >= 8 then
    return 0.00, 0.44, 0.87 -- blue
  elseif evGold >= 1 then
    return 0.12, 1.00, 0.00 -- green
  end
  return 0.62, 0.62, 0.62 -- gray
end

function GoldMap.WorldMapPins:GetGatherReferencePrice(eval)
  if not eval then
    return nil
  end
  if eval._gatherColorPrice ~= nil then
    return eval._gatherColorPrice or nil
  end

  local bestPrice = nil
  for _, row in ipairs(eval.items or {}) do
    if row.price and (not bestPrice or row.price > bestPrice) then
      bestPrice = row.price
    end
  end

  eval._gatherColorPrice = bestPrice or false
  return bestPrice
end

function GoldMap.WorldMapPins:ColorForGatherPrice(priceCopper)
  if not priceCopper then
    return 0.62, 0.62, 0.62 -- gray
  end
  local priceGold = priceCopper / 10000
  if priceGold >= 40 then
    return 1.00, 0.50, 0.00 -- orange
  elseif priceGold >= 20 then
    return 0.64, 0.21, 0.93 -- purple
  elseif priceGold >= 8 then
    return 0.00, 0.44, 0.87 -- blue
  elseif priceGold >= 1 then
    return 0.12, 1.00, 0.00 -- green
  end
  return 0.62, 0.62, 0.62 -- gray
end

function GoldMap.WorldMapPins:IsMapOrDescendant(candidateMapID, rootMapID)
  if not candidateMapID or not rootMapID then
    return false
  end
  if candidateMapID == rootMapID then
    return true
  end
  if not C_Map or not C_Map.GetMapInfo then
    return false
  end

  local cacheKey = tostring(candidateMapID) .. ":" .. tostring(rootMapID)
  if self.parentChainCache[cacheKey] ~= nil then
    return self.parentChainCache[cacheKey]
  end

  local current = candidateMapID
  for _ = 1, 12 do
    if not current then
      break
    end
    if current == rootMapID then
      self.parentChainCache[cacheKey] = true
      return true
    end
    local info = C_Map.GetMapInfo(current)
    current = info and info.parentMapID or nil
  end

  self.parentChainCache[cacheKey] = false
  return false
end

function GoldMap.WorldMapPins:GetMapAtPosition(parentMapID, x, y)
  if not parentMapID or not x or not y then
    return nil
  end
  if not C_Map or not C_Map.GetMapInfoAtPosition then
    return nil
  end

  local parentCache = self.mapAtPositionCache[parentMapID]
  if not parentCache then
    parentCache = {}
    self.mapAtPositionCache[parentMapID] = parentCache
  end

  local key = math.floor((x * 10000) + 0.5) .. ":" .. math.floor((y * 10000) + 0.5)
  local cached = parentCache[key]
  if cached ~= nil then
    return cached or nil
  end

  local mapInfo = C_Map.GetMapInfoAtPosition(parentMapID, x, y)
  local mapID = nil
  if type(mapInfo) == "table" then
    mapID = mapInfo.mapID
  elseif type(mapInfo) == "number" then
    mapID = mapInfo
  end
  parentCache[key] = mapID or false
  return mapID
end

function GoldMap.WorldMapPins:GetCurrentContext()
  if not WorldMapFrame or not WorldMapFrame:IsShown() then
    return nil, nil, nil
  end

  local mapID = WorldMapFrame:GetMapID()
  if not mapID then
    return nil, nil, nil
  end

  local zoneKey = GoldMap.Ids:GetZoneKeyForMapID(mapID, true)
  if not zoneKey then
    return nil, mapID, nil
  end

  local zoneData = GoldMapData and GoldMapData.Zones and GoldMapData.Zones[zoneKey]
  if not zoneData then
    return nil, mapID, nil
  end

  return zoneKey, mapID, zoneData
end

function GoldMap.WorldMapPins:GetProjectedPoint(spawn, mapID)
  if not spawn or not mapID then
    return nil
  end

  local mapCache = self.projectedByMap[mapID]
  if not mapCache then
    mapCache = {}
    self.projectedByMap[mapID] = mapCache
  end

  local cached = mapCache[spawn]
  if cached then
    return cached.x, cached.y
  end

  local px, py = GoldMap.MapProjection:ProjectSpawnToMap(spawn, mapID)
  if px and py and px >= 0 and px <= 1 and py >= 0 and py <= 1 then
    mapCache[spawn] = {
      x = px,
      y = py,
    }
    return px, py
  end

  return nil
end

function GoldMap.WorldMapPins:IsPointAllowedOnMap(currentMapID, px, py)
  if not currentMapID or not px or not py then
    return false
  end

  if not CONTINENT_ROOTS[currentMapID] then
    return true
  end

  local resolvedMapID = self:GetMapAtPosition(currentMapID, px, py)
  if not resolvedMapID then
    return false
  end

  return self:IsMapOrDescendant(resolvedMapID, currentMapID)
end

function GoldMap.WorldMapPins:RequestRefresh()
  self.refreshThrottle:Run()
end

function GoldMap.WorldMapPins:RefreshNow()
  if not GoldMap.db or not GoldMap.db.ui.showPins then
    self:ReleaseAllPins()
    return
  end

  local zoneKey, currentMapID = self:GetCurrentContext()
  if not zoneKey or not currentMapID then
    self:ReleaseAllPins()
    return
  end

  local mobSpawns = GoldMapData and GoldMapData.Spawns and GoldMapData.Spawns[zoneKey]
  local mobSeed = GoldMapData and GoldMapData.SeedDrops
  local gatherSpawns = GoldMapData and GoldMapData.GatherSpawns and GoldMapData.GatherSpawns[zoneKey]
  local gatherNodes = GoldMapData and GoldMapData.GatherNodes
  local filters = GoldMap.GetFilters and GoldMap:GetFilters() or {}
  local allowHerb = GoldMap.IsGatherProfessionEnabled and GoldMap:IsGatherProfessionEnabled("HERBALISM", filters) or true
  local allowOre = GoldMap.IsGatherProfessionEnabled and GoldMap:IsGatherProfessionEnabled("MINING", filters) or true

  local hasMobSource = (filters.showMobTargets ~= false) and mobSpawns and mobSeed and #mobSpawns > 0
  local hasGatherSource = (allowHerb or allowOre) and gatherSpawns and gatherNodes and #gatherSpawns > 0
  if not hasMobSource and not hasGatherSource then
    self:ReleaseAllPins()
    return
  end

  local mobEvaluator = GoldMap.GetEvaluator and GoldMap:GetEvaluator() or nil
  local gatherEvaluator = GoldMap.GetGatherEvaluator and GoldMap:GetGatherEvaluator() or nil
  if not mobEvaluator and not gatherEvaluator then
    self:ReleaseAllPins()
    return
  end

  local width = self.overlay:GetWidth()
  local height = self.overlay:GetHeight()
  if width <= 0 or height <= 0 then
    return
  end

  self.activeCount = 0
  local evalByNpc = {}
  local evalByNode = {}
  local maxPins = (GoldMap.db.ui and GoldMap.db.ui.maxVisiblePins) or 2500
  local candidates = {}

  if hasMobSource and mobEvaluator then
    for _, spawn in ipairs(mobSpawns) do
      local px, py = self:GetProjectedPoint(spawn, currentMapID)
      if px and py and self:IsPointAllowedOnMap(currentMapID, px, py) then
        local mob = mobSeed[spawn.npcID]
        if mob then
          local eval = evalByNpc[spawn.npcID]
          if eval == nil then
            eval = mobEvaluator:EvaluateMobByID(spawn.npcID)
            evalByNpc[spawn.npcID] = eval or false
          elseif eval == false then
            eval = nil
          end

          if eval then
            table.insert(candidates, {
              kind = "MOB",
              id = spawn.npcID,
              px = px,
              py = py,
              spawn = spawn,
              mob = mob,
              eval = eval,
            })
          end
        end
      end
    end
  end

  if hasGatherSource and gatherEvaluator then
    for _, spawn in ipairs(gatherSpawns) do
      local px, py = self:GetProjectedPoint(spawn, currentMapID)
      if px and py and self:IsPointAllowedOnMap(currentMapID, px, py) then
        local node = gatherNodes[spawn.nodeID]
        if node and GoldMap:IsGatherProfessionEnabled(node.profession, filters) then
          local eval = evalByNode[spawn.nodeID]
          if eval == nil then
            eval = gatherEvaluator:EvaluateNodeByID(spawn.nodeID)
            evalByNode[spawn.nodeID] = eval or false
          elseif eval == false then
            eval = nil
          end

          if eval then
            table.insert(candidates, {
              kind = "GATHER",
              id = spawn.nodeID,
              px = px,
              py = py,
              spawn = spawn,
              node = node,
              eval = eval,
            })
          end
        end
      end
    end
  end

  table.sort(candidates, function(a, b)
    local aEV = a.eval and a.eval.evCopper or 0
    local bEV = b.eval and b.eval.evCopper or 0
    if aEV == bEV then
      if a.id == b.id then
        if a.py == b.py then
          return a.px < b.px
        end
        return a.py < b.py
      end
      return a.id < b.id
    end
    return aEV > bEV
  end)

  local occupied = {}
  local placedCandidates = {}
  local mobCandidates = {}
  local gatherCandidates = {}
  local gatherHerbCandidates = {}
  local gatherMiningCandidates = {}
  local gatherOtherCandidates = {}
  for _, candidate in ipairs(candidates) do
    if candidate.kind == "GATHER" then
      table.insert(gatherCandidates, candidate)
      local profession = candidate.node and candidate.node.profession
      if profession == "MINING" then
        table.insert(gatherMiningCandidates, candidate)
      elseif profession == "HERBALISM" then
        table.insert(gatherHerbCandidates, candidate)
      else
        table.insert(gatherOtherCandidates, candidate)
      end
    else
      table.insert(mobCandidates, candidate)
    end
  end

  local gatherQuota = 0
  local mobQuota = maxPins
  if #gatherCandidates > 0 and #mobCandidates > 0 then
    gatherQuota = math.max(80, math.floor(maxPins * 0.35))
    mobQuota = math.max(0, maxPins - gatherQuota)
  end

  local function TryPlaceCandidate(candidate)
    if self.activeCount >= maxPins then
      return false
    end
    if placedCandidates[candidate] then
      return false
    end

    local spacingPx = self:GetCandidatePinSpacingPx(candidate)
    local spacingW = math.max(0.001, spacingPx / width)
    local spacingH = math.max(0.001, spacingPx / height)
    local cx = math.floor(candidate.px / spacingW)
    local cy = math.floor(candidate.py / spacingH)
    local bucketType = GetCandidateBucketType(candidate) or candidate.kind or "GEN"
    local key = bucketType .. ":" .. cx .. ":" .. cy
    if occupied[key] then
      return false
    end
    occupied[key] = true

    local eval = candidate.eval
    local pin = self:AcquirePin()
    pin:SetSize(16, 16)
    ApplyPinHitRect(pin, 16)
    pin.payload = {
      kind = candidate.kind,
      spawn = candidate.spawn,
      mob = candidate.mob,
      node = candidate.node,
      eval = eval,
    }

    local r, g, b
    local valueHigh = false
    if candidate.kind == "GATHER" then
      local gatherPrice = self:GetGatherReferencePrice(eval)
      r, g, b = self:ColorForGatherPrice(gatherPrice)
      valueHigh = (gatherPrice or 0) >= (40 * 10000)
    else
      r, g, b = self:ColorForEV(eval.evCopper)
      valueHigh = (eval.evCopper or 0) >= (40 * 10000)
    end
    pin.tintR, pin.tintG, pin.tintB = r, g, b
    pin.icon:SetTexture(GetIconForPayload(pin.payload) or pin.baseTexturePath)
    pin.icon:SetVertexColor(r, g, b, 0.95)
    pin.valueHigh:SetShown(valueHigh)
    pin:SetPoint("CENTER", self.overlay, "TOPLEFT", candidate.px * width, -(candidate.py * height))
    placedCandidates[candidate] = true
    return true
  end

  local placedGather = 0
  local placedMob = 0

  if gatherQuota > 0 then
    local miningQuota = 0
    local herbQuota = 0
    if #gatherMiningCandidates > 0 and #gatherHerbCandidates > 0 then
      miningQuota = math.max(1, math.floor(gatherQuota * 0.4))
      herbQuota = math.max(1, gatherQuota - miningQuota)
    end

    if miningQuota > 0 then
      for _, candidate in ipairs(gatherMiningCandidates) do
        if placedGather >= miningQuota then
          break
        end
        if TryPlaceCandidate(candidate) then
          placedGather = placedGather + 1
        end
      end
    end

    if herbQuota > 0 then
      local placedHerb = 0
      for _, candidate in ipairs(gatherHerbCandidates) do
        if placedHerb >= herbQuota then
          break
        end
        if TryPlaceCandidate(candidate) then
          placedHerb = placedHerb + 1
          placedGather = placedGather + 1
        end
      end
    end

    for _, candidate in ipairs(gatherCandidates) do
      if placedGather >= gatherQuota then
        break
      end
      if TryPlaceCandidate(candidate) then
        placedGather = placedGather + 1
      end
    end

    if placedGather < gatherQuota and #gatherOtherCandidates > 0 then
      for _, candidate in ipairs(gatherOtherCandidates) do
        if placedGather >= gatherQuota then
          break
        end
        if TryPlaceCandidate(candidate) then
          placedGather = placedGather + 1
        end
      end
    end
  end

  if mobQuota > 0 then
    for _, candidate in ipairs(mobCandidates) do
      if placedMob >= mobQuota or self.activeCount >= maxPins then
        break
      end
      if TryPlaceCandidate(candidate) then
        placedMob = placedMob + 1
      end
    end
  end

  if self.activeCount < maxPins then
    for _, candidate in ipairs(candidates) do
      if self.activeCount >= maxPins then
        break
      end
      TryPlaceCandidate(candidate)
    end
  end

  if self.activeCount >= maxPins then
    local now = GetTime()
    if not self.lastCapWarningAt or (now - self.lastCapWarningAt) > 10 then
      self.lastCapWarningAt = now
      GoldMap:Printf("Pin display capped at %d for performance. Tighten filters to refine.", maxPins)
    end
  end

  self:FinalizePins()
end
