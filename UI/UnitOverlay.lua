local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.UnitOverlay = GoldMap.UnitOverlay or {}

local EVENTS = {
  "PLAYER_TARGET_CHANGED",
  "NAME_PLATE_UNIT_ADDED",
  "NAME_PLATE_UNIT_REMOVED",
  "PLAYER_ENTERING_WORLD",
}

local function ColorForEV(evCopper)
  if not evCopper then
    return 0.6, 0.6, 0.6
  end
  local evGold = evCopper / 10000
  if evGold >= 20 then
    return 0.15, 0.95, 0.2
  elseif evGold >= 5 then
    return 1.0, 0.82, 0.2
  end
  return 1.0, 0.35, 0.2
end

local function FormatGoldShort(copper)
  if not copper then
    return "--"
  end
  return string.format("%.2fg", copper / 10000)
end

local function BuildTargetInfo(eval)
  if not eval then
    return ""
  end

  local evText = FormatGoldShort(eval.evCopper)
  local deltaText = eval.levelDelta and string.format("%+d lvl", eval.levelDelta) or "? lvl"
  local roleText = eval.groupRecommended and "Group" or "Solo"
  local rankText = eval.rankLabel or "Normal"
  local best = eval.bestDrop

  if not best then
    return string.format("GoldMap %s\n%s | %s | %s", evText, roleText, rankText, deltaText)
  end

  local bestChance = tonumber(best.chance) or 0
  return string.format("GoldMap %s\n%s | %s | %s | %.1f%% top", evText, roleText, rankText, deltaText, bestChance)
end

function GoldMap.UnitOverlay:GetEvalForUnit(unit)
  if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then
    return nil
  end

  local evaluator = GoldMap.GetEvaluator and GoldMap:GetEvaluator() or nil
  if not evaluator then
    return nil
  end

  local guid = UnitGUID(unit)
  local npcID = GoldMap.Ids:GetNPCIDFromGUID(guid)
  if not npcID then
    return nil
  end

  return evaluator:EvaluateMobByID(npcID), npcID
end

function GoldMap.UnitOverlay:EnsureTargetIcon()
  if self.targetIcon or not TargetFrame then
    return
  end

  local icon = CreateFrame("Button", "GoldMapTargetIcon", TargetFrame)
  icon:SetSize(18, 18)
  local anchor = TargetFrameTextureFrame or TargetFrame
  icon:SetPoint("LEFT", anchor, "RIGHT", -22, -12)
  icon:SetFrameStrata("HIGH")

  local tex = icon:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture(GoldMap:GetIconPath("pinSelected", 64) or "Interface\\Buttons\\WHITE8X8")
  icon.tex = tex

  local badge = icon:CreateTexture(nil, "OVERLAY")
  badge:SetSize(10, 10)
  badge:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 2, 2)
  badge:SetTexture(GoldMap:GetIconPath("valueHigh", 64) or "Interface\\Buttons\\WHITE8X8")
  icon.badge = badge

  local info = TargetFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  info:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 42, -1)
  info:SetWidth(190)
  info:SetJustifyH("LEFT")
  info:SetJustifyV("TOP")
  info:SetShadowColor(0, 0, 0, 1)
  info:SetShadowOffset(1, -1)
  info:SetTextColor(0.95, 0.9, 0.5)
  info:Hide()
  icon.info = info

  icon:SetScript("OnEnter", function(selfButton)
    if not selfButton.eval then
      return
    end
    GoldMap.PinTooltip:ShowTargetEval(selfButton, selfButton.eval)
  end)

  icon:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  icon:Hide()
  self.targetIcon = icon
end

function GoldMap.UnitOverlay:UpdateTargetIcon()
  self:EnsureTargetIcon()
  if not self.targetIcon then
    return
  end

  local eval = self:GetEvalForUnit("target")
  if not eval then
    self.targetIcon.eval = nil
    if self.targetIcon.info then
      self.targetIcon.info:Hide()
    end
    self.targetIcon:Hide()
    return
  end

  local r, g, b = ColorForEV(eval.evCopper)
  self.targetIcon.tex:SetVertexColor(r, g, b, 1)
  self.targetIcon.badge:SetShown((eval.evCopper or 0) >= 20 * 10000)
  if self.targetIcon.info then
    local infoText = BuildTargetInfo(eval)
    self.targetIcon.info:SetText(infoText)
    self.targetIcon.info:SetTextColor(math.min(1, r + 0.2), math.min(1, g + 0.2), math.min(1, b + 0.2))
    self.targetIcon.info:SetShown(true)
  end
  self.targetIcon.eval = eval
  self.targetIcon:Show()
end

function GoldMap.UnitOverlay:EnsureNameplateIcon(plate)
  if not plate then
    return nil
  end

  if plate.GoldMapIcon then
    return plate.GoldMapIcon
  end

  local icon = plate:CreateTexture(nil, "OVERLAY")
  icon:SetSize(16, 16)
  icon:SetPoint("BOTTOM", plate, "TOP", 0, 4)
  icon:SetTexture(GoldMap:GetIconPath("pinBase", 64) or "Interface\\Buttons\\WHITE8X8")
  icon:Hide()

  local badge = plate:CreateTexture(nil, "OVERLAY")
  badge:SetSize(8, 8)
  badge:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 2, 2)
  badge:SetTexture(GoldMap:GetIconPath("valueHigh", 64) or "Interface\\Buttons\\WHITE8X8")
  badge:Hide()

  local text = plate:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("BOTTOM", icon, "TOP", 0, 2)
  text:SetTextColor(0.95, 0.9, 0.5)
  text:Hide()

  plate.GoldMapIcon = icon
  plate.GoldMapBadge = badge
  plate.GoldMapText = text
  return icon
end

function GoldMap.UnitOverlay:UpdateNameplateForUnit(unit)
  if not unit or not C_NamePlate then
    return
  end

  local plate = C_NamePlate.GetNamePlateForUnit(unit)
  if not plate then
    return
  end

  local icon = self:EnsureNameplateIcon(plate)
  if not icon then
    return
  end

  local eval = self:GetEvalForUnit(unit)
  if not eval then
    icon:Hide()
    if plate.GoldMapBadge then
      plate.GoldMapBadge:Hide()
    end
    if plate.GoldMapText then
      plate.GoldMapText:Hide()
    end
    plate.GoldMapEval = nil
    return
  end

  local r, g, b = ColorForEV(eval.evCopper)
  icon:SetVertexColor(r, g, b, 1)
  icon:Show()
  if plate.GoldMapBadge then
    plate.GoldMapBadge:SetShown((eval.evCopper or 0) >= 20 * 10000)
  end
  if plate.GoldMapText then
    plate.GoldMapText:SetText("GoldMap " .. FormatGoldShort(eval.evCopper))
    plate.GoldMapText:SetShown(true)
  end
  plate.GoldMapEval = eval
end

function GoldMap.UnitOverlay:HideNameplate(unit)
  if not unit or not C_NamePlate then
    return
  end
  local plate = C_NamePlate.GetNamePlateForUnit(unit)
  if not plate then
    return
  end
  if plate.GoldMapIcon then
    plate.GoldMapIcon:Hide()
  end
  if plate.GoldMapBadge then
    plate.GoldMapBadge:Hide()
  end
  if plate.GoldMapText then
    plate.GoldMapText:Hide()
  end
  plate.GoldMapEval = nil
end

function GoldMap.UnitOverlay:RefreshAll()
  self:UpdateTargetIcon()

  if C_NamePlate and C_NamePlate.GetNamePlates then
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
      if plate and plate.namePlateUnitToken then
        self:UpdateNameplateForUnit(plate.namePlateUnitToken)
      end
    end
  end
end

function GoldMap.UnitOverlay:OnEvent(eventName, ...)
  if eventName == "PLAYER_TARGET_CHANGED" then
    self:UpdateTargetIcon()
  elseif eventName == "NAME_PLATE_UNIT_ADDED" then
    local unit = ...
    self:UpdateNameplateForUnit(unit)
  elseif eventName == "NAME_PLATE_UNIT_REMOVED" then
    local unit = ...
    self:HideNameplate(unit)
  elseif eventName == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(1, function()
      self:RefreshAll()
    end)
  end
end

function GoldMap.UnitOverlay:Init()
  if self.initialized then
    return
  end

  self.frame = CreateFrame("Frame")
  self.frame:SetScript("OnEvent", function(_, eventName, ...)
    self:OnEvent(eventName, ...)
  end)

  for _, eventName in ipairs(EVENTS) do
    self.frame:RegisterEvent(eventName)
  end

  GoldMap:RegisterMessage("FILTERS_CHANGED", function()
    self:RefreshAll()
  end)

  GoldMap:RegisterMessage("PRICE_CACHE_UPDATED", function()
    self:RefreshAll()
  end)

  self.initialized = true
end
