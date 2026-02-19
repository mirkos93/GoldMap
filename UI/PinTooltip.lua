local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.PinTooltip = GoldMap.PinTooltip or {}

local function FormatPercent(value)
  return string.format("%.2f%%", value or 0)
end

local function FormatExpectedGold(evCopper)
  if not evCopper then
    return "--"
  end
  return GetCoinTextureString(math.floor(evCopper + 0.5))
end

local function ConfidenceColor(label)
  local tier = GoldMap.AHCache:GetConfidenceTierFromLabel(label)
  return GoldMap.AHCache:GetConfidenceColor(tier)
end

local function ReliabilityHint(label)
  if label == "Unknown" then
    return "no market data yet"
  end
  if label == "High" then
    return "very reliable"
  end
  if label == "Medium" then
    return "usable, keep scanning"
  end
  return "low, scan more before trusting"
end

function GoldMap.PinTooltip:RenderValueRows(tooltip, eval, context)
  if not eval then
    return false
  end

  context = context or {}
  local maxLines = context.maxLines or GoldMap.db.ui.maxTooltipItems

  local expectedGoldText = FormatExpectedGold(eval.evCopper)
  local scanAge = GoldMap:FormatAge(eval.scanAgeSeconds)
  local valueLabel = context.valueLabel or "Estimated Gold"
  local showTechnical = IsShiftKeyDown and IsShiftKeyDown()
  local confidenceLabel, confidenceScore, confidenceMeta = GoldMap.AHCache:GetAggregateConfidence(eval.items, maxLines)
  local sellTier, sellLabel, sellScore = GoldMap.AHCache:GetAggregateSellSpeed(eval.items, maxLines)
  if not eval.hasPrice or (eval.pricedDropCount or 0) <= 0 then
    confidenceLabel = "Unknown"
    confidenceScore = 0
  end
  local cR, cG, cB = ConfidenceColor(confidenceLabel)
  local sR, sG, sB = GoldMap.AHCache:GetSellSpeedColor(sellTier)

  tooltip:AddLine(valueLabel .. ": " .. expectedGoldText, 0.9, 0.9, 0.9)
  if confidenceLabel == "Unknown" then
    tooltip:AddLine("Data reliability: Unknown (no market data yet)", cR, cG, cB)
  else
    tooltip:AddLine(string.format("Data reliability: %s (%d/100, %s)", confidenceLabel, confidenceScore or 0, ReliabilityHint(confidenceLabel)), cR, cG, cB)
  end
  tooltip:AddLine(string.format("Likely to sell: %s (%d/100)", sellLabel, sellScore or 0), sR, sG, sB)
  tooltip:AddLine(string.format("Matching items: %d/%d  |  Priced: %d  |  Spawns: %d", eval.filteredDropCount or 0, eval.totalDropCount or 0, eval.pricedDropCount or 0, eval.spawnCount or 0), 0.7, 0.7, 0.7)
  tooltip:AddLine("Last market sync: " .. scanAge, 0.7, 0.7, 0.7)

  if showTechnical and confidenceMeta and confidenceMeta.sampleItems and confidenceMeta.sampleItems > 0 then
    local parts = {}
    if type(confidenceMeta.avgAgeDays) == "number" then
      table.insert(parts, string.format("avg age %.1fd", confidenceMeta.avgAgeDays))
    end
    if type(confidenceMeta.avgHistoryDays) == "number" then
      table.insert(parts, string.format("history %.1fd", confidenceMeta.avgHistoryDays))
    end
    if type(confidenceMeta.exactRatio) == "number" then
      table.insert(parts, string.format("exact %.0f%%", confidenceMeta.exactRatio * 100))
    end
    if type(confidenceMeta.avgAvailable) == "number" then
      table.insert(parts, string.format("seen qty %.0f", confidenceMeta.avgAvailable))
    end
    if #parts > 0 then
      tooltip:AddLine("Auctionator signals: " .. table.concat(parts, "  |  "), 0.68, 0.68, 0.68)
    end
  end
  if showTechnical then
    tooltip:AddLine("Model: estimate from seed drop rates + latest Auction House snapshot", 0.6, 0.6, 0.6)
  else
    tooltip:AddLine("Hold Shift for detailed market signals.", 0.63, 0.63, 0.63)
  end
  if confidenceLabel ~= "High" then
    tooltip:AddLine("Tip: run Auction House scans repeatedly across multiple play sessions to reach High confidence.", 0.72, 0.72, 0.72)
  end
  tooltip:AddLine(" ")

  local shown = 0
  for _, row in ipairs(eval.items or {}) do
    if shown >= maxLines then
      break
    end

    local itemLink = GoldMap.Ids:GetItemLink(row.itemID, row.itemName, row.quality)
    local qualityIcon = GoldMap.Ids:GetQualityIconPath(row.quality)
    local priceText = row.price and GetCoinTextureString(row.price) or "No price yet"
    local valueLine = row.evContribution and GetCoinTextureString(math.floor(row.evContribution + 0.5)) or "--"
    local rowTier = row.sellSpeedTier
    local rowLabel = row.sellSpeedLabel
    if rowTier == nil or not rowLabel then
      rowTier, rowLabel = GoldMap.AHCache:GetSellSpeed(row.itemID)
    end
    local rowReliabilityTier = row.reliabilityTier
    local rowReliabilityLabel = row.reliabilityLabel
    if rowReliabilityTier == nil or not rowReliabilityLabel then
      rowReliabilityTier, rowReliabilityLabel = GoldMap.AHCache:GetConfidenceTier(row.itemID)
    end
    local tierInfo = GoldMap.AHCache:GetSellSpeedTierInfo(rowTier)
    local reliabilityInfo = GoldMap.AHCache:GetConfidenceTierInfo(rowReliabilityTier)
    local sellSpeedText = string.format("|c%s%s|r", tierInfo.colorCode, rowLabel or "None")
    local reliabilityText = string.format("|c%s%s|r", reliabilityInfo.colorCode, rowReliabilityLabel or "Unknown")
    local countText = (row.minCount and row.maxCount and row.minCount ~= row.maxCount)
      and string.format("x%d-%d", row.minCount, row.maxCount)
      or ("x" .. tostring(row.minCount or 1))

    local chanceText = FormatPercent(row.chance)
    if context and context.chancePrefix then
      chanceText = string.format("%s %s", context.chancePrefix, chanceText)
    end
    local itemLabel = string.format("|T%s:12:12:0:0|t %s (%s, %s)", qualityIcon, itemLink, chanceText, countText)

    local rightText
    if showTechnical then
      rightText = string.format("%s  |  %s  |  %s", priceText, sellSpeedText, reliabilityText)
    else
      rightText = string.format("%s  |  %s", priceText, sellSpeedText)
    end

    tooltip:AddDoubleLine(
      itemLabel,
      rightText,
      1, 1, 1,
      1, 1, 1
    )
    tooltip:AddDoubleLine("  Value from this item", valueLine, 0.65, 0.65, 0.65, 0.9, 0.9, 0.9)

    shown = shown + 1
  end

  if shown == 0 then
    tooltip:AddLine("No items match current filters.", 1, 0.3, 0.3)
    if not eval.hasPrice then
      tooltip:AddLine("No market data yet. Run an Auctionator scan, then use /goldmap scan to sync.", 1, 0.82, 0.2)
    end
  elseif shown >= maxLines and #eval.items > maxLines then
    tooltip:AddLine("More drops omitted...", 0.75, 0.75, 0.75)
  end

  return true
end

function GoldMap.PinTooltip:RenderMobInfo(tooltip, mob, eval, context)
  if not mob or not eval then
    return false
  end

  context = context or {}
  local showTitle = context.showTitle ~= false
  local titlePrefix = context.titlePrefix or ""
  local levelText = mob.minLevel == mob.maxLevel and tostring(mob.minLevel) or (mob.minLevel .. "-" .. mob.maxLevel)

  if showTitle then
    tooltip:AddLine(titlePrefix .. mob.name, 1, 0.82, 0)
    tooltip:AddLine("Level " .. levelText .. "  |  Source: " .. (eval.source or mob.source or "Seed DB"), 0.85, 0.85, 0.85)
  end

  return self:RenderValueRows(tooltip, eval, {
    maxLines = context.maxLines,
    valueLabel = "Estimated Gold per kill",
  })
end

function GoldMap.PinTooltip:RenderGatherInfo(tooltip, node, eval, context)
  if not node or not eval then
    return false
  end

  context = context or {}
  local showTitle = context.showTitle ~= false
  local titlePrefix = context.titlePrefix or ""
  local profession = node.profession == "HERBALISM" and "Herbalism" or (node.profession == "MINING" and "Mining" or "Gathering")

  if showTitle then
    tooltip:AddLine(titlePrefix .. node.name, 0.65, 1, 0.65)
    tooltip:AddLine(profession .. "  |  Source: " .. (eval.source or node.source or "Seed DB"), 0.85, 0.85, 0.85)
  end

  return self:RenderValueRows(tooltip, eval, {
    maxLines = context.maxLines,
    valueLabel = "Estimated Gold per node",
    chancePrefix = "Yield",
  })
end

function GoldMap.PinTooltip:Show(pin, payload)
  if not payload then
    return
  end

  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  GameTooltip:ClearLines()

  local shown = false
  if payload.kind == "GATHER" and payload.node and payload.eval then
    shown = self:RenderGatherInfo(GameTooltip, payload.node, payload.eval, { showTitle = true, maxLines = GoldMap.db.ui.maxTooltipItems })
  elseif payload.mob and payload.eval then
    shown = self:RenderMobInfo(GameTooltip, payload.mob, payload.eval, { showTitle = true, maxLines = GoldMap.db.ui.maxTooltipItems })
  end

  if shown then
    GameTooltip:Show()
    return
  end
  GameTooltip:Hide()
end

function GoldMap.PinTooltip:Hide()
  GameTooltip:Hide()
end
