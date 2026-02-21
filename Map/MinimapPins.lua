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

local MinimapRadiusAPI = C_Minimap and C_Minimap.GetViewRadius

local MINIMAP_SIZE = {
  indoor = {
    [0] = 300,
    [1] = 240,
    [2] = 180,
    [3] = 120,
    [4] = 80,
    [5] = 50,
  },
  outdoor = {
    [0] = 466 + 2 / 3,
    [1] = 400,
    [2] = 333 + 1 / 3,
    [3] = 266 + 2 / 6,
    [4] = 200,
    [5] = 133 + 1 / 3,
  },
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
    return 0.62, 0.62, 0.62
  end
  local evGold = evCopper / 10000
  if evGold >= 40 then
    return 1.00, 0.50, 0.00
  elseif evGold >= 20 then
    return 0.64, 0.21, 0.93
  elseif evGold >= 8 then
    return 0.00, 0.44, 0.87
  elseif evGold >= 1 then
    return 0.12, 1.00, 0.00
  end
  return 0.62, 0.62, 0.62
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
    return 0.62, 0.62, 0.62
  end
  local priceGold = priceCopper / 10000
  if priceGold >= 40 then
    return 1.00, 0.50, 0.00
  elseif priceGold >= 20 then
    return 0.64, 0.21, 0.93
  elseif priceGold >= 8 then
    return 0.00, 0.44, 0.87
  elseif priceGold >= 1 then
    return 0.12, 1.00, 0.00
  end
  return 0.62, 0.62, 0.62
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

local function GetCandidateMinimapSpacingPx(candidate)
  local ui = GoldMap.db and GoldMap.db.ui or {}
  if candidate and candidate.kind == "GATHER" then
    local profession = candidate.node and candidate.node.profession
    if profession == "HERBALISM" then
      return math.max(6, math.min(40, ui.minimapHerbPinSpacing or 18))
    elseif profession == "MINING" then
      return math.max(6, math.min(40, ui.minimapOrePinSpacing or 14))
    end
  end
  return math.max(6, math.min(40, ui.minimapMobPinSpacing or 12))
end

local function BuildMinimapGeometry(iconSize)
  local radiusPixelsX = math.max(35, (Minimap:GetWidth() * 0.5) - iconSize - 2)
  local radiusPixelsY = math.max(35, (Minimap:GetHeight() * 0.5) - iconSize - 2)
  local radiusPixels = math.min(radiusPixelsX, radiusPixelsY)
  return radiusPixelsX, radiusPixelsY, radiusPixels
end

local function MakePin(parent)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(14, 14)
  button:SetFrameLevel(parent:GetFrameLevel() + 15)
  button:EnableMouse(true)
  ApplyPinHitRect(button, 14)

  button.baseTexturePath = GoldMap:GetIconPath("pinBase", 64) or "Interface\\Buttons\\WHITE8X8"

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

  button:SetScript("OnLeave", function()
    GoldMap.PinTooltip:Hide()
  end)

  return button
end

function GoldMap.MinimapPins:GetHBDPins()
  if self.hbdPins == nil then
    self.hbdPins = (LibStub and LibStub("HereBeDragons-Pins-2.0", true)) or false
  end
  if self.hbdPins == false then
    return nil
  end
  return self.hbdPins
end

function GoldMap.MinimapPins:AttachPinToMinimap(pin, candidate)
  local hbdPins = self:GetHBDPins()
  if not hbdPins or not pin or not candidate then
    return false
  end

  local spawn = candidate.spawn
  if not spawn then
    return false
  end

  local dbX = tonumber(spawn.wx)
  local dbY = tonumber(spawn.wy)
  if not dbX or not dbY then
    return false
  end

  local instanceID = tonumber(candidate.instanceID)
  if instanceID == nil then
    instanceID = tonumber(spawn.instanceID) or 0
  end

  -- GoldMap DB world coords use wx=position_x and wy=position_y.
  -- HBD world coords use x=position_y and y=position_x, so swap axes.
  local hbdX = dbY
  local hbdY = dbX

  hbdPins:AddMinimapIconWorld(self, pin, instanceID, hbdX, hbdY, false)
  pin.hbdAttached = true
  return true
end

function GoldMap.MinimapPins:DetachPinFromMinimap(pin)
  if not pin or not pin.hbdAttached then
    return
  end
  local hbdPins = self:GetHBDPins()
  if hbdPins then
    hbdPins:RemoveMinimapIcon(self, pin)
  end
  pin.hbdAttached = nil
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

function GoldMap.MinimapPins:ResolveZoneKeyFromWorld(wx, wy)
  if not wx or not wy then
    return nil
  end
  local zones = GoldMapData and GoldMapData.Zones
  if not zones then
    return nil
  end

  for zoneKey, zoneData in pairs(zones) do
    local bounds = zoneData and zoneData.bounds
    if bounds then
      local minX = tonumber(bounds.minX)
      local maxX = tonumber(bounds.maxX)
      local minY = tonumber(bounds.minY)
      local maxY = tonumber(bounds.maxY)
      if minX and maxX and minY and maxY and wx >= minX and wx <= maxX and wy >= minY and wy <= maxY then
        return zoneKey
      end
    end
  end

  return nil
end

function GoldMap.MinimapPins:IsGlobalWorldPosition(zoneKey, wx, wy)
  if not zoneKey or not wx or not wy then
    return false
  end
  local zoneData = GoldMapData and GoldMapData.Zones and GoldMapData.Zones[zoneKey]
  local bounds = zoneData and zoneData.bounds
  if not bounds then
    return false
  end

  local minX = tonumber(bounds.minX)
  local maxX = tonumber(bounds.maxX)
  local minY = tonumber(bounds.minY)
  local maxY = tonumber(bounds.maxY)
  if not minX or not maxX or not minY or not maxY then
    return false
  end

  local margin = 2000
  return wx >= (minX - margin) and wx <= (maxX + margin) and wy >= (minY - margin) and wy <= (maxY + margin)
end

function GoldMap.MinimapPins:GetPlayerLocation()
  -- Use HBD for world position: it correctly handles UnitPosition's (y,x,z,instance)
  -- return order so that wx/wy are in the same coordinate system as spawn data.
  local HBD = LibStub and LibStub("HereBeDragons-2.0", true)
  if HBD then
    -- HBD:GetPlayerWorldPosition() returns (posX, posY, instanceID) where:
    --   posX = UnitPosition 2nd return = east-coordinate
    --   posY = UnitPosition 1st return = north-coordinate
    -- Spawn data uses: wx = DB position_x = UnitPosition posY (N/S axis)
    --                  wy = DB position_y = UnitPosition posX (E/W axis)
    -- So we must swap: wx = hbd_y, wy = hbd_x
    local hbd_x, hbd_y, instanceID = HBD:GetPlayerWorldPosition()
    if not hbd_x or not hbd_y then
      return nil
    end
    local wx = hbd_y  -- DB position_x / UnitPosition posY
    local wy = hbd_x  -- DB position_y / UnitPosition posX

    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local zoneKey = currentMapID and GoldMap.Ids:GetZoneKeyForMapID(currentMapID, true) or nil
    if not zoneKey then
      zoneKey = self:ResolveZoneKeyFromWorld(wx, wy)
    end
    if not zoneKey then
      return nil
    end

    local continentMapID = nil
    if zoneKey == "EK" then
      continentMapID = 1415
    elseif zoneKey == "KAL" then
      continentMapID = 1414
    end

    local cx, cy
    if continentMapID and HBD.GetZoneCoordinatesFromWorldInstance then
      local mx, my = HBD:GetZoneCoordinatesFromWorldInstance(hbd_x, hbd_y, instanceID, continentMapID, true)
      if mx and my and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then
        cx, cy = mx, my
      end
    end

    return {
      zoneKey = zoneKey,
      currentMapID = currentMapID,
      instanceID = instanceID,
      continentMapID = continentMapID,
      cx = cx,
      cy = cy,
      wx = wx,
      wy = wy,
    }
  end

  -- Fallback (no HBD): keep original logic but fix the UnitPosition y/x swap.
  if not C_Map or not C_Map.GetBestMapForUnit then
    return nil
  end

  local currentMapID = C_Map.GetBestMapForUnit("player")
  local zoneKey = currentMapID and GoldMap.Ids:GetZoneKeyForMapID(currentMapID, true) or nil

  local sourceMapID = currentMapID
  local mapPos = sourceMapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(sourceMapID, "player") or nil
  local x, y = GetVectorXY(mapPos)
  if x and y and (x < 0 or x > 1 or y < 0 or y > 1) then
    x, y = nil, nil
  end

  if not zoneKey then
    local ekMapPos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(1415, "player") or nil
    local ekX, ekY = GetVectorXY(ekMapPos)
    if ekX and ekY then
      zoneKey = "EK"
      sourceMapID = 1415
      mapPos = ekMapPos
      x, y = ekX, ekY
    else
      local kalMapPos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(1414, "player") or nil
      local kalX, kalY = GetVectorXY(kalMapPos)
      if kalX and kalY then
        zoneKey = "KAL"
        sourceMapID = 1414
        mapPos = kalMapPos
        x, y = kalX, kalY
      end
    end
  end

  local wx, wy, instanceID
  if UnitPosition then
    -- UnitPosition returns (posY, posX, z, instanceID).
    -- Spawn data convention: wx = DB position_x = posY, wy = DB position_y = posX.
    local posY, posX, _, uInstance = UnitPosition("player")
    if posX and posY then
      wx = posY  -- DB position_x / N-S axis
      wy = posX  -- DB position_y / E-W axis
      instanceID = uInstance

      if zoneKey and not self:IsGlobalWorldPosition(zoneKey, wx, wy) then
        wx, wy = nil, nil
      end
    end
  end

  if (not wx or not wy) and mapPos and sourceMapID and C_Map.GetWorldPosFromMapPos then
    local mapInstanceID, worldPos = C_Map.GetWorldPosFromMapPos(sourceMapID, mapPos)
    local gx, gy = GetVectorXY(worldPos)
    wx = gx
    wy = gy
    instanceID = instanceID or mapInstanceID
  end

  if not wx or not wy then
    return nil
  end

  if not zoneKey then
    zoneKey = self:ResolveZoneKeyFromWorld(wx, wy)
  end

  if not zoneKey then
    return nil
  end

  if (not x or not y) and sourceMapID and C_Map.GetPlayerMapPosition then
    local fallbackMapPos = C_Map.GetPlayerMapPosition(sourceMapID, "player")
    local fx, fy = GetVectorXY(fallbackMapPos)
    if fx and fy and fx >= 0 and fx <= 1 and fy >= 0 and fy <= 1 then
      x, y = fx, fy
    end
  end

  local continentMapID = nil
  if zoneKey == "EK" then
    continentMapID = 1415
  elseif zoneKey == "KAL" then
    continentMapID = 1414
  end

  local cx, cy = nil, nil
  if continentMapID and C_Map and C_Map.GetPlayerMapPosition then
    local contPos = C_Map.GetPlayerMapPosition(continentMapID, "player")
    local mx, my = GetVectorXY(contPos)
    if mx and my and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then
      cx, cy = mx, my
    end
  end

  return {
    zoneKey = zoneKey,
    currentMapID = sourceMapID or currentMapID,
    instanceID = instanceID,
    continentMapID = continentMapID,
    cx = cx,
    cy = cy,
    wx = wx,
    wy = wy,
  }
end

function GoldMap.MinimapPins:GetWorldRangeForMap(_, normalizedRange)
  local baseRadius
  if MinimapRadiusAPI then
    baseRadius = C_Minimap.GetViewRadius()
  else
    local zoom = (Minimap and Minimap.GetZoom and Minimap:GetZoom()) or 0
    local indoors = (GetCVar and (GetCVar("minimapZoom") + 0 == zoom)) and "outdoor" or "indoor"
    local diameter = MINIMAP_SIZE[indoors] and MINIMAP_SIZE[indoors][zoom] or MINIMAP_SIZE.outdoor[0]
    baseRadius = (diameter or 466.6667) * 0.5
  end

  if not baseRadius or baseRadius <= 0 then
    baseRadius = 233.3333
  end

  local ratio = (normalizedRange and normalizedRange > 0) and (normalizedRange / 0.035) or 1
  ratio = math.max(0.35, math.min(4.0, ratio))
  return baseRadius * ratio
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
    self:DetachPinFromMinimap(pin)
    pin:Hide()
    pin.payload = nil
    pin.candidate = nil
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
    self:DetachPinFromMinimap(pin)
    pin:Hide()
    pin.payload = nil
    pin.candidate = nil
    pin.tintR, pin.tintG, pin.tintB = nil, nil, nil
    if pin.valueHigh then
      pin.valueHigh:Hide()
    end
  end
end

function GoldMap.MinimapPins:RequestRefresh()
  self:RequestFullRefresh()
end

function GoldMap.MinimapPins:RequestFullRefresh()
  self.fullRefreshRequested = true
  if self.fullRefreshThrottle then
    self.fullRefreshThrottle:Run()
  else
    self:RefreshNow()
  end
end

function GoldMap.MinimapPins:GetRefreshInterval()
  if self.isMoving then
    return 0.05
  end
  return 0.10
end

function GoldMap.MinimapPins:RepositionActivePins()
  -- HereBeDragons-Pins handles minimap pin movement/rotation continuously.
end

function GoldMap.MinimapPins:RefreshNow()
  self.fullRefreshRequested = false

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
  if not self:GetHBDPins() then
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
  local allowHerb = GoldMap.IsGatherProfessionEnabled and GoldMap:IsGatherProfessionEnabled("HERBALISM", filters) or (filters.showGatherTargets ~= false)
  local allowOre = GoldMap.IsGatherProfessionEnabled and GoldMap:IsGatherProfessionEnabled("MINING", filters) or (filters.showGatherTargets ~= false)
  local allowGather = allowHerb or allowOre
  if not evaluator and not gatherEvaluator then
    self:ReleaseAllPins()
    return
  end

  self.activeCount = 0

  local range = math.max(0.005, math.min(0.2, GoldMap.db.ui.minimapRange or 0.035))
  local iconSize = math.max(8, math.min(22, GoldMap.db.ui.minimapIconSize or 14))
  local maxPins = math.max(10, math.min(300, GoldMap.db.ui.minimapMaxPins or 80))
  local px = tonumber(playerLoc.wx)
  local py = tonumber(playerLoc.wy)
  if not px or not py then
    self:ReleaseAllPins()
    return
  end

  local worldRange = self:GetWorldRangeForMap(playerLoc.currentMapID, range)
  local candidateRange = math.max(worldRange * 1.20, worldRange + 40)
  local candidateRangeSquared = candidateRange * candidateRange
  local _, _, radiusPixels = BuildMinimapGeometry(iconSize)

  local evalByNpc = {}
  local evalByNode = {}
  local mobSeed = GoldMapData and GoldMapData.SeedDrops
  local gatherNodes = GoldMapData and GoldMapData.GatherNodes
  local candidates = self:GetNearbySpawnsWorld(zoneKey, px, py, candidateRange)
  wipe(self.tmpVisible)

  for _, entry in ipairs(candidates) do
    local spawn = entry.data
    local sx = tonumber(spawn.wx)
    local sy = tonumber(spawn.wy)
    if sx and sy then
      local xDist = px - sx
      local yDist = py - sy
      local distSquared = (xDist * xDist) + (yDist * yDist)
      if distSquared <= candidateRangeSquared then
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
              distSquared = distSquared,
              worldX = sx,
              worldY = sy,
              instanceID = playerLoc.instanceID,
            })
          end
        elseif entry.kind == "GATHER" and allowGather and gatherEvaluator and gatherNodes and gatherNodes[spawn.nodeID] and GoldMap:IsGatherProfessionEnabled(gatherNodes[spawn.nodeID].profession, filters) then
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
              distSquared = distSquared,
              worldX = sx,
              worldY = sy,
              instanceID = playerLoc.instanceID,
            })
          end
        end
      end
    end
  end

  table.sort(self.tmpVisible, function(a, b)
    local evA = a.eval and (a.eval.evCopper or 0) or 0
    local evB = b.eval and (b.eval.evCopper or 0) or 0
    if evA ~= evB then
      return evA > evB
    end
    if a.kind ~= b.kind then
      return tostring(a.kind) < tostring(b.kind)
    end
    local idA = (a.spawn and (a.spawn.npcID or a.spawn.nodeID)) or 0
    local idB = (b.spawn and (b.spawn.npcID or b.spawn.nodeID)) or 0
    if idA ~= idB then
      return idA < idB
    end
    if a.worldX ~= b.worldX then
      return a.worldX < b.worldX
    end
    if a.worldY ~= b.worldY then
      return a.worldY < b.worldY
    end
    return (a.distSquared or 0) < (b.distSquared or 0)
  end)

  local placedCandidates = {}
  local occupiedCells = {}
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

    local spacingPx = GetCandidateMinimapSpacingPx(candidate)
    local spacingWorld = (spacingPx / math.max(1, radiusPixels)) * worldRange
    spacingWorld = math.max(20, spacingWorld)
    local cellX, cellY
    if candidate.worldX and candidate.worldY then
      cellX = math.floor(candidate.worldX / spacingWorld)
      cellY = math.floor(candidate.worldY / spacingWorld)
    else
      return false
    end

    local profession = candidate.node and candidate.node.profession or ""
    local cellKey = tostring(candidate.kind or "GEN") .. ":" .. tostring(profession) .. ":" .. cellX .. ":" .. cellY
    if occupiedCells[cellKey] then
      return false
    end
    occupiedCells[cellKey] = true

    local pin = self:AcquirePin()
    pin:SetSize(iconSize, iconSize)
    ApplyPinHitRect(pin, iconSize)
    pin.payload = {
      kind = candidate.kind,
      spawn = candidate.spawn,
      mob = candidate.mob,
      node = candidate.node,
      eval = candidate.eval,
    }
    pin.candidate = candidate

    local r, g, b
    local valueHigh = false
    if candidate.kind == "GATHER" then
      local gatherPrice = GetGatherReferencePrice(candidate.eval)
      r, g, b = ColorForGatherPrice(gatherPrice)
      valueHigh = (gatherPrice or 0) >= (40 * 10000)
    else
      r, g, b = ColorForEV(candidate.eval.evCopper)
      valueHigh = (candidate.eval.evCopper or 0) >= (40 * 10000)
    end
    pin.tintR, pin.tintG, pin.tintB = r, g, b
    pin.icon:SetTexture(GetIconForPayload(pin.payload) or pin.baseTexturePath)
    pin.icon:SetVertexColor(r, g, b, 0.95)
    pin.valueHigh:SetShown(valueHigh)
    if not self:AttachPinToMinimap(pin, candidate) then
      self.activeCount = self.activeCount - 1
      pin.payload = nil
      pin.candidate = nil
      pin:Hide()
      return false
    end
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
  self.lastFullRefreshTime = GetTime and GetTime() or 0
end

function GoldMap.MinimapPins:OnEvent(eventName)
  if not self.initialized then
    return
  end

  if eventName == "PLAYER_STARTED_MOVING" then
    self.isMoving = true
    return
  end

  if eventName == "PLAYER_STOPPED_MOVING" then
    self.isMoving = false
    self:RequestFullRefresh()
    return
  end

  if eventName == "PLAYER_ENTERING_WORLD" then
    self.lastZoneKey = nil
    self.isMoving = false
    self:ReleaseAllPins()
    C_Timer.After(1, function()
      self:RequestFullRefresh()
    end)
    return
  end

  if eventName == "PLAYER_LEAVING_WORLD" or eventName == "ZONE_CHANGED_NEW_AREA" or eventName == "ZONE_CHANGED" or eventName == "ZONE_CHANGED_INDOORS" then
    self.lastZoneKey = nil
    self.isMoving = false
    self:ReleaseAllPins()
    C_Timer.After(0.2, function()
      self:RequestFullRefresh()
    end)
    return
  end

  self:RequestFullRefresh()
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

  local hbdPins = self:GetHBDPins()
  if hbdPins and hbdPins.SetMinimapObject then
    hbdPins:SetMinimapObject(Minimap)
  end

  self.pinPool = {}
  self.activeCount = 0
  self.tmpCandidates = {}
  self.tmpVisible = {}

  self.fullRefreshRequested = false
  self.lastFullRefreshTime = 0
  self.fullRefreshThrottle = GoldMap.Throttle:New(0.10, function()
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

      local now = GetTime and GetTime() or 0
      local fullInterval = self.isMoving and 0.35 or 0.8
      if self.fullRefreshRequested or (now - (self.lastFullRefreshTime or 0) >= fullInterval) then
        self:RequestFullRefresh()
      end
    end
  end)

  self:BuildSpatialIndex()

  GoldMap:RegisterMessage("FILTERS_CHANGED", function()
    self:RequestFullRefresh()
  end)
  GoldMap:RegisterMessage("PRICE_CACHE_UPDATED", function()
    self:RequestFullRefresh()
  end)
  GoldMap:RegisterMessage("GATHER_DATA_UPDATED", function()
    self:BuildSpatialIndex()
    self:RequestFullRefresh()
  end)

  self.initialized = true
end
