local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.ScanAdvisor = GoldMap.ScanAdvisor or {}

local function Clamp(value, low, high)
  if value < low then
    return low
  end
  if value > high then
    return high
  end
  return value
end

local function FormatPct(value)
  return string.format("%.0f%%", (tonumber(value) or 0) * 100)
end

function GoldMap.ScanAdvisor:GetConfig()
  local scanner = GoldMap.db and GoldMap.db.scanner or {}
  return {
    enabled = scanner.scanAdvisorEnabled ~= false,
    intervalMinutes = Clamp(math.floor(tonumber(scanner.advisorIntervalMinutes) or 10), 2, 60),
    cooldownMinutes = Clamp(math.floor(tonumber(scanner.advisorNotifyCooldownMinutes) or 45), 5, 180),
    yellowHours = Clamp(math.floor(tonumber(scanner.advisorYellowHours) or 12), 6, 72),
    redHours = Clamp(math.floor(tonumber(scanner.advisorRedHours) or 24), 12, 120),
    yellowStaleRatio = Clamp(tonumber(scanner.advisorYellowStaleRatio) or 0.30, 0.05, 0.95),
    redStaleRatio = Clamp(tonumber(scanner.advisorRedStaleRatio) or 0.55, 0.10, 0.99),
    yellowMissingRatio = Clamp(tonumber(scanner.advisorYellowMissingRatio) or 0.20, 0.05, 0.95),
    redMissingRatio = Clamp(tonumber(scanner.advisorRedMissingRatio) or 0.40, 0.10, 0.99),
  }
end

function GoldMap.ScanAdvisor:BuildReport()
  local scanner = GoldMap.Scanner
  local hasAuctionator = GoldMap.AHCache and GoldMap.AHCache:IsAuctionatorAvailable() or false
  local trackedSet, trackedCount = nil, 0
  if scanner and type(scanner.GetTrackedItemSet) == "function" then
    trackedSet, trackedCount = scanner:GetTrackedItemSet()
  end

  local health = GoldMap.AHCache and GoldMap.AHCache.GetTrackedMarketHealth and GoldMap.AHCache:GetTrackedMarketHealth(trackedSet or {}) or {}
  local lastScanAt = GoldMap.AHCache and GoldMap.AHCache:GetLastScanAt() or 0
  local now = GetServerTime()
  local lastSyncHours = (lastScanAt and lastScanAt > 0) and math.max(0, (now - lastScanAt) / 3600) or nil

  local cfg = self:GetConfig()
  if cfg.redHours < cfg.yellowHours then
    cfg.redHours = cfg.yellowHours
  end
  if cfg.redStaleRatio < cfg.yellowStaleRatio then
    cfg.redStaleRatio = cfg.yellowStaleRatio
  end
  if cfg.redMissingRatio < cfg.yellowMissingRatio then
    cfg.redMissingRatio = cfg.yellowMissingRatio
  end

  local severity = 0
  local reasons = {}

  if not hasAuctionator then
    severity = 2
    table.insert(reasons, "Auctionator API unavailable")
  end

  if not trackedCount or trackedCount <= 0 then
    trackedCount = tonumber(health.tracked) or 0
  end

  local staleRatio = tonumber(health.stale24hRatio) or 0
  local missingRatio = tonumber(health.missingRatio) or 0

  if lastSyncHours == nil then
    severity = math.max(severity, 2)
    table.insert(reasons, "No GoldMap market sync yet")
  else
    if lastSyncHours >= cfg.redHours then
      severity = math.max(severity, 2)
      table.insert(reasons, string.format("Last sync %.1fh ago", lastSyncHours))
    elseif lastSyncHours >= cfg.yellowHours then
      severity = math.max(severity, 1)
      table.insert(reasons, string.format("Last sync %.1fh ago", lastSyncHours))
    end
  end

  if staleRatio >= cfg.redStaleRatio then
    severity = math.max(severity, 2)
    table.insert(reasons, "Too many stale prices (>24h)")
  elseif staleRatio >= cfg.yellowStaleRatio then
    severity = math.max(severity, 1)
    table.insert(reasons, "Many stale prices (>24h)")
  end

  if missingRatio >= cfg.redMissingRatio then
    severity = math.max(severity, 2)
    table.insert(reasons, "Large missing price coverage")
  elseif missingRatio >= cfg.yellowMissingRatio then
    severity = math.max(severity, 1)
    table.insert(reasons, "Partial missing price coverage")
  end

  local label
  local colorCode
  local recommendation
  if severity == 2 then
    label = "RED"
    colorCode = "ffff6666"
    recommendation = "Open Auction House, run Auctionator scan, then /goldmap scan."
  elseif severity == 1 then
    label = "YELLOW"
    colorCode = "ffffcc00"
    recommendation = "Market data is aging. Consider an Auctionator scan soon."
  else
    label = "GREEN"
    colorCode = "ff33ff66"
    recommendation = "Market data is fresh."
  end

  return {
    severity = severity,
    label = label,
    colorCode = colorCode,
    trackedItems = trackedCount or 0,
    stale24hRatio = staleRatio,
    missingRatio = missingRatio,
    stale24h = tonumber(health.stale24h) or 0,
    missing = tonumber(health.missing) or 0,
    priced = tonumber(health.priced) or 0,
    averageAgeHours = tonumber(health.averageAgeHours),
    lastSyncHours = lastSyncHours,
    reasons = reasons,
    recommendation = recommendation,
  }
end

function GoldMap.ScanAdvisor:BuildMessage(report)
  if not report then
    return "Scan advisor unavailable."
  end

  local lastSync = report.lastSyncHours and string.format("%.1fh", report.lastSyncHours) or "never"
  local avgAge = report.averageAgeHours and string.format("%.1fh", report.averageAgeHours) or "n/a"

  local parts = {
    string.format("|c%sScan Advisor: %s|r", report.colorCode or "ff33ff66", report.label or "GREEN"),
    string.format("tracked %d", report.trackedItems or 0),
    string.format("missing %s", FormatPct(report.missingRatio)),
    string.format("stale>24h %s", FormatPct(report.stale24hRatio)),
    string.format("avg age %s", avgAge),
    string.format("last sync %s", lastSync),
  }

  if report.recommendation and report.recommendation ~= "" then
    parts[#parts + 1] = report.recommendation
  end

  return table.concat(parts, " | ")
end

function GoldMap.ScanAdvisor:GetLastReport()
  return self.lastReport
end

function GoldMap.ScanAdvisor:RefreshReport()
  local report = self:BuildReport()
  self.lastReport = report
  GoldMap:SendMessage("SCAN_ADVISOR_UPDATED", report)
  return report
end

function GoldMap.ScanAdvisor:CheckNow(forcePrint)
  local report = self:RefreshReport()

  local cfg = self:GetConfig()
  if cfg.enabled == false and not forcePrint then
    return report
  end

  local now = GetServerTime()
  local cooldownSeconds = cfg.cooldownMinutes * 60
  local key = string.format("%s|%s|%.0f|%.0f", report.label or "GREEN", report.trackedItems or 0, (report.missingRatio or 0) * 100, (report.stale24hRatio or 0) * 100)
  local canNotify = false

  if forcePrint then
    canNotify = true
  elseif (report.severity or 0) > 0 then
    if self.lastNotifyKey ~= key then
      canNotify = true
    elseif not self.lastNotifyAt or (now - self.lastNotifyAt) >= cooldownSeconds then
      canNotify = true
    end
  end

  if canNotify then
    GoldMap:Printf("%s", self:BuildMessage(report))
    self.lastNotifyAt = now
    self.lastNotifyKey = key
  end

  return report
end

function GoldMap.ScanAdvisor:RestartTickerIfNeeded()
  local cfg = self:GetConfig()
  if not cfg.enabled then
    if self.ticker and self.ticker.Cancel then
      self.ticker:Cancel()
    end
    self.ticker = nil
    self.tickerInterval = nil
    return
  end
  local intervalSeconds = cfg.intervalMinutes * 60

  if self.ticker and self.tickerInterval == intervalSeconds then
    return
  end

  if self.ticker and self.ticker.Cancel then
    self.ticker:Cancel()
    self.ticker = nil
  end

  self.tickerInterval = intervalSeconds
  if C_Timer and C_Timer.NewTicker then
    self.ticker = C_Timer.NewTicker(intervalSeconds, function()
      if not GoldMap or not GoldMap.ScanAdvisor then
        return
      end
      GoldMap.ScanAdvisor:CheckNow(false)
    end)
  end
end

function GoldMap.ScanAdvisor:Init()
  if self.initialized then
    self:RestartTickerIfNeeded()
    return
  end

  self.lastNotifyAt = 0
  self.lastNotifyKey = nil
  self.lastReport = nil
  self.ticker = nil
  self.tickerInterval = nil

  GoldMap:RegisterMessage("PRICE_CACHE_UPDATED", function()
    C_Timer.After(0.5, function()
      if GoldMap and GoldMap.ScanAdvisor then
        GoldMap.ScanAdvisor:CheckNow(false)
      end
    end)
  end)

  GoldMap:RegisterMessage("SCAN_STATUS", function()
    C_Timer.After(0.2, function()
      if GoldMap and GoldMap.ScanAdvisor then
        GoldMap.ScanAdvisor:CheckNow(false)
      end
    end)
  end)

  GoldMap:RegisterMessage("AH_CLOSED", function()
    C_Timer.After(1.0, function()
      if GoldMap and GoldMap.ScanAdvisor then
        GoldMap.ScanAdvisor:CheckNow(false)
      end
    end)
  end)

  self:RestartTickerIfNeeded()

  C_Timer.After(4.0, function()
    if GoldMap and GoldMap.ScanAdvisor then
      GoldMap.ScanAdvisor:CheckNow(false)
    end
  end)

  self.initialized = true
end
