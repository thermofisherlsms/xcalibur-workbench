-- Copyright (c) 2016 Thermo Fisher Scientific
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


-- Load necessary libraries
local menu = require("menu")
local mdiNoteBook = require("mdiNoteBook")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Get enumerations

-- Get constructors

-- local variables
local noteBookList = mdiNoteBook.noteBookList
local rawFile
local stopTime = 20

-- This has a forward declaration
local function GetActivePane()
    -- Get the active notebook
  local activeNoteBook = noteBookList.active
  if not activeNoteBook then
    print ("No active notebook")
    return
  end
  local rawFile = activeNoteBook.rawFile
  
  -- Now get the active page
  local activePage = activeNoteBook.pageList.active
  if not activePage then
    print ("No active page")
    return
  end
  
  -- Next get the active pane
  local activePane = activePage.paneList.active
  if not activePane then
    print ("No active pane")
    return
  end
  return activePane
end

local function ShowSlopes()
  local activePane = GetActivePane()
  rawFile = activePane.rawFile
  local lastRT = 0
  local tolerance = 0.5
  for scanNumber = rawFile.FirstScanNumber, rawFile.LastScanNumber do
    local rt = rawFile:GetRetentionTime(scanNumber)             -- Get retention time for this scan
    if stopTime and rt > stopTime then break end                -- Break out if just testing
    if math.floor(rt) > lastRT then                             -- Print a message for every whole RT of analysis
      print(string.format("Analyzing RT %d", math.floor(rt)))
      lastRT = rt
    end
    if rawFile:GetMSNOrder(scanNumber) == 2 then                -- Only process MS2's
      local precursor = rawFile:GetPrecursorMass(scanNumber)
      local massRange = string.format("%0.2f-%0.2f", precursor - tolerance, precursor + tolerance)
      -- Do the slow method of using Xcalibur generated XIC's
      local xic = rawFile:GetChroData({ 	-- see MsFileReader doc for complete details
      Type = 				0,			-- 0 Mass Range, 1 TIC, Base Peak 2
      Operator = 			0,			    -- 0 None, 1 Minus, 2 Plus
      Type2 = 			0,			      -- 0 Mass Range, 1 Base Peak
      Filter = 			"ms",	        -- Scan Filter
      MassRange1 = 		self.massRange,	-- Mass Range for chro1
      MassRange2 = 		nil,		    -- Mass Range for chro2
      SmoothingType = 	0,			  -- 0 None, 1 Boxcar, 2 Gaussian
      SmoothingValue = 	3,			  -- Odd value between 3-15
      Delay = 			0,
      StartTime = 		args.startTime or 0,
      EndTime = 			args.endTime or 0,
      })

    end
  end
  
end

-- Set up the menu for accessing these routines
local thisParentName = "Slope Routines"
local complements = menu.AddMenu({name = thisParentName, parentName = "Tools"})
local showSelected = menu.AddMenu({name = "Show XIC Slopes", parentName = thisParentName, callBack = ShowSlopes})
