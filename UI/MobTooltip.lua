local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.MobTooltip = GoldMap.MobTooltip or {}

function GoldMap.MobTooltip:Init()
  if self.initialized then
    return
  end

  GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
    tooltip.goldMapGUID = nil
  end)

  GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
    self:TryInject(tooltip)
  end)

  GoldMap:RegisterMessage("FILTERS_CHANGED", function()
    self:RefreshUnitTooltip()
  end)

  self.initialized = true
end

function GoldMap.MobTooltip:RefreshUnitTooltip()
  if not GameTooltip or not GameTooltip:IsShown() then
    return
  end

  local _, unit = GameTooltip:GetUnit()
  if not unit or not UnitExists(unit) then
    return
  end

  GameTooltip.goldMapGUID = nil
  GameTooltip:SetUnit(unit)
end

function GoldMap.MobTooltip:TryInject(tooltip)
  if self.injecting then
    return
  end

  local _, unit = tooltip:GetUnit()
  if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then
    return
  end

  local guid = UnitGUID(unit)
  if not guid then
    return
  end

  if tooltip.goldMapGUID == guid then
    return
  end

  local npcID = GoldMap.Ids:GetNPCIDFromGUID(guid)
  if not npcID then
    return
  end

  local evaluator = GoldMap.GetEvaluator and GoldMap:GetEvaluator() or nil
  if not evaluator then
    return
  end

  local eval = evaluator:EvaluateMobByID(npcID)
  if not eval then
    return
  end

  self.injecting = true
  local ok, err = pcall(function()
    tooltip:AddLine(" ")
    tooltip:AddLine("|cffd4af37GoldMap|r", 1, 0.85, 0.2)
    GoldMap.PinTooltip:RenderMobInfo(tooltip, eval.mob, eval, {
      showTitle = false,
      maxLines = math.min(5, GoldMap.db.ui.maxTooltipItems),
    })

    tooltip.goldMapGUID = guid
    tooltip:Show()
  end)
  self.injecting = false

  if not ok then
    GoldMap:Debugf("Mob tooltip inject failed: %s", tostring(err))
  end
end
