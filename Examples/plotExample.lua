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

-- plotExample.lua
-- Example code for making generic plots
-- Load necessary libraries
local zPane = require("zPane")
local multiPlotPage = require("multiPlotPage")
local mdiNoteBook = require("mdiNoteBook")

-- Get enumerations
local Color = luanet.import_type("System.Drawing.Color")
local AxisType = luanet.import_type("ZedGraph.AxisType")
local SymbolType = luanet.import_type("ZedGraph.SymbolType")

local function plotBar(pane)
  local barData = {{x = 1, y = 1},{x = 2, y = 2},{x = 3, y = 1.5},}
  pane:AddXYTable({data = barData, xKey = "x", yKey = "y",
                  seriesType = "bar", color = Color.Green})
end

local function plotPie(pane)
  pane:AddPieSlice({value = 10, name = "First", skipDraw = true, displacement = 0.1})
  pane:AddPieSlice({value = 20, name = "Second", skipDraw = true})
  pane:AddPieSlice({value = 30, name = "Third"})
end

local function plotPoints(pane)
  pane.paneControl.XAxis.Title.Text = "Points X Title"
  pane.paneControl.YAxis.Title.Text = "Points Y Title"
  local sinData = {}
  local cosData = {}
  local pointCount = 20
  for i = 1, pointCount do
    cosData[i] = {x = i, y = math.cos(i * 2 * math.pi / pointCount)}
    sinData[i] = {x = i, y = math.sin(i * 2 * math.pi / pointCount)}
  end
  pane:AddXYTable({name = "cos", data = cosData, xKey = "x", yKey = "y", index = 1,
                  noLine = true, symbol = SymbolType.Square, symbolSize = 3, color = Color.Red})
  pane:AddXYTable({name = "sin", data = sinData, xKey = "x", yKey = "y", index = 2,
                  noLine = true, symbol = SymbolType.Star, color = Color.Blue})
end

local function plotWaves(pane)
  pane.paneControl.XAxis.Title.Text = "Wave X Title"
  pane.paneControl.YAxis.Title.Text = "Wave Y Title"
  local sinData = {}
  local cosData = {}
  local pointCount = 100
  for i = 1, pointCount do
    cosData[i] = {x = i, y = math.cos(i * 2 * math.pi / pointCount)}
    sinData[i] = {x = i, y = math.sin(i * 2 * math.pi / pointCount)}
  end
  pane:AddXYTable({name = "cos", data = cosData, xKey = "x", yKey = "y", index = 1, color = Color.Red})
  pane:AddXYTable({name = "sin", data = sinData, xKey = "x", yKey = "y", index = 2, color = Color.Blue})
end


function plotExample()
  local noteBook = mdiNoteBook()                                      -- Create the notebook
  noteBook.form.Text = "Example Plot Notebook"
  
  -- Create the first page.  2 panes
  local paneList = {}                                                 -- Create a list of panes
  for i = 1, 2 do
    paneList[i] = zPane({name = string.format("Pane %d", i)})         -- Create the panes
  end
  local generic = multiPlotPage{name = "multi", panes = paneList,     -- Create the first page
                                rows = 2}
  noteBook:AddPage(generic)                                           -- Add the page to the notebook
  plotWaves(generic.paneList[1])                                      -- Plot some waves in the top pane
  plotPoints(generic.paneList[2])                                     -- Plot some points in the bottom pane
  
  -- Create the second page.  Just 1 pane.
  local barPage = multiPlotPage({name = "bar"})                       -- Without "panes", we get 1 pane automatically
  noteBook:AddPage(barPage)
  plotBar(barPage.paneList.active)
  
  -- Create the third page.  Just 1 pane
  local piePage = multiPlotPage({name = "pie"})                       -- Without "panes", we get 1 pane automatically
  noteBook:AddPage(piePage)
  plotPie(piePage.paneList.active)

end

