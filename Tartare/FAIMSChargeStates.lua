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

-- FAIMSChargeStates.lua
-- This is a Tartare report for generating precursor charge state plots separated by CV.

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Local variables
local faimsChargeStates = {name = "FAIMS Charge States", enabled = false}
local allResults = {}
local toolTip = [[FAIMS Charge States for MS2 Precursors]]

function faimsChargeStates.generateReport(notebook)
  -- If no results, do not make a report
  if #allResults == 0 then return end
  
  -- Collect all CV settings
  local cvKeys = {}
  for _, result in ipairs(allResults) do
    for _, entry in ipairs(result) do
      cvKeys[tostring(entry.cv)] = true
    end
  end
  local cvList = {}
  for key, _ in pairs(cvKeys) do
    table.insert(cvList, tonumber(key))
  end
  table.sort(cvList)
  print ("Sorted cvList")
  for index, value in ipairs(cvList) do print (key, value) end
  
  -- Make panes
  local paneList = {}
  for index, value in ipairs(cvList)  do
    -- Make the Charge bar graph
    local barPane = zPane()
    paneList[index] = barPane
    local paneControl = barPane.paneControl
    paneControl.XAxis.Title.Text = "Precursor Charge State"
    paneControl.YAxis.Title.Text = "Count"
    paneControl.Title.Text = string.format("CV = %0.1f", value)
  end
  local barPage = multiPlotPage{name = "Charge", panes = paneList}
  barPage.pageControl.ToolTipText = toolTip
  notebook:AddPage(barPage)
    
  -- Make the histograms
  for index, value in ipairs(cvList) do
    tartare.histogram({pane = paneList[index], data = allResults, key = "z", integer = true,
        seriesType = "bar", filterFunction = function(a) return a.cv == value end})
  end
end

function faimsChargeStates.processFile(rawFile, fileName, firstFile)
  if firstFile then allResults = {} end
  local thisResult = {fileName = fileName}
  -- Collect data
  local maxCharge = 0
  local masterCVs = {}
  for scanNumber = rawFile.FirstSpectrumNumber, rawFile.LastSpectrumNumber do
    local order = rawFile:GetMSNOrder(scanNumber)
    local thisCV = rawFile:GetScanTrailer(scanNumber, "FAIMS CV:")
    if not thisCV then    -- CV doesn't exist in this raw file
      print (string.format("CV Data not Available in %s", fileName))
      return
    end
    if order == 1 then
      masterCVs[scanNumber] = thisCV
    elseif order == 2 then
      local chargeState = rawFile:GetScanTrailer(scanNumber, "Charge State:")
      local thisMaster = rawFile:GetScanTrailer(scanNumber, "Master Scan Number:")
      if not thisMaster then    -- Master entry doesn't exist in this raw file
        print (string.format("Master Scan Number Data not Available in %s", fileName))
        return
      end
      thisCV = masterCVs[thisMaster]
      if not thisCV then
        print(string.format("CV Information not Available for Master %d in %s", thisMaster, fileName))
        return
      end
      table.insert(thisResult, {z = chargeState, cv = thisCV})
    end
  end
  if #thisResult > 0 then table.insert(allResults, thisResult) end
end

-- Register this report
tartare.register(faimsChargeStates)
