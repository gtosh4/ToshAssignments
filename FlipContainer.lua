--[[-----------------------------------------------------------------------------
FlipContainer
Container that shows only one child at a time. Useful as the element of a DropdownGroup, TabGroup, or TreeGroup.
-------------------------------------------------------------------------------]]
local Type, Version = "FlipContainer", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local pairs, ipairs, assert, type, wipe = pairs, ipairs, assert, type, wipe

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent
local _G = _G

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]
local function Child_Show(frame, child)
  child.frame:Show()
end

local function Child_Hide(frame, child)
  child.frame:Hide()
end
--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
  ["AddPage"] = function(self, name, page)
    self.pages[name] = page
  end,

  ["RemovePage"] = function(self, name)
    self.pages[name] = nil
  end,

  ["ShowPage"] = function(self, name)
    local page = self.pages[name]
    if page then
      local old = self.children[1]
      if old and old ~= page then
        old.frame:Hide()
      end
      if (not old) or (old ~= page) then
        self.children[1] = self.pages[name]
        self:DoLayout()
      end
    end
  end,

	["OnWidthSet"] = function(self, width)
		local content = self.content
		content:SetWidth(width)
		content.width = width
	end,

	["OnHeightSet"] = function(self, height)
		local content = self.content
		content:SetHeight(height)
		content.height = height
	end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")

	--Container Support
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT")
	content:SetPoint("BOTTOMRIGHT")

	local widget = {
    frame     = frame,
    pages     = {},
		content   = content,
		type      = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end

	return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
