local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.MinimapButton = GoldMap.MinimapButton or {}

local function EnsureButtonDefaults()
  GoldMapDB = GoldMapDB or {}
  GoldMapDB.ui = GoldMapDB.ui or {}
  GoldMapDB.ui.minimapButton = GoldMapDB.ui.minimapButton or {
    angle = 210,
    hidden = false,
  }
end

local function UpdateButtonPosition(button)
  local settings = GoldMapDB.ui.minimapButton
  local angle = math.rad(settings.angle or 210)
  local radius = 78
  local x = math.cos(angle) * radius
  local y = math.sin(angle) * radius

  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function GoldMap.MinimapButton:Init()
  if self.button or not Minimap then
    return
  end

  EnsureButtonDefaults()

  local button = CreateFrame("Button", "GoldMapMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetMovable(true)
  button:EnableMouse(true)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(20, 20)
  background:SetPoint("TOPLEFT", 7, -5)
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  button.bg = background

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 7, -5)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetTexture(GoldMap:GetIconPath("pinBase", 64) or "Interface\\Icons\\INV_Misc_Coin_01")
  button.icon = icon

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT", 0, 0)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  button.border = border

  button:SetScript("OnClick", function(_, mouseButton)
    if button.dragging then
      return
    end

    if mouseButton == "RightButton" then
      GoldMap.FilterPanel:ShowPanel()
    else
      GoldMap.Options:Open()
      C_Timer.After(0, function()
        if GoldMap.MinimapButton and GoldMap.MinimapButton.button then
          UpdateButtonPosition(GoldMap.MinimapButton.button)
          GoldMap.MinimapButton:RefreshVisibility()
        end
      end)
    end
  end)

  button:SetScript("OnEnter", function(selfButton)
    GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cffd4af37GoldMap|r")
    GameTooltip:AddLine("Left click: Open settings", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Right click: Open map filters", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Shift + drag: Move button", 0.75, 0.75, 0.75)
    GameTooltip:Show()
  end)

  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  button:SetScript("OnDragStart", function(selfButton)
    if not IsShiftKeyDown() then
      return
    end
    selfButton.dragging = true
    selfButton:SetScript("OnUpdate", function(frame)
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      local x = (cx / scale) - mx
      local y = (cy / scale) - my
      local angle = math.deg(math.atan2(y, x))
      GoldMapDB.ui.minimapButton.angle = angle
      UpdateButtonPosition(frame)
    end)
  end)

  button:SetScript("OnDragStop", function(selfButton)
    selfButton.dragging = false
    selfButton:SetScript("OnUpdate", nil)
  end)

  UpdateButtonPosition(button)
  self.button = button
  self:RefreshVisibility()
end

function GoldMap.MinimapButton:RefreshVisibility()
  if not self.button then
    return
  end
  local hidden = GoldMap.db and GoldMap.db.ui and GoldMap.db.ui.hideMinimapButton
  self.button:SetShown(not hidden)
end
