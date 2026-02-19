local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.GatherEvaluator = GoldMap.GatherEvaluator or {}

local function BuildFilterSignature(filters)
  return table.concat({
    tostring(filters.showGatherTargets),
    tostring(filters.gatherMinDropRate),
    tostring(filters.gatherMaxDropRate),
    tostring(filters.filterMode),
    tostring(filters.gatherMinEVGold),
    tostring(filters.gatherMaxEVGold),
    tostring(filters.gatherMinItemPriceGold),
    tostring(filters.gatherMinReliabilityTier),
    tostring(filters.gatherMinSellSpeedTier),
    tostring(filters.gatherMinQuality),
    tostring(filters.showNoPricePins),
  }, "|")
end

function GoldMap.GatherEvaluator:Init()
  if self.initialized then
    return
  end

  self.cache = {}
  self.spawnCountByNode = {}

  self:RebuildIndexes()

  GoldMap:RegisterMessage("FILTERS_CHANGED", function()
    wipe(self.cache)
  end)

  GoldMap:RegisterMessage("PRICE_CACHE_UPDATED", function()
    -- Price revision gating handles this automatically.
  end)

  self.initialized = true
end

function GoldMap.GatherEvaluator:RebuildIndexes()
  wipe(self.spawnCountByNode)

  local spawnsByZone = GoldMapData and GoldMapData.GatherSpawns
  if not spawnsByZone then
    return
  end

  for _, spawnList in pairs(spawnsByZone) do
    for _, spawn in ipairs(spawnList) do
      local nodeID = spawn.nodeID
      self.spawnCountByNode[nodeID] = (self.spawnCountByNode[nodeID] or 0) + 1
    end
  end
end

function GoldMap.GatherEvaluator:GetSpawnCount(nodeID)
  return self.spawnCountByNode[nodeID] or 0
end

function GoldMap.GatherEvaluator:GetNodeByID(nodeID)
  local nodes = GoldMapData and GoldMapData.GatherNodes
  if not nodes then
    return nil
  end
  return nodes[nodeID]
end

function GoldMap.GatherEvaluator:EvaluateNodeByID(nodeID)
  local node = self:GetNodeByID(nodeID)
  if not node then
    return nil
  end
  return self:EvaluateNode(nodeID, node)
end

function GoldMap.GatherEvaluator:EvaluateNode(nodeID, node)
  local filters = GoldMap:GetFilters()
  if filters.showGatherTargets == false then
    self.cache[nodeID] = {
      revision = GoldMap.AHCache:GetRevision(),
      filterSig = BuildFilterSignature(filters),
      value = nil,
    }
    return nil
  end

  local revision = GoldMap.AHCache:GetRevision()
  local filterSig = BuildFilterSignature(filters)

  local cached = self.cache[nodeID]
  if cached and cached.revision == revision and cached.filterSig == filterSig then
    return cached.value
  end

  local minDropRate = tonumber(filters.gatherMinDropRate)
  if minDropRate == nil then
    minDropRate = tonumber(filters.minDropRate) or 0
  end
  minDropRate = math.max(0, math.min(100, minDropRate))

  local maxDropRate = tonumber(filters.gatherMaxDropRate)
  if maxDropRate == nil then
    maxDropRate = tonumber(filters.maxDropRate) or 100
  end
  maxDropRate = math.max(minDropRate, math.min(100, maxDropRate))

  local minEVGold = tonumber(filters.gatherMinEVGold)
  if minEVGold == nil then
    minEVGold = tonumber(filters.minEVGold) or 0
  end
  minEVGold = math.max(0, minEVGold)

  local maxEVGold = tonumber(filters.gatherMaxEVGold)
  if maxEVGold == nil then
    maxEVGold = tonumber(filters.maxEVGold) or 999999
  end
  maxEVGold = math.max(minEVGold, maxEVGold)

  local gatherMinItemPriceGold = tonumber(filters.gatherMinItemPriceGold)
  if gatherMinItemPriceGold == nil then
    gatherMinItemPriceGold = tonumber(filters.minItemPriceGold) or 0
  end
  gatherMinItemPriceGold = math.max(0, gatherMinItemPriceGold)
  local minPriceCopper = math.floor(gatherMinItemPriceGold * 10000)

  local gatherMinQuality = tonumber(filters.gatherMinQuality)
  if gatherMinQuality == nil then
    gatherMinQuality = tonumber(filters.minQuality) or 1
  end
  gatherMinQuality = math.max(0, math.floor(gatherMinQuality))

  local gatherMinSellSpeedTier = tonumber(filters.gatherMinSellSpeedTier)
  if gatherMinSellSpeedTier == nil then
    gatherMinSellSpeedTier = tonumber(filters.minSellSpeedTier) or 0
  end
  gatherMinSellSpeedTier = math.max(0, math.min(3, math.floor(gatherMinSellSpeedTier)))

  local gatherMinReliabilityTier = tonumber(filters.gatherMinReliabilityTier)
  if gatherMinReliabilityTier == nil then
    gatherMinReliabilityTier = tonumber(filters.minReliabilityTier) or 0
  end
  gatherMinReliabilityTier = math.max(0, math.min(3, math.floor(gatherMinReliabilityTier)))

  local minEVCopper = math.floor(minEVGold * 10000)
  local maxEVCopper = math.floor(maxEVGold * 10000)
  local mode = (filters.filterMode == "ANY") and "ANY" or "ALL"
  local chanceFilterActive = minDropRate > 0 or maxDropRate < 100
  local qualityFilterActive = gatherMinQuality > 0
  local priceFilterActive = minPriceCopper > 0
  local reliabilityFilterActive = gatherMinReliabilityTier > 0
  local sellSpeedFilterActive = gatherMinSellSpeedTier > 0
  local dropFilterActive = chanceFilterActive or qualityFilterActive or priceFilterActive or reliabilityFilterActive or sellSpeedFilterActive
  local evFilterActive = minEVCopper > 0 or maxEVCopper < math.floor(999999 * 10000)
  local includeNoPriceRows = filters.showNoPricePins and true or false

  local rows = {}
  local totalDropCount = node.drops and #node.drops or 0

  for _, drop in ipairs(node.drops or {}) do
    local chancePass = drop.chance >= minDropRate and drop.chance <= maxDropRate
    local qualityPass = drop.quality >= gatherMinQuality

    local price = GoldMap.AHCache:Get(drop.itemID)
    local pricePass = minPriceCopper <= 0 or (price and price >= minPriceCopper)
    if price and not pricePass then
      price = nil
    end

    local avgCount = math.max(1, ((drop.minCount or 1) + (drop.maxCount or 1)) / 2)
    local evContribution = price and (price * (drop.chance / 100) * avgCount) or nil
    local reliabilityTier, reliabilityLabel, reliabilityScore = nil, nil, nil
    local reliabilityPass = true
    if reliabilityFilterActive then
      reliabilityTier, reliabilityLabel, reliabilityScore = GoldMap.AHCache:GetConfidenceTier(drop.itemID)
      reliabilityPass = reliabilityTier >= gatherMinReliabilityTier
    end
    local sellTier, sellLabel, sellScore = GoldMap.AHCache:GetSellSpeed(drop.itemID)
    local sellPass = sellTier >= gatherMinSellSpeedTier

    local row = {
      itemID = drop.itemID,
      itemName = drop.itemName,
      chance = drop.chance,
      quality = drop.quality,
      minCount = drop.minCount or 1,
      maxCount = drop.maxCount or 1,
      avgCount = avgCount,
      price = price,
      evContribution = evContribution,
      reliabilityTier = reliabilityTier,
      reliabilityLabel = reliabilityLabel,
      reliabilityScore = reliabilityScore,
      sellSpeedTier = sellTier,
      sellSpeedLabel = sellLabel,
      sellSpeedScore = sellScore,
    }

    local rowPass = chancePass and qualityPass and pricePass and reliabilityPass and sellPass and (includeNoPriceRows or price ~= nil)
    if rowPass then
      table.insert(rows, row)
    end
  end

  local dropPass = #rows > 0
  if mode == "ALL" and not dropPass then
    self.cache[nodeID] = {
      revision = revision,
      filterSig = filterSig,
      value = nil,
    }
    return nil
  end

  local evTotal = 0
  local hasAnyPrice = false
  local pricedDropCount = 0
  for _, row in ipairs(rows) do
    if row.price then
      hasAnyPrice = true
      pricedDropCount = pricedDropCount + 1
      if row.evContribution then
        evTotal = evTotal + row.evContribution
      end
    end
  end

  table.sort(rows, function(a, b)
    local aEV = a.evContribution or -1
    local bEV = b.evContribution or -1
    if aEV == bEV then
      if a.chance == b.chance then
        return a.itemID < b.itemID
      end
      return a.chance > b.chance
    end
    return aEV > bEV
  end)

  local ev = hasAnyPrice and evTotal or nil
  local evPass = false
  if ev then
    evPass = ev >= minEVCopper and ev <= maxEVCopper
  else
    evPass = filters.showNoPricePins and minEVCopper <= 0
  end

  local passesFilters
  if mode == "ALL" then
    passesFilters = dropPass and evPass
  else
    local activeCount = 0
    if dropFilterActive then
      activeCount = activeCount + 1
    end
    if evFilterActive then
      activeCount = activeCount + 1
    end

    if activeCount == 0 then
      passesFilters = true
    else
      passesFilters =
        (dropFilterActive and dropPass) or
        (evFilterActive and evPass)
    end
  end

  if not passesFilters then
    self.cache[nodeID] = {
      revision = revision,
      filterSig = filterSig,
      value = nil,
    }
    return nil
  end

  local result = {
    kind = "GATHER",
    nodeID = nodeID,
    node = node,
    profession = node.profession,
    evCopper = ev,
    hasPrice = hasAnyPrice,
    items = rows,
    filteredDropCount = #rows,
    pricedDropCount = pricedDropCount,
    totalDropCount = totalDropCount,
    spawnCount = self:GetSpawnCount(nodeID),
    source = node.source or "Seed DB",
    bestDrop = rows[1],
    scanAgeSeconds = GoldMap:GetSecondsSinceLastScan(),
    dropPass = dropPass,
    evPass = evPass,
    filterMode = mode,
  }

  self.cache[nodeID] = {
    revision = revision,
    filterSig = filterSig,
    value = result,
  }

  return result
end
