local _, GoldMap = ...
GoldMap = GoldMap or {}

GoldMap.FilterPanel = GoldMap.FilterPanel or {}

local TAB_DEFS = {
  { key = "quick", label = "Quick" },
  { key = "mobs", label = "Mobs" },
  { key = "gather", label = "Gathering" },
  { key = "advanced", label = "Advanced" },
  { key = "presets", label = "Presets" },
}

local PRESET_FILTER_KEYS = {
  "showMobTargets",
  "showGatherTargets",
  "minDropRate",
  "maxDropRate",
  "minEVGold",
  "maxEVGold",
  "gatherMinDropRate",
  "gatherMaxDropRate",
  "gatherMinEVGold",
  "gatherMaxEVGold",
  "minItemPriceGold",
  "gatherMinItemPriceGold",
  "minReliabilityTier",
  "gatherMinReliabilityTier",
  "minSellSpeedTier",
  "gatherMinSellSpeedTier",
  "minQuality",
  "gatherMinQuality",
  "showNoPricePins",
  "minMobLevel",
  "maxMobLevel",
  "filterMode",
}

local function Trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function MakeLabel(parent, text, font)
  local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
  fs:SetText(text)
  fs:SetJustifyH("LEFT")
  return fs
end

local function MakeNumericInput(parent, width)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetAutoFocus(false)
  eb:SetSize(width or 110, 22)
  eb:SetNumeric(false)
  return eb
end

local function MakeCheckbox(parent, label)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb.text = cb.text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  cb.text:SetText(label)
  cb.text:SetJustifyH("LEFT")
  return cb
end

local function ParseNumber(text, fallback)
  local value = tonumber(text)
  if not value then
    return fallback
  end
  return value
end

local function AddInputRow(self, parent, state, label, key)
  local y = state.y

  local lbl = MakeLabel(parent, label)
  lbl:SetPoint("TOPLEFT", 12, y)

  local input = MakeNumericInput(parent, 110)
  input:SetPoint("TOPRIGHT", -16, y + 6)

  self.inputs[key] = input

  input:SetScript("OnEnterPressed", function(box)
    box:ClearFocus()
    self:ApplyInputs()
  end)

  input:SetScript("OnTextChanged", function(_, userInput)
    if userInput then
      self.hasPendingInputChanges = true
    end
  end)

  input:SetScript("OnEditFocusLost", function()
    if self.hasPendingInputChanges then
      self:ApplyInputs()
    end
  end)

  input:SetScript("OnEscapePressed", function(box)
    box:ClearFocus()
    self.hasPendingInputChanges = false
    self:SyncInputsFromDB()
  end)

  state.y = y - 32
  return lbl, input
end

local function AddSectionTitle(parent, state, text)
  local title = MakeLabel(parent, text, "GameFontNormal")
  title:SetPoint("TOPLEFT", 12, state.y)
  state.y = state.y - 22
  return title
end

local function AddHint(parent, state, text)
  local hint = MakeLabel(parent, text, "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 12, state.y)
  hint:SetWidth(406)
  hint:SetJustifyH("LEFT")
  hint:SetJustifyV("TOP")
  local estimatedLines = math.max(1, math.ceil(string.len(text) / 68))
  state.y = state.y - (estimatedLines * 14) - 8
  return hint
end

local function CreateScrollablePage(parent)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(parent)

  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 6, -8)
  scroll:SetPoint("BOTTOMRIGHT", -26, 8)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  page.scroll = scroll
  page.content = content
  page.state = { y = -10 }

  local function RefreshWidth()
    local width = page:GetWidth()
    if width and width > 60 then
      content:SetWidth(width - 36)
    end
  end

  page:SetScript("OnShow", RefreshWidth)
  page:SetScript("OnSizeChanged", RefreshWidth)

  return page
end

function GoldMap.FilterPanel:CreateQualityDropdown(parent, frameName, onValueSelected)
  local dropdown = CreateFrame("Frame", frameName, parent, "UIDropDownMenuTemplate")

  local qualities = {
    { value = 0, text = "Any" },
    { value = 1, text = "Common+" },
    { value = 2, text = "Uncommon+" },
    { value = 3, text = "Rare+" },
    { value = 4, text = "Epic" },
  }

  UIDropDownMenu_SetWidth(dropdown, 130)

  UIDropDownMenu_Initialize(dropdown, function(_, _, _)
    for _, entry in ipairs(qualities) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.text
      info.value = entry.value
      info.func = function(selfButton)
        UIDropDownMenu_SetSelectedValue(dropdown, selfButton.value)
        if onValueSelected then
          onValueSelected(selfButton.value)
        end
      end
      UIDropDownMenu_AddButton(info)
    end
  end)

  return dropdown
end

function GoldMap.FilterPanel:CreateSellSpeedDropdown(parent, frameName, onValueSelected)
  local dropdown = CreateFrame("Frame", frameName, parent, "UIDropDownMenuTemplate")

  local tiers = {
    { value = 0, text = "|cff9d9d9dNone (no minimum)|r" },
    { value = 1, text = "|cff1eff00Low or better|r" },
    { value = 2, text = "|cff0070ddMedium or better|r" },
    { value = 3, text = "|cffa335eeHigh only|r" },
  }

  UIDropDownMenu_SetWidth(dropdown, 200)
  UIDropDownMenu_Initialize(dropdown, function(_, _, _)
    for _, entry in ipairs(tiers) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.text
      info.value = entry.value
      info.func = function(selfButton)
        UIDropDownMenu_SetSelectedValue(dropdown, selfButton.value)
        if onValueSelected then
          onValueSelected(selfButton.value)
        end
      end
      UIDropDownMenu_AddButton(info)
    end
  end)

  return dropdown
end

function GoldMap.FilterPanel:CreateReliabilityDropdown(parent, frameName, onValueSelected)
  local dropdown = CreateFrame("Frame", frameName, parent, "UIDropDownMenuTemplate")

  local tiers = {
    { value = 0, text = "|cff9d9d9dAny (include unknown)|r" },
    { value = 1, text = "|cff1eff00Low or better|r" },
    { value = 2, text = "|cff0070ddMedium or better|r" },
    { value = 3, text = "|cffff8000High only|r" },
  }

  UIDropDownMenu_SetWidth(dropdown, 200)
  UIDropDownMenu_Initialize(dropdown, function(_, _, _)
    for _, entry in ipairs(tiers) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.text
      info.value = entry.value
      info.func = function(selfButton)
        UIDropDownMenu_SetSelectedValue(dropdown, selfButton.value)
        if onValueSelected then
          onValueSelected(selfButton.value)
        end
      end
      UIDropDownMenu_AddButton(info)
    end
  end)

  return dropdown
end

function GoldMap.FilterPanel:CreateFilterModeDropdown(parent)
  local dropdown = CreateFrame("Frame", "GoldMapFilterModeDropdown", parent, "UIDropDownMenuTemplate")

  local modes = {
    { value = "ALL", text = "Match all selected filters (Narrow)" },
    { value = "ANY", text = "Match any selected filter (Broad)" },
  }

  UIDropDownMenu_SetWidth(dropdown, 260)

  UIDropDownMenu_Initialize(dropdown, function(_, _, _)
    for _, entry in ipairs(modes) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.text
      info.value = entry.value
      info.func = function(selfButton)
        UIDropDownMenu_SetSelectedValue(dropdown, selfButton.value)
        GoldMap.db.filters.filterMode = selfButton.value
        GoldMap:NotifyFiltersChanged()
      end
      UIDropDownMenu_AddButton(info)
    end
  end)

  return dropdown
end

function GoldMap.FilterPanel:GetCurrentPresetData()
  local data = {}
  local filters = GoldMap.db and GoldMap.db.filters or {}
  for _, key in ipairs(PRESET_FILTER_KEYS) do
    if filters[key] ~= nil then
      data[key] = filters[key]
    end
  end
  return data
end

function GoldMap.FilterPanel:ApplyPresetData(data)
  if type(data) ~= "table" then
    return false
  end

  local filters = GoldMap.db and GoldMap.db.filters
  if not filters then
    return false
  end

  for _, key in ipairs(PRESET_FILTER_KEYS) do
    if data[key] ~= nil then
      filters[key] = data[key]
    end
  end
  filters.onlyKillableForPlayer = true

  self.hasPendingInputChanges = false
  self:SyncInputsFromDB()
  GoldMap:NotifyFiltersChanged()
  return true
end

function GoldMap.FilterPanel:GetCustomPresets()
  GoldMap.db.customPresets = GoldMap.db.customPresets or {}
  return GoldMap.db.customPresets
end

function GoldMap.FilterPanel:BuildCustomPresetNameList()
  local names = {}
  for name in pairs(self:GetCustomPresets()) do
    table.insert(names, name)
  end
  table.sort(names, function(a, b)
    return string.lower(a) < string.lower(b)
  end)
  return names
end

function GoldMap.FilterPanel:UpdateCustomPresetButtons()
  local buttons = self.customPresetButtons
  if not buttons then
    return
  end

  local selected = self.selectedCustomPresetName
  local hasSelection = selected and self:GetCustomPresets()[selected] ~= nil

  if hasSelection then
    buttons.apply:Enable()
    buttons.update:Enable()
    buttons.delete:Enable()
  else
    buttons.apply:Disable()
    buttons.update:Disable()
    buttons.delete:Disable()
  end
end

function GoldMap.FilterPanel:RefreshCustomPresetDropdown()
  if not self.customPresetDropdown then
    return
  end

  self.customPresetNames = self:BuildCustomPresetNameList()
  UIDropDownMenu_Initialize(self.customPresetDropdown, self.customPresetDropdown._initFunc)

  local selected = self.selectedCustomPresetName
  if (not selected or selected == "") and GoldMap.db and GoldMap.db.ui then
    selected = GoldMap.db.ui.selectedCustomPresetName
  end

  if selected and self:GetCustomPresets()[selected] then
    self.selectedCustomPresetName = selected
    UIDropDownMenu_SetSelectedValue(self.customPresetDropdown, selected)
    UIDropDownMenu_SetText(self.customPresetDropdown, selected)
  else
    self.selectedCustomPresetName = nil
    if GoldMap.db and GoldMap.db.ui then
      GoldMap.db.ui.selectedCustomPresetName = nil
    end
    UIDropDownMenu_SetSelectedValue(self.customPresetDropdown, nil)
    UIDropDownMenu_SetText(self.customPresetDropdown, "Select custom preset")
  end

  self:UpdateCustomPresetButtons()
end

function GoldMap.FilterPanel:CreateCustomPresetDropdown(parent)
  local dropdown = CreateFrame("Frame", "GoldMapCustomPresetDropdown", parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(dropdown, 250)

  dropdown._initFunc = function(_, _, _)
    local names = self.customPresetNames or {}
    if #names == 0 then
      local empty = UIDropDownMenu_CreateInfo()
      empty.text = "No custom presets saved yet"
      empty.disabled = true
      UIDropDownMenu_AddButton(empty)
      return
    end

    for _, name in ipairs(names) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = name
      info.value = name
      info.func = function(selfButton)
        self.selectedCustomPresetName = selfButton.value
        GoldMap.db.ui = GoldMap.db.ui or {}
        GoldMap.db.ui.selectedCustomPresetName = selfButton.value
        UIDropDownMenu_SetSelectedValue(dropdown, selfButton.value)
        UIDropDownMenu_SetText(dropdown, selfButton.value)
        if self.customPresetNameInput and not self.customPresetNameInput:HasFocus() then
          self.customPresetNameInput:SetText(selfButton.value)
        end
        self:UpdateCustomPresetButtons()
      end
      UIDropDownMenu_AddButton(info)
    end
  end

  UIDropDownMenu_Initialize(dropdown, dropdown._initFunc)
  return dropdown
end

function GoldMap.FilterPanel:SaveCurrentAsCustomPreset()
  local input = self.customPresetNameInput
  local name = Trim(input and input:GetText() or "")
  if name == "" then
    GoldMap:Printf("Enter a preset name first.")
    return
  end

  if string.len(name) > 40 then
    GoldMap:Printf("Preset name is too long (max 40 characters).")
    return
  end

  local presets = self:GetCustomPresets()
  if presets[name] then
    self.selectedCustomPresetName = name
    GoldMap.db.ui = GoldMap.db.ui or {}
    GoldMap.db.ui.selectedCustomPresetName = name
    self:RefreshCustomPresetDropdown()
    GoldMap:Printf("Preset '%s' already exists. Use Update Selected to overwrite it.", name)
    return
  end

  presets[name] = self:GetCurrentPresetData()
  self.selectedCustomPresetName = name
  GoldMap.db.ui = GoldMap.db.ui or {}
  GoldMap.db.ui.selectedCustomPresetName = name
  if self.customPresetNameInput then
    self.customPresetNameInput:SetText(name)
  end
  self:RefreshCustomPresetDropdown()
  GoldMap:Printf("Saved custom preset '%s'.", name)
end

function GoldMap.FilterPanel:UpdateSelectedCustomPreset()
  local selected = self.selectedCustomPresetName
  local presets = self:GetCustomPresets()
  if not selected or not presets[selected] then
    GoldMap:Printf("Select a custom preset to update.")
    return
  end

  presets[selected] = self:GetCurrentPresetData()
  self:RefreshCustomPresetDropdown()
  GoldMap:Printf("Updated custom preset '%s'.", selected)
end

function GoldMap.FilterPanel:DeleteSelectedCustomPreset()
  local selected = self.selectedCustomPresetName
  local presets = self:GetCustomPresets()
  if not selected or not presets[selected] then
    GoldMap:Printf("Select a custom preset to delete.")
    return
  end

  presets[selected] = nil
  self.selectedCustomPresetName = nil
  GoldMap.db.ui = GoldMap.db.ui or {}
  GoldMap.db.ui.selectedCustomPresetName = nil
  if self.customPresetNameInput then
    self.customPresetNameInput:SetText("")
  end
  self:RefreshCustomPresetDropdown()
  GoldMap:Printf("Deleted custom preset '%s'.", selected)
end

function GoldMap.FilterPanel:ApplySelectedCustomPreset()
  local selected = self.selectedCustomPresetName
  local preset = selected and self:GetCustomPresets()[selected] or nil
  if not preset then
    GoldMap:Printf("Select a custom preset to apply.")
    return
  end

  self:ApplyPresetData(preset)
end

function GoldMap.FilterPanel:ApplyInputs()
  if not self.frame or not self.frame:IsShown() then
    return
  end

  local filters = GoldMap.db.filters
  filters.onlyKillableForPlayer = true

  filters.minDropRate = math.max(0, math.min(100, ParseNumber(self.inputs.minDrop:GetText(), filters.minDropRate)))
  filters.maxDropRate = math.max(filters.minDropRate, math.min(100, ParseNumber(self.inputs.maxDrop:GetText(), filters.maxDropRate)))
  filters.minEVGold = math.max(0, ParseNumber(self.inputs.minEV:GetText(), filters.minEVGold))
  filters.maxEVGold = math.max(filters.minEVGold, ParseNumber(self.inputs.maxEV:GetText(), filters.maxEVGold))

  filters.gatherMinEVGold = math.max(0, ParseNumber(self.inputs.gatherMinEV:GetText(), filters.gatherMinEVGold or 0))
  filters.gatherMaxEVGold = math.max(filters.gatherMinEVGold, ParseNumber(self.inputs.gatherMaxEV:GetText(), filters.gatherMaxEVGold or 999999))
  filters.gatherMinItemPriceGold = math.max(0, ParseNumber(self.inputs.gatherMinPrice:GetText(), filters.gatherMinItemPriceGold or 0))

  filters.minItemPriceGold = math.max(0, ParseNumber(self.inputs.minPrice:GetText(), filters.minItemPriceGold))
  filters.minMobLevel = math.max(1, math.min(63, math.floor(ParseNumber(self.inputs.minMobLevel:GetText(), filters.minMobLevel))))
  filters.maxMobLevel = math.max(filters.minMobLevel, math.min(63, math.floor(ParseNumber(self.inputs.maxMobLevel:GetText(), filters.maxMobLevel))))

  self.hasPendingInputChanges = false
  self:SyncInputsFromDB()
  GoldMap:NotifyFiltersChanged()
end

function GoldMap.FilterPanel:SyncInputsFromDB()
  local filters = GoldMap.db.filters
  filters.onlyKillableForPlayer = true

  self.inputs.minDrop:SetText(string.format("%.2f", filters.minDropRate))
  self.inputs.maxDrop:SetText(string.format("%.2f", filters.maxDropRate))
  self.inputs.minEV:SetText(string.format("%.2f", filters.minEVGold))
  self.inputs.maxEV:SetText(string.format("%.2f", filters.maxEVGold))

  self.inputs.gatherMinEV:SetText(string.format("%.2f", filters.gatherMinEVGold or 0))
  self.inputs.gatherMaxEV:SetText(string.format("%.2f", filters.gatherMaxEVGold or 999999))
  self.inputs.gatherMinPrice:SetText(string.format("%.2f", filters.gatherMinItemPriceGold or 0))

  self.inputs.minPrice:SetText(string.format("%.2f", filters.minItemPriceGold))
  self.inputs.minMobLevel:SetText(tostring(filters.minMobLevel))
  self.inputs.maxMobLevel:SetText(tostring(filters.maxMobLevel))

  if self.inputs.showMobTargets then
    self.inputs.showMobTargets:SetChecked(filters.showMobTargets ~= false)
  end
  if self.inputs.showGatherTargets then
    self.inputs.showGatherTargets:SetChecked(filters.showGatherTargets ~= false)
  end
  if self.inputs.showNoPrice then
    self.inputs.showNoPrice:SetChecked(filters.showNoPricePins)
  end

  UIDropDownMenu_SetSelectedValue(self.inputs.minQuality, filters.minQuality)
  UIDropDownMenu_SetSelectedValue(self.inputs.gatherMinQuality, filters.gatherMinQuality or 1)
  if self.inputs.quickSellSpeed then
    UIDropDownMenu_SetSelectedValue(self.inputs.quickSellSpeed, filters.minSellSpeedTier or 0)
  end
  if self.inputs.quickReliability then
    UIDropDownMenu_SetSelectedValue(self.inputs.quickReliability, filters.minReliabilityTier or 0)
  end
  if self.inputs.mobSellSpeed then
    UIDropDownMenu_SetSelectedValue(self.inputs.mobSellSpeed, filters.minSellSpeedTier or 0)
  end
  if self.inputs.mobReliability then
    UIDropDownMenu_SetSelectedValue(self.inputs.mobReliability, filters.minReliabilityTier or 0)
  end
  if self.inputs.gatherSellSpeed then
    UIDropDownMenu_SetSelectedValue(self.inputs.gatherSellSpeed, filters.gatherMinSellSpeedTier or 0)
  end
  if self.inputs.gatherReliability then
    UIDropDownMenu_SetSelectedValue(self.inputs.gatherReliability, filters.gatherMinReliabilityTier or 0)
  end
  UIDropDownMenu_SetSelectedValue(self.inputs.filterMode, filters.filterMode or "ALL")
end

function GoldMap.FilterPanel:ApplyPreset(presetKey)
  local f = GoldMap.db.filters
  f.onlyKillableForPlayer = true
  f.showMobTargets = true
  f.showGatherTargets = true

  if presetKey == "FAST" then
    f.minDropRate = 1
    f.maxDropRate = 100
    f.minEVGold = 8
    f.maxEVGold = 999999
    f.gatherMinDropRate = 1
    f.gatherMaxDropRate = 100
    f.gatherMinEVGold = 8
    f.gatherMaxEVGold = 999999
    f.gatherMinItemPriceGold = 0.5
    f.minReliabilityTier = 2
    f.gatherMinReliabilityTier = 2
    f.minSellSpeedTier = 2
    f.gatherMinSellSpeedTier = 2
    f.gatherMinQuality = 1
    f.minItemPriceGold = 0.5
    f.minQuality = 1
    f.filterMode = "ALL"
    f.showNoPricePins = false
    f.minMobLevel = 1
    f.maxMobLevel = 63
  elseif presetKey == "STEADY" then
    f.minDropRate = 5
    f.maxDropRate = 100
    f.minEVGold = 3
    f.maxEVGold = 999999
    f.gatherMinDropRate = 5
    f.gatherMaxDropRate = 100
    f.gatherMinEVGold = 3
    f.gatherMaxEVGold = 999999
    f.gatherMinItemPriceGold = 0.2
    f.minReliabilityTier = 1
    f.gatherMinReliabilityTier = 1
    f.minSellSpeedTier = 1
    f.gatherMinSellSpeedTier = 1
    f.gatherMinQuality = 1
    f.minItemPriceGold = 0.2
    f.minQuality = 1
    f.filterMode = "ALL"
    f.showNoPricePins = false
    f.minMobLevel = 1
    f.maxMobLevel = 63
  elseif presetKey == "HIGH" then
    f.minDropRate = 0.5
    f.maxDropRate = 100
    f.minEVGold = 20
    f.maxEVGold = 999999
    f.gatherMinDropRate = 0.5
    f.gatherMaxDropRate = 100
    f.gatherMinEVGold = 20
    f.gatherMaxEVGold = 999999
    f.gatherMinItemPriceGold = 5
    f.minReliabilityTier = 1
    f.gatherMinReliabilityTier = 1
    f.minSellSpeedTier = 0
    f.gatherMinSellSpeedTier = 0
    f.gatherMinQuality = 2
    f.minItemPriceGold = 5
    f.minQuality = 2
    f.filterMode = "ALL"
    f.showNoPricePins = false
    f.minMobLevel = 1
    f.maxMobLevel = 63
  elseif presetKey == "NOPRICE" then
    f.minDropRate = 0
    f.maxDropRate = 100
    f.minEVGold = 0
    f.maxEVGold = 999999
    f.gatherMinDropRate = 0
    f.gatherMaxDropRate = 100
    f.gatherMinEVGold = 0
    f.gatherMaxEVGold = 999999
    f.gatherMinItemPriceGold = 0
    f.minReliabilityTier = 0
    f.gatherMinReliabilityTier = 0
    f.minSellSpeedTier = 0
    f.gatherMinSellSpeedTier = 0
    f.gatherMinQuality = 1
    f.minItemPriceGold = 0
    f.minQuality = 1
    f.filterMode = "ALL"
    f.showNoPricePins = true
    f.minMobLevel = 1
    f.maxMobLevel = 63
  end

  self:SyncInputsFromDB()
  GoldMap:NotifyFiltersChanged()
end

function GoldMap.FilterPanel:SetActiveTab(tabKey)
  if not self.pages then
    return
  end

  for key, page in pairs(self.pages) do
    page:SetShown(key == tabKey)
  end

  for key, button in pairs(self.tabButtons) do
    if key == tabKey then
      button:Disable()
    else
      button:Enable()
    end
  end

  self.activeTab = tabKey
end

function GoldMap.FilterPanel:Reanchor()
  if not self.frame then
    return
  end

  self.frame:ClearAllPoints()
  if WorldMapFrame and WorldMapFrame:IsShown() then
    self.frame:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -34, -86)
  else
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  end
end

function GoldMap.FilterPanel:ShowPanel(forceShow)
  if not self.frame then
    return
  end

  if forceShow then
    self:Reanchor()
    self.frame:Show()
  else
    if self.frame:IsShown() then
      self.frame:Hide()
    else
      self:Reanchor()
      self.frame:Show()
    end
  end
end

function GoldMap.FilterPanel:BuildQuickPage(page)
  AddSectionTitle(page.content, page.state, "Core Filters")
  AddInputRow(self, page.content, page.state, "Min droprate (%)", "minDrop")
  AddInputRow(self, page.content, page.state, "Max droprate (%)", "maxDrop")
  AddInputRow(self, page.content, page.state, "Min item price (gold)", "minPrice")

  local reliabilityLabel = MakeLabel(page.content, "Minimum data reliability")
  reliabilityLabel:SetPoint("TOPLEFT", 12, page.state.y)
  local reliabilityDropdown = self:CreateReliabilityDropdown(page.content, "GoldMapQuickReliabilityDropdown", function(value)
    GoldMap.db.filters.minReliabilityTier = value
    GoldMap.db.filters.gatherMinReliabilityTier = value
    self:SyncInputsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)
  reliabilityDropdown:SetPoint("TOPRIGHT", -10, page.state.y + 8)
  self.inputs.quickReliability = reliabilityDropdown
  page.state.y = page.state.y - 42

  local sellSpeedLabel = MakeLabel(page.content, "Minimum selling speed")
  sellSpeedLabel:SetPoint("TOPLEFT", 12, page.state.y)
  local sellSpeedDropdown = self:CreateSellSpeedDropdown(page.content, "GoldMapQuickSellSpeedDropdown", function(value)
    GoldMap.db.filters.minSellSpeedTier = value
    GoldMap.db.filters.gatherMinSellSpeedTier = value
    self:SyncInputsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)
  sellSpeedDropdown:SetPoint("TOPRIGHT", -10, page.state.y + 8)
  self.inputs.quickSellSpeed = sellSpeedDropdown
  page.state.y = page.state.y - 42

  local showNoPrice = MakeCheckbox(page.content, "Include targets with no market price yet")
  showNoPrice:SetPoint("TOPLEFT", 10, page.state.y + 6)
  showNoPrice:SetScript("OnClick", function(selfButton)
    GoldMap.db.filters.showNoPricePins = selfButton:GetChecked() and true or false
    GoldMap:NotifyFiltersChanged()
  end)
  self.inputs.showNoPrice = showNoPrice
  page.state.y = page.state.y - 30

  AddSectionTitle(page.content, page.state, "Data Sources")

  local showMobTargets = MakeCheckbox(page.content, "Include mob farm targets")
  showMobTargets:SetPoint("TOPLEFT", 10, page.state.y + 6)
  showMobTargets:SetScript("OnClick", function(selfButton)
    GoldMap.db.filters.showMobTargets = selfButton:GetChecked() and true or false
    GoldMap:NotifyFiltersChanged()
  end)
  self.inputs.showMobTargets = showMobTargets
  page.state.y = page.state.y - 30

  local showGatherTargets = MakeCheckbox(page.content, "Include gathering targets (Herbs/Ore)")
  showGatherTargets:SetPoint("TOPLEFT", 10, page.state.y + 6)
  showGatherTargets:SetScript("OnClick", function(selfButton)
    GoldMap.db.filters.showGatherTargets = selfButton:GetChecked() and true or false
    GoldMap:NotifyFiltersChanged()
  end)
  self.inputs.showGatherTargets = showGatherTargets
  page.state.y = page.state.y - 30

  AddHint(page.content, page.state, "Quick tab keeps the most used filters in one place. Data reliability and selling speed are color-coded summaries from local Auctionator history.")
  page.content:SetHeight(math.max(360, math.abs(page.state.y) + 24))
end

function GoldMap.FilterPanel:BuildMobsPage(page)
  AddSectionTitle(page.content, page.state, "Mob Target Filters")
  AddInputRow(self, page.content, page.state, "Minimum mob level", "minMobLevel")
  AddInputRow(self, page.content, page.state, "Maximum mob level", "maxMobLevel")
  AddInputRow(self, page.content, page.state, "Min estimated gold per kill", "minEV")
  AddInputRow(self, page.content, page.state, "Max estimated gold per kill", "maxEV")

  local reliabilityLabel = MakeLabel(page.content, "Minimum data reliability")
  reliabilityLabel:SetPoint("TOPLEFT", 12, page.state.y)
  local reliabilityDropdown = self:CreateReliabilityDropdown(page.content, "GoldMapMobReliabilityDropdown", function(value)
    GoldMap.db.filters.minReliabilityTier = value
    self:SyncInputsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)
  reliabilityDropdown:SetPoint("TOPRIGHT", -10, page.state.y + 8)
  self.inputs.mobReliability = reliabilityDropdown
  page.state.y = page.state.y - 42

  local sellSpeedLabel = MakeLabel(page.content, "Minimum item selling speed")
  sellSpeedLabel:SetPoint("TOPLEFT", 12, page.state.y)
  local sellSpeedDropdown = self:CreateSellSpeedDropdown(page.content, "GoldMapMobSellSpeedDropdown", function(value)
    GoldMap.db.filters.minSellSpeedTier = value
    self:SyncInputsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)
  sellSpeedDropdown:SetPoint("TOPRIGHT", -10, page.state.y + 8)
  self.inputs.mobSellSpeed = sellSpeedDropdown
  page.state.y = page.state.y - 42

  local qualityLabel = MakeLabel(page.content, "Minimum item quality")
  qualityLabel:SetPoint("TOPLEFT", 12, page.state.y)
  local qualityDropdown = self:CreateQualityDropdown(page.content, "GoldMapQualityDropdown", function(value)
    GoldMap.db.filters.minQuality = value
    GoldMap:NotifyFiltersChanged()
  end)
  qualityDropdown:SetPoint("TOPRIGHT", -10, page.state.y + 8)
  self.inputs.minQuality = qualityDropdown
  page.state.y = page.state.y - 42

  AddHint(page.content, page.state, "Estimated gold is expected value from drop chance and current Auction House snapshot prices. Reliability filters weak data; selling speed helps avoid expensive-but-stagnant drops.")
  page.content:SetHeight(math.max(360, math.abs(page.state.y) + 24))
end

function GoldMap.FilterPanel:BuildGatherPage(page)
  AddSectionTitle(page.content, page.state, "Gathering Filters")
  AddInputRow(self, page.content, page.state, "Min gather item price (gold)", "gatherMinPrice")
  AddInputRow(self, page.content, page.state, "Min estimated gold per node", "gatherMinEV")
  AddInputRow(self, page.content, page.state, "Max estimated gold per node", "gatherMaxEV")

  local reliabilityLabel = MakeLabel(page.content, "Minimum data reliability")
  reliabilityLabel:SetPoint("TOPLEFT", 12, page.state.y)
  local reliabilityDropdown = self:CreateReliabilityDropdown(page.content, "GoldMapGatherReliabilityDropdown", function(value)
    GoldMap.db.filters.gatherMinReliabilityTier = value
    self:SyncInputsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)
  reliabilityDropdown:SetPoint("TOPRIGHT", -10, page.state.y + 8)
  self.inputs.gatherReliability = reliabilityDropdown
  page.state.y = page.state.y - 42

  local sellSpeedLabel = MakeLabel(page.content, "Minimum item selling speed")
  sellSpeedLabel:SetPoint("TOPLEFT", 12, page.state.y)
  local sellSpeedDropdown = self:CreateSellSpeedDropdown(page.content, "GoldMapGatherSellSpeedDropdown", function(value)
    GoldMap.db.filters.gatherMinSellSpeedTier = value
    self:SyncInputsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)
  sellSpeedDropdown:SetPoint("TOPRIGHT", -10, page.state.y + 8)
  self.inputs.gatherSellSpeed = sellSpeedDropdown
  page.state.y = page.state.y - 42

  local qualityLabel = MakeLabel(page.content, "Minimum gather item quality")
  qualityLabel:SetPoint("TOPLEFT", 12, page.state.y)
  local qualityDropdown = self:CreateQualityDropdown(page.content, "GoldMapGatherQualityDropdown", function(value)
    GoldMap.db.filters.gatherMinQuality = value
    GoldMap:NotifyFiltersChanged()
  end)
  qualityDropdown:SetPoint("TOPRIGHT", -10, page.state.y + 8)
  self.inputs.gatherMinQuality = qualityDropdown
  page.state.y = page.state.y - 42

  AddHint(page.content, page.state, "Use this tab separately from mob filters to prevent gathering nodes from being hidden by mob thresholds.")
  page.content:SetHeight(math.max(380, math.abs(page.state.y) + 24))
end

function GoldMap.FilterPanel:BuildAdvancedPage(page)
  AddSectionTitle(page.content, page.state, "Filter Logic")

  local modeLabel = MakeLabel(page.content, "How selected filters are matched")
  modeLabel:SetPoint("TOPLEFT", 12, page.state.y)

  local modeDropdown = self:CreateFilterModeDropdown(page.content)
  modeDropdown:SetPoint("TOPLEFT", modeLabel, "BOTTOMLEFT", -12, -4)
  self.inputs.filterMode = modeDropdown
  page.state.y = page.state.y - 64

  AddHint(page.content, page.state, "Match all selected filters (Narrow): strict filtering.\nMatch any selected filter (Broad): more exploratory results.")

  AddSectionTitle(page.content, page.state, "Notes")
  AddHint(page.content, page.state, "Only attackable farm targets are shown by design. This avoids guards/civilians and non-practical city targets.")

  page.content:SetHeight(math.max(320, math.abs(page.state.y) + 24))
end

function GoldMap.FilterPanel:BuildPresetsPage(page)
  AddSectionTitle(page.content, page.state, "Quick Presets")
  AddHint(page.content, page.state, "Presets update all Mob + Gathering filters together. You can then fine-tune in each dedicated tab.")

  local btnFast = CreateFrame("Button", nil, page.content, "UIPanelButtonTemplate")
  btnFast:SetSize(120, 24)
  btnFast:SetPoint("TOPLEFT", 12, page.state.y)
  btnFast:SetText("Fast")
  btnFast:SetScript("OnClick", function()
    self:ApplyPreset("FAST")
  end)

  local btnSteady = CreateFrame("Button", nil, page.content, "UIPanelButtonTemplate")
  btnSteady:SetSize(120, 24)
  btnSteady:SetPoint("LEFT", btnFast, "RIGHT", 10, 0)
  btnSteady:SetText("Steady")
  btnSteady:SetScript("OnClick", function()
    self:ApplyPreset("STEADY")
  end)

  page.state.y = page.state.y - 34

  local btnHigh = CreateFrame("Button", nil, page.content, "UIPanelButtonTemplate")
  btnHigh:SetSize(120, 24)
  btnHigh:SetPoint("TOPLEFT", 12, page.state.y)
  btnHigh:SetText("High Value")
  btnHigh:SetScript("OnClick", function()
    self:ApplyPreset("HIGH")
  end)

  local btnNoPrice = CreateFrame("Button", nil, page.content, "UIPanelButtonTemplate")
  btnNoPrice:SetSize(120, 24)
  btnNoPrice:SetPoint("LEFT", btnHigh, "RIGHT", 10, 0)
  btnNoPrice:SetText("No Price")
  btnNoPrice:SetScript("OnClick", function()
    self:ApplyPreset("NOPRICE")
  end)

  page.state.y = page.state.y - 40

  AddSectionTitle(page.content, page.state, "Custom Presets")
  AddHint(page.content, page.state, "Save your current filters as reusable presets. You can apply, update, or delete them at any time.")

  local nameLabel = MakeLabel(page.content, "Preset name")
  nameLabel:SetPoint("TOPLEFT", 12, page.state.y)
  local nameInput = MakeNumericInput(page.content, 220)
  nameInput:SetNumeric(false)
  nameInput:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
  nameInput:SetScript("OnEnterPressed", function(box)
    box:ClearFocus()
    self:SaveCurrentAsCustomPreset()
  end)
  nameInput:SetScript("OnTextChanged", function(_, userInput)
    if not userInput then
      return
    end
    local typed = Trim(nameInput:GetText())
    if typed ~= "" and self:GetCustomPresets()[typed] then
      self.selectedCustomPresetName = typed
      GoldMap.db.ui = GoldMap.db.ui or {}
      GoldMap.db.ui.selectedCustomPresetName = typed
      UIDropDownMenu_SetSelectedValue(self.customPresetDropdown, typed)
      UIDropDownMenu_SetText(self.customPresetDropdown, typed)
    else
      self.selectedCustomPresetName = nil
      GoldMap.db.ui = GoldMap.db.ui or {}
      GoldMap.db.ui.selectedCustomPresetName = nil
      UIDropDownMenu_SetSelectedValue(self.customPresetDropdown, nil)
      UIDropDownMenu_SetText(self.customPresetDropdown, "Select custom preset")
    end
    self:UpdateCustomPresetButtons()
  end)
  nameInput:SetScript("OnEscapePressed", function(box)
    box:ClearFocus()
  end)
  self.customPresetNameInput = nameInput
  page.state.y = page.state.y - 36

  local dropdownLabel = MakeLabel(page.content, "Saved presets")
  dropdownLabel:SetPoint("TOPLEFT", 12, page.state.y)
  local dropdown = self:CreateCustomPresetDropdown(page.content)
  dropdown:SetPoint("TOPLEFT", dropdownLabel, "BOTTOMLEFT", -16, -4)
  self.customPresetDropdown = dropdown
  page.state.y = page.state.y - 56

  local saveButton = CreateFrame("Button", nil, page.content, "UIPanelButtonTemplate")
  saveButton:SetSize(122, 24)
  saveButton:SetPoint("TOPLEFT", 12, page.state.y)
  saveButton:SetText("Save New")
  saveButton:SetScript("OnClick", function()
    self:SaveCurrentAsCustomPreset()
  end)

  local applyButton = CreateFrame("Button", nil, page.content, "UIPanelButtonTemplate")
  applyButton:SetSize(122, 24)
  applyButton:SetPoint("LEFT", saveButton, "RIGHT", 10, 0)
  applyButton:SetText("Apply Selected")
  applyButton:SetScript("OnClick", function()
    self:ApplySelectedCustomPreset()
  end)
  page.state.y = page.state.y - 34

  local updateButton = CreateFrame("Button", nil, page.content, "UIPanelButtonTemplate")
  updateButton:SetSize(122, 24)
  updateButton:SetPoint("TOPLEFT", 12, page.state.y)
  updateButton:SetText("Update Selected")
  updateButton:SetScript("OnClick", function()
    self:UpdateSelectedCustomPreset()
  end)

  local deleteButton = CreateFrame("Button", nil, page.content, "UIPanelButtonTemplate")
  deleteButton:SetSize(122, 24)
  deleteButton:SetPoint("LEFT", updateButton, "RIGHT", 10, 0)
  deleteButton:SetText("Delete Selected")
  deleteButton:SetScript("OnClick", function()
    self:DeleteSelectedCustomPreset()
  end)
  page.state.y = page.state.y - 40

  self.customPresetButtons = {
    save = saveButton,
    apply = applyButton,
    update = updateButton,
    delete = deleteButton,
  }

  AddSectionTitle(page.content, page.state, "What each preset means")
  AddHint(page.content, page.state, "Fast: favors quick-selling targets with better baseline value.\nSteady: balanced setup for regular farming sessions.\nHigh Value: focuses on expensive outcomes, even if slower to sell.\nNo Price: includes not-yet-priced targets to discover new opportunities.")

  page.content:SetHeight(math.max(560, math.abs(page.state.y) + 24))
  self:RefreshCustomPresetDropdown()
end

function GoldMap.FilterPanel:Init()
  if self.frame then
    return
  end

  if not WorldMapFrame then
    UIParentLoadAddOn("Blizzard_WorldMap")
  end

  local frame = CreateFrame("Frame", "GoldMapFilterPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate")
  frame:SetSize(470, 520)
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(200)
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
  title:SetPoint("TOPLEFT", 18, -16)
  title:SetText("GoldMap Filters")

  local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  subtitle:SetText("Filter farm targets while keeping your map open.")

  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

  local tabBar = CreateFrame("Frame", nil, frame)
  tabBar:SetPoint("TOPLEFT", 14, -56)
  tabBar:SetPoint("TOPRIGHT", -14, -56)
  tabBar:SetHeight(28)

  local contentHost = CreateFrame("Frame", nil, frame)
  contentHost:SetPoint("TOPLEFT", 14, -88)
  contentHost:SetPoint("BOTTOMRIGHT", -14, 48)

  local contentBg = contentHost:CreateTexture(nil, "BACKGROUND")
  contentBg:SetAllPoints(contentHost)
  contentBg:SetColorTexture(0, 0, 0, 0.25)

  self.inputs = {}
  self.pages = {}
  self.tabButtons = {}
  self.hasPendingInputChanges = false

  local btnWidth = 82
  for i, tabDef in ipairs(TAB_DEFS) do
    local button = CreateFrame("Button", nil, tabBar, "UIPanelButtonTemplate")
    button:SetSize(btnWidth, 22)
    button:SetPoint("TOPLEFT", (i - 1) * (btnWidth + 6), 0)
    button:SetText(tabDef.label)
    button:SetScript("OnClick", function()
      self:SetActiveTab(tabDef.key)
    end)
    self.tabButtons[tabDef.key] = button

    local page = CreateScrollablePage(contentHost)
    page:Hide()
    self.pages[tabDef.key] = page
  end

  self:BuildQuickPage(self.pages.quick)
  self:BuildMobsPage(self.pages.mobs)
  self:BuildGatherPage(self.pages.gather)
  self:BuildAdvancedPage(self.pages.advanced)
  self:BuildPresetsPage(self.pages.presets)

  local applyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  applyButton:SetSize(120, 24)
  applyButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
  applyButton:SetText("Apply")
  applyButton:SetScript("OnClick", function()
    self:ApplyInputs()
  end)

  local resetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  resetButton:SetSize(120, 24)
  resetButton:SetPoint("RIGHT", applyButton, "LEFT", -8, 0)
  resetButton:SetText("Reset")
  resetButton:SetScript("OnClick", function()
    local defaults = GoldMap.defaults and GoldMap.defaults.filters or {}
    for key, value in pairs(defaults) do
      GoldMap.db.filters[key] = value
    end
    GoldMap.db.filters.onlyKillableForPlayer = true
    self:SyncInputsFromDB()
    GoldMap:NotifyFiltersChanged()
  end)

  local closeSmall = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  closeSmall:SetSize(90, 24)
  closeSmall:SetPoint("RIGHT", resetButton, "LEFT", -8, 0)
  closeSmall:SetText("Close")
  closeSmall:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame:SetScript("OnShow", function()
    GoldMap.db.filters.onlyKillableForPlayer = true
    self:SyncInputsFromDB()
    self:RefreshCustomPresetDropdown()
    if not self.activeTab then
      self:SetActiveTab("quick")
    else
      self:SetActiveTab(self.activeTab)
    end
  end)

  if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", function()
      if frame:IsShown() then
        self:Reanchor()
      end
    end)
  end

  frame:Hide()
  self.frame = frame
end
