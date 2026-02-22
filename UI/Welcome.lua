local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.Welcome = GoldMap.Welcome or {}

local function EnsureMeta()
  GoldMapDB = GoldMapDB or {}
  GoldMapDB.meta = GoldMapDB.meta or {}
  if GoldMapDB.meta.welcomeSeen == nil then
    GoldMapDB.meta.welcomeSeen = false
  end
end

local function MakeSectionTitle(parent, text, anchorTo, offsetY)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  if anchorTo then
    fs:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY or -14)
  else
    fs:SetPoint("TOPLEFT", 26, -72)
  end
  fs:SetText(text)
  return fs
end

local function MakeBodyText(parent, text, anchorTo, offsetY)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY or -8)
  fs:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetText(text)
  return fs
end

function GoldMap.Welcome:BuildFrame()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "GoldMapWelcomeFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
  frame:SetSize(660, 520)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(120)
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

  local bodyBackground = frame:CreateTexture(nil, "BACKGROUND")
  bodyBackground:SetPoint("TOPLEFT", 10, -10)
  bodyBackground:SetPoint("BOTTOMRIGHT", -10, 10)
  bodyBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
  bodyBackground:SetVertexColor(0.05, 0.06, 0.08, 0.93)

  local header = frame:CreateTexture(nil, "ARTWORK")
  header:SetPoint("TOPLEFT", 14, -14)
  header:SetPoint("TOPRIGHT", -14, -14)
  header:SetHeight(52)
  header:SetTexture("Interface\\Buttons\\WHITE8X8")
  header:SetVertexColor(0.12, 0.16, 0.22, 0.92)

  local iconPlate = frame:CreateTexture(nil, "OVERLAY", nil, 0)
  iconPlate:SetSize(34, 34)
  iconPlate:SetPoint("TOPLEFT", 21, -29)
  iconPlate:SetTexture("Interface\\Buttons\\WHITE8X8")
  iconPlate:SetVertexColor(0.02, 0.03, 0.05, 0.9)

  local icon = frame:CreateTexture(nil, "OVERLAY", nil, 1)
  icon:SetSize(26, 26)
  icon:SetPoint("CENTER", iconPlate, "CENTER", 0, 0)
  icon:SetTexture(GoldMap:GetIconPath("uiInfo", 64) or "Interface\\Icons\\INV_Misc_Coin_01")
  icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
  icon:SetVertexColor(1, 1, 1, 1)
  icon:SetAlpha(1)

  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
  title:SetText("Welcome to GoldMap")

  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
  closeButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -74)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 62)

  local scrollContent = CreateFrame("Frame", nil, scrollFrame)
  scrollContent:SetSize(588, 760)
  scrollFrame:SetScrollChild(scrollContent)

  local intro = scrollContent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  intro:SetPoint("TOPLEFT", 4, -4)
  intro:SetPoint("RIGHT", scrollContent, "RIGHT", -8, 0)
  intro:SetJustifyH("LEFT")
  intro:SetText("GoldMap highlights profitable farm routes on your World Map and Minimap using seed drop data plus your local Auction House market snapshot.")

  local whatTitle = MakeSectionTitle(scrollContent, "What You Will See", intro, -18)
  local whatText = MakeBodyText(
    scrollContent,
    "- Pins for mob farms (value per kill).\n"
      .. "- Pins for Herbalism and Mining nodes (value per node).\n"
      .. "- Tooltip breakdown with item links, chance/yield, price, and contribution.\n"
      .. "- Filters and presets to narrow results by value, reliability, speed, quality, and difficulty.\n"
      .. "- Separate visibility toggles for Mob, Herb, and Ore pins.",
    whatTitle
  )

  local howTitle = MakeSectionTitle(scrollContent, "Quick Setup", whatText, -16)
  local howText = MakeBodyText(
    scrollContent,
    "1. Open Auction House and run an Auctionator scan.\n"
      .. "2. Run /goldmap scan to sync GoldMap prices.\n"
      .. "3. Open world map filters and select your farm profile.\n"
      .. "4. Follow map/minimap pins and tooltip Estimated Gold details.",
    howTitle
  )

  local readingTitle = MakeSectionTitle(scrollContent, "How To Read GoldMap Values", howText, -16)
  local readingText = MakeBodyText(
    scrollContent,
    "- Estimated Gold is an expected value, not guaranteed loot.\n"
      .. "- Data reliability: Unknown / Low / Medium / High.\n"
      .. "- Likely to sell: Low (red), Medium (orange), High (green).\n"
      .. "- Hold Shift on tooltips for advanced market details.",
    readingTitle
  )

  local importantTitle = MakeSectionTitle(scrollContent, "Important Notes", readingText, -16)
  local importantText = MakeBodyText(
    scrollContent,
    "- GoldMap relies on Auctionator as required market data source.\n"
      .. "- /goldmap scan syncs from Auctionator cache. It does not scan AH by itself.\n"
      .. "- Before your first scan, some entries show \"No price yet\" and Estimated Gold as \"--\".\n"
      .. "- Outlier guard reduces distorted values from absurd AH listings.\n"
      .. "- Non-attackable / non-practical city targets are always filtered out.",
    importantTitle
  )
  scrollContent:SetScript("OnShow", function(content)
    local top = intro:GetTop() or 0
    local bottom = importantText:GetBottom() or 0
    local height = math.max(760, math.ceil(top - bottom + 20))
    content:SetHeight(height)
  end)

  local buttonsBar = CreateFrame("Frame", nil, frame)
  buttonsBar:SetPoint("BOTTOMLEFT", 22, 16)
  buttonsBar:SetPoint("BOTTOMRIGHT", -22, 16)
  buttonsBar:SetHeight(34)

  local settingsButton = CreateFrame("Button", nil, buttonsBar, "UIPanelButtonTemplate")
  settingsButton:SetSize(170, 24)
  settingsButton:SetPoint("LEFT", buttonsBar, "LEFT", 0, 0)
  settingsButton:SetText("Open Settings")
  settingsButton:SetScript("OnClick", function()
    GoldMap.Options:Open()
  end)

  local filtersButton = CreateFrame("Button", nil, buttonsBar, "UIPanelButtonTemplate")
  filtersButton:SetSize(210, 24)
  filtersButton:SetPoint("LEFT", settingsButton, "RIGHT", 8, 0)
  filtersButton:SetText("Open World Map Filters")
  filtersButton:SetScript("OnClick", function()
    ToggleWorldMap()
    GoldMap.FilterPanel:ShowPanel(true)
  end)

  local close = CreateFrame("Button", nil, buttonsBar, "UIPanelButtonTemplate")
  close:SetSize(120, 24)
  close:SetPoint("RIGHT", buttonsBar, "RIGHT", 0, 0)
  close:SetText("Got It")
  close:SetScript("OnClick", function()
    frame:Hide()
  end)

  local footer = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMLEFT", buttonsBar, "TOPLEFT", 4, 8)
  footer:SetText("Tip: reopen this window anytime with /goldmap welcome.")

  frame:Hide()
  self.frame = frame
end

function GoldMap.Welcome:Init()
  if self.initialized then
    return
  end
  EnsureMeta()
  self:BuildFrame()
  self.initialized = true
end

function GoldMap.Welcome:Show(force)
  self:Init()
  if not self.frame then
    return
  end

  if force then
    self.frame:Show()
    return
  end

  EnsureMeta()
  if GoldMapDB.meta.welcomeSeen then
    return
  end

  GoldMapDB.meta.welcomeSeen = true
  self.frame:Show()
end
