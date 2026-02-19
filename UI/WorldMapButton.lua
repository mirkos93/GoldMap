local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.WorldMapButton = GoldMap.WorldMapButton or {}

local function TryCreateKrowiButton()
  if not LibStub then
    return nil, false
  end

  local lib = LibStub("Krowi_WorldMapButtons-1.4", true)
  if not lib or not lib.Add then
    return nil, false
  end

  local ok, button = pcall(function()
    return lib:Add(nil, "Button")
  end)
  if not ok or not button then
    return nil, false
  end

  return button, true
end

local function GetWorldMapButtonHost()
  if not WorldMapFrame then
    return nil
  end

  if WorldMapFrame.GetCanvasContainer then
    local canvas = WorldMapFrame:GetCanvasContainer()
    if canvas then
      return canvas
    end
  end

  if WorldMapFrame.ScrollContainer then
    return WorldMapFrame.ScrollContainer
  end

  return WorldMapFrame
end

local function EstimateTopRightStackOffset(host, selfButton)
  if not host then
    return 4
  end

  local scanned = {}
  local nextOffset = 4
  local function ScanChildren(parent)
    if not parent or scanned[parent] then
      return
    end
    scanned[parent] = true

    local children = { parent:GetChildren() }
    for _, child in ipairs(children) do
      if child ~= selfButton and child.IsShown and child:IsShown() and child.GetPoint and child.GetObjectType and child:GetObjectType() == "Button" then
        local point, relativeTo, relativePoint, x, y = child:GetPoint(1)
        if point == "TOPRIGHT" and relativePoint == "TOPRIGHT" and relativeTo == host and type(x) == "number" and type(y) == "number" then
          -- Restrict to the top-right button row (Questie/RareScanner/default map buttons).
          if y >= -12 and y <= 10 then
            local usedOffset = -x
            if usedOffset >= 0 and usedOffset < 2000 then
              nextOffset = math.max(nextOffset, usedOffset + 32)
            end
          end
        end
      end
    end
  end

  ScanChildren(host)
  ScanChildren(WorldMapFrame)
  if WorldMapFrame and WorldMapFrame.ScrollContainer then
    ScanChildren(WorldMapFrame.ScrollContainer)
  end

  return nextOffset
end

function GoldMap.WorldMapButton:Reanchor()
  if self.usingKrowi then
    return
  end

  local button = self.button
  if not button or not WorldMapFrame then
    return
  end

  local host = GetWorldMapButtonHost()
  if not host then
    return
  end

  if button:GetParent() ~= host then
    button:SetParent(host)
  end

  local xOffset = EstimateTopRightStackOffset(host, button)
  button:ClearAllPoints()
  button:SetPoint("TOPRIGHT", host, "TOPRIGHT", -xOffset, -2)
  button:SetFrameStrata("TOOLTIP")
  button:SetFrameLevel(host:GetFrameLevel() + 50)
end

function GoldMap.WorldMapButton:Init()
  if self.button then
    return
  end

  if not WorldMapFrame then
    UIParentLoadAddOn("Blizzard_WorldMap")
  end
  if not WorldMapFrame then
    return
  end

  local button, usingKrowi = TryCreateKrowiButton()
  local host = nil
  if not button then
    host = GetWorldMapButtonHost() or WorldMapFrame
    button = CreateFrame("Button", "GoldMapWorldMapButton", host)
  else
    host = button:GetParent()
  end
  host = host or WorldMapFrame

  button:SetSize(32, 32)
  button:SetFrameStrata("TOOLTIP")
  button:SetFrameLevel(host:GetFrameLevel() + 50)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local ring = button:CreateTexture(nil, "BACKGROUND")
  ring:SetSize(54, 54)
  ring:SetPoint("TOPLEFT", 0, 0)
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  ring:SetTexCoord(0, 1, 0, 1)
  ring:SetVertexColor(0.9, 0.9, 0.9, 1)
  button.ring = ring

  local background = button:CreateTexture(nil, "BORDER")
  background:SetSize(26, 26)
  background:SetPoint("TOPLEFT", 3, -4)
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  button.background = background

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 6, -5)
  icon:SetTexture(GoldMap:GetIconPath("pinBase", 64) or "Interface\\Icons\\INV_Misc_Coin_01")
  button.icon = icon

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      GoldMap.Options:Open()
      return
    end

    if GoldMap.FilterPanel then
      GoldMap.FilterPanel:ShowPanel()
    end
  end)

  button:SetScript("OnEnter", function(selfButton)
    selfButton.ring:SetVertexColor(1, 1, 1, 1)
    selfButton.icon:SetVertexColor(1, 1, 1, 1)
    GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cffd4af37GoldMap|r")
    GameTooltip:AddLine("Left click: Open map filters", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Right click: Open settings", 0.9, 0.9, 0.9)
    GameTooltip:Show()
  end)

  button:SetScript("OnLeave", function(selfButton)
    selfButton.ring:SetVertexColor(0.9, 0.9, 0.9, 1)
    selfButton.icon:SetVertexColor(0.95, 0.95, 0.95, 1)
    GameTooltip:Hide()
  end)

  button.icon:SetVertexColor(0.95, 0.95, 0.95, 1)
  button.Refresh = function()
    if not GoldMap.WorldMapButton.usingKrowi then
      GoldMap.WorldMapButton:Reanchor()
    end
  end
  self.button = button
  self.usingKrowi = usingKrowi and true or false
  button:Show()

  if usingKrowi then
    if WorldMapFrame then
      WorldMapFrame:HookScript("OnShow", function()
        if GoldMap.WorldMapButton and GoldMap.WorldMapButton.button then
          GoldMap.WorldMapButton.button:Show()
        end
      end)
    end
    C_Timer.After(0.1, function()
      if GoldMap.WorldMapButton and GoldMap.WorldMapButton.button then
        GoldMap.WorldMapButton.button:Show()
      end
    end)
    return
  end

  self:Reanchor()

  if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", function()
      GoldMap.WorldMapButton:Reanchor()
      C_Timer.After(0.05, function()
        GoldMap.WorldMapButton:Reanchor()
      end)
    end)
  end

  if WorldMapFrame and WorldMapFrame.RefreshOverlayFrames then
    hooksecurefunc(WorldMapFrame, "RefreshOverlayFrames", function()
      GoldMap.WorldMapButton:Reanchor()
    end)
  end

  C_Timer.After(1.0, function()
    GoldMap.WorldMapButton:Reanchor()
  end)
end
