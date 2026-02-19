local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.AHCache = GoldMap.AHCache or {}

local function EnsureRecordMetadata(record, now)
  if not record then
    return nil
  end

  record.seenAt = tonumber(record.seenAt) or now
  record.firstSeenAt = tonumber(record.firstSeenAt) or record.seenAt
  record.samples = math.max(1, tonumber(record.samples) or 1)
  return record
end

local function Clamp(value, low, high)
  if value < low then
    return low
  end
  if value > high then
    return high
  end
  return value
end

GoldMap.AHCache.SellSpeedTiers = {
  [0] = { label = "None", color = { 0.62, 0.62, 0.62 }, colorCode = "ff9d9d9d" },
  [1] = { label = "Low", color = { 0.12, 1.00, 0.00 }, colorCode = "ff1eff00" },
  [2] = { label = "Medium", color = { 0.00, 0.44, 0.87 }, colorCode = "ff0070dd" },
  [3] = { label = "High", color = { 0.64, 0.21, 0.93 }, colorCode = "ffa335ee" },
}

GoldMap.AHCache.ConfidenceTiers = {
  [0] = { label = "Unknown", color = { 0.62, 0.62, 0.62 }, colorCode = "ff9d9d9d" },
  [1] = { label = "Low", color = { 0.12, 1.00, 0.00 }, colorCode = "ff1eff00" },
  [2] = { label = "Medium", color = { 0.00, 0.44, 0.87 }, colorCode = "ff0070dd" },
  [3] = { label = "High", color = { 1.00, 0.50, 0.00 }, colorCode = "ffff8000" },
}

function GoldMap.AHCache:GetSellSpeedTierInfo(tier)
  return self.SellSpeedTiers[tonumber(tier) or 0] or self.SellSpeedTiers[0]
end

function GoldMap.AHCache:GetSellSpeedLabel(tier)
  return self:GetSellSpeedTierInfo(tier).label
end

function GoldMap.AHCache:GetSellSpeedColor(tier)
  local color = self:GetSellSpeedTierInfo(tier).color
  return color[1], color[2], color[3]
end

function GoldMap.AHCache:GetConfidenceTierInfo(tier)
  return self.ConfidenceTiers[tonumber(tier) or 0] or self.ConfidenceTiers[0]
end

function GoldMap.AHCache:GetConfidenceColor(tier)
  local color = self:GetConfidenceTierInfo(tier).color
  return color[1], color[2], color[3]
end

function GoldMap.AHCache:GetConfidenceTierFromLabel(label)
  if label == "High" then
    return 3
  elseif label == "Medium" then
    return 2
  elseif label == "Low" then
    return 1
  end
  return 0
end

function GoldMap.AHCache:Init()
  GoldMapPriceCache = GoldMapPriceCache or {
    items = {},
    revision = 0,
    lastScanAt = 0,
  }
  self.data = GoldMapPriceCache
  self.signalCache = self.signalCache or {}
end

function GoldMap.AHCache:Get(itemID)
  local record = self.data.items[itemID]
  if not record then
    return nil
  end
  EnsureRecordMetadata(record, GetServerTime())
  return record.price, record.seenAt
end

function GoldMap.AHCache:GetRecord(itemID)
  local record = self.data.items[itemID]
  if not record then
    return nil
  end
  return EnsureRecordMetadata(record, GetServerTime())
end

function GoldMap.AHCache:IsFresh(itemID, staleSeconds)
  local _, seenAt = self:Get(itemID)
  if not seenAt then
    return false
  end
  return (GetServerTime() - seenAt) <= staleSeconds
end

function GoldMap.AHCache:Set(itemID, price, source)
  local now = GetServerTime()
  local existing = self.data.items[itemID]
  local firstSeenAt = existing and existing.firstSeenAt or now
  local samples = (existing and tonumber(existing.samples) or 0) + 1
  self.data.items[itemID] = {
    price = price,
    source = source or "scan",
    seenAt = now,
    firstSeenAt = tonumber(firstSeenAt) or now,
    samples = math.max(1, samples),
  }
  self.data.revision = (self.data.revision or 0) + 1
  self:InvalidateSignalCache(itemID)
  GoldMap:SendMessage("PRICE_CACHE_UPDATED", itemID, price)
end

function GoldMap.AHCache:SetMany(priceByItemID, source)
  if not priceByItemID then
    return 0
  end

  local now = GetServerTime()
  local written = 0
  for itemID, price in pairs(priceByItemID) do
    if itemID and price and price > 0 then
      local existing = self.data.items[itemID]
      local firstSeenAt = existing and existing.firstSeenAt or now
      local samples = (existing and tonumber(existing.samples) or 0) + 1
      self.data.items[itemID] = {
        price = price,
        source = source or "scan_bulk",
        seenAt = now,
        firstSeenAt = tonumber(firstSeenAt) or now,
        samples = math.max(1, samples),
      }
      written = written + 1
    end
  end

  if written > 0 then
    self.data.revision = (self.data.revision or 0) + 1
    self:InvalidateSignalCache()
    GoldMap:SendMessage("PRICE_CACHE_UPDATED")
  end

  return written
end

function GoldMap.AHCache:SetScanTimestamp()
  self.data.lastScanAt = GetServerTime()
end

function GoldMap.AHCache:GetRevision()
  return self.data.revision or 0
end

function GoldMap.AHCache:GetLastScanAt()
  return self.data.lastScanAt or 0
end

function GoldMap.AHCache:IsAuctionatorAvailable()
  return Auctionator
    and Auctionator.API
    and Auctionator.API.v1
    and type(Auctionator.API.v1.GetAuctionPriceByItemID) == "function"
end

function GoldMap.AHCache:InvalidateSignalCache(itemID)
  if not self.signalCache then
    return
  end
  if itemID then
    self.signalCache[itemID] = nil
  else
    self.signalCache = {}
  end
end

local function SafeAuctionatorCall(fn, ...)
  if type(fn) ~= "function" then
    return nil, false
  end
  local ok, result = pcall(fn, ...)
  if not ok then
    return nil, false
  end
  return result, true
end

function GoldMap.AHCache:ImportFromAuctionator(itemSet, maxAgeDays)
  if not itemSet or not self:IsAuctionatorAvailable() then
    return {
      requested = 0,
      priced = 0,
      imported = 0,
      tooOld = 0,
      errors = 0,
    }
  end

  local api = Auctionator.API.v1
  local now = GetServerTime()
  local callerID = "GoldMap"
  local maxAge = tonumber(maxAgeDays)
  local hasAgeAPI = type(api.GetAuctionAgeByItemID) == "function"
  local hasExactAPI = type(api.IsAuctionDataExactByItemID) == "function"
  local updatedAny = false
  local stats = {
    requested = 0,
    priced = 0,
    imported = 0,
    tooOld = 0,
    errors = 0,
  }

  for itemID in pairs(itemSet) do
    if type(itemID) == "number" then
      stats.requested = stats.requested + 1
      local price, okPrice = SafeAuctionatorCall(api.GetAuctionPriceByItemID, callerID, itemID)
      if not okPrice then
        stats.errors = stats.errors + 1
      elseif type(price) == "number" and price > 0 then
        stats.priced = stats.priced + 1
        local ageDays = nil
        local exact = nil

        if hasAgeAPI then
          local okAge
          ageDays, okAge = SafeAuctionatorCall(api.GetAuctionAgeByItemID, callerID, itemID)
          if not okAge then
            stats.errors = stats.errors + 1
          end
        end

        if hasExactAPI then
          local okExact
          exact, okExact = SafeAuctionatorCall(api.IsAuctionDataExactByItemID, callerID, itemID)
          if not okExact then
            stats.errors = stats.errors + 1
          end
        end

        local withinAge = true
        if hasAgeAPI and maxAge and maxAge >= 0 then
          if type(ageDays) == "number" then
            withinAge = ageDays <= maxAge
          else
            withinAge = false
          end
        end

        if withinAge then
          local existing = self.data.items[itemID]
          local firstSeenAt = existing and existing.firstSeenAt or now
          local samples = (existing and tonumber(existing.samples) or 0) + 1
          self.data.items[itemID] = {
            price = price,
            source = "auctionator_api",
            seenAt = now,
            firstSeenAt = tonumber(firstSeenAt) or now,
            samples = math.max(1, samples),
            sourceAgeDays = (type(ageDays) == "number" and ageDays >= 0) and ageDays or nil,
            sourceExact = (type(exact) == "boolean") and exact or nil,
          }
          stats.imported = stats.imported + 1
          updatedAny = true
        else
          stats.tooOld = stats.tooOld + 1
        end
      end
    end
  end

  if updatedAny then
    self.data.revision = (self.data.revision or 0) + 1
    self:InvalidateSignalCache()
    GoldMap:SendMessage("PRICE_CACHE_UPDATED")
  end

  return stats
end

function GoldMap.AHCache:GetAuctionatorSignals(itemID)
  if type(itemID) ~= "number" then
    return nil
  end

  local now = GetServerTime()
  local revision = self:GetRevision()
  local cached = self.signalCache and self.signalCache[itemID]
  if cached and cached.revision == revision and cached.expireAt and cached.expireAt > now then
    return cached.data
  end

  local signals = {
    hasAPI = false,
    hasHistory = false,
    exact = nil,
    ageDays = nil,
    historyDays = nil,
    activityDays7 = 0,
    availableAvg = nil,
    availableLatest = nil,
    volatilityPct = nil,
  }

  if self:IsAuctionatorAvailable() then
    local callerID = "GoldMap"
    local api = Auctionator.API.v1
    signals.hasAPI = true

    if type(api.GetAuctionAgeByItemID) == "function" then
      local ageDays, okAge = SafeAuctionatorCall(api.GetAuctionAgeByItemID, callerID, itemID)
      if okAge and type(ageDays) == "number" then
        signals.ageDays = ageDays
      end
    end

    if type(api.IsAuctionDataExactByItemID) == "function" then
      local exact, okExact = SafeAuctionatorCall(api.IsAuctionDataExactByItemID, callerID, itemID)
      if okExact and type(exact) == "boolean" then
        signals.exact = exact
      end
    end
  end

  if Auctionator and Auctionator.Database and type(Auctionator.Database.GetPriceHistory) == "function" then
    local history, okHistory = SafeAuctionatorCall(Auctionator.Database.GetPriceHistory, Auctionator.Database, tostring(itemID))
    if okHistory and type(history) == "table" and #history > 0 then
      signals.hasHistory = true

      local newestRawDay = nil
      local oldestRawDay = nil
      local minSeen = nil
      local maxSeen = nil
      local availableSum = 0
      local availableSamples = 0
      local activityDays7 = {}

      for index, row in ipairs(history) do
        local rawDay = tonumber(row and row.rawDay)
        if rawDay then
          newestRawDay = newestRawDay and math.max(newestRawDay, rawDay) or rawDay
          oldestRawDay = oldestRawDay and math.min(oldestRawDay, rawDay) or rawDay
          if not activityDays7[rawDay] then
            activityDays7[rawDay] = true
          end
        end

        local available = tonumber(row and row.available)
        if available then
          availableSum = availableSum + available
          availableSamples = availableSamples + 1
          if index == 1 then
            signals.availableLatest = available
          end
        elseif index == 1 then
          signals.availableLatest = 0
        end

        local rowMin = tonumber(row and row.minSeen)
        local rowMax = tonumber(row and row.maxSeen)
        if rowMin then
          minSeen = minSeen and math.min(minSeen, rowMin) or rowMin
        end
        if rowMax then
          maxSeen = maxSeen and math.max(maxSeen, rowMax) or rowMax
        end
      end

      if newestRawDay and oldestRawDay then
        signals.historyDays = math.max(1, newestRawDay - oldestRawDay + 1)
        local active = 0
        for day in pairs(activityDays7) do
          if (newestRawDay - day) <= 6 then
            active = active + 1
          end
        end
        signals.activityDays7 = active
      end

      if availableSamples > 0 then
        signals.availableAvg = availableSum / availableSamples
      end

      if minSeen and minSeen > 0 and maxSeen then
        signals.volatilityPct = ((maxSeen - minSeen) / minSeen) * 100
      end
    end
  end

  self.signalCache[itemID] = {
    revision = revision,
    expireAt = now + 300,
    data = signals,
  }
  return signals
end

function GoldMap.AHCache:GetSellSpeed(itemID)
  local record = self:GetRecord(itemID)
  if not record or not record.price or record.price <= 0 then
    local tier = 0
    return tier, self:GetSellSpeedLabel(tier), 0, {
      reason = "No market data",
      ageDays = nil,
      activityDays7 = 0,
      availableAvg = nil,
      exact = nil,
    }
  end

  local signals = self:GetAuctionatorSignals(itemID) or {}
  local score = 0

  local ageDays = tonumber(signals.ageDays)
  if ageDays ~= nil then
    if ageDays <= 1 then
      score = score + 30
    elseif ageDays <= 3 then
      score = score + 24
    elseif ageDays <= 7 then
      score = score + 14
    elseif ageDays <= 14 then
      score = score + 6
    end
  end

  local activityDays7 = tonumber(signals.activityDays7) or 0
  score = score + Clamp(activityDays7 * 6, 0, 36)

  local avgAvailable = tonumber(signals.availableAvg)
  if avgAvailable and avgAvailable > 0 then
    score = score + Clamp(math.floor(math.log(avgAvailable + 1) * 4), 0, 18)
  end

  if signals.exact == true then
    score = score + 10
  end

  local volatilityPct = tonumber(signals.volatilityPct)
  if volatilityPct and volatilityPct > 180 then
    score = score - 12
  elseif volatilityPct and volatilityPct > 100 then
    score = score - 6
  end

  score = Clamp(math.floor(score + 0.5), 0, 100)

  local tier
  if score >= 70 then
    tier = 3
  elseif score >= 45 then
    tier = 2
  elseif score >= 20 then
    tier = 1
  else
    tier = 0
  end

  return tier, self:GetSellSpeedLabel(tier), score, {
    ageDays = ageDays,
    activityDays7 = activityDays7,
    availableAvg = avgAvailable,
    exact = signals.exact,
    volatilityPct = volatilityPct,
  }
end

function GoldMap.AHCache:GetConfidence(itemID)
  local record = self:GetRecord(itemID)
  if not record or not record.price or record.price <= 0 then
    return "Low", 0, {
      samples = 0,
      ageHours = nil,
      historyHours = nil,
      reason = "No local market data yet",
    }
  end

  local now = GetServerTime()
  local samples = math.max(1, tonumber(record.samples) or 1)
  local seenAt = tonumber(record.seenAt) or now
  local firstSeenAt = tonumber(record.firstSeenAt) or seenAt
  local ageHours = math.max(0, (now - seenAt) / 3600)
  local historyHours = math.max(0, (seenAt - firstSeenAt) / 3600)

  local score = 0

  -- Local consistency in GoldMap cache.
  if samples >= 12 then
    score = score + 20
  elseif samples >= 8 then
    score = score + 16
  elseif samples >= 4 then
    score = score + 12
  elseif samples >= 2 then
    score = score + 8
  else
    score = score + 4
  end

  if ageHours <= 12 then
    score = score + 12
  elseif ageHours <= 24 then
    score = score + 8
  elseif ageHours <= 72 then
    score = score + 5
  elseif ageHours <= 168 then
    score = score + 2
  end

  if historyHours >= 72 then
    score = score + 10
  elseif historyHours >= 24 then
    score = score + 6
  elseif historyHours >= 8 then
    score = score + 3
  end

  local signals = self:GetAuctionatorSignals(itemID)
  if signals then
    local exact = signals.exact
    if exact == nil and type(record.sourceExact) == "boolean" then
      exact = record.sourceExact
    end

    if exact == true then
      score = score + 12
    elseif exact == false then
      score = score + 3
    end

    local ageDays = tonumber(signals.ageDays)
    if ageDays ~= nil then
      if ageDays <= 1 then
        score = score + 18
      elseif ageDays <= 3 then
        score = score + 12
      elseif ageDays <= 7 then
        score = score + 8
      elseif ageDays <= 14 then
        score = score + 3
      end
    end

    local historyDays = tonumber(signals.historyDays)
    if historyDays ~= nil then
      if historyDays >= 21 then
        score = score + 16
      elseif historyDays >= 14 then
        score = score + 12
      elseif historyDays >= 7 then
        score = score + 8
      elseif historyDays >= 3 then
        score = score + 4
      end
    end

    local activityDays7 = tonumber(signals.activityDays7) or 0
    score = score + Clamp(activityDays7 * 2, 0, 10)

    local averageAvailable = tonumber(signals.availableAvg)
    if averageAvailable and averageAvailable > 0 then
      score = score + Clamp(math.floor(math.log(averageAvailable + 1) * 3), 0, 8)
    end

    local volatilityPct = tonumber(signals.volatilityPct)
    if volatilityPct and volatilityPct > 140 then
      score = score - 8
    elseif volatilityPct and volatilityPct > 80 then
      score = score - 4
    end
  end

  if record.source == "auctionator_api" then
    score = score + 4
    if type(record.sourceAgeDays) == "number" and record.sourceAgeDays > 3 then
      score = score - 4
    end
  end

  score = Clamp(math.floor(score + 0.5), 0, 100)

  local label
  if score >= 70 then
    label = "High"
  elseif score >= 40 then
    label = "Medium"
  else
    label = "Low"
  end

  return label, score, {
    samples = samples,
    ageHours = ageHours,
    historyHours = historyHours,
    source = record.source,
    auctionatorAgeDays = signals and signals.ageDays or nil,
    auctionatorHistoryDays = signals and signals.historyDays or nil,
    auctionatorActivityDays7 = signals and signals.activityDays7 or nil,
    auctionatorExact = signals and signals.exact or nil,
    auctionatorAvailableAvg = signals and signals.availableAvg or nil,
    auctionatorAvailableLatest = signals and signals.availableLatest or nil,
    auctionatorVolatilityPct = signals and signals.volatilityPct or nil,
  }
end

function GoldMap.AHCache:GetConfidenceTier(itemID)
  local record = self:GetRecord(itemID)
  if not record then
    local tier = 0
    return tier, self:GetConfidenceTierInfo(tier).label, 0, {
      source = "none",
    }
  end

  local label, score, meta = self:GetConfidence(itemID)
  local tier = self:GetConfidenceTierFromLabel(label)
  return tier, label, score, meta
end

function GoldMap.AHCache:GetAggregateConfidence(items, maxRows)
  if not items or #items == 0 then
    return "Unknown", 0, {
      sampleItems = 0,
      totalWeight = 0,
    }
  end

  local sumWeight = 0
  local weightedScore = 0
  local considered = 0
  local weightedAgeDays = 0
  local weightedHistoryDays = 0
  local weightedActivityDays7 = 0
  local weightedAvailable = 0
  local weightedExact = 0
  local recordsSeen = 0
  local ageWeight = 0
  local historyWeight = 0
  local activityWeight = 0
  local availableWeight = 0
  local exactWeight = 0
  local limit = tonumber(maxRows) or #items

  for i, row in ipairs(items) do
    if i > limit then
      break
    end

    if row and row.itemID then
      if self:GetRecord(row.itemID) then
        recordsSeen = recordsSeen + 1
      end
      local _, score, meta = self:GetConfidence(row.itemID)
      local weight = tonumber(row.evContribution) or tonumber(row.price) or 1
      weight = math.max(1, weight)
      weightedScore = weightedScore + (score * weight)
      sumWeight = sumWeight + weight
      considered = considered + 1

      if meta then
        if type(meta.auctionatorAgeDays) == "number" then
          weightedAgeDays = weightedAgeDays + (meta.auctionatorAgeDays * weight)
          ageWeight = ageWeight + weight
        end
        if type(meta.auctionatorHistoryDays) == "number" then
          weightedHistoryDays = weightedHistoryDays + (meta.auctionatorHistoryDays * weight)
          historyWeight = historyWeight + weight
        end
        if type(meta.auctionatorActivityDays7) == "number" then
          weightedActivityDays7 = weightedActivityDays7 + (meta.auctionatorActivityDays7 * weight)
          activityWeight = activityWeight + weight
        end
        if type(meta.auctionatorAvailableAvg) == "number" then
          weightedAvailable = weightedAvailable + (meta.auctionatorAvailableAvg * weight)
          availableWeight = availableWeight + weight
        end
        if meta.auctionatorExact ~= nil then
          weightedExact = weightedExact + ((meta.auctionatorExact and 1 or 0) * weight)
          exactWeight = exactWeight + weight
        end
      end
    end
  end

  if considered == 0 or sumWeight <= 0 then
    return "Unknown", 0, {
      sampleItems = 0,
      totalWeight = 0,
    }
  end

  if recordsSeen <= 0 then
    return "Unknown", 0, {
      sampleItems = considered,
      totalWeight = sumWeight,
      recordsSeen = recordsSeen,
    }
  end

  local score = math.floor((weightedScore / sumWeight) + 0.5)
  local label
  if score >= 70 then
    label = "High"
  elseif score >= 40 then
    label = "Medium"
  else
    label = "Low"
  end

  return label, score, {
    sampleItems = considered,
    totalWeight = sumWeight,
    recordsSeen = recordsSeen,
    avgAgeDays = ageWeight > 0 and (weightedAgeDays / ageWeight) or nil,
    avgHistoryDays = historyWeight > 0 and (weightedHistoryDays / historyWeight) or nil,
    avgActivityDays7 = activityWeight > 0 and (weightedActivityDays7 / activityWeight) or nil,
    avgAvailable = availableWeight > 0 and (weightedAvailable / availableWeight) or nil,
    exactRatio = exactWeight > 0 and (weightedExact / exactWeight) or nil,
  }
end

function GoldMap.AHCache:GetAggregateSellSpeed(items, maxRows)
  if not items or #items == 0 then
    local tier = 0
    return tier, self:GetSellSpeedLabel(tier), 0, {
      sampleItems = 0,
      totalWeight = 0,
    }
  end

  local weightedScore = 0
  local totalWeight = 0
  local considered = 0
  local limit = tonumber(maxRows) or #items

  for index, row in ipairs(items) do
    if index > limit then
      break
    end

    if row and row.itemID then
      local _, _, score = self:GetSellSpeed(row.itemID)
      local weight = tonumber(row.evContribution) or tonumber(row.price) or 1
      weight = math.max(1, weight)
      weightedScore = weightedScore + (score * weight)
      totalWeight = totalWeight + weight
      considered = considered + 1
    end
  end

  if considered == 0 or totalWeight <= 0 then
    local tier = 0
    return tier, self:GetSellSpeedLabel(tier), 0, {
      sampleItems = 0,
      totalWeight = 0,
    }
  end

  local score = math.floor((weightedScore / totalWeight) + 0.5)
  local tier
  if score >= 70 then
    tier = 3
  elseif score >= 45 then
    tier = 2
  elseif score >= 20 then
    tier = 1
  else
    tier = 0
  end

  return tier, self:GetSellSpeedLabel(tier), score, {
    sampleItems = considered,
    totalWeight = totalWeight,
  }
end
