-- Copyright (c) 2016 Thermo Fisher Scientific
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files
-- (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify,
-- merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished
-- to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-- trendPane.lua
-- A zPane with the ability to plot header/trailer/status data

-- Load necessary libraries
local zPane = require("zPane")

-- Get assemblies
luanet.load_assembly ("System.Drawing")
luanet.load_assembly ("ZedGraph")

-- Get constructors
local plotCtor = luanet.import_type("ZedGraph.ZedGraphControl")
local pointPairListCtor = luanet.import_type("ZedGraph.PointPairList")
local GraphPane = luanet.import_type("ZedGraph.GraphPane")

-- Get enumerations
local Color = luanet.import_type("System.Drawing.Color")
local SymbolType = luanet.import_type("ZedGraph.SymbolType")            -- This is an enum

-- local variables

-- forward declarations for local functions

-- local functions

-- Start of the zPane object
local trendPane = {}
trendPane.__index = trendPane

setmetatable(trendPane, {
    __index = zPane,    -- this is the inheritance
    __call = function (cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end,})

---Create a new object of the class
function trendPane:_init(args)
  args = args or {}
  zPane._init(self, args)
  self.rawFile = args.rawFile
  self.filter = ""
  self.label = ""
  self.paneControl.Title.Text = "trendPane"
  -- Add properties, zPane already called properties.Inherit()
  self:AddProperty({key = "filter", label = "Filter"})
  self:AddProperty({key = "label", label = "Label"})
end

-- I could cache the labels, but speed isn't really critical
-- so don't bother
function trendPane:IsHeader(label)
  local rf = self.rawFile
  local header = rf:GetScanHeader(rf.FirstSpectrumNumber)
  return header[label] ~= nil
end

function trendPane:IsStatus(label)
  local rf = self.rawFile
  local trailer = rf:GetStatusLog(rf.FirstSpectrumNumber)
  return trailer[label] ~= nil
end

function trendPane:IsTrailer(label)
  local rf = self.rawFile
  local trailer = rf:GetScanTrailer(rf.FirstSpectrumNumber)
  return trailer[label] ~= nil
end

function trendPane:Plot(label)
  local rf = self.rawFile
  if self:IsHeader(label) then
    return self:PlotGeneric(label, rf.GetScanHeader)
  elseif self:IsTrailer(label) then
    return self:PlotGeneric(label, rf.GetScanTrailer)
  elseif self:IsStatus(label) then
    return self:PlotStatus(label)
  else
    print (string.format("Label '%s' not valid", label))
    return nil
  end
end

function trendPane:PlotGeneric(label, accessFunction)
  local rf = self.rawFile
  local xyData = {}
  local header
  for i = rf.FirstSpectrumNumber, rf.LastSpectrumNumber do
    data = accessFunction(rf, i)
    if not data[label] then
      print (string.format("Label '%s' not found for scan %d", label, i))
      return nil
    end
    table.insert(xyData, {x = rf:GetRetentionTime(i), y = data[label]})
  end
  local pane = self.paneControl
  self:Clear()                                        -- Clear all data from the pane
  pane.Title.Text = label
  pane.XAxis.Title.Text = "Retention Time (min)"
  pane.YAxis.Title.Text = "Value"
  self:AddXYTable({data = xyData, xKey = "x", yKey = "y"})
  self.label = label
  return true
end

-- Status only updates about once a second, so no need
-- to fetch from every scan
function trendPane:PlotStatus(label)
  local rf = self.rawFile
  local xyData = {}
  local scanNumber, statusLog
  local startTime = rf:GetRetentionTime(rf.FirstSpectrumNumber)
  local endTime = rf:GetRetentionTime(rf.LastSpectrumNumber)
  local currentTime = startTime
  local increment = 1 / 60        -- increment by one second
  while currentTime < endTime do
    scanNumber = rf:GetScanNumberFromRT(currentTime) 
    statusLog = rf:GetStatusLog(scanNumber)
    if not statusLog[label] then
      print (string.format("Label '%s' not found in status log for scan %d", label, i))
      return nil
    end
    table.insert(xyData, {x = currentTime, y = statusLog[label]})
    currentTime = currentTime + increment
  end
  local pane = self.paneControl
  self:Clear()                                        -- Clear all data from the pane
  pane.Title.Text = label
  pane.XAxis.Title.Text = "Retention Time (min)"
  pane.YAxis.Title.Text = "Value"
  self:AddXYTable({data = xyData, xKey = "x", yKey = "y"})
  self.label = label
  return true
end

return trendPane
