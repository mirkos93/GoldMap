local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.ItemTooltip = GoldMap.ItemTooltip or {}

local TOOLTIP_NAMES = {
  "GameTooltip",
  "ItemRefTooltip",
  "ShoppingTooltip1",
  "ShoppingTooltip2",
}

local function GetItemContextFromTooltip(tooltip)
  if not tooltip or type(tooltip.GetItem) ~= "function" then
    return nil, nil
  end

  local _, itemLink = tooltip:GetItem()
  if not itemLink then
    return nil, nil
  end

  local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
  if not itemID and GetItemInfoInstant then
    itemID = select(1, GetItemInfoInstant(itemLink))
  end
  return itemID, itemLink
end

local function ColorizeLabel(label, tierInfo)
  if not tierInfo or not tierInfo.colorCode then
    return label
  end
  return string.format("|c%s%s|r", tierInfo.colorCode, label)
end

local function GetLiveAuctionatorPrice(itemID, itemLink)
  if not (Auctionator and Auctionator.API and Auctionator.API.v1) then
    return nil, nil
  end

  local api = Auctionator.API.v1
  local callerID = "GoldMap"

  if itemLink and type(api.GetAuctionPriceByItemLink) == "function" then
    local okLink, valueLink = pcall(api.GetAuctionPriceByItemLink, callerID, itemLink)
    if okLink and type(valueLink) == "number" and valueLink > 0 then
      return valueLink, "auctionator_link"
    end
  end

  if itemID and type(api.GetAuctionPriceByItemID) == "function" then
    local okID, valueID = pcall(api.GetAuctionPriceByItemID, callerID, itemID)
    if okID and type(valueID) == "number" and valueID > 0 then
      return valueID, "auctionator_item"
    end
  end

  return nil, nil
end

function GoldMap.ItemTooltip:IsEnabled()
  return GoldMap.db and GoldMap.db.ui and GoldMap.db.ui.showItemTooltipMarket ~= false
end

function GoldMap.ItemTooltip:ClearMarker(tooltip)
  if not tooltip then
    return
  end
  tooltip.goldMapItemTooltipID = nil
  tooltip.goldMapItemTooltipLink = nil
  tooltip.goldMapItemTooltipRev = nil
end

function GoldMap.ItemTooltip:TryInject(tooltip)
  if self.injecting then
    return
  end
  if not self:IsEnabled() then
    return
  end

  local itemID, itemLink = GetItemContextFromTooltip(tooltip)
  if not itemID then
    return
  end

  local revision = GoldMap.AHCache and GoldMap.AHCache.GetRevision and GoldMap.AHCache:GetRevision() or 0
  if tooltip.goldMapItemTooltipID == itemID
    and tooltip.goldMapItemTooltipLink == itemLink
    and tooltip.goldMapItemTooltipRev == revision
  then
    return
  end

  local price = GoldMap.AHCache:Get(itemID)
  local livePrice, liveSource = GetLiveAuctionatorPrice(itemID, itemLink)
  local displayPrice = nil
  local displaySource = nil

  if livePrice and livePrice > 0 then
    displayPrice = livePrice
    displaySource = liveSource
  elseif price and price > 0 then
    displayPrice = price
    displaySource = "cache"
  end

  local sellTier, sellLabel, sellScore, sellMeta = GoldMap.AHCache:GetSellSpeed(itemID)
  local confidenceTier, confidenceLabel, confidenceScore = GoldMap.AHCache:GetConfidenceTier(itemID)

  -- Skip clutter for completely unknown items.
  if (not displayPrice or displayPrice <= 0) and (sellTier or 0) <= 0 and (confidenceTier or 0) <= 0 then
    return
  end

  self.injecting = true
  local ok = pcall(function()
    local sellInfo = GoldMap.AHCache:GetSellSpeedTierInfo(sellTier)
    local confidenceInfo = GoldMap.AHCache:GetConfidenceTierInfo(confidenceTier)
    local priceText = (displayPrice and displayPrice > 0) and GetCoinTextureString(displayPrice) or "No price"
    local ageText = "n/a"
    if sellMeta and tonumber(sellMeta.ageHours) then
      ageText = string.format("%.1fh", tonumber(sellMeta.ageHours))
    elseif sellMeta and tonumber(sellMeta.ageDays) then
      ageText = string.format("%.0fd", tonumber(sellMeta.ageDays))
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("|cffd4af37GoldMap Market|r", 1, 0.85, 0.2)
    tooltip:AddDoubleLine("Price", priceText, 0.85, 0.85, 0.85, 1, 1, 1)
    tooltip:AddDoubleLine(
      "Likely to sell",
      string.format("%s (%d/100)", ColorizeLabel(sellLabel, sellInfo), sellScore or 0),
      0.85, 0.85, 0.85,
      1, 1, 1
    )
    tooltip:AddDoubleLine(
      "Data reliability",
      string.format("%s (%d/100)", ColorizeLabel(confidenceLabel, confidenceInfo), confidenceScore or 0),
      0.85, 0.85, 0.85,
      1, 1, 1
    )
    tooltip:AddDoubleLine("Market age", ageText, 0.70, 0.70, 0.70, 0.70, 0.70, 0.70)
    if displaySource == "auctionator_link" then
      tooltip:AddLine("Source: Auctionator exact item (link match)", 0.62, 0.62, 0.62)
    elseif displaySource == "auctionator_item" then
      tooltip:AddLine("Source: Auctionator item-level market data", 0.62, 0.62, 0.62)
    end

    tooltip.goldMapItemTooltipID = itemID
    tooltip.goldMapItemTooltipLink = itemLink
    tooltip.goldMapItemTooltipRev = revision
    tooltip:Show()
  end)
  self.injecting = false

  if not ok then
    self:ClearMarker(tooltip)
  end
end

function GoldMap.ItemTooltip:HookTooltip(tooltip)
  if not tooltip or tooltip.goldMapItemTooltipHooked then
    return
  end

  tooltip:HookScript("OnTooltipCleared", function(tt)
    GoldMap.ItemTooltip:ClearMarker(tt)
  end)

  tooltip:HookScript("OnTooltipSetItem", function(tt)
    GoldMap.ItemTooltip:TryInject(tt)
  end)

  tooltip.goldMapItemTooltipHooked = true
end

function GoldMap.ItemTooltip:HookKnownTooltips()
  for _, name in ipairs(TOOLTIP_NAMES) do
    local tooltip = _G[name]
    if tooltip then
      self:HookTooltip(tooltip)
    end
  end
end

function GoldMap.ItemTooltip:Init()
  if self.initialized then
    return
  end

  self:HookKnownTooltips()

  GoldMap:RegisterMessage("PRICE_CACHE_UPDATED", function()
    if GameTooltip and GameTooltip:IsShown() then
      self:TryInject(GameTooltip)
    end
  end)

  GoldMap:RegisterMessage("FILTERS_CHANGED", function()
    if GameTooltip then
      self:ClearMarker(GameTooltip)
      if GameTooltip:IsShown() then
        self:TryInject(GameTooltip)
      end
    end
  end)

  -- Late hook for tooltips instantiated after login.
  C_Timer.After(3, function()
    if GoldMap and GoldMap.ItemTooltip then
      GoldMap.ItemTooltip:HookKnownTooltips()
    end
  end)

  self.initialized = true
end
