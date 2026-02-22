local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.Options = GoldMap.Options or {}
local SLIDER_TOP_MARGIN = -24

local function MakeCheckbox(parent, label, tooltip)
  local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  if cb.Text then
    cb.Text:SetText(label)
    cb.Text:SetWidth(420)
    cb.Text:SetJustifyH("LEFT")
  else
    cb.text = cb.text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.text:SetWidth(420)
    cb.text:SetJustifyH("LEFT")
    cb.text:SetText(label)
  end
  cb.tooltipText = tooltip
  return cb
end

local function MakeEditBox(parent, width, numericOnly)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetAutoFocus(false)
  eb:SetSize(width, 24)
  eb:SetNumeric(numericOnly ~= false)
  return eb
end

local function MakeSlider(parent, name, minValue, maxValue, step, width)
  local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider:SetOrientation("HORIZONTAL")
  slider:SetWidth(width or 240)
  return slider
end

local function SetSliderLabels(name, title, low, high)
  if _G[name .. "Text"] then
    _G[name .. "Text"]:SetText(title)
  end
  if _G[name .. "Low"] then
    _G[name .. "Low"]:SetText(low)
  end
  if _G[name .. "High"] then
    _G[name .. "High"]:SetText(high)
  end
end

local function Clamp(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function CreateScrollableSection(parent)
  local section = CreateFrame("Frame", nil, parent)
  section:SetAllPoints(parent)

  local scroll = CreateFrame("ScrollFrame", nil, section, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -28, 4)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  section.scroll = scroll
  section.content = content

  local function RefreshWidth()
    local width = section:GetWidth()
    if width and width > 50 then
      content:SetWidth(width - 36)
    end
  end

  section:SetScript("OnSizeChanged", RefreshWidth)
  section:SetScript("OnShow", RefreshWidth)

  return section
end

function GoldMap.Options:EnsureHelpFrame()
  if self.helpFrame then
    return self.helpFrame
  end

  local frame = CreateFrame("Frame", "GoldMapHelpFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
  frame:SetSize(620, 500)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(130)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(selfFrame)
    selfFrame:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(selfFrame)
    selfFrame:StopMovingOrSizing()
  end)

  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 24,
      edgeSize = 24,
      insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    frame:SetBackdropColor(0.05, 0.06, 0.08, 0.96)
  end

  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 20, -20)
  title:SetText("GoldMap Guide")

  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 20, -52)
  scrollFrame:SetPoint("BOTTOMRIGHT", -42, 52)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(1, 1)
  scrollFrame:SetScrollChild(content)

  local body = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  body:SetPoint("TOPLEFT", 0, 0)
  body:SetWidth(540)
  body:SetJustifyH("LEFT")
  body:SetJustifyV("TOP")
  body:SetText(
    "GoldMap quick guide\n"
      .. "- GoldMap highlights profitable farms on World Map and Minimap.\n"
      .. "- Targets include mob farms plus Herbalism/Mining nodes.\n"
      .. "- Market values come from Auctionator (required).\n\n"
      .. "Setup (first run)\n"
      .. "1. Open Auction House and run an Auctionator scan.\n"
      .. "2. Run /goldmap scan to sync GoldMap with Auctionator data.\n"
      .. "3. Open the World Map filters and pick a preset.\n"
      .. "4. Refine results with Mob / Gathering filter tabs.\n\n"
      .. "Glossary (simple terms)\n"
      .. "- Estimated Gold: expected value per kill or per node, based on chance/yield and market price.\n"
      .. "- Data reliability: how trustworthy the local market sample is (Unknown / Low / Medium / High).\n"
      .. "- Likely to sell: how quickly an item is expected to move (Low / Medium / High).\n"
      .. "- No price yet: item has no usable market sample; value shows as \"--\".\n"
      .. "- Fight type: quick split between Solo-friendly and Group-oriented mob targets.\n"
      .. "- Difficulty: combines mob rank (Normal/Elite/Boss) and your level gap.\n"
      .. "- Narrow mode: target must pass all active filters.\n"
      .. "- Broad mode: target can pass any active filter group.\n\n"
      .. "Color meaning\n"
      .. "- Likely to sell: Low (red), Medium (orange), High (green).\n"
      .. "- Reliability and quality labels also use colored text for quick reading.\n\n"
      .. "Data confidence and stability\n"
      .. "- Run Auctionator scans regularly across different sessions.\n"
      .. "- Older data lowers confidence until refreshed.\n"
      .. "- Outlier guard reduces value spikes from absurd AH listings.\n"
      .. "- GoldMap syncs from Auctionator cache; it does not run AH scans by itself.\n\n"
      .. "Tooltip behavior\n"
      .. "- Tooltips respect your active filters (price, chance, quality, reliability, speed).\n"
      .. "- Hold Shift for advanced diagnostics.\n"
      .. "- Source labels are shown only with Shift + Debug.\n\n"
      .. "Practical tips\n"
      .. "- Use presets for fast setup, then fine-tune in dedicated tabs.\n"
      .. "- Use separate visibility toggles for Mob, Herb, and Ore pins.\n"
      .. "- If data looks stale, run another Auctionator scan and /goldmap scan.\n"
      .. "- Use /goldmap welcome to reopen the onboarding window anytime."
  )

  local textHeight = body:GetStringHeight() or 700
  content:SetHeight(math.max(720, textHeight + 20))

  local okButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  okButton:SetSize(120, 24)
  okButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 16)
  okButton:SetText("Close")
  okButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame:Hide()
  self.helpFrame = frame
  return frame
end

function GoldMap.Options:Init()
  if self.panel then
    return
  end

  local panel = CreateFrame("Frame", "GoldMapOptionsPanel")
  panel.name = "GoldMap"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("GoldMap")

  local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  subtitle:SetText("Settings are split into sections for a cleaner and stable layout.")

  local nav = CreateFrame("Frame", nil, panel)
  nav:SetPoint("TOPLEFT", 16, -84)
  nav:SetPoint("BOTTOMLEFT", 16, 14)
  nav:SetWidth(176)

  local navBg = nav:CreateTexture(nil, "BACKGROUND")
  navBg:SetAllPoints(nav)
  navBg:SetColorTexture(0.05, 0.05, 0.05, 0.35)

  local host = CreateFrame("Frame", nil, panel)
  host:SetPoint("TOPLEFT", nav, "TOPRIGHT", 12, 0)
  host:SetPoint("BOTTOMRIGHT", -16, 14)

  local hostBg = host:CreateTexture(nil, "BACKGROUND")
  hostBg:SetAllPoints(host)
  hostBg:SetColorTexture(0, 0, 0, 0.1)

  local sectionOrder = {
    { key = "general", label = "General" },
    { key = "visibility", label = "Visibility" },
    { key = "map", label = "Map & Minimap" },
    { key = "graphics", label = "Graphics" },
    { key = "tooltip", label = "Tooltip" },
    { key = "scan", label = "Market Data" },
    { key = "help", label = "Help & Reset" },
  }

  local navButtons = {}
  local sections = {}

  local function SetActiveSection(sectionKey)
    for key, section in pairs(sections) do
      section:SetShown(key == sectionKey)
    end
    for key, button in pairs(navButtons) do
      if key == sectionKey then
        button:Disable()
      else
        button:Enable()
      end
    end
    self.activeSection = sectionKey
  end

  for i, def in ipairs(sectionOrder) do
    local button = CreateFrame("Button", nil, nav, "UIPanelButtonTemplate")
    button:SetSize(156, 24)
    button:SetPoint("TOPLEFT", 10, -10 - ((i - 1) * 28))
    button:SetText(def.label)
    button:SetScript("OnClick", function()
      SetActiveSection(def.key)
    end)
    navButtons[def.key] = button

    sections[def.key] = CreateScrollableSection(host)
    sections[def.key]:Hide()
  end

  local general = sections.general.content
  local visibility = sections.visibility.content
  local mapSection = sections.map.content
  local graphicsSection = sections.graphics.content
  local tooltipSection = sections.tooltip.content
  local scanSection = sections.scan.content
  local helpSection = sections.help.content

  local generalTitle = general:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  generalTitle:SetPoint("TOPLEFT", 8, -8)
  generalTitle:SetText("General UI")

  local generalDesc = general:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  generalDesc:SetPoint("TOPLEFT", generalTitle, "BOTTOMLEFT", 0, -8)
  generalDesc:SetWidth(520)
  generalDesc:SetJustifyH("LEFT")
  generalDesc:SetText("Main UI controls and diagnostics. Use the sections on the left to access specific settings.")

  local showPins = MakeCheckbox(general, "Show world map pins", "Toggle GoldMap world map overlays")
  showPins:SetPoint("TOPLEFT", generalDesc, "BOTTOMLEFT", -2, -14)

  local showMinimapPins = MakeCheckbox(general, "Show minimap pins", "Toggle GoldMap minimap overlays")
  showMinimapPins:SetPoint("TOPLEFT", showPins, "BOTTOMLEFT", 0, -8)

  local showMinimapButton = MakeCheckbox(general, "Show minimap settings button", "Display a GoldMap button around the minimap")
  showMinimapButton:SetPoint("TOPLEFT", showMinimapPins, "BOTTOMLEFT", 0, -8)

  local debugMode = MakeCheckbox(general, "Enable GoldMap debug logging", "Print scanner and runtime diagnostics in chat")
  debugMode:SetPoint("TOPLEFT", showMinimapButton, "BOTTOMLEFT", 0, -8)

  local luaDebugLabel = general:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  luaDebugLabel:SetPoint("TOPLEFT", debugMode, "BOTTOMLEFT", 4, -12)
  luaDebugLabel:SetText("Lua debug (global scriptErrors):")

  local luaDebugButton = CreateFrame("Button", nil, general, "UIPanelButtonTemplate")
  luaDebugButton:SetSize(180, 22)
  luaDebugButton:SetPoint("LEFT", luaDebugLabel, "RIGHT", 10, 0)

  local openFiltersButton = CreateFrame("Button", nil, general, "UIPanelButtonTemplate")
  openFiltersButton:SetSize(220, 24)
  openFiltersButton:SetPoint("TOPLEFT", luaDebugLabel, "BOTTOMLEFT", 0, -18)
  openFiltersButton:SetText("Open World Map Filters")
  openFiltersButton:SetScript("OnClick", function()
    ToggleWorldMap()
    if GoldMap.FilterPanel then
      GoldMap.FilterPanel:ShowPanel(true)
    end
  end)

  local openHelpFromGeneralButton = CreateFrame("Button", nil, general, "UIPanelButtonTemplate")
  openHelpFromGeneralButton:SetSize(220, 24)
  openHelpFromGeneralButton:SetPoint("TOPLEFT", openFiltersButton, "BOTTOMLEFT", 0, -8)
  openHelpFromGeneralButton:SetText("Open Help / Glossary")
  openHelpFromGeneralButton:SetScript("OnClick", function()
    local helpFrame = self:EnsureHelpFrame()
    if helpFrame then
      helpFrame:Show()
    end
  end)

  local generalBottom = openHelpFromGeneralButton:GetBottom() or 0
  local generalTop = general:GetTop() or 0
  general:SetHeight(math.max(360, generalTop - generalBottom + 24))

  local visTitle = visibility:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  visTitle:SetPoint("TOPLEFT", 8, -8)
  visTitle:SetText("Visibility Filters")

  local visDesc = visibility:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  visDesc:SetPoint("TOPLEFT", visTitle, "BOTTOMLEFT", 0, -8)
  visDesc:SetWidth(520)
  visDesc:SetJustifyH("LEFT")
  visDesc:SetText("These global toggles impact map, minimap, overlays, and tooltips.")

  local visNote = visibility:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  visNote:SetPoint("TOPLEFT", visDesc, "BOTTOMLEFT", 6, -14)
  visNote:SetWidth(520)
  visNote:SetJustifyH("LEFT")
  visNote:SetText("Use World Map Filters for farm criteria (droprate, EV, item price, reliability, selling speed, no-price targets). Mob targets are always attackable/farmable only.")

  local visibilityBottom = visNote:GetBottom() or 0
  local visibilityTop = visibility:GetTop() or 0
  visibility:SetHeight(math.max(300, visibilityTop - visibilityBottom + 24))

  local mapTitle = mapSection:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  mapTitle:SetPoint("TOPLEFT", 8, -8)
  mapTitle:SetText("Map & Minimap")

  local mapDesc = mapSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  mapDesc:SetPoint("TOPLEFT", mapTitle, "BOTTOMLEFT", 0, -8)
  mapDesc:SetWidth(520)
  mapDesc:SetJustifyH("LEFT")
  mapDesc:SetText("Adjust pin count, minimap range, and icon size. Each setting has both a slider and a numeric input.")

  local maxPinsLabel = mapSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  maxPinsLabel:SetPoint("TOPLEFT", mapDesc, "BOTTOMLEFT", 0, -16)
  maxPinsLabel:SetText("World map pin limit:")
  local maxPinsInput = MakeEditBox(mapSection, 64)
  maxPinsInput:SetPoint("LEFT", maxPinsLabel, "RIGHT", 10, 0)
  local maxPinsSlider = MakeSlider(mapSection, "GoldMapMaxPinsSlider", 100, 15000, 100, 280)
  maxPinsSlider:SetPoint("TOPLEFT", maxPinsLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local minimapPinsLabel = mapSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  minimapPinsLabel:SetPoint("TOPLEFT", maxPinsSlider, "BOTTOMLEFT", 8, -36)
  minimapPinsLabel:SetText("Minimap pin limit:")
  local minimapPinsInput = MakeEditBox(mapSection, 64)
  minimapPinsInput:SetPoint("LEFT", minimapPinsLabel, "RIGHT", 10, 0)
  local minimapPinsSlider = MakeSlider(mapSection, "GoldMapMiniPinsSlider", 10, 300, 1, 280)
  minimapPinsSlider:SetPoint("TOPLEFT", minimapPinsLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local minimapRangeLabel = mapSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  minimapRangeLabel:SetPoint("TOPLEFT", minimapPinsSlider, "BOTTOMLEFT", 8, -36)
  minimapRangeLabel:SetText("Minimap range (% of zone map):")
  local minimapRangeInput = MakeEditBox(mapSection, 64)
  minimapRangeInput:SetPoint("LEFT", minimapRangeLabel, "RIGHT", 10, 0)
  local minimapRangeSlider = MakeSlider(mapSection, "GoldMapMiniRangeSlider", 0.5, 20, 0.1, 280)
  minimapRangeSlider:SetPoint("TOPLEFT", minimapRangeLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local minimapSizeLabel = mapSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  minimapSizeLabel:SetPoint("TOPLEFT", minimapRangeSlider, "BOTTOMLEFT", 8, -36)
  minimapSizeLabel:SetText("Minimap icon size:")
  local minimapSizeInput = MakeEditBox(mapSection, 64)
  minimapSizeInput:SetPoint("LEFT", minimapSizeLabel, "RIGHT", 10, 0)
  local minimapSizeSlider = MakeSlider(mapSection, "GoldMapMiniSizeSlider", 8, 22, 1, 280)
  minimapSizeSlider:SetPoint("TOPLEFT", minimapSizeLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local mapBottom = minimapSizeSlider:GetBottom() or 0
  local mapTop = mapSection:GetTop() or 0
  mapSection:SetHeight(math.max(720, mapTop - mapBottom + 80))

  local graphicsTitle = graphicsSection:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  graphicsTitle:SetPoint("TOPLEFT", 8, -8)
  graphicsTitle:SetText("Graphics")

  local graphicsDesc = graphicsSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  graphicsDesc:SetPoint("TOPLEFT", graphicsTitle, "BOTTOMLEFT", 0, -8)
  graphicsDesc:SetWidth(520)
  graphicsDesc:SetJustifyH("LEFT")
  graphicsDesc:SetText("Tune map readability by reducing pin density per target type.")

  local worldHerbSpaceLabel = graphicsSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  worldHerbSpaceLabel:SetPoint("TOPLEFT", graphicsDesc, "BOTTOMLEFT", 0, -16)
  worldHerbSpaceLabel:SetText("World map herb pin spacing (px):")
  local worldHerbSpaceInput = MakeEditBox(graphicsSection, 64)
  worldHerbSpaceInput:SetPoint("LEFT", worldHerbSpaceLabel, "RIGHT", 10, 0)
  local worldHerbSpaceSlider = MakeSlider(graphicsSection, "GoldMapWorldHerbSpacingSlider", 8, 64, 1, 280)
  worldHerbSpaceSlider:SetPoint("TOPLEFT", worldHerbSpaceLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local worldOreSpaceLabel = graphicsSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  worldOreSpaceLabel:SetPoint("TOPLEFT", worldHerbSpaceSlider, "BOTTOMLEFT", 8, -36)
  worldOreSpaceLabel:SetText("World map ore pin spacing (px):")
  local worldOreSpaceInput = MakeEditBox(graphicsSection, 64)
  worldOreSpaceInput:SetPoint("LEFT", worldOreSpaceLabel, "RIGHT", 10, 0)
  local worldOreSpaceSlider = MakeSlider(graphicsSection, "GoldMapWorldOreSpacingSlider", 8, 64, 1, 280)
  worldOreSpaceSlider:SetPoint("TOPLEFT", worldOreSpaceLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local worldMobSpaceLabel = graphicsSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  worldMobSpaceLabel:SetPoint("TOPLEFT", worldOreSpaceSlider, "BOTTOMLEFT", 8, -36)
  worldMobSpaceLabel:SetText("World map mob pin spacing (px):")
  local worldMobSpaceInput = MakeEditBox(graphicsSection, 64)
  worldMobSpaceInput:SetPoint("LEFT", worldMobSpaceLabel, "RIGHT", 10, 0)
  local worldMobSpaceSlider = MakeSlider(graphicsSection, "GoldMapWorldMobSpacingSlider", 8, 64, 1, 280)
  worldMobSpaceSlider:SetPoint("TOPLEFT", worldMobSpaceLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local miniHerbSpaceLabel = graphicsSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  miniHerbSpaceLabel:SetPoint("TOPLEFT", worldMobSpaceSlider, "BOTTOMLEFT", 8, -36)
  miniHerbSpaceLabel:SetText("Minimap herb pin spacing (px):")
  local miniHerbSpaceInput = MakeEditBox(graphicsSection, 64)
  miniHerbSpaceInput:SetPoint("LEFT", miniHerbSpaceLabel, "RIGHT", 10, 0)
  local miniHerbSpaceSlider = MakeSlider(graphicsSection, "GoldMapMiniHerbSpacingSlider", 6, 40, 1, 280)
  miniHerbSpaceSlider:SetPoint("TOPLEFT", miniHerbSpaceLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local miniOreSpaceLabel = graphicsSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  miniOreSpaceLabel:SetPoint("TOPLEFT", miniHerbSpaceSlider, "BOTTOMLEFT", 8, -36)
  miniOreSpaceLabel:SetText("Minimap ore pin spacing (px):")
  local miniOreSpaceInput = MakeEditBox(graphicsSection, 64)
  miniOreSpaceInput:SetPoint("LEFT", miniOreSpaceLabel, "RIGHT", 10, 0)
  local miniOreSpaceSlider = MakeSlider(graphicsSection, "GoldMapMiniOreSpacingSlider", 6, 40, 1, 280)
  miniOreSpaceSlider:SetPoint("TOPLEFT", miniOreSpaceLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local miniMobSpaceLabel = graphicsSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  miniMobSpaceLabel:SetPoint("TOPLEFT", miniOreSpaceSlider, "BOTTOMLEFT", 8, -36)
  miniMobSpaceLabel:SetText("Minimap mob pin spacing (px):")
  local miniMobSpaceInput = MakeEditBox(graphicsSection, 64)
  miniMobSpaceInput:SetPoint("LEFT", miniMobSpaceLabel, "RIGHT", 10, 0)
  local miniMobSpaceSlider = MakeSlider(graphicsSection, "GoldMapMiniMobSpacingSlider", 6, 40, 1, 280)
  miniMobSpaceSlider:SetPoint("TOPLEFT", miniMobSpaceLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local resetGraphicsButton = CreateFrame("Button", nil, graphicsSection, "UIPanelButtonTemplate")
  resetGraphicsButton:SetSize(240, 24)
  resetGraphicsButton:SetPoint("TOPLEFT", miniMobSpaceSlider, "BOTTOMLEFT", 8, -28)
  resetGraphicsButton:SetText("Reset Graphics to Defaults")

  local graphicsBottom = resetGraphicsButton:GetBottom() or 0
  local graphicsTop = graphicsSection:GetTop() or 0
  graphicsSection:SetHeight(math.max(940, graphicsTop - graphicsBottom + 64))

  local tooltipTitle = tooltipSection:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  tooltipTitle:SetPoint("TOPLEFT", 8, -8)
  tooltipTitle:SetText("Tooltip Settings")

  local tooltipDesc = tooltipSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  tooltipDesc:SetPoint("TOPLEFT", tooltipTitle, "BOTTOMLEFT", 0, -8)
  tooltipDesc:SetWidth(520)
  tooltipDesc:SetJustifyH("LEFT")
  tooltipDesc:SetText("Tooltip content always follows active filters. Use this section to control how many drops are shown per mob.")

  local maxTooltipLabel = tooltipSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  maxTooltipLabel:SetPoint("TOPLEFT", tooltipDesc, "BOTTOMLEFT", 0, -16)
  maxTooltipLabel:SetText("Max tooltip drops:")

  local maxTooltipInput = MakeEditBox(tooltipSection, 64)
  maxTooltipInput:SetPoint("LEFT", maxTooltipLabel, "RIGHT", 10, 0)

  local maxTooltipSlider = MakeSlider(tooltipSection, "GoldMapTooltipLinesSlider", 1, 20, 1, 280)
  maxTooltipSlider:SetPoint("TOPLEFT", maxTooltipLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local showItemTooltipSignals = MakeCheckbox(
    tooltipSection,
    "Show GoldMap market signals in item tooltips",
    "Adds price, likely-to-sell, and reliability lines on item tooltips (bags, AH, links)"
  )
  showItemTooltipSignals:SetPoint("TOPLEFT", maxTooltipSlider, "BOTTOMLEFT", 0, -12)

  local tooltipBottom = showItemTooltipSignals:GetBottom() or 0
  local tooltipTop = tooltipSection:GetTop() or 0
  tooltipSection:SetHeight(math.max(360, tooltipTop - tooltipBottom + 48))

  local scanTitle = scanSection:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  scanTitle:SetPoint("TOPLEFT", 8, -8)
  scanTitle:SetText("Auctionator Sync")

  local scanDesc = scanSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  scanDesc:SetPoint("TOPLEFT", scanTitle, "BOTTOMLEFT", 0, -8)
  scanDesc:SetWidth(520)
  scanDesc:SetJustifyH("LEFT")
  scanDesc:SetText(
    "GoldMap no longer runs its own Auction House scanner. It reads market data from Auctionator and syncs tracked items into GoldMap."
  )

  local dataSourceLabel = scanSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  dataSourceLabel:SetPoint("TOPLEFT", scanDesc, "BOTTOMLEFT", 0, -14)
  dataSourceLabel:SetText("Data source: |cff33ff99Auctionator (required)|r")

  local queryDelayLabel = scanSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  queryDelayLabel:SetPoint("TOPLEFT", dataSourceLabel, "BOTTOMLEFT", 0, -18)
  queryDelayLabel:SetText("Max Auctionator data age (days):")
  local queryDelayInput = MakeEditBox(scanSection, 64, false)
  queryDelayInput:SetPoint("LEFT", queryDelayLabel, "RIGHT", 10, 0)
  local queryDelaySlider = MakeSlider(scanSection, "GoldMapQueryDelaySlider", 0, 14, 1, 280)
  queryDelaySlider:SetPoint("TOPLEFT", queryDelayLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local advisorEnabled = MakeCheckbox(scanSection, "Enable market freshness advisor notifications", "Suggests when it's a good time to run an AH scan")
  advisorEnabled:SetPoint("TOPLEFT", queryDelaySlider, "BOTTOMLEFT", 0, -8)

  local advisorIntervalLabel = scanSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  advisorIntervalLabel:SetPoint("TOPLEFT", advisorEnabled, "BOTTOMLEFT", 6, -18)
  advisorIntervalLabel:SetText("Advisor check interval (minutes):")
  local advisorIntervalInput = MakeEditBox(scanSection, 64, false)
  advisorIntervalInput:SetPoint("LEFT", advisorIntervalLabel, "RIGHT", 10, 0)
  local advisorIntervalSlider = MakeSlider(scanSection, "GoldMapAdvisorIntervalSlider", 2, 60, 1, 280)
  advisorIntervalSlider:SetPoint("TOPLEFT", advisorIntervalLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local advisorCooldownLabel = scanSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  advisorCooldownLabel:SetPoint("TOPLEFT", advisorIntervalSlider, "BOTTOMLEFT", 8, -36)
  advisorCooldownLabel:SetText("Advisor notification cooldown (minutes):")
  local advisorCooldownInput = MakeEditBox(scanSection, 64, false)
  advisorCooldownInput:SetPoint("LEFT", advisorCooldownLabel, "RIGHT", 10, 0)
  local advisorCooldownSlider = MakeSlider(scanSection, "GoldMapAdvisorCooldownSlider", 5, 180, 5, 280)
  advisorCooldownSlider:SetPoint("TOPLEFT", advisorCooldownLabel, "BOTTOMLEFT", -8, SLIDER_TOP_MARGIN)

  local syncNowButton = CreateFrame("Button", nil, scanSection, "UIPanelButtonTemplate")
  syncNowButton:SetSize(220, 24)
  syncNowButton:SetPoint("TOPLEFT", advisorCooldownSlider, "BOTTOMLEFT", 8, -26)
  syncNowButton:SetText("Sync From Auctionator Now")

  local scanHint = scanSection:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  scanHint:SetPoint("TOPLEFT", syncNowButton, "BOTTOMLEFT", 0, -14)
  scanHint:SetWidth(520)
  scanHint:SetJustifyH("LEFT")
  scanHint:SetText("How to keep data fresh: run Auctionator scans regularly, then use /goldmap scan to sync. Advisor warns when stale/missing market coverage suggests another AH visit.")

  local marketStatus = scanSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  marketStatus:SetPoint("TOPLEFT", scanHint, "BOTTOMLEFT", 0, -14)
  marketStatus:SetWidth(520)
  marketStatus:SetJustifyH("LEFT")
  marketStatus:SetJustifyV("TOP")
  marketStatus:SetText("Status: waiting for Auctionator integration details...")

  local scanBottom = marketStatus:GetBottom() or 0
  local scanTop = scanSection:GetTop() or 0
  scanSection:SetHeight(math.max(620, scanTop - scanBottom + 48))

  local helpTitle = helpSection:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  helpTitle:SetPoint("TOPLEFT", 8, -8)
  helpTitle:SetText("Help, Glossary, and Reset")

  local helpDesc = helpSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  helpDesc:SetPoint("TOPLEFT", helpTitle, "BOTTOMLEFT", 0, -8)
  helpDesc:SetWidth(520)
  helpDesc:SetJustifyH("LEFT")
  helpDesc:SetText("Open the GoldMap glossary and manage first-run onboarding.")

  local openGuideButton = CreateFrame("Button", nil, helpSection, "UIPanelButtonTemplate")
  openGuideButton:SetSize(220, 24)
  openGuideButton:SetPoint("TOPLEFT", helpDesc, "BOTTOMLEFT", 0, -14)
  openGuideButton:SetText("Open Help / Glossary")
  openGuideButton:SetScript("OnClick", function()
    local helpFrame = self:EnsureHelpFrame()
    if helpFrame then
      helpFrame:Show()
    end
  end)

  local welcomeResetButton = CreateFrame("Button", nil, helpSection, "UIPanelButtonTemplate")
  welcomeResetButton:SetSize(220, 24)
  welcomeResetButton:SetPoint("TOPLEFT", openGuideButton, "BOTTOMLEFT", 0, -8)
  welcomeResetButton:SetText("Show Welcome Again")
  welcomeResetButton:SetScript("OnClick", function()
    GoldMapDB = GoldMapDB or {}
    GoldMapDB.meta = GoldMapDB.meta or {}
    GoldMapDB.meta.welcomeSeen = false
    if GoldMap.Welcome and GoldMap.Welcome.Show then
      GoldMap.Welcome:Show(true)
    end
  end)

  local helpBottom = welcomeResetButton:GetBottom() or 0
  local helpTop = helpSection:GetTop() or 0
  helpSection:SetHeight(math.max(300, helpTop - helpBottom + 48))

  local syncingControls = false

  local function RefreshMarketStatus()
    if not marketStatus then
      return
    end

    local scanner = GoldMap.Scanner
    if not scanner or type(scanner.GetAuctionatorIntegrationState) ~= "function" then
      marketStatus:SetText("Status: scanner unavailable.")
      return
    end

    local state = scanner:GetAuctionatorIntegrationState()
    local lines = {}
    lines[#lines + 1] = string.format(
      "Status: API %s  |  DB hook %s  |  Tracked items %d",
      state.auctionatorAvailable and "|cff33ff33OK|r" or "|cffff6666Missing|r",
      state.dbUpdateHooked and "|cff33ff33ON|r" or "|cffffcc00OFF|r",
      tonumber(state.trackedItems) or 0
    )

    local since = GoldMap:GetSecondsSinceLastScan()
    lines[#lines + 1] = "Last GoldMap sync: " .. GoldMap:FormatAge(since)

    local lastStats = state.lastStats
    if lastStats then
      lines[#lines + 1] = string.format(
        "Last sync result: imported %d/%d, priced %d, too old %d, errors %d",
        tonumber(lastStats.imported) or 0,
        tonumber(lastStats.requested) or 0,
        tonumber(lastStats.priced) or 0,
        tonumber(lastStats.tooOld) or 0,
        tonumber(lastStats.errors) or 0
      )
    end

    if GoldMap.ScanAdvisor and type(GoldMap.ScanAdvisor.GetLastReport) == "function" then
      local report = GoldMap.ScanAdvisor:GetLastReport()
      if not report and type(GoldMap.ScanAdvisor.RefreshReport) == "function" then
        report = GoldMap.ScanAdvisor:RefreshReport()
      end
      if report then
        lines[#lines + 1] = string.format(
          "Advisor: |c%s%s|r  |  Missing %s  |  Stale>24h %s",
          report.colorCode or "ff33ff66",
          report.label or "GREEN",
          string.format("%.0f%%", (tonumber(report.missingRatio) or 0) * 100),
          string.format("%.0f%%", (tonumber(report.stale24hRatio) or 0) * 100)
        )
      end
    end

    marketStatus:SetText(table.concat(lines, "\n"))
  end

  local function RefreshLuaDebugButton()
    local enabled = GoldMap:IsLuaDebugEnabled()
    luaDebugButton:SetText(enabled and "Disable Lua Debug" or "Enable Lua Debug")
    luaDebugLabel:SetText(string.format("Lua debug (global scriptErrors): %s", enabled and "|cff33ff33ON|r" or "|cffff6666OFF|r"))
  end

  local function SyncControlsFromDB()
    syncingControls = true

    showPins:SetChecked(GoldMap.db.ui.showPins)
    showMinimapPins:SetChecked(GoldMap.db.ui.showMinimapPins)
    showMinimapButton:SetChecked(not GoldMap.db.ui.hideMinimapButton)
    showItemTooltipSignals:SetChecked(GoldMap.db.ui.showItemTooltipMarket ~= false)
    advisorEnabled:SetChecked(GoldMap.db.scanner.scanAdvisorEnabled ~= false)
    debugMode:SetChecked(GoldMap:IsDebugEnabled())

    maxPinsInput:SetNumber(GoldMap.db.ui.maxVisiblePins)
    minimapPinsInput:SetNumber(GoldMap.db.ui.minimapMaxPins)
    minimapRangeInput:SetNumber((GoldMap.db.ui.minimapRange or GoldMap.defaults.ui.minimapRange) * 100)
    minimapSizeInput:SetNumber(GoldMap.db.ui.minimapIconSize)
    maxTooltipInput:SetNumber(GoldMap.db.ui.maxTooltipItems)
    worldHerbSpaceInput:SetNumber(GoldMap.db.ui.worldHerbPinSpacing or GoldMap.defaults.ui.worldHerbPinSpacing or 28)
    worldOreSpaceInput:SetNumber(GoldMap.db.ui.worldOrePinSpacing or GoldMap.defaults.ui.worldOrePinSpacing or 22)
    worldMobSpaceInput:SetNumber(GoldMap.db.ui.worldMobPinSpacing or GoldMap.defaults.ui.worldMobPinSpacing or 16)
    miniHerbSpaceInput:SetNumber(GoldMap.db.ui.minimapHerbPinSpacing or GoldMap.defaults.ui.minimapHerbPinSpacing or 18)
    miniOreSpaceInput:SetNumber(GoldMap.db.ui.minimapOrePinSpacing or GoldMap.defaults.ui.minimapOrePinSpacing or 14)
    miniMobSpaceInput:SetNumber(GoldMap.db.ui.minimapMobPinSpacing or GoldMap.defaults.ui.minimapMobPinSpacing or 12)
    queryDelayInput:SetText(tostring(math.floor((GoldMap.db.scanner.auctionatorMaxAgeDays or GoldMap.defaults.scanner.auctionatorMaxAgeDays or 7) + 0.5)))
    advisorIntervalInput:SetText(tostring(math.floor((GoldMap.db.scanner.advisorIntervalMinutes or GoldMap.defaults.scanner.advisorIntervalMinutes or 10) + 0.5)))
    advisorCooldownInput:SetText(tostring(math.floor((GoldMap.db.scanner.advisorNotifyCooldownMinutes or GoldMap.defaults.scanner.advisorNotifyCooldownMinutes or 45) + 0.5)))

    maxPinsSlider:SetValue(GoldMap.db.ui.maxVisiblePins)
    minimapPinsSlider:SetValue(GoldMap.db.ui.minimapMaxPins)
    minimapRangeSlider:SetValue((GoldMap.db.ui.minimapRange or GoldMap.defaults.ui.minimapRange) * 100)
    minimapSizeSlider:SetValue(GoldMap.db.ui.minimapIconSize)
    maxTooltipSlider:SetValue(GoldMap.db.ui.maxTooltipItems)
    worldHerbSpaceSlider:SetValue(GoldMap.db.ui.worldHerbPinSpacing or GoldMap.defaults.ui.worldHerbPinSpacing or 28)
    worldOreSpaceSlider:SetValue(GoldMap.db.ui.worldOrePinSpacing or GoldMap.defaults.ui.worldOrePinSpacing or 22)
    worldMobSpaceSlider:SetValue(GoldMap.db.ui.worldMobPinSpacing or GoldMap.defaults.ui.worldMobPinSpacing or 16)
    miniHerbSpaceSlider:SetValue(GoldMap.db.ui.minimapHerbPinSpacing or GoldMap.defaults.ui.minimapHerbPinSpacing or 18)
    miniOreSpaceSlider:SetValue(GoldMap.db.ui.minimapOrePinSpacing or GoldMap.defaults.ui.minimapOrePinSpacing or 14)
    miniMobSpaceSlider:SetValue(GoldMap.db.ui.minimapMobPinSpacing or GoldMap.defaults.ui.minimapMobPinSpacing or 12)
    queryDelaySlider:SetValue(GoldMap.db.scanner.auctionatorMaxAgeDays or GoldMap.defaults.scanner.auctionatorMaxAgeDays or 7)
    advisorIntervalSlider:SetValue(GoldMap.db.scanner.advisorIntervalMinutes or GoldMap.defaults.scanner.advisorIntervalMinutes or 10)
    advisorCooldownSlider:SetValue(GoldMap.db.scanner.advisorNotifyCooldownMinutes or GoldMap.defaults.scanner.advisorNotifyCooldownMinutes or 45)

    RefreshMarketStatus()
    RefreshLuaDebugButton()
    syncingControls = false
  end

  local function RefreshSliderCaptions()
    SetSliderLabels("GoldMapMaxPinsSlider", "World Map Pin Limit", "100", "15000")
    SetSliderLabels("GoldMapMiniPinsSlider", "Minimap Pin Limit", "10", "300")
    SetSliderLabels("GoldMapMiniRangeSlider", "Minimap Range", "0.5%", "20%")
    SetSliderLabels("GoldMapMiniSizeSlider", "Minimap Icon Size", "8", "22")
    SetSliderLabels("GoldMapWorldHerbSpacingSlider", "World Herb Spacing", "8", "64")
    SetSliderLabels("GoldMapWorldOreSpacingSlider", "World Ore Spacing", "8", "64")
    SetSliderLabels("GoldMapWorldMobSpacingSlider", "World Mob Spacing", "8", "64")
    SetSliderLabels("GoldMapMiniHerbSpacingSlider", "Minimap Herb Spacing", "6", "40")
    SetSliderLabels("GoldMapMiniOreSpacingSlider", "Minimap Ore Spacing", "6", "40")
    SetSliderLabels("GoldMapMiniMobSpacingSlider", "Minimap Mob Spacing", "6", "40")
    SetSliderLabels("GoldMapTooltipLinesSlider", "Max Tooltip Drops", "1", "20")
    SetSliderLabels("GoldMapQueryDelaySlider", "Auctionator Max Age (days)", "0", "14")
    SetSliderLabels("GoldMapAdvisorIntervalSlider", "Advisor Check Interval (min)", "2", "60")
    SetSliderLabels("GoldMapAdvisorCooldownSlider", "Advisor Notification Cooldown (min)", "5", "180")
  end

  panel:SetScript("OnShow", function()
    SyncControlsFromDB()
    RefreshSliderCaptions()
    SetActiveSection(self.activeSection or "general")
  end)

  showPins:SetScript("OnClick", function(selfButton)
    GoldMap.db.ui.showPins = selfButton:GetChecked() and true or false
    GoldMap:NotifyFiltersChanged()
  end)

  showMinimapPins:SetScript("OnClick", function(selfButton)
    GoldMap.db.ui.showMinimapPins = selfButton:GetChecked() and true or false
    GoldMap:NotifyFiltersChanged()
  end)

  showMinimapButton:SetScript("OnClick", function(selfButton)
    GoldMap.db.ui.hideMinimapButton = not selfButton:GetChecked()
    if GoldMap.MinimapButton then
      GoldMap.MinimapButton:RefreshVisibility()
    end
  end)

  showItemTooltipSignals:SetScript("OnClick", function(selfButton)
    GoldMap.db.ui.showItemTooltipMarket = selfButton:GetChecked() and true or false
    if GoldMap.ItemTooltip and GameTooltip then
      GoldMap.ItemTooltip:ClearMarker(GameTooltip)
      if GameTooltip:IsShown() and GoldMap.db.ui.showItemTooltipMarket ~= false then
        GoldMap.ItemTooltip:TryInject(GameTooltip)
      end
    end
  end)

  advisorEnabled:SetScript("OnClick", function(selfButton)
    GoldMap.db.scanner.scanAdvisorEnabled = selfButton:GetChecked() and true or false
    if GoldMap.ScanAdvisor and GoldMap.ScanAdvisor.RestartTickerIfNeeded then
      GoldMap.ScanAdvisor:RestartTickerIfNeeded()
      GoldMap.ScanAdvisor:CheckNow(false)
    end
    SyncControlsFromDB()
  end)

  debugMode:SetScript("OnClick", function(selfButton)
    GoldMap:SetDebugEnabled(selfButton:GetChecked())
  end)

  luaDebugButton:SetScript("OnClick", function()
    GoldMap:SetLuaDebugEnabled(not GoldMap:IsLuaDebugEnabled())
    RefreshLuaDebugButton()
    if GoldMap:IsLuaDebugEnabled() then
      GoldMap:Printf("Lua debug enabled (global): errors from all addons will be shown.")
    else
      GoldMap:Printf("Lua debug disabled.")
    end
  end)

  maxPinsInput:SetScript("OnEnterPressed", function(selfBox)
    local value = tonumber(selfBox:GetText()) or GoldMap.defaults.ui.maxVisiblePins
    value = Clamp(math.floor(value), 100, 15000)
    GoldMap.db.ui.maxVisiblePins = value
    SyncControlsFromDB()
    selfBox:ClearFocus()
    GoldMap:NotifyFiltersChanged()
  end)

  minimapPinsInput:SetScript("OnEnterPressed", function(selfBox)
    local value = tonumber(selfBox:GetText()) or GoldMap.defaults.ui.minimapMaxPins
    value = Clamp(math.floor(value), 10, 300)
    GoldMap.db.ui.minimapMaxPins = value
    SyncControlsFromDB()
    selfBox:ClearFocus()
    GoldMap:NotifyFiltersChanged()
  end)

  minimapRangeInput:SetScript("OnEnterPressed", function(selfBox)
    local percent = tonumber(selfBox:GetText()) or (GoldMap.defaults.ui.minimapRange * 100)
    percent = Clamp(percent, 0.5, 20)
    GoldMap.db.ui.minimapRange = percent / 100
    SyncControlsFromDB()
    selfBox:ClearFocus()
    GoldMap:NotifyFiltersChanged()
  end)

  minimapSizeInput:SetScript("OnEnterPressed", function(selfBox)
    local value = tonumber(selfBox:GetText()) or GoldMap.defaults.ui.minimapIconSize
    value = Clamp(math.floor(value), 8, 22)
    GoldMap.db.ui.minimapIconSize = value
    SyncControlsFromDB()
    selfBox:ClearFocus()
    GoldMap:NotifyFiltersChanged()
  end)

  maxTooltipInput:SetScript("OnEnterPressed", function(selfBox)
    local value = tonumber(selfBox:GetText()) or GoldMap.defaults.ui.maxTooltipItems
    value = Clamp(math.floor(value), 1, 20)
    GoldMap.db.ui.maxTooltipItems = value
    SyncControlsFromDB()
    selfBox:ClearFocus()
    GoldMap:NotifyFiltersChanged()
  end)

  worldHerbSpaceInput:SetScript("OnEnterPressed", function(selfBox)
    local value = tonumber(selfBox:GetText()) or (GoldMap.defaults.ui.worldHerbPinSpacing or 28)
    value = Clamp(math.floor(value + 0.5), 8, 64)
    GoldMap.db.ui.worldHerbPinSpacing = value
    SyncControlsFromDB()
    selfBox:ClearFocus()
    GoldMap:NotifyFiltersChanged()
  end)

  worldOreSpaceInput:SetScript("OnEnterPressed", function(selfBox)
    local value = tonumber(selfBox:GetText()) or (GoldMap.defaults.ui.worldOrePinSpacing or 22)
    value = Clamp(math.floor(value + 0.5), 8, 64)
    GoldMap.db.ui.worldOrePinSpacing = value
    SyncControlsFromDB()
    selfBox:ClearFocus()
    GoldMap:NotifyFiltersChanged()
  end)

  worldMobSpaceInput:SetScript("OnEnterPressed", function(selfBox)
    local value = tonumber(selfBox:GetText()) or (GoldMap.defaults.ui.worldMobPinSpacing or 16)
    value = Clamp(math.floor(value + 0.5), 8, 64)
    GoldMap.db.ui.worldMobPinSpacing = value
    SyncControlsFromDB()
    selfBox:ClearFocus()
    GoldMap:NotifyFiltersChanged()
  end)

  miniHerbSpaceInput:SetScript("OnEnterPressed", function(selfBox)
    local value = tonumber(selfBox:GetText()) or (GoldMap.defaults.ui.minimapHerbPinSpacing or 18)
    value = Clamp(math.floor(value + 0.5), 6, 40)
    GoldMap.db.ui.minimapHerbPinSpacing = value
    SyncControlsFromDB()
    selfBox:ClearFocus()
    GoldMap:NotifyFiltersChanged()
  end)

  miniOreSpaceInput:SetScript("OnEnterPressed", function(selfBox)
    local value = tonumber(selfBox:GetText()) or (GoldMap.defaults.ui.minimapOrePinSpacing or 14)
    value = Clamp(math.floor(value + 0.5), 6, 40)
    GoldMap.db.ui.minimapOrePinSpacing = value
    SyncControlsFromDB()
    selfBox:ClearFocus()
    GoldMap:NotifyFiltersChanged()
  end)

  miniMobSpaceInput:SetScript("OnEnterPressed", function(selfBox)
    local value = tonumber(selfBox:GetText()) or (GoldMap.defaults.ui.minimapMobPinSpacing or 12)
    value = Clamp(math.floor(value + 0.5), 6, 40)
    GoldMap.db.ui.minimapMobPinSpacing = value
    SyncControlsFromDB()
    selfBox:ClearFocus()
    GoldMap:NotifyFiltersChanged()
  end)

  queryDelayInput:SetScript("OnEnterPressed", function(selfBox)
    local days = tonumber(selfBox:GetText()) or (GoldMap.defaults.scanner.auctionatorMaxAgeDays or 7)
    days = Clamp(math.floor(days + 0.5), 0, 14)
    GoldMap.db.scanner.auctionatorMaxAgeDays = days
    SyncControlsFromDB()
    selfBox:ClearFocus()
  end)

  advisorIntervalInput:SetScript("OnEnterPressed", function(selfBox)
    local minutes = tonumber(selfBox:GetText()) or (GoldMap.defaults.scanner.advisorIntervalMinutes or 10)
    minutes = Clamp(math.floor(minutes + 0.5), 2, 60)
    GoldMap.db.scanner.advisorIntervalMinutes = minutes
    if GoldMap.ScanAdvisor and GoldMap.ScanAdvisor.RestartTickerIfNeeded then
      GoldMap.ScanAdvisor:RestartTickerIfNeeded()
    end
    SyncControlsFromDB()
    selfBox:ClearFocus()
  end)

  advisorCooldownInput:SetScript("OnEnterPressed", function(selfBox)
    local minutes = tonumber(selfBox:GetText()) or (GoldMap.defaults.scanner.advisorNotifyCooldownMinutes or 45)
    minutes = Clamp(math.floor(minutes + 0.5), 5, 180)
    GoldMap.db.scanner.advisorNotifyCooldownMinutes = minutes
    SyncControlsFromDB()
    selfBox:ClearFocus()
  end)

  maxPinsSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.ui.maxVisiblePins = math.floor(value + 0.5)
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  minimapPinsSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.ui.minimapMaxPins = math.floor(value + 0.5)
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  minimapRangeSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.ui.minimapRange = value / 100
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  minimapSizeSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.ui.minimapIconSize = math.floor(value + 0.5)
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  maxTooltipSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.ui.maxTooltipItems = math.floor(value + 0.5)
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  worldHerbSpaceSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.ui.worldHerbPinSpacing = Clamp(math.floor(value + 0.5), 8, 64)
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  worldOreSpaceSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.ui.worldOrePinSpacing = Clamp(math.floor(value + 0.5), 8, 64)
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  worldMobSpaceSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.ui.worldMobPinSpacing = Clamp(math.floor(value + 0.5), 8, 64)
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  miniHerbSpaceSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.ui.minimapHerbPinSpacing = Clamp(math.floor(value + 0.5), 6, 40)
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  miniOreSpaceSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.ui.minimapOrePinSpacing = Clamp(math.floor(value + 0.5), 6, 40)
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  miniMobSpaceSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.ui.minimapMobPinSpacing = Clamp(math.floor(value + 0.5), 6, 40)
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  queryDelaySlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.scanner.auctionatorMaxAgeDays = Clamp(math.floor(value + 0.5), 0, 14)
    SyncControlsFromDB()
  end)

  advisorIntervalSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.scanner.advisorIntervalMinutes = Clamp(math.floor(value + 0.5), 2, 60)
    if GoldMap.ScanAdvisor and GoldMap.ScanAdvisor.RestartTickerIfNeeded then
      GoldMap.ScanAdvisor:RestartTickerIfNeeded()
    end
    SyncControlsFromDB()
  end)

  advisorCooldownSlider:SetScript("OnValueChanged", function(_, value)
    if syncingControls then
      return
    end
    GoldMap.db.scanner.advisorNotifyCooldownMinutes = Clamp(math.floor(value + 0.5), 5, 180)
    SyncControlsFromDB()
  end)

  syncNowButton:SetScript("OnClick", function()
    if GoldMap.Scanner and GoldMap.Scanner.StartSeedScan then
      GoldMap.Scanner:StartSeedScan(true)
      C_Timer.After(0.15, RefreshMarketStatus)
    else
      GoldMap:Printf("Scanner module unavailable.")
    end
  end)

  local function ResetGraphicsDefaults()
    local defaults = GoldMap.defaults and GoldMap.defaults.ui or {}
    GoldMap.db.ui.worldMobPinSpacing = defaults.worldMobPinSpacing
    GoldMap.db.ui.worldHerbPinSpacing = defaults.worldHerbPinSpacing
    GoldMap.db.ui.worldOrePinSpacing = defaults.worldOrePinSpacing
    GoldMap.db.ui.minimapMobPinSpacing = defaults.minimapMobPinSpacing
    GoldMap.db.ui.minimapHerbPinSpacing = defaults.minimapHerbPinSpacing
    GoldMap.db.ui.minimapOrePinSpacing = defaults.minimapOrePinSpacing
    SyncControlsFromDB()
    GoldMap:NotifyFiltersChanged()
    GoldMap:Printf("Graphics settings reset to defaults.")
  end

  local popupKey = "GOLDMAP_RESET_GRAPHICS_CONFIRM"
  if type(StaticPopupDialogs) == "table" then
    StaticPopupDialogs[popupKey] = StaticPopupDialogs[popupKey] or {
      text = "Reset all Graphics settings to defaults?",
      button1 = YES,
      button2 = NO,
      OnAccept = function()
        ResetGraphicsDefaults()
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
  end

  resetGraphicsButton:SetScript("OnClick", function()
    if StaticPopup_Show and type(StaticPopupDialogs) == "table" then
      StaticPopup_Show(popupKey)
    else
      ResetGraphicsDefaults()
    end
  end)

  GoldMap:RegisterMessage("SCAN_STATUS", function()
    if panel:IsShown() then
      C_Timer.After(0.05, RefreshMarketStatus)
    end
  end)

  GoldMap:RegisterMessage("SCAN_ADVISOR_UPDATED", function()
    if panel:IsShown() then
      C_Timer.After(0.05, RefreshMarketStatus)
    end
  end)

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
    Settings.RegisterAddOnCategory(category)
    self.settingsCategory = category
    self.settingsCategoryID = (category.GetID and category:GetID()) or category.ID
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end

  self.panel = panel
  self.SetActiveSection = SetActiveSection
end

function GoldMap.Options:Open()
  if not self.panel then
    return
  end

  if Settings and Settings.OpenToCategory and self.settingsCategoryID then
    Settings.OpenToCategory(self.settingsCategoryID)
    return
  end

  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(self.panel)
    InterfaceOptionsFrame_OpenToCategory(self.panel)
  end
end
