-- Copyright (c) 2018 Thermo Fisher Scientific
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

-- AGCLinearity.lua
-- This is a Tartare report for generating AGC Linearity Plots

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Load enumerations
local SymbolType = luanet.import_type("ZedGraph.SymbolType")

-- Local variables
local agcLinearity = {name = "AGC Linearity"}
local allResults = {}
local toolTip =
[[Raw TIC is proportional to the number of ions detected in each spectrum.
This plot reflects the linearity of AGC with injection time]]


function agcLinearity.generateReport(notebook)
  -- If no results, do not make a report
  if #allResults == 0 then return end
  
  -- Find out MSn orders in file
  local orders = {}
  for _, result in ipairs(allResults) do
    for _, entry in ipairs(result) do
      orders[entry.n] = true
    end
  end
  local keys = {}
  for key, _ in pairs(orders) do
    table.insert(keys, key)
  end
  table.sort(keys)
  
  -- Create panes
  local paneTable = {}
  for index, order in ipairs(keys) do
    local thisPane = zPane()
    table.insert(paneTable, thisPane)
    local paneControl = thisPane.paneControl
    paneControl.XAxis.Title.Text = "Injection Time (msec)"
    paneControl.YAxis.Title.Text = "Raw TIC"
    paneControl.Title.Text = string.format ("MS%d Raw TICs", order)
    if index > 1 then paneControl.Legend.IsVisible = false end
  end
  local thisPage = multiPlotPage{name = "AGC Linearity", panes = paneTable}
  thisPage.pageControl.ToolTipText = toolTip
  notebook:AddPage(thisPage)
  
  -- Data must be sorted in order of injection time
  for _, result in ipairs(allResults) do
    table.sort(result, function(a,b) return a.it < b.it end)
  end
  
  -- Now plot the data
  for index, order in ipairs(keys) do
    tartare.averagePlot({pane = paneTable[index], data = allResults, xKey = "it", yKey = "tic",
                        filterFunction = function(a) return a.n == order end})
  end
end

function agcLinearity.processFile(rawFile, fileName, firstFile)
  if firstFile then allResults = {} end
  local thisResult = {fileName = fileName}
  -- Collect data
  for scanNumber = rawFile.FirstSpectrumNumber, rawFile.LastSpectrumNumber do
    local header = rawFile:GetScanHeader(scanNumber)
    local injectionTime = rawFile:GetScanTrailer(scanNumber, "Ion Injection Time (ms):")
    table.insert(thisResult, {n = rawFile:GetMSNOrder(scanNumber),
                          tic = header.TIC * injectionTime / 1000,
                          it = injectionTime})
  end
  if #thisResult > 0 then table.insert(allResults, thisResult) end
end

-- Register this report
tartare.register(agcLinearity)
