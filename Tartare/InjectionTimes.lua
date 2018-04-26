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

-- Chromatograms.lua
-- This is a Tartare report for generating Injection Time Plots

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Load enumerations
local AxisType = luanet.import_type("ZedGraph.AxisType")

-- Local variables
local injectionTimes = {name = "Injection Times"}
local allResults = {}

function injectionTimes.generateReport(notebook)
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
  
  -- Loop across data and put into format for plotting
  for _, order in ipairs(keys) do
    local histPane = zPane()
    local timePane = zPane()
    local thisPage = multiPlotPage{name = string.format("MS%d IT", order),
                                panes = {timePane, histPane}}
    notebook:AddPage(thisPage)
    local paneControl = histPane.paneControl
    paneControl.XAxis.Title.Text = "Log10 Injection Time (msec)"
    paneControl.YAxis.Title.Text = "Count"
    paneControl.Title.Text = string.format ("MS%d Injection Times", order)
    paneControl = timePane.paneControl
    paneControl.XAxis.Title.Text = "Retention Time (min)"
    paneControl.YAxis.Title.Text = "Injection Time (msec)"
    paneControl.YAxis.Type = AxisType.Log
    paneControl.Title.Text = string.format ("MS%d Injection Times", order)
    local thisData = {}
    for _, result in ipairs(allResults) do
      local newResult = {fileName = result.fileName}
      table.insert(thisData, newResult)
      for _, entry in ipairs(result) do
        if entry.n == order then
          table.insert(newResult, {rt = entry.rt, time = entry.time})
        end
      end
    end
    
    tartare.histogram({pane = histPane, data = thisData, key = "time", logScale = true})
    tartare.timePlot({pane = timePane, data = thisData, key = "time"})
  end
  allResults = {}
end


function injectionTimes.processFile(rawFile, fileName, firstFile)
  if firstFile then allResults = {} end
  local thisResult = {fileName = fileName}
  -- Collect data
  for scanNumber = rawFile.FirstSpectrumNumber, rawFile.LastSpectrumNumber do
    table.insert(thisResult, {n = rawFile:GetMSNOrder(scanNumber),
                          time = rawFile:GetScanTrailer(scanNumber, "Ion Injection Time (ms):"),
                          rt = rawFile:GetRetentionTime(scanNumber)})
  end
  if #thisResult > 0 then table.insert(allResults, thisResult) end
end

-- Register this report
tartare.register(injectionTimes)
