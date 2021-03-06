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

-- Precursors.lua
-- This is a Tartare report for generating a plot of precursor intensities

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Local variables
local precursors = {name = "Precursors"}
local allResults = {}
local thisInformation = {}
local thisResult = {}
local allMSNOrders = {}
local toolTip = [[Intensity of Selected MS2 Precursors in MS1 Master]]

-- local functions
-- Get the index of the first peak above the specified mass
local function findIndex(data, mass)
  -- Take care of the trivial cases first
  if #data == 0 then return nil end
  if data[#data].Mass < mass then return nil end
  if data[1].Mass >= mass then return 1 end
  -- Not a trivial answer, so binary search
  local startIndex = 1
  local stopIndex = #data
  local thisIndex = math.ceil((stopIndex + startIndex) / 2)  -- Start in the middle
  while true do
    if data[thisIndex].Mass > mass then -- Search above
      stopIndex = thisIndex
      thisIndex = math.ceil((startIndex + thisIndex) / 2)
    else
      startIndex = thisIndex
      thisIndex = math.ceil((stopIndex + thisIndex) / 2)
    end
    if thisIndex == stopIndex then return thisIndex end
  end
end

local function getBasePeak(data, center, width)
  local startMZ = center - 0.5 * width
  local stopMZ = startMZ + width
  local index = findIndex(data, startMZ)
  if not index then
    print (string.format("No index for m/z %f", center))
    return 0
  end
  local intensity = 0
  while index <= #data do
    if data[index]. Mass > stopMZ then return intensity end
    intensity = math.max(intensity, data[index].Intensity)
    index = index + 1
  end
  return intensity
end

function precursors.generateReport(notebook)
  local quit = true
  for _, result in ipairs(allResults) do
    if #result > 0 then
      quit = false
      break
    end
  end
  if quit then return end

  -- Make a list of panes and initialize axes
  local histPane = zPane()
  local paneControl = histPane.paneControl
  paneControl.XAxis.Title.Text = "log10 (Precursor Intensity)"
  paneControl.YAxis.Title.Text = "Count"
  local thisPage = multiPlotPage{name = "Precursors", panes = {histPane}}
  thisPage.pageControl.ToolTipText = toolTip
  notebook:AddPage(thisPage)
  tartare.histogram({data = allResults, pane = histPane, key = "intensity", logScale = true})
end

function precursors.processFile(rawFile, rawFileName, firstFile)
  -- Currently only functions for Orbitrap Fusion because I don't know the
  -- method report format for other instruments
  if not string.find(rawFile:GetInstName(), "Fusion") then return end
  
  if firstFile then
    allResults = {}
  end
  
  -- Set up the result table for this raw file
  thisInformation = {fileName = rawFileName}    -- This has data for extracting from the spectra
  thisResult = {fileName = rawFileName}         -- This will contain the results of the spectral extraction
  table.insert(allResults, thisResult)
  local masters = {}
  thisInformation.masters = masters
  local continue = false
  -- Loop through scans and collect all necessary data
  for scanNumber = rawFile.FirstSpectrumNumber, rawFile.LastSpectrumNumber do
    local order = rawFile:GetMSNOrder(scanNumber)
    local masterSN, precursor
    if order == 2 then 
      precursor = rawFile:GetPrecursor(scanNumber)
      masterSN = rawFile:GetScanTrailer(scanNumber, "Master Scan Number:")
      if not masters[masterSN] then
        masters[masterSN] = {scanNumber}
      else
        table.insert(masters[masterSN], scanNumber)
      end
      thisInformation[scanNumber] = {precursor = precursor}
      continue = true
    end
    local thisRT = rawFile:GetRetentionTime(scanNumber)
  end
  if not continue then return end
  -- Extract information about isolation width from the method
  thisInformation.isolationWidths = {}
  local method = rawFile:GetMSInstrumentMethod()
  for n = 2, 2 do
    local search = string.format("MSn Level = %d", n)
    local start, stop = string.find(method, search)
    stop = string.find(method, "Isolation Window = ", stop)
    if not stop then return end
    local width
    width = string.match(method, "%d[%d.]*", stop + 1)
    thisInformation.isolationWidths[n] = tonumber(width)
  end
end

-- For each master scan, extract the intensity in the isolation window
-- for each dependent MS2
function precursors.processLabelData(labelData, description)
  local isolationWidth = thisInformation.isolationWidths[2]
  -- For each MS2 that has this spectrum as a master
  for _, ms2SN in pairs(thisInformation.masters[description.scanNumber]) do
    local ms2 = thisInformation[ms2SN]
    local precursor = ms2.precursor
    local precursorSignal = getBasePeak(labelData, precursor, isolationWidth)
    if precursorSignal and precursorSignal > 0 then
      table.insert(thisResult, {intensity = precursorSignal})
    end
  end
end

-- Only get label data for FTMS where n = 1 and this is a listed master scan
function precursors.wantsLabelData(description)
  local masters = thisInformation.masters
  return masters and masters[description.scanNumber]
end

-- Register this report
tartare.register(precursors)
