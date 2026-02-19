local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.Evaluator = GoldMap.Evaluator or {}
GoldMap.Evaluator._isFallback = nil

local function BuildFilterSignature(filters)
  return table.concat({
    tostring(filters.showMobTargets),
    tostring(filters.minDropRate),
    tostring(filters.maxDropRate),
    tostring(filters.minMobLevel),
    tostring(filters.maxMobLevel),
    tostring(filters.filterMode),
    tostring(filters.minEVGold),
    tostring(filters.maxEVGold),
    tostring(filters.minItemPriceGold),
    tostring(filters.minReliabilityTier),
    tostring(filters.minSellSpeedTier),
    tostring(filters.minQuality),
    tostring(filters.showNoPricePins),
  }, "|")
end

local function MobMatchesLevelRange(mob, minLevel, maxLevel)
  local mobMin = tonumber(mob.minLevel) or 0
  local mobMax = tonumber(mob.maxLevel) or mobMin
  if mobMax < mobMin then
    mobMax = mobMin
  end
  return mobMax >= minLevel and mobMin <= maxLevel
end

function GoldMap.Evaluator:Init()
  if self.initialized then
    return
  end

  self.cache = {}
  self.spawnCountByNPC = {}

  self:RebuildIndexes()

  GoldMap:RegisterMessage("FILTERS_CHANGED", function()
    wipe(self.cache)
  end)

  GoldMap:RegisterMessage("PRICE_CACHE_UPDATED", function()
    -- Price revision gating handles this automatically, keep cache entries.
  end)

  self.initialized = true
end

function GoldMap.Evaluator:RebuildIndexes()
  wipe(self.spawnCountByNPC)

  local spawnsByZone = GoldMapData and GoldMapData.Spawns
  if not spawnsByZone then
    return
  end

  for _, spawnList in pairs(spawnsByZone) do
    for _, spawn in ipairs(spawnList) do
      local npcID = spawn.npcID
      self.spawnCountByNPC[npcID] = (self.spawnCountByNPC[npcID] or 0) + 1
    end
  end
end

function GoldMap.Evaluator:GetSpawnCount(npcID)
  return self.spawnCountByNPC[npcID] or 0
end

function GoldMap.Evaluator:GetMobByNPCID(npcID)
  local seed = GoldMapData and GoldMapData.SeedDrops
  if not seed then
    return nil
  end
  return seed[npcID]
end

function GoldMap.Evaluator:EvaluateMobByID(npcID)
  local mob = self:GetMobByNPCID(npcID)
  if not mob then
    return nil
  end
  return self:EvaluateMob(npcID, mob)
end

function GoldMap.Evaluator:EvaluateMob(npcID, mob)
  local filters = GoldMap:GetFilters()
  if filters.showMobTargets == false then
    self.cache[npcID] = {
      revision = GoldMap.AHCache:GetRevision(),
      filterSig = BuildFilterSignature(filters),
      value = nil,
    }
    return nil
  end

  local revision = GoldMap.AHCache:GetRevision()
  local filterSig = BuildFilterSignature(filters)

  local cached = self.cache[npcID]
  if cached and cached.revision == revision and cached.filterSig == filterSig then
    return cached.value
  end

  local minPriceCopper = math.floor(filters.minItemPriceGold * 10000)
  local minReliabilityTier = math.max(0, math.min(3, math.floor(tonumber(filters.minReliabilityTier) or 0)))
  local minSellSpeedTier = math.max(0, math.min(3, math.floor(tonumber(filters.minSellSpeedTier) or 0)))
  local minEVCopper = math.floor(filters.minEVGold * 10000)
  local maxEVCopper = math.floor(filters.maxEVGold * 10000)
  local minMobLevel = math.max(1, math.floor(filters.minMobLevel or 1))
  local maxMobLevel = math.max(minMobLevel, math.floor(filters.maxMobLevel or 63))
  local mode = (filters.filterMode == "ANY") and "ANY" or "ALL"
  local levelPass = MobMatchesLevelRange(mob, minMobLevel, maxMobLevel)
  local killablePass = mob.attackable ~= false
  local chanceFilterActive = (filters.minDropRate or 0) > 0 or (filters.maxDropRate or 100) < 100
  local qualityFilterActive = (filters.minQuality or 0) > 0
  local priceFilterActive = minPriceCopper > 0
  local reliabilityFilterActive = minReliabilityTier > 0
  local sellSpeedFilterActive = minSellSpeedTier > 0
  local includeNoPriceRows = filters.showNoPricePins and true or false
  local dropFilterActive = chanceFilterActive or qualityFilterActive or priceFilterActive or reliabilityFilterActive or sellSpeedFilterActive
  local levelFilterActive = minMobLevel > 1 or maxMobLevel < 63
  local evFilterActive = minEVCopper > 0 or maxEVCopper < math.floor(999999 * 10000)

  local rows = {}
  local totalDropCount = mob.drops and #mob.drops or 0

  for _, drop in ipairs(mob.drops or {}) do
    local chancePass = drop.chance >= filters.minDropRate and drop.chance <= filters.maxDropRate
    local qualityPass = drop.quality >= filters.minQuality

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
      reliabilityPass = reliabilityTier >= minReliabilityTier
    end
    local sellTier, sellLabel, sellScore = GoldMap.AHCache:GetSellSpeed(drop.itemID)
    local sellPass = sellTier >= minSellSpeedTier

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

    local itemPass = chancePass and qualityPass and pricePass and reliabilityPass and sellPass and (includeNoPriceRows or price ~= nil)
    if itemPass then
      table.insert(rows, row)
    end
  end

  local dropPass = #rows > 0
  if mode == "ALL" and not dropPass then
    self.cache[npcID] = {
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

  if not killablePass then
    self.cache[npcID] = {
      revision = revision,
      filterSig = filterSig,
      value = nil,
    }
    return nil
  end

  local passesFilters
  if mode == "ALL" then
    passesFilters = levelPass and dropPass and evPass
  else
    local activeCount = 0
    if levelFilterActive then
      activeCount = activeCount + 1
    end
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
        (levelFilterActive and levelPass) or
        (dropFilterActive and dropPass) or
        (evFilterActive and evPass)
    end
  end

  if not passesFilters then
    self.cache[npcID] = {
      revision = revision,
      filterSig = filterSig,
      value = nil,
    }
    return nil
  end

  local result = {
    npcID = npcID,
    mob = mob,
    evCopper = ev,
    hasPrice = hasAnyPrice,
    items = rows,
    filteredDropCount = #rows,
    pricedDropCount = pricedDropCount,
    totalDropCount = totalDropCount,
    spawnCount = self:GetSpawnCount(npcID),
    source = mob.source or "Seed DB",
    bestDrop = rows[1],
    scanAgeSeconds = GoldMap:GetSecondsSinceLastScan(),
    levelPass = levelPass,
    killablePass = killablePass,
    dropPass = dropPass,
    evPass = evPass,
    filterMode = mode,
  }

  self.cache[npcID] = {
    revision = revision,
    filterSig = filterSig,
    value = result,
  }

  return result
end
