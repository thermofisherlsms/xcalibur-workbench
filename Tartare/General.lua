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

-- General.lua
-- This is a Tartare report for generating General rawfile information

-- Load necessary libraries
local tartare = require ("Tartare")
local gridPage = require("gridPage")

-- Local variables
local general = {name = "General"}
local allResults = {}
local toolTip = [[General information about Raw File]]

function general.generateReport(notebook)
  if #allResults == 0 then return end
  local page = gridPage{name = "General"}
  page.gridControl.RowHeadersVisible = false    -- Hide the row header
  page.pageControl.ToolTipText = toolTip
  notebook:AddPage(page)                        -- Add the page to the notebook
  Application.DoEvents()                        -- Let windows draw the page
  
  -- Create the header
  local header = {}
  for _, entry in ipairs(allResults[1]) do
    table.insert(header, entry.label)
  end
  page:FillHeaderRow(header)

  -- Fill in the grid data
  local gridData = {}
  for index, result in ipairs(allResults) do
    -- Create a single line entry for the grid
    local line = {}
    for _, entry in ipairs(result) do
      table.insert(line, entry.value)
    end
    table.insert(gridData, line)
  end
  page:Fill(gridData)
end

function general.processFile(rawFile, rawFileName, firstFile)
  if firstFile then allResults = {} end
  -- Set up the result table for this raw file
  local thisResult = {}
  table.insert(thisResult, {label = "Raw File", value = rawFileName or string.format("File #%d", #allResults + 1)})
  table.insert(thisResult, {label = "Instrument", value = rawFile:GetInstName()})
  table.insert(thisResult, {label = "SW Version", value = rawFile:GetInstSoftwareVersion()})
  table.insert(thisResult, {label = "Low m//z", value = rawFile:GetLowMass()})
  table.insert(thisResult, {label = "High m//z", value = rawFile:GetHighMass()})
  table.insert(allResults, thisResult)
end

-- Register this report
tartare.register(general)
