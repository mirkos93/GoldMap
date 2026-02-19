local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.AHUtils = GoldMap.AHUtils or {}

local RESULTS_PER_PAGE = 50

function GoldMap.AHUtils:IsLegacyAH()
  return type(QueryAuctionItems) == "function"
end

function GoldMap.AHUtils:GetResultsPerPage()
  return RESULTS_PER_PAGE
end

function GoldMap.AHUtils:GetUnitPriceFromAuctionInfo(auctionInfo)
  if not auctionInfo then
    return nil
  end

  local stackSize = auctionInfo[3] or 0
  local buyout = auctionInfo[10] or 0

  if stackSize <= 0 or buyout <= 0 then
    return nil
  end

  return math.floor((buyout / stackSize) + 0.5)
end

function GoldMap.AHUtils:CollectBestUnitPriceForItem(itemID)
  local total = GetNumAuctionItems("list")
  if not total or total <= 0 then
    return nil, 0
  end

  local bestPrice = nil
  local matches = 0

  for i = 1, total do
    local info = { GetAuctionItemInfo("list", i) }
    local listedItemID = info[17]
    if not listedItemID and info[2] and GetItemInfoInstant then
      listedItemID = select(1, GetItemInfoInstant(info[2]))
    end

    if listedItemID == itemID then
      local unitPrice = self:GetUnitPriceFromAuctionInfo(info)
      if unitPrice then
        if not bestPrice or unitPrice < bestPrice then
          bestPrice = unitPrice
        end
        matches = matches + 1
      end
    end
  end

  return bestPrice, matches
end

function GoldMap.AHUtils:CollectBestUnitPricesForSet(itemSet, bestByItemID)
  local total = GetNumAuctionItems("list")
  if not total or total <= 0 or not itemSet then
    return 0
  end

  bestByItemID = bestByItemID or {}
  local matches = 0

  for i = 1, total do
    local info = { GetAuctionItemInfo("list", i) }
    local listedItemID = info[17]
    if not listedItemID and info[2] and GetItemInfoInstant then
      listedItemID = select(1, GetItemInfoInstant(info[2]))
    end

    if listedItemID and itemSet[listedItemID] then
      local unitPrice = self:GetUnitPriceFromAuctionInfo(info)
      if unitPrice then
        local currentBest = bestByItemID[listedItemID]
        if not currentBest or unitPrice < currentBest then
          bestByItemID[listedItemID] = unitPrice
        end
        matches = matches + 1
      end
    end
  end

  return matches
end

function GoldMap.AHUtils:ItemName(itemID)
  local name = GetItemInfo(itemID)
  return name
end

function GoldMap.AHUtils:FormatCoin(copper)
  if not copper then
    return "No price yet"
  end
  return GetCoinTextureString(copper)
end
