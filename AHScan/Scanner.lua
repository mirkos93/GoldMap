local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.Scanner = GoldMap.Scanner or {}

function GoldMap.Scanner:Init()
  if self.initialized then
    return
  end

  self.running = false
  self.lastAuctionatorStats = nil
  self.trackedItemSet = nil
  self.trackedItemCount = 0
  self.dbUpdateSyncPending = false
  self.auctionatorUpdateRegistered = false

  GoldMap:RegisterMessage("REQUEST_SCAN", function(force)
    self:StartSeedScan(force)
  end)

  GoldMap:RegisterMessage("AH_OPENED", function()
    -- Keep local prices fresh from Auctionator whenever AH is opened.
    self:RegisterAuctionatorDBUpdates()
    self:SyncFromAuctionator(false, true)
  end)

  -- Try a silent warmup shortly after login so existing Auctionator data is usable immediately.
  C_Timer.After(2.0, function()
    if GoldMap and GoldMap.Scanner then
      GoldMap.Scanner:RegisterAuctionatorDBUpdates()
      GoldMap.Scanner:SyncFromAuctionator(false, true)
    end
  end)

  self.initialized = true
end

function GoldMap.Scanner:IsRunning()
  return self.running and true or false
end

function GoldMap.Scanner:Abort(_reason)
  self.running = false
  return false
end

function GoldMap.Scanner:CountEntries(map)
  local count = 0
  for _ in pairs(map or {}) do
    count = count + 1
  end
  return count
end

function GoldMap.Scanner:GetTrackedItemSet()
  if self.trackedItemSet then
    return self.trackedItemSet, self.trackedItemCount or 0
  end

  local seed = GoldMapData and GoldMapData.SeedDrops or {}
  local gather = GoldMapData and GoldMapData.GatherNodes or {}
  local set = {}

  for _, mob in pairs(seed) do
    for _, drop in ipairs(mob.drops or {}) do
      if type(drop.itemID) == "number" then
        set[drop.itemID] = true
      end
    end
  end

  for _, node in pairs(gather) do
    for _, drop in ipairs(node.drops or {}) do
      if type(drop.itemID) == "number" then
        set[drop.itemID] = true
      end
    end
  end

  self.trackedItemSet = set
  self.trackedItemCount = self:CountEntries(set)
  return self.trackedItemSet, self.trackedItemCount
end

function GoldMap.Scanner:RegisterAuctionatorDBUpdates()
  if self.auctionatorUpdateRegistered then
    return true
  end

  if not (Auctionator and Auctionator.API and Auctionator.API.v1 and type(Auctionator.API.v1.RegisterForDBUpdate) == "function") then
    return false
  end

  local ok, err = pcall(Auctionator.API.v1.RegisterForDBUpdate, "GoldMap", function()
    if not GoldMap or not GoldMap.Scanner then
      return
    end
    if GoldMap.Scanner.dbUpdateSyncPending then
      return
    end
    GoldMap.Scanner.dbUpdateSyncPending = true
    C_Timer.After(1.0, function()
      if not GoldMap or not GoldMap.Scanner then
        return
      end
      GoldMap.Scanner.dbUpdateSyncPending = false
      GoldMap.Scanner:SyncFromAuctionator(false, true)
    end)
  end)

  if not ok then
    GoldMap:Debugf("Auctionator RegisterForDBUpdate failed: %s", tostring(err))
    return false
  end

  self.auctionatorUpdateRegistered = true
  return true
end

function GoldMap.Scanner:BuildSeedItemSet(force)
  local trackedItemSet = self:GetTrackedItemSet()
  local staleSeconds = GoldMap.db and GoldMap.db.scanner and GoldMap.db.scanner.staleSeconds or (6 * 60 * 60)
  local set = {}

  if force then
    for itemID in pairs(trackedItemSet or {}) do
      set[itemID] = true
    end
    return set
  end

  for itemID in pairs(trackedItemSet or {}) do
    local record = GoldMap.AHCache and GoldMap.AHCache.GetRecord and GoldMap.AHCache:GetRecord(itemID) or nil
    local needsSourceRepair = (record ~= nil and record.source ~= "auctionator_api")
    local needsPriceModelUpgrade = (record ~= nil and record.source == "auctionator_api" and tonumber(record.priceModelVersion) ~= 2)
    if needsSourceRepair or needsPriceModelUpgrade or not GoldMap.AHCache:IsFresh(itemID, staleSeconds) then
      set[itemID] = true
    end
  end

  return set
end

function GoldMap.Scanner:GetLastAuctionatorStats()
  return self.lastAuctionatorStats
end

function GoldMap.Scanner:GetAuctionatorIntegrationState()
  local _, trackedCount = self:GetTrackedItemSet()
  local hasAPI = GoldMap.AHCache and GoldMap.AHCache:IsAuctionatorAvailable() or false
  return {
    auctionatorAvailable = hasAPI,
    dbUpdateHooked = self.auctionatorUpdateRegistered and true or false,
    trackedItems = trackedCount or 0,
    lastSyncAt = GoldMap.AHCache and GoldMap.AHCache:GetLastScanAt() or 0,
    lastStats = self.lastAuctionatorStats,
  }
end

function GoldMap.Scanner:EmitStatus(reason, stats)
  GoldMap:SendMessage("SCAN_STATUS", {
    running = false,
    mode = "auctionator_sync",
    reason = reason,
    totalItems = stats and stats.requested or 0,
    cachedItems = stats and stats.imported or 0,
    missingItems = stats and math.max(0, (stats.requested or 0) - (stats.priced or 0)) or 0,
    failedItems = stats and (stats.errors or 0) or 0,
    timeoutCount = 0,
    currentItemID = nil,
    currentPage = nil,
    auctionator = stats,
  })
end

function GoldMap.Scanner:SyncFromAuctionator(force, silent)
  if not GoldMap.AHCache:IsAuctionatorAvailable() then
    local stats = {
      enabled = true,
      available = false,
      requested = 0,
      imported = 0,
      priced = 0,
      tooOld = 0,
      errors = 0,
      skippedFresh = 0,
      remaining = 0,
      force = force and true or false,
    }
    self.lastAuctionatorStats = stats
    self:EmitStatus("auctionator_unavailable", stats)
    if not silent then
      GoldMap:Printf("Auctionator is required and its API is unavailable.")
    end
    return false
  end

  local requestedSet = self:BuildSeedItemSet(force and true or false)
  local requestedCount = self:CountEntries(requestedSet)

  if requestedCount == 0 then
    local stats = {
      enabled = true,
      available = true,
      requested = 0,
      imported = 0,
      priced = 0,
      tooOld = 0,
      errors = 0,
      skippedFresh = 0,
      remaining = 0,
      force = force and true or false,
    }
    self.lastAuctionatorStats = stats
    self:EmitStatus("nothing_to_update", stats)
    if not silent then
      GoldMap:Printf("All tracked prices are already fresh.")
    end
    return false
  end

  local maxAgeDays = GoldMap.db and GoldMap.db.scanner and GoldMap.db.scanner.auctionatorMaxAgeDays or 7
  local importStats = GoldMap.AHCache:ImportFromAuctionator(requestedSet, maxAgeDays)
  local stats = {
    enabled = true,
    available = true,
    requested = requestedCount,
    imported = importStats.imported or 0,
    priced = importStats.priced or 0,
    tooOld = importStats.tooOld or 0,
    errors = importStats.errors or 0,
    skippedFresh = 0,
    remaining = math.max(0, requestedCount - (importStats.priced or 0)),
    force = force and true or false,
  }

  self.lastAuctionatorStats = stats
  if stats.imported > 0 then
    GoldMap.AHCache:SetScanTimestamp()
  end

  self:EmitStatus("complete", stats)

  if not silent then
    GoldMap:Printf(
      "Auctionator sync complete. Imported %d/%d tracked prices (%d priced, %d too old, %d errors).",
      stats.imported,
      stats.requested,
      stats.priced,
      stats.tooOld,
      stats.errors
    )
  end

  return stats.imported > 0
end

function GoldMap.Scanner:StartSeedScan(force)
  return self:SyncFromAuctionator(force and true or false, false)
end

function GoldMap.Scanner:StartFullBrowseScan()
  return self:SyncFromAuctionator(true, false)
end
