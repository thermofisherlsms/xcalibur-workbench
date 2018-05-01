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
-- This is a Tartare report for generating Chromatograms

-- Load necessary libraries
local tartare = require ("Tartare")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Local variables
local chromatograms = {name = "Chromatograms"}
local allResults = {}
local toolTip = [[Base Peak MS1 Chromatograms]]

function chromatograms.generateReport(notebook)
  -- If no results, do not make a report
  if #allResults == 0 then return end
  
  local generic = multiPlotPage{name = "Chromatogram",
                                panes = {zPane()}}
  notebook:AddPage(generic)
  generic.pageControl.ToolTipText = toolTip
  local pane = generic.paneList[1].paneControl
  pane.XAxis.Title.Text = "Retention Time (min)"
  pane.YAxis.Title.Text = "Intensity"
  pane.Title.Text = "Base Peak Chromatogram"
  Application.DoEvents()
  -- Collect data
  for fileIndex, result in ipairs(allResults) do
    local bpc = {}
    local rt = result.rt
    local intensity = result.intensity
    for index = 1, #result.rt do do      -- For each spectrum
      table.insert(bpc, {x = rt[index], y = intensity[index]})
      end
    end
    generic.paneList[1]:AddXYTable({data = bpc, xKey = "x", yKey = "y",
                                    index = fileIndex, name = result.fileName})
    Application.DoEvents()
  end
  allResults = {}       -- Clear the results table
end

function chromatograms.processFile(rawFile, fileName, firstFile)
  if firstFile then allResults = {} end
  local thisResult = {fileName = fileName, rt = {}, intensity = {}}
  -- Collect data
  for scanNumber = rawFile.FirstSpectrumNumber, rawFile.LastSpectrumNumber do
    if rawFile:GetMSNOrder(scanNumber) == 1 then
      local header = rawFile:GetScanHeader(scanNumber)
      table.insert(thisResult.rt, header.StartTime)
      table.insert(thisResult.intensity, header.BasePeakIntensity)
    end
  end
  -- Only insert result if we have one or more full scans
  if #thisResult.rt > 0 then
    table.insert(allResults, thisResult)
  end
end

-- Register this report
tartare.register(chromatograms)
