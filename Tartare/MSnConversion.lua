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

-- MSnConversion.lua
-- This is a Tartare report for generating plots of MSn Conversion Factors plots

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Local variables
local msnConversion = {name = "MSn Conversion"}
local allResults = {}
local thisInformation = {}
local thisResult = {}
local maxOrder
local instrumentType

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

-- Parse instrument dependent method file to figure
-- out the isolation widths
local function getIsolationWidth(method, stage)
  local function fail(errorMsg)
    error(errorMsg or "MSn Conversion: No Method Data Available")
  end
  if not method then fail() end
  local width
  if string.find(instrumentType, "Fusion") then
    local search = string.format("MSn Level = %d", stage)
    local start, stop = string.find(method, search)
    if not stop then fail("MSn Conversion: Could not find 'MSn Level' in method") end
    stop = string.find(method, "Isolation Window = ", stop)
    if not stop then fail("MSn Conversion: Could not find 'Isolation Window' in method") end
    width = string.match(method, "%d[%d.]*", stop + 1)
    if not width then fail("MSn Conversion: Could not extract width from method") end
    width = tonumber(width)
    if not width then fail("MSn Conversion: Could not extract width from method") end
  elseif string.find(instrumentType, "Q Exactive") then
    local search = "Isolation window"
    local start, stop = string.find(method, search)
    if not stop then fail("MSn Conversion: Could not find 'Isolation window' in method") end
    local lineEnd = string.find(method, "\n", stop + 1)
    local line = string.sub(method, stop + 1, lineEnd)
    line = line:gsub("^%s*", "")  -- This trims whitespaces
    width = string.match(line, "%d[%d.]+")
    if not width then fail("MSn Conversion: Could not extract width from method") end
    width = tonumber(width)
    if not width then fail("MSn Conversion: Could not extract width from method") end
  elseif string.find(instrumentType, "Elite") or string.find(instrumentType, "FT") then
    local search = "Scan Event Details:"
    local start, stop = string.find(method, search)
    if not stop then fail("MSn Conversion: Could not find 'Scan Event Details' in method") end
    search = "Isolation Width:"
    start, stop = string.find(method, search, stop)
    if not stop then fail("MSn Conversion: Could not find 'Isolation Width:' in method") end
    local lineEnd = string.find(method, "\n", stop + 1)
    local line = string.sub(method, stop + 1, lineEnd)
    line = line:gsub("^%s*", "")  -- This trims whitespaces
    width = string.match(line, "%d[%d.]+")
    if not width then fail("MSn Conversion: Could not extract width from method") end
    width = tonumber(width)
    if not width then fail("MSn Conversion: Could not extract width from method") end
  end
  return width
end

local function getSignal(data, center, width)
  local startMZ = center - 0.5 * width
  local stopMZ = startMZ + width
  local index = findIndex(data, startMZ)
  if not index then return 0 end
  local intensity = 0
  while index <= #data do
    if data[index]. Mass > stopMZ then return intensity end
    intensity = intensity + data[index].Intensity
    index = index + 1
  end
  return intensity
end

local function getToolTip(order)
  local toolTip = string.format("Conversion of MS1 Precursor to MS%d Signal\r\n", order)
  toolTip = toolTip .. "Reflects Isolation and Activation Efficiency"
  return toolTip
end

function msnConversion.generateReport(notebook)
  local quit = true
  for _, result in ipairs(allResults) do
    if #result > 0 then
      quit = false
      break
    end
  end
  if quit then return end
  
  local pageList = {}
  for order = 2, maxOrder do
    -- Make a list of panes and initialize axes
    local timePane = zPane()
    local paneControl = timePane.paneControl
    paneControl.XAxis.Title.Text = "Retention Time (min)"
    paneControl.YAxis.Title.Text = string.format("MS%d Conversion Factor", order)
    local mzPane = zPane()
    paneControl = mzPane.paneControl
    paneControl.XAxis.Title.Text = "Precursor m/z"
    paneControl.YAxis.Title.Text = string.format("MS%d Conversion Factor", order)
    paneControl.Legend.IsVisible = false
    local thisPage = multiPlotPage{name = string.format("MS%d Conversion", order), panes = {timePane, mzPane}}
    thisPage.pageControl.ToolTipText = getToolTip(order)
    table.insert(pageList, thisPage)
    notebook:AddPage(thisPage)
    tartare.averagePlot({data = allResults, pane = timePane, yKey = "efficiency",
                        filterFunction = function(a) return a.n == order end})
  end
  
  -- Resort data so that it's in precursor order
  for _, result in ipairs(allResults) do
    table.sort(result, function(a,b) return a.precursor < b.precursor end)
  end
  local pageIndex = 1
  for order = 2, maxOrder do
    tartare.averagePlot({data = allResults, pane = pageList[pageIndex].paneList[2], xKey = "precursor",
                        yKey = "efficiency", averageWidth = 10, 
                          filterFunction = function(a) return a.n == order end})
    pageIndex = pageIndex + 1
  end
end

function msnConversion.processFile(rawFile, rawFileName, firstFile)
  -- Currently only functions for Orbitrap Fusion because I don't know the
  -- method report format for other instruments
  --if not string.find(rawFile:GetInstName(), "Fusion") then return end
  
  if firstFile then
    allResults = {}
    maxOrder = 0
    instrumentType = rawFile:GetInstName()
  end
  
  -- Set up the result table for this raw file
  thisInformation = {fileName = rawFileName}    -- This has data for extracting from the spectra
  thisResult = {fileName = rawFileName}         -- This will contain the results of the spectral extraction
  table.insert(allResults, thisResult)
  local masters = {}
  local lastMaster
  thisInformation.masters = masters
  -- Loop through scans and collect all necessary data
  for scanNumber = rawFile.FirstSpectrumNumber, rawFile.LastSpectrumNumber do
    local tic = rawFile:GetScanHeader(scanNumber).TIC
    local order = rawFile:GetMSNOrder(scanNumber)
    local thisRT = rawFile:GetRetentionTime(scanNumber)
    local masterSN, precursor
    if order == 1 then
      lastMaster = scanNumber
    elseif order > 1 then
      maxOrder = math.max(maxOrder, order)
      local thisOrder = order
      -- If this trailer call returns nil, use the most recent full scan
      masterSN = rawFile:GetScanTrailer(scanNumber, "Master Scan Number:") or lastMaster
      while thisOrder > 2 do
        masterSN = rawFile:GetScanTrailer(masterSN, "Master Scan Number:") or lastMaster
        thisOrder = thisOrder - 1
      end
      
      precursor = rawFile:GetPrecursor(scanNumber)
      if not masters[masterSN] then
        masters[masterSN] = {scanNumber}
      else
        table.insert(masters[masterSN], scanNumber)
      end
      thisInformation[scanNumber] = {n = order, rt = thisRT, precursor = precursor, tic = tic, master = masterSN}
    end
  end
  -- Extract information about isolation width from the method
  thisInformation.isolationWidths = {}
  local method = rawFile:GetMSInstrumentMethod()
  for n = 2, maxOrder do
    thisInformation.isolationWidths[n] = getIsolationWidth(method, n)
  end
end

-- For each master scan, extract the intensity in the isolation window
-- for each dependent MS2
function msnConversion.processLabelData(labelData, description)
  -- For each MSn that has this spectrum as a master
  for _, msnSN in pairs(thisInformation.masters[description.scanNumber]) do
    local msn = thisInformation[msnSN]
    local precursor = msn.precursor
    local precursorSignal = getSignal(labelData, precursor, thisInformation.isolationWidths[msn.n])
    if precursorSignal and precursorSignal > 0 then
      table.insert(thisResult, {n = msn.n, efficiency = msn.tic / precursorSignal, rt = msn.rt,
                                precursor = msn.precursor})
    end
  end
end

-- Only get label data for FTMS where n = 1 and this is a listed master scan
function msnConversion.wantsLabelData(description)
  local masters = thisInformation.masters
  return masters and masters[description.scanNumber]
end

-- Register this report
tartare.register(msnConversion)
