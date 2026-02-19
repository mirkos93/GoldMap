local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.MinimapPins = GoldMap.MinimapPins or {}

local EVENTS = {
  "PLAYER_ENTERING_WORLD",
  "PLAYER_LEAVING_WORLD",
  "ZONE_CHANGED",
  "ZONE_CHANGED_NEW_AREA",
  "ZONE_CHANGED_INDOORS",
  "MINIMAP_UPDATE_ZOOM",
  "PLAYER_STARTED_MOVING",
  "PLAYER_STOPPED_MOVING",
}

local function GetVectorXY(vec, maybeY)
  if vec == nil then
    return nil, nil
  end
  if type(vec) == "number" then
    return vec, maybeY
  end
  if vec.GetXY then
    return vec:GetXY()
  end
  return vec.x, vec.y
end

local function ColorForEV(evCopper)
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

local function GetGatherReferencePrice(eval)
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

local function ColorForGatherPrice(priceCopper)
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

local function ApplyPinHitRect(button, size)
  local iconSize = size or 14
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

local function MakePin(parent)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(14, 14)
  button:SetFrameLevel(parent:GetFrameLevel() + 15)
  button:EnableMouse(true)
  ApplyPinHitRect(button, 14)

  button.baseTexturePath = GoldMap:GetIconPath("pinBase", 64) or "Interface\\Buttons\\WHITE8X8"
  button.selectedTexturePath = GoldMap:GetIconPath("pinSelected", 64) or button.baseTexturePath

  local icon = button:CreateTexture(nil, "OVERLAY")
  icon:SetAllPoints()
  icon:SetTexture(button.baseTexturePath)
  button.icon = icon

  local valueHigh = button:CreateTexture(nil, "ARTWORK")
  valueHigh:SetSize(8, 8)
  valueHigh:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
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

function GoldMap.MinimapPins:BuildSpatialIndex()
  self.worldCellSize = 350
  self.zoneIndex = {}

  local function IndexSpawn(zoneKey, spawn, kind)
    if not zoneKey or not spawn then
      return
    end

    local wx = tonumber(spawn.wx)
    local wy = tonumber(spawn.wy)
    if not wx or not wy then
      return
    end

    local index = self.zoneIndex[zoneKey]
    if not index then
      index = {}
      self.zoneIndex[zoneKey] = index
    end

    local cellX = math.floor(wx / self.worldCellSize)
    local cellY = math.floor(wy / self.worldCellSize)
    local key = cellX .. ":" .. cellY
    index[key] = index[key] or {}
    table.insert(index[key], {
      kind = kind,
      data = spawn,
    })
  end

  for zoneKey, spawnList in pairs((GoldMapData and GoldMapData.Spawns) or {}) do
    for _, spawn in ipairs(spawnList) do
      IndexSpawn(zoneKey, spawn, "MOB")
    end
  end

  for zoneKey, spawnList in pairs((GoldMapData and GoldMapData.GatherSpawns) or {}) do
    for _, spawn in ipairs(spawnList) do
      IndexSpawn(zoneKey, spawn, "GATHER")
    end
  end
end

function GoldMap.MinimapPins:GetNearbySpawnsWorld(zoneKey, worldX, worldY, worldRange)
  local zoneIndex = self.zoneIndex and self.zoneIndex[zoneKey]
  if not zoneIndex or not worldX or not worldY or not worldRange then
    wipe(self.tmpCandidates)
    return self.tmpCandidates
  end

  wipe(self.tmpCandidates)

  local cellSpan = math.max(1, math.ceil(worldRange / self.worldCellSize))
  local centerCellX = math.floor(worldX / self.worldCellSize)
  local centerCellY = math.floor(worldY / self.worldCellSize)

  for cx = centerCellX - cellSpan, centerCellX + cellSpan do
    for cy = centerCellY - cellSpan, centerCellY + cellSpan do
      local key = cx .. ":" .. cy
      local list = zoneIndex[key]
      if list then
        for _, entry in ipairs(list) do
          table.insert(self.tmpCandidates, entry)
        end
      end
    end
  end

  return self.tmpCandidates
end

function GoldMap.MinimapPins:GetPlayerLocation()
  if not C_Map or not C_Map.GetPlayerMapPosition or not C_Map.GetWorldPosFromMapPos then
    return nil
  end

  local currentMapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not currentMapID then
    return nil
  end

  local zoneKey = GoldMap.Ids:GetZoneKeyForMapID(currentMapID, true)
  if not zoneKey then
    return nil
  end

  local mapPos = C_Map.GetPlayerMapPosition(currentMapID, "player")
  local x, y = GetVectorXY(mapPos)
  if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
    return nil
  end

  local instanceID, worldPos = C_Map.GetWorldPosFromMapPos(currentMapID, mapPos)
  local wx, wy = GetVectorXY(worldPos)
  if not wx or not wy then
    return nil
  end

  return {
    zoneKey = zoneKey,
    currentMapID = currentMapID,
    instanceID = instanceID,
    x = x,
    y = y,
    wx = wx,
    wy = wy,
  }
end

function GoldMap.MinimapPins:GetWorldRangeForMap(mapID, normalizedRange)
  local unitsPerMap = GoldMap.MapProjection:GetApproxWorldUnitsPerMap(mapID)
  if not unitsPerMap or unitsPerMap <= 0 then
    return normalizedRange * 12000
  end
  return normalizedRange * unitsPerMap
end

function GoldMap.MinimapPins:AcquirePin()
  local pin = self.pinPool[self.activeCount + 1]
  if not pin then
    pin = MakePin(self.container)
    self.pinPool[self.activeCount + 1] = pin
  end
  self.activeCount = self.activeCount + 1
  return pin
end

function GoldMap.MinimapPins:ReleaseAllPins()
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

function GoldMap.MinimapPins:FinalizePins()
  for i = self.activeCount + 1, #self.pinPool do
    local pin = self.pinPool[i]
    pin:Hide()
    pin.payload = nil
    pin.tintR, pin.tintG, pin.tintB = nil, nil, nil
    if pin.valueHigh then
      pin.valueHigh:Hide()
    end
  end
end

function GoldMap.MinimapPins:RequestRefresh()
  self.refreshThrottle:Run()
end

function GoldMap.MinimapPins:GetRefreshInterval()
  if self.isMoving then
    return 0.03
  end
  return 0.12
end

function GoldMap.MinimapPins:RefreshNow()
  if not self.initialized then
    return
  end
  if not GoldMap.db or not GoldMap.db.ui.showMinimapPins then
    self:ReleaseAllPins()
    return
  end
  if not Minimap or not Minimap:IsShown() then
    self:ReleaseAllPins()
    return
  end

  local playerLoc = self:GetPlayerLocation()
  if not playerLoc then
    self.lastZoneKey = nil
    self:ReleaseAllPins()
    return
  end

  local zoneKey = playerLoc.zoneKey
  if self.lastZoneKey and self.lastZoneKey ~= zoneKey then
    self:ReleaseAllPins()
  end
  self.lastZoneKey = zoneKey

  local evaluator = GoldMap.GetEvaluator and GoldMap:GetEvaluator() or nil
  local gatherEvaluator = GoldMap.GetGatherEvaluator and GoldMap:GetGatherEvaluator() or nil
  local filters = GoldMap.GetFilters and GoldMap:GetFilters() or {}
  local allowMob = filters.showMobTargets ~= false
  local allowGather = filters.showGatherTargets ~= false
  if not evaluator and not gatherEvaluator then
    self:ReleaseAllPins()
    return
  end

  self.activeCount = 0

  local range = math.max(0.005, math.min(0.2, GoldMap.db.ui.minimapRange or 0.035))
  local iconSize = math.max(8, math.min(22, GoldMap.db.ui.minimapIconSize or 14))
  local maxPins = math.max(10, math.min(300, GoldMap.db.ui.minimapMaxPins or 80))
  local zoomLevel = Minimap.GetZoom and (Minimap:GetZoom() or 0) or 0
  local zoomAdjustedRange = range / math.max(0.55, 1 + (zoomLevel * 0.22))
  local rangeSquared = zoomAdjustedRange * zoomAdjustedRange

  local worldRange = self:GetWorldRangeForMap(playerLoc.currentMapID, zoomAdjustedRange)
  local worldRangeSquared = worldRange * worldRange

  local radiusPixels = math.max(35, (Minimap:GetWidth() * 0.5) - iconSize - 2)
  local scale = radiusPixels / zoomAdjustedRange

  local evalByNpc = {}
  local evalByNode = {}
  local mobSeed = GoldMapData and GoldMapData.SeedDrops
  local gatherNodes = GoldMapData and GoldMapData.GatherNodes
  local candidates = self:GetNearbySpawnsWorld(zoneKey, playerLoc.wx, playerLoc.wy, worldRange)
  wipe(self.tmpVisible)

  for _, entry in ipairs(candidates) do
    local spawn = entry.data
    local wx = tonumber(spawn.wx)
    local wy = tonumber(spawn.wy)
    if wx and wy then
      local dwx = wx - playerLoc.wx
      local dwy = wy - playerLoc.wy
      local distWorldSquared = (dwx * dwx) + (dwy * dwy)
      if distWorldSquared <= worldRangeSquared then
        local sx, sy = GoldMap.MapProjection:ProjectSpawnToMap(spawn, playerLoc.currentMapID)
        if sx and sy and sx >= 0 and sx <= 1 and sy >= 0 and sy <= 1 then
          local dx = sx - playerLoc.x
          local dy = sy - playerLoc.y
          local distNormSquared = (dx * dx) + (dy * dy)
          if distNormSquared <= rangeSquared then
            if entry.kind == "MOB" and allowMob and evaluator and mobSeed and mobSeed[spawn.npcID] then
              local eval = evalByNpc[spawn.npcID]
              if eval == nil then
                eval = evaluator:EvaluateMobByID(spawn.npcID)
                evalByNpc[spawn.npcID] = eval or false
              elseif eval == false then
                eval = nil
              end

              if eval then
                table.insert(self.tmpVisible, {
                  kind = "MOB",
                  spawn = spawn,
                  mob = eval.mob,
                  eval = eval,
                  distSquared = distNormSquared,
                  dx = dx,
                  dy = dy,
                })
              end
            elseif entry.kind == "GATHER" and allowGather and gatherEvaluator and gatherNodes and gatherNodes[spawn.nodeID] then
              local eval = evalByNode[spawn.nodeID]
              if eval == nil then
                eval = gatherEvaluator:EvaluateNodeByID(spawn.nodeID)
                evalByNode[spawn.nodeID] = eval or false
              elseif eval == false then
                eval = nil
              end

              if eval then
                table.insert(self.tmpVisible, {
                  kind = "GATHER",
                  spawn = spawn,
                  node = gatherNodes[spawn.nodeID],
                  eval = eval,
                  distSquared = distNormSquared,
                  dx = dx,
                  dy = dy,
                })
              end
            end
          end
        end
      end
    end
  end

  table.sort(self.tmpVisible, function(a, b)
    if a.distSquared == b.distSquared then
      return (a.eval.evCopper or 0) > (b.eval.evCopper or 0)
    end
    return a.distSquared < b.distSquared
  end)

  local rotateMinimap = GetCVar and GetCVar("rotateMinimap") == "1"
  local facing = rotateMinimap and (GetPlayerFacing and GetPlayerFacing() or 0) or 0
  local sinFacing = math.sin(facing)
  local cosFacing = math.cos(facing)
  local placedCandidates = {}
  local mobVisible = {}
  local gatherVisible = {}
  local gatherHerbVisible = {}
  local gatherMiningVisible = {}
  local gatherOtherVisible = {}
  for _, candidate in ipairs(self.tmpVisible) do
    if candidate.kind == "GATHER" then
      table.insert(gatherVisible, candidate)
      local profession = candidate.node and candidate.node.profession
      if profession == "MINING" then
        table.insert(gatherMiningVisible, candidate)
      elseif profession == "HERBALISM" then
        table.insert(gatherHerbVisible, candidate)
      else
        table.insert(gatherOtherVisible, candidate)
      end
    else
      table.insert(mobVisible, candidate)
    end
  end

  local gatherQuota = 0
  local mobQuota = maxPins
  if #gatherVisible > 0 and #mobVisible > 0 then
    gatherQuota = math.max(8, math.floor(maxPins * 0.35))
    mobQuota = math.max(0, maxPins - gatherQuota)
  end

  local function TryPlaceCandidate(candidate)
    if self.activeCount >= maxPins then
      return false
    end
    if placedCandidates[candidate] then
      return false
    end

    local eval = candidate.eval
    local vx = candidate.dx
    local vy = -candidate.dy

    if rotateMinimap then
      local rx = (vx * cosFacing) - (vy * sinFacing)
      local ry = (vx * sinFacing) + (vy * cosFacing)
      vx, vy = rx, ry
    end

    local px = vx * scale
    local py = vy * scale
    local pixelDist = math.sqrt((px * px) + (py * py))
    if pixelDist > radiusPixels and pixelDist > 0 then
      local clampScale = radiusPixels / pixelDist
      px = px * clampScale
      py = py * clampScale
    end

    local pin = self:AcquirePin()
    pin:SetSize(iconSize, iconSize)
    ApplyPinHitRect(pin, iconSize)
    pin:ClearAllPoints()
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
      local gatherPrice = GetGatherReferencePrice(eval)
      r, g, b = ColorForGatherPrice(gatherPrice)
      valueHigh = (gatherPrice or 0) >= (40 * 10000)
    else
      r, g, b = ColorForEV(eval.evCopper)
      valueHigh = (eval.evCopper or 0) >= (40 * 10000)
    end
    pin.tintR, pin.tintG, pin.tintB = r, g, b
    pin.icon:SetTexture(GetIconForPayload(pin.payload) or pin.baseTexturePath)
    pin.icon:SetVertexColor(r, g, b, 0.95)
    pin.valueHigh:SetShown(valueHigh)
    pin:SetPoint("CENTER", Minimap, "CENTER", px, py)
    pin:Show()
    placedCandidates[candidate] = true
    return true
  end

  local placedGather = 0
  local placedMob = 0

  if gatherQuota > 0 then
    local miningQuota = 0
    local herbQuota = 0
    if #gatherMiningVisible > 0 and #gatherHerbVisible > 0 then
      miningQuota = math.max(1, math.floor(gatherQuota * 0.4))
      herbQuota = math.max(1, gatherQuota - miningQuota)
    end

    if miningQuota > 0 then
      for _, candidate in ipairs(gatherMiningVisible) do
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
      for _, candidate in ipairs(gatherHerbVisible) do
        if placedHerb >= herbQuota then
          break
        end
        if TryPlaceCandidate(candidate) then
          placedHerb = placedHerb + 1
          placedGather = placedGather + 1
        end
      end
    end

    for _, candidate in ipairs(gatherVisible) do
      if placedGather >= gatherQuota then
        break
      end
      if TryPlaceCandidate(candidate) then
        placedGather = placedGather + 1
      end
    end

    if placedGather < gatherQuota and #gatherOtherVisible > 0 then
      for _, candidate in ipairs(gatherOtherVisible) do
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
    for _, candidate in ipairs(mobVisible) do
      if placedMob >= mobQuota or self.activeCount >= maxPins then
        break
      end
      if TryPlaceCandidate(candidate) then
        placedMob = placedMob + 1
      end
    end
  end

  if self.activeCount < maxPins then
    for _, candidate in ipairs(self.tmpVisible) do
      if self.activeCount >= maxPins then
        break
      end
      TryPlaceCandidate(candidate)
    end
  end

  self:FinalizePins()
end

function GoldMap.MinimapPins:OnEvent(eventName)
  if not self.initialized then
    return
  end

  if eventName == "PLAYER_STARTED_MOVING" then
    self.isMoving = true
    self:RequestRefresh()
    return
  end

  if eventName == "PLAYER_STOPPED_MOVING" then
    self.isMoving = false
    self:RequestRefresh()
    return
  end

  if eventName == "PLAYER_ENTERING_WORLD" then
    self.lastZoneKey = nil
    self.isMoving = false
    self:ReleaseAllPins()
    C_Timer.After(1, function()
      self:RequestRefresh()
    end)
    return
  end

  if eventName == "PLAYER_LEAVING_WORLD" or eventName == "ZONE_CHANGED_NEW_AREA" or eventName == "ZONE_CHANGED" or eventName == "ZONE_CHANGED_INDOORS" then
    self.lastZoneKey = nil
    self.isMoving = false
    self:ReleaseAllPins()
    C_Timer.After(0.2, function()
      self:RequestRefresh()
    end)
    return
  end

  self:RequestRefresh()
end

function GoldMap.MinimapPins:Init()
  if self.initialized then
    return
  end
  if not Minimap then
    return
  end

  self.container = CreateFrame("Frame", "GoldMapMinimapOverlay", Minimap)
  self.container:SetAllPoints(Minimap)
  self.container:SetFrameLevel(Minimap:GetFrameLevel() + 6)
  self.container:EnableMouse(true)
  if self.container.SetPropagateMouseClicks then
    self.container:SetPropagateMouseClicks(true)
  end
  if self.container.SetPropagateMouseMotion then
    self.container:SetPropagateMouseMotion(true)
  end

  self.pinPool = {}
  self.activeCount = 0
  self.tmpCandidates = {}
  self.tmpVisible = {}

  self.refreshThrottle = GoldMap.Throttle:New(0.03, function()
    self:RefreshNow()
  end)

  self.eventFrame = CreateFrame("Frame")
  self.eventFrame:SetScript("OnEvent", function(_, eventName)
    self:OnEvent(eventName)
  end)
  for _, eventName in ipairs(EVENTS) do
    self.eventFrame:RegisterEvent(eventName)
  end

  self.isMoving = false
  self.updateAccumulator = 0
  self.updateFrame = CreateFrame("Frame")
  self.updateFrame:SetScript("OnUpdate", function(_, elapsed)
    self.updateAccumulator = self.updateAccumulator + (elapsed or 0)
    local interval = self:GetRefreshInterval()
    if self.updateAccumulator >= interval then
      self.updateAccumulator = 0
      self:RequestRefresh()
    end
  end)

  self:BuildSpatialIndex()

  GoldMap:RegisterMessage("FILTERS_CHANGED", function()
    self:RequestRefresh()
  end)
  GoldMap:RegisterMessage("PRICE_CACHE_UPDATED", function()
    self:RequestRefresh()
  end)
  GoldMap:RegisterMessage("GATHER_DATA_UPDATED", function()
    self:BuildSpatialIndex()
    self:RequestRefresh()
  end)

  self.initialized = true
end
