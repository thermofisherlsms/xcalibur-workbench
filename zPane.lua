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

-- zPane.lua
-- A generic zedgraph pane

-- Load necessary libraries
local properties = require("properties")

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

local defaultColors = {Color.Black, Color.Red, Color.Blue, Color.Green, Color.Brown, Color.Orange,
                        Color.Violet, Color.Pink, Color.Aqua, Color.Cyan, Color.DarkBlue, Color.DarkGray,
                        Color.DarkGreen, Color.DarkOrange, Color.DarkRed, Color.LightBlue}

-- local variables

-- forward declarations for local functions

-- local functions


-- Start of the zPane object
local zPane = {}
zPane.__index = zPane

setmetatable(zPane, {
    __call = function (cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end,})

---Create a new object of the class
function zPane:_init(args)
  args = args or {}
  self.paneControl = GraphPane()
  self.paneControl.Tag = self
  -- Initial Margins are 10 all around
  -- Initial Border.Width is 1
  self.paneControl.Border.Width = 3
  properties.Inherit(self)            -- Inherit methods from properties table
end

function zPane:AddCurve(args)
  args = args or {}
  local points = pointPairListCtor()                                  -- Get a new point list
  local curveName = args.name or ""                                   -- No name by default
  local curveCount = self.paneControl.CurveList.Count + 1             -- This will be the count after adding this curve
  local curveColor = args.color or defaultColors[curveCount + 1] or Color.Black
  local curveSymbol = args.symbol or SymbolType.None                  -- No symbol by default
  local seriesType = args.seriesType or "curve"
  local newCurve
  if seriesType == "curve" then
    newCurve = self.paneControl:AddCurve(curveName, points, curveColor, curveSymbol)
  elseif seriesType == "bar" then
    newCurve = self.paneControl:AddBar(curveName, points, curveColor)
  elseif seriesType == "stick" then
    newCurve = self.paneControl:AddStick(curveName, points, curveColor)
  else
    print ("Series Type Not Known: ", seriesType)
    return nil
  end
  if args.noLine then newCurve.Line.IsVisible = false end             -- Show line by default
  if args.symbolSize then newCurve.Symbol.Size = args.symbolSize end  -- default symbol size
  return newCurve                                                     -- return the curve
end

function zPane:AddPieSlice(args)
  args = args or {}
  local value = args.value
  if not value then
    print ("Usage: zPane:AddPieSlice({value = x})")
    return nil
  end
  local paneControl = self.paneControl
  local newIndex = paneControl.CurveList.Count + 1
  local color = args.color or defaultColors[newIndex]
  local displacement = args.displacement or 0
  local name = args.name or ""
  local slice = self.paneControl:AddPieSlice(value, color,
                                  displacement, name)                 -- returns a PieItem
  -- Refresh the graph
  local plotControl = self.plotControl
  if plotControl and not args.skipDraw then
    --print ("Refreshing Pane")
    plotControl:AxisChange()
    plotControl:Invalidate()
  end

end

function zPane:AddXYTable(args)
  args = args or {}
  if not args.data or not args.xKey or not args.yKey then
    print ("Usage: zPane:addXYTable({data = x, xKey = y, yKey = z, [index = zz]})")
  end
  local data = args.data
  local xKey = args.xKey
  local yKey = args.yKey
  local index = args.index or 1
  local pane = self.paneControl
  -- If there are not enough curves to match the index
  -- then just add more for user convenience.
  while pane.CurveList.Count < index do
    self:AddCurve(args)
  end
  
  -- Add the data
  local curve = pane.CurveList[index-1]           -- Shift back to C base-0 indexing
  curve:Clear()
  if args.lineWidth then
    curve.Line.Width = args.lineWidth
  end
  -- I'm going to pcall the section here because
  -- I've seen some issues with this crashing when
  -- there's been .NET memory corruption
  if not pcall(function() 
                    for index, point in ipairs(data) do
                      curve:AddPoint(point[xKey], point[yKey])
                      if point.label then
                        curve.Points[index-1].Tag = point.label
                      end
                    end
                end)
  then
    print ("Memory Error When Plotting Graph!!!!")
    return
  end
  -- Set the axes
  if args.xMin then
    pane.XAxis.Scale.Min = args.xMin
  else
    pane.XAxis.Scale.MinAuto = true
  end
  
  if args.xMax then
    pane.XAxis.Scale.Max = args.xMax
  else
    pane.XAxis.Scale.MaxAuto = true
  end
  
  if args.yMin then
    pane.YAxis.Scale.Min = args.yMin
  else
    pane.YAxis.Scale.MinAuto = true
  end
  
  if args.yMax then
    pane.YAxis.Scale.Max = args.yMax
  else
    pane.YAxis.Scale.MaxAuto = true
  end
  
  -- Refresh the graph
  local plotControl = self.plotControl
  if plotControl and not args.skipDraw then
    --print ("Refreshing Pane")
    plotControl:AxisChange()
    plotControl:Invalidate()
  end
end

  -- Clear all curves
  function zPane:Clear()
    local paneControl = self.paneControl
    for i = 1, paneControl.CurveList.Count do
      local curve = paneControl.CurveList[i-1]        -- Use 0-based indexing
      curve:Clear()             
    end
  end

-- Dispose of all associated .NET resources
-- curves and point lists
function zPane:Dispose()
  print ("Disposing pane")
  self.paneControl:Dispose()
end

-- This will most likely be overridden
function zPane:GetPropertyTitle()
  return "Generic Plot"
end

function zPane:SetActive(setting)
  -- No argument means to set active
  if setting == nil then setting = true end
  local border = self.paneControl.Border
  border.IsVisible = setting
  if setting then
    border.Color = Color.Blue
  end
  self:UpdatePropertyForm()
  return setting
end

-- Default is not functionality
function zPane:ShiftClick(pointF)
end

return zPane
