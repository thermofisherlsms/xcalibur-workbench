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

-- MSnRate.lua
-- This is a Tartare report for generating a plot of MSn rate

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Local variables
local msnRate = {name = "MSn Rate"}
local allResults = {}
local allMSNOrders = {}
local toolTip = [[Repetition Rate for MSn Spectra]]

function msnRate.generateReport(notebook)
  -- Collect MSn Orders
  local orderList = {}
  for key, _ in pairs(allMSNOrders) do
    table.insert(orderList, key)
  end
  table.sort(orderList)
  
  -- Make a list of panes and initialize axes
  local paneList = {}
  for index, order in ipairs(orderList) do
    local thisPane = zPane()
    table.insert(paneList, thisPane)
    local paneControl = thisPane.paneControl
    paneControl.XAxis.Title.Text = "Retention Time (min)"
    paneControl.YAxis.Title.Text = "Rate (Hz)"
    paneControl.Title.Text = string.format("MS%d", order)
    if index > 1 then paneControl.Legend.IsVisible = false end
  end
  local thisPage = multiPlotPage{name = "MS Rate", panes = paneList}
  thisPage.pageControl.ToolTipText = toolTip
  notebook:AddPage(thisPage)
  
  -- Loop across data and put into format for plotting
  -- Can't use tartare.averagePlot, not obvious why, but you can probalby figure it out
  local averageTime = 1
  for index, order in ipairs(orderList) do
    for fileIndex, result in ipairs(allResults) do
      local plotData = {}
      local thisRT
      local lastRT = 0
      local nextRT = averageTime
      local count = 0
      for _, entry in ipairs(result) do
        if entry.n == order then
          count = count + 1
          thisRT = entry.rt
          if thisRT > nextRT then
            table.insert(plotData, {rt = thisRT, rate = count / ((thisRT - lastRT) * 60)})
            count = 0
            nextRT = nextRT + averageTime
            lastRT = thisRT
          end
        end
      end
      -- Get the last time window
      if thisRT > lastRT then
        table.insert(plotData, {rt = thisRT, rate = count / ((thisRT - lastRT) * 60)})
      end
      paneList[index]:AddXYTable({data = plotData, xKey = "rt", yKey = "rate", index = fileIndex, name = result.fileName})
    end
  end
end

function msnRate.processFile(rawFile, rawFileName, firstFile)
  if firstFile then
    allResults = {}
    allMSNOrders = {}
  end
  -- Set up the result table for this raw file
  local thisResult = {fileName = rawFileName or string.format("File #%d", #allResults + 1)}
  table.insert(allResults, thisResult)
  local lastRT = {}
  -- Loop through scans and collect all necessary data
  for scanNumber = rawFile.FirstSpectrumNumber, rawFile.LastSpectrumNumber do
    local order = rawFile:GetMSNOrder(scanNumber)
    allMSNOrders[order] = true
    local thisRT = rawFile:GetRetentionTime(scanNumber)
    table.insert(thisResult, {n = order, rt = thisRT})
  end
end

-- Register this report
tartare.register(msnRate)
