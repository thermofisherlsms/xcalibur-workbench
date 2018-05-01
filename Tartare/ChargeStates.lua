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

-- ChargeStates.lua
-- This is a Tartare report for generating precursor charge state plots

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Local variables
local chargeStates = {name = "Precursor Charge State"}
local allResults = {}
local toolTip = [[Distribution of Charge States for MS2 Precursors]]

function chargeStates.generateReport(notebook)
  -- If no results, do not make a report
  if #allResults == 0 then return end
  
  -- Make the Charge bar graph
  local barPane = zPane()
  local barPage = multiPlotPage{name = "Charge",
                                panes = {barPane}}
  barPage.pageControl.ToolTipText = toolTip
  notebook:AddPage(barPage)
  local paneControl = barPage.paneList[1].paneControl
  paneControl.XAxis.Title.Text = "Precursor Charge State"
  paneControl.YAxis.Title.Text = "Count"
  paneControl.Title.Text = "Charge State"
  tartare.histogram({pane = barPane, data = allResults, key = "z", integer = true, seriesType = "bar"})
end

function chargeStates.processFile(rawFile, fileName, firstFile)
  if firstFile then allResults = {} end
  local thisResult = {fileName = fileName}
  -- Collect data
  local maxCharge = 0
  for scanNumber = rawFile.FirstSpectrumNumber, rawFile.LastSpectrumNumber do
    if rawFile:GetMSNOrder(scanNumber) == 2 then
      local chargeState = rawFile:GetScanTrailer(scanNumber, "Charge State:")
      table.insert(thisResult, {z = chargeState})
    end
  end
  if #thisResult > 0 then table.insert(allResults, thisResult) end
end

-- Register this report
tartare.register(chargeStates)
