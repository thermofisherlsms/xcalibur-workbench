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
-- This is a Tartare report for generating TopN and Top Speed spacing charts

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Local variables
local spacing = {name = "Scan Spacing"}
local allResults = {}

function spacing.generateReport(notebook)
  -- If no results, do not make a report
  if #allResults == 0 then return end
  
  -- Find out the max N and max time
  local maxN = 0
  local maxTime = 0
  for _, result in ipairs(allResults) do
    for _, entry in ipairs(result) do
      maxN = math.max(maxN, entry.count)
      maxTime = math.max(maxTime, entry.time)
    end
  end
  
  -- Make the Top N bar graph
  local topNPane = zPane()
  local topNPage = multiPlotPage{name = "Top N Spacing",
                                panes = {topNPane}}
  notebook:AddPage(topNPage)
  local paneControl = topNPane.paneControl
  paneControl.XAxis.Title.Text = "Top N Spacing"
  paneControl.YAxis.Title.Text = "Count"
  paneControl.Title.Text = "Top N Spacing"
  tartare.histogram({pane = topNPane, data = allResults, integer = true, key = "count", seriesType = "bar"})

  -- Make a Top Speed Histogram
  local histPane = zPane()
  local histPage = multiPlotPage{name = "Top Speed",
                                panes = {histPane}}
  notebook:AddPage(histPage)
  paneControl = histPane.paneControl
  paneControl.XAxis.Title.Text = "Cycle Time (sec)"
  paneControl.YAxis.Title.Text = "Count"
  paneControl.Title.Text = "Top Speed Timing"
  tartare.histogram({pane = histPane, data = allResults, key = "time"})
  allResults = {}       -- Clear the results table  
end

function spacing.processFile(rawFile, fileName, firstFile)
  if firstFile then allResults = {} end
  local thisResult = {fileName = fileName}
  local lastMS, lastMSRT, thisRT
  -- Collect data
  for scanNumber = rawFile.FirstSpectrumNumber, rawFile.LastSpectrumNumber do
    if rawFile:GetMSNOrder(scanNumber) == 1 then
      thisRT = rawFile:GetRetentionTime(scanNumber) * 60 -- Convert to seconds
      if lastMS then
        table.insert(thisResult, {count = scanNumber - lastMS - 1, time = thisRT - lastMSRT})
      end
      lastMS = scanNumber
      lastMSRT = thisRT
    end
  end
  if #thisResult > 0 then table.insert(allResults, thisResult) end
end

-- Register this report
tartare.register(spacing)
