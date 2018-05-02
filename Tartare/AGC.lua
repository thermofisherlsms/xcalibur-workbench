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

-- AGC.lua
-- This is a Tartare report for generating Raw TIC Plots which reflect AGC behavior

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Load enumerations
local AxisType = luanet.import_type("ZedGraph.AxisType")

-- Local variables
local agc = {name = "AGC"}
local allResults = {}
local toolTip =
[[Raw TIC is proportional to the number of ions detected in each spectrum.
This reflects AGC behavior]]

function agc.generateReport(notebook)
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
    paneControl.XAxis.Title.Text = "Retention Time (min)"
    paneControl.YAxis.Title.Text = "Raw TIC"
    paneControl.YAxis.Type = AxisType.Log
    paneControl.Title.Text = string.format ("MS%d", order)
    if index > 1 then paneControl.Legend.IsVisible = false end
  end
  local thisPage = multiPlotPage{name = "AGC", panes = paneTable}
  thisPage.pageControl.ToolTipText = toolTip
  notebook:AddPage(thisPage)
    
  for index, order in ipairs(keys) do
    tartare.averagePlot({pane = paneTable[index], data = allResults, yKey = "tic",
                      filterFunction = function(a) return a.n == order end})
  end
end

function agc.processFile(rawFile, fileName, firstFile)
  if firstFile then allResults = {} end
  local tempResult = {}
  local maxIT = 0
  -- Collect data
  for scanNumber = rawFile.FirstSpectrumNumber, rawFile.LastSpectrumNumber do
    local header = rawFile:GetScanHeader(scanNumber)
    local it = rawFile:GetScanTrailer(scanNumber, "Ion Injection Time (ms):")
    maxIT = math.max(maxIT, it)
    table.insert(tempResult, {n = rawFile:GetMSNOrder(scanNumber),
                          it = it, tic = header.TIC * it / 1000,
                          rt = rawFile:GetRetentionTime(scanNumber)})
  end
  
  -- Now copy over only spectra that didn't hit the max inject time
  -- This isn't exactly right in that we are finding the maximum injection
  -- time that occurred, and not the maximum injection time that was listed
  -- in the method, but it will only make a difference of one spectrum
  -- and saves having to parse the method report
  local thisResult = {fileName = fileName}
  for _, entry in ipairs(tempResult) do
    if entry.it < maxIT then
      table.insert(thisResult, entry)
    end
  end
  
  if #thisResult > 0 then table.insert(allResults, thisResult) end
end

-- Register this report
tartare.register(agc)
