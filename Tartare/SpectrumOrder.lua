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

-- SpectrumOrder.lua
-- This is a Tartare report for generating spectrum MSn Order plots

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Local variables
local spectrumOrder = {name = "MSn Order"}
local allResults = {}
local toolTip = [[Number of Spectra for Each MSn Order]]

function spectrumOrder.generateReport(notebook)
  local orderPane = zPane()
  local thisPage = multiPlotPage{name = "Scan Order", panes = {orderPane}}
  thisPage.pageControl.ToolTipText = toolTip
  local paneControl = orderPane.paneControl
  paneControl.XAxis.Title.Text = "MS Order"
  paneControl.YAxis.Title.Text = "Count"
  paneControl.Title.Text = "MSn Order"
  notebook:AddPage(thisPage)
  Application.DoEvents()                        -- Let windows draw the page
  
  tartare.histogram{pane = orderPane, data = allResults, key = "order", seriesType = "bar", integer = true}
end

function spectrumOrder.processFile(rawFile, rawFileName, firstFile)
  if firstFile then allResults = {} end
  -- Set up the result table for this raw file
  local thisResult = {fileName = rawFileName or string.format("File #%d", #allResults + 1)}
  -- Loop through scans and collect all necessary data
  for scanNumber = rawFile.FirstSpectrumNumber, rawFile.LastSpectrumNumber do
    table.insert(thisResult, {order = rawFile:GetMSNOrder(scanNumber)})
  end
  if #thisResult > 0 then table.insert(allResults, thisResult) end
end

-- Register this report
tartare.register(spectrumOrder)
