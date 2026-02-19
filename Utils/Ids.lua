local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.Ids = GoldMap.Ids or {}

GoldMap.Ids.QualityLabels = {
  [0] = "Poor",
  [1] = "Common",
  [2] = "Uncommon",
  [3] = "Rare",
  [4] = "Epic",
}

GoldMap.Ids.QualityColors = {
  [0] = "ff9d9d9d",
  [1] = "ffffffff",
  [2] = "ff1eff00",
  [3] = "ff0070dd",
  [4] = "ffa335ee",
}

GoldMap.Ids.QualityIconKeys = {
  [0] = "qualityCommon",
  [1] = "qualityCommon",
  [2] = "qualityUncommon",
  [3] = "qualityRare",
  [4] = "qualityEpic",
}

function GoldMap.Ids:GetQualityLabel(quality)
  return self.QualityLabels[quality] or ("Quality " .. tostring(quality))
end

function GoldMap.Ids:GetQualityColor(quality)
  return self.QualityColors[quality] or self.QualityColors[1]
end

function GoldMap.Ids:GetQualityIconPath(quality)
  local iconKey = self.QualityIconKeys[quality] or "qualityCommon"
  return GoldMap:GetIconPath(iconKey, 64)
end

function GoldMap.Ids:GetGatherNodeIconPath(profession, size)
  local iconKey = "pinBase"
  if profession == "HERBALISM" then
    iconKey = "nodeHerb"
  elseif profession == "MINING" then
    iconKey = "nodeOre"
  end
  return GoldMap:GetIconPath(iconKey, size or 64)
end

function GoldMap.Ids:GetItemName(itemID, fallbackName)
  local itemName = GetItemInfo(itemID)
  if itemName and itemName ~= "" then
    return itemName
  end

  if fallbackName and fallbackName ~= "" then
    return fallbackName
  end

  if C_Item and C_Item.RequestLoadItemDataByID then
    C_Item.RequestLoadItemDataByID(itemID)
  end

  return "Loading item..."
end

function GoldMap.Ids:GetItemLink(itemID, fallbackName, fallbackQuality)
  local itemName, itemLink, itemQuality = GetItemInfo(itemID)
  if itemLink and itemLink ~= "" then
    return itemLink, itemQuality or fallbackQuality
  end

  local displayName = itemName
  if not displayName or displayName == "" then
    displayName = fallbackName
  end

  if not displayName or displayName == "" then
    if C_Item and C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(itemID)
    end
    return "|cff9d9d9dLoading item...|r", fallbackQuality or 1
  end

  local quality = itemQuality or fallbackQuality or 1
  local color = self:GetQualityColor(quality)
  local link = string.format("|c%s|Hitem:%d:0:0:0:0:0:0:0|h[%s]|h|r", color, itemID, displayName)
  return link, quality
end

function GoldMap.Ids:GetNPCIDFromGUID(guid)
  if not guid then
    return nil
  end
  local unitType, _, _, _, _, npcID = strsplit("-", guid)
  if unitType ~= "Creature" and unitType ~= "Vehicle" then
    return nil
  end
  return tonumber(npcID)
end

function GoldMap.Ids:GetZoneKeyForMapIDDirect(mapID)
  local zones = GoldMapData and GoldMapData.Zones
  if not zones then
    return nil
  end

  for zoneKey, zoneData in pairs(zones) do
    if zoneData.uiMapIDs then
      for _, uiMapID in ipairs(zoneData.uiMapIDs) do
        if uiMapID == mapID then
          return zoneKey
        end
      end
    end
  end

  return nil
end

function GoldMap.Ids:GetZoneKeyForMapID(mapID, allowParentLookup)
  if allowParentLookup == false then
    return self:GetZoneKeyForMapIDDirect(mapID)
  end

  local zones = GoldMapData and GoldMapData.Zones
  if not zones then
    return nil
  end

  self.zoneKeyCache = self.zoneKeyCache or {}
  if self.zoneKeyCache[mapID] ~= nil then
    return self.zoneKeyCache[mapID] or nil
  end

  local function FindByMapID(candidateMapID)
    return self:GetZoneKeyForMapIDDirect(candidateMapID)
  end

  local currentMapID = mapID
  for _ = 1, 10 do
    if not currentMapID then
      break
    end

    local zoneKey = FindByMapID(currentMapID)
    if zoneKey then
      self.zoneKeyCache[mapID] = zoneKey
      return zoneKey
    end

    if not C_Map or not C_Map.GetMapInfo then
      break
    end
    local mapInfo = C_Map.GetMapInfo(currentMapID)
    currentMapID = mapInfo and mapInfo.parentMapID or nil
  end

  self.zoneKeyCache[mapID] = false
  return nil
end
