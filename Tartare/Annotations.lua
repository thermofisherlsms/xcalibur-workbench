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

-- Annotations.lua
-- This is a Tartare report for generating plots of the number of annotated features

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Load enumerations

-- Local variables
local annotations = {name = "Annotations", enabled = true}
local allResults = {}
local thisResult = {}
local thisRawFile, thisRT
local toolTip = [[Total number of Orbitrap MS1 Peaks and Isotope Clusters]]
local instrumentType, plotClusters, extractClusters

-- This is going to return bits with base-1
-- Which may be a "bit" confusing
local function bitTable(value, bitCount)
  bitCount = bitCount or 8
  local bits = {}
  local remainder
  value = math.floor(value)  -- Make sure it's an integer to start
  for i = 1, bitCount do
    remainder = value % math.pow(2, i)
    if remainder > 0 then
      bits[i] = true
      value = value - remainder
    end
  end
  return bits
end

function annotations.generateReport(notebook)
  -- If no entries in all the results, do not make a report
  local continue = false
  for _, result in ipairs(allResults) do
    if #result > 0 then
      continue = true
      break
    end
  end
  if not continue then return end
  
  -- Create panes
  local clusterPane
  if plotClusters then
    clusterPane = zPane()
    local paneControl = clusterPane.paneControl
    paneControl.XAxis.Title.Text = "Retention Time (min)"
    paneControl.YAxis.Title.Text = "Clusters per Spectrum"
    paneControl.Title.Text = "MS1 Clusters"
    paneControl.Legend.IsVisible = false
  end
  
  local peakPane = zPane()
  local paneControl = peakPane.paneControl
  paneControl.XAxis.Title.Text = "Retention Time (min)"
  paneControl.YAxis.Title.Text = "Peaks per Spectrum"
  paneControl.Title.Text = "MS1 Peaks"
  
  local thisPage = multiPlotPage{name = "Annotations", panes = {peakPane, clusterPane}}
  thisPage.pageControl.ToolTipText = toolTip
  notebook:AddPage(thisPage)
  tartare.averagePlot({pane = peakPane, data = allResults, yKey = "peaks"})
  if plotClusters then
    tartare.averagePlot({pane = clusterPane, data = allResults, yKey = "clusters"})
  end
end

-- This routine only uses label data, so no processing here
-- Just clear allResults on the first call and thisResult on each call
function annotations.processFile(rawFile, fileName, firstFile)
  if firstFile then
    allResults = {}
    plotClusters = false  -- only plot clusters for restricted instrument types
  end
  thisResult = {fileName = fileName}
  table.insert(allResults, thisResult)
  thisRawFile = rawFile
  instrumentType = rawFile:GetInstName()
  if string.find(instrumentType, "Fusion") or string.find(instrumentType, "Q Exactive") then
    plotClusters = true
    extractClusters = true
  else
    tartare.reportError(string.format("Cluster annotation not supported for %s in file %s", instrumentType, fileName))
    extractClusters = false
  end
end

-- A cluster always has a most abundant peak labeled in the resolution
-- by 0x4 being set
function annotations.processLabelData(labelData, description)
  if not extractClusters then
    table.insert(thisResult, {rt = thisRT, peaks = #labelData})
    return
  end
  local clusterCount = 0
  local bits
  local remainder
  -- Annotation of peak top only applies to QE and Fusion
  for _, peak in ipairs(labelData) do
    remainder = math.floor(peak.Resolution % 10)
    if remainder >=4 and remainder <= 7 then
      clusterCount = clusterCount + 1
    end
  end
  table.insert(thisResult, {rt = thisRT, clusters = clusterCount, peaks = #labelData})
end

-- Only get label data for FTMS where n = 1
function annotations.wantsLabelData(description)
  if string.find(description.filter, "FTMS") and description.order == 1 then
    thisRT = thisRawFile:GetRetentionTime(description.scanNumber)
    return true
  else
    return false
  end
end

-- Register this report
tartare.register(annotations)
