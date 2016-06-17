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

-- tabPage.lua
-- Container object for different notebook pages
-- OO structure from http://lua-users.org/wiki/ObjectOrientationTutorial

-- Load necessary libraries
local properties = require("properties")

-- Get assemblies

-- Get constructors
local TabPage = luanet.import_type("System.Windows.Forms.TabPage")

-- Get enumerations
local Keys = luanet.import_type("System.Windows.Forms.Keys")

-- local variables
local comboBox

-- Forward declarations for local helper functions

-- local functions
local function FilterMatch(scanFilter, searchList)
  -- Add spaces around filter so components can match at start and end
  scanFilter = " " .. scanFilter .. " "
  for _, search in ipairs(searchList) do
    if not scanFilter:find(search) then return false end
  end
  print (string.format("Filter:%s Matches:%s:", scanFilter, searchList[1]))
  return true
end

-- Break the filter into individual components
local function GetFilterComponents(searchFilter)
  local components = {}
  for component in string.gmatch(searchFilter, "%S+") do
    -- Add spaces around search component
    table.insert(components, " " .. component .. " ")
  end
  return components
end

-- Start of the mdiPage object
local tabPage = {}
tabPage.__index = tabPage

setmetatable(tabPage, {
    __call = function (cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end,})

---Create a new object of the class
function tabPage:_init(args)
  args = args or {}
  self.pageControl = TabPage(args.name)
  self.pageControl.Tag = self                     -- Set Tag to self for callback association
  self.pageControl.Enter:Add(tabPage.SelectedCB)
  properties.Inherit(self)                        -- Inherit methods from the properties table
end

-- This will most likely be overridden
function tabPage:GetPropertyTitle()
  return "tabPage"
end

-- Send is the TabPage, so not the . instead of : syntax
function tabPage.SelectedCB(sender, args)
  local parent = sender.Parent                    -- This is the TabControl of the notebook's Form
  local activeNoteBook = parent.Tag               -- This is the Lua notebook
  local activePage = sender.Tag                   -- Get the Tag from the sender page, this is a notebook page
  activeNoteBook.pageList.active = activePage     -- Set the active page for the notebook
  activePage:UpdatePropertyForm()                 -- Update the Property Page
end

-- This will most likely be overriden
function tabPage:SetPropertiesFinalize()
end

-- This uses : syntax, since it's called by the pane or page
-- Left and right are up and down
-- Shift increases skip by 10x
-- Control increases skip by 100x
-- Shift + Control increases skip by 1000x
function tabPage:ChangeScanNumber(args, rawFile, scanNumber, filter)
  rawFile = rawFile or self.rawFile
  scanNumber = scanNumber or self.scanNumber
  local keyCode = args.KeyCode
  local targetScanNumber
  local multiplier = 1
  local scanShift = 0
  if args.Shift then
    multiplier = multiplier * 10
  end
  if args.Control then
    multiplier = multiplier * 100
  end
  if keyCode == Keys.Left then
    scanShift = -1 * multiplier
  elseif keyCode == Keys.Right then
    scanShift = 1 * multiplier
  elseif keyCode == Keys.Home then
    targetScanNumber = rawFile.FirstSpectrumNumber
  elseif keyCode == Keys.End then
    targetScanNumber = rawFile.LastSpectrumNumber
  else
    return                                    -- Not a valid key to respond to
  end
  if scanShift then targetScanNumber = scanNumber + scanShift end
  -- Validate scan number
  local firstSpectrumNumber = rawFile.FirstSpectrumNumber
  local lastSpectrumNumber = rawFile.LastSpectrumNumber
  targetScanNumber = math.max(targetScanNumber, firstSpectrumNumber)
  targetScanNumber = math.min(targetScanNumber, lastSpectrumNumber)
  
  -- If no filter is specified, then we are done
  if not filter then return targetScanNumber end
  
  -- Check if this scan matches the filter
  print ("Looking for match at ", targetScanNumber)
  local filterList = GetFilterComponents(filter)                          -- Get a list of the filter components
  local thisFilter = rawFile:GetScanFilter(targetScanNumber)              -- Get the filter for the target scan
  if FilterMatch(thisFilter, filterList) then return targetScanNumber end -- Return this scan on a match
  
  -- Find the first lower scan number that matches the filter
  local lowSpectrum = targetScanNumber - 1
  while lowSpectrum >= firstSpectrumNumber do
    thisFilter = rawFile:GetScanFilter(lowSpectrum)
    if FilterMatch(thisFilter, filterList) then break end
    lowSpectrum = lowSpectrum - 1
  end
  if lowSpectrum < firstSpectrumNumber then lowSpectrum = false end
  
  -- Find the first higher scan number that matches the filter
  local highSpectrum = targetScanNumber + 1
  while highSpectrum <= lastSpectrumNumber do
    thisFilter = rawFile:GetScanFilter(highSpectrum)
    if FilterMatch(thisFilter, filterList) then break end
    highSpectrum = highSpectrum + 1
  end
  if highSpectrum > lastSpectrumNumber then highSpectrum = false end
  
  -- Low spectrum invalid
  if not lowSpectrum then                             -- No match found on low side
    return highSpectrum or scanNumber                 -- Return high if valid, otherwise current scan
  end
  if not highSpectrum then return lowSpectrum end     -- No match on high side, return low side
  
  -- See if either spectrum around the target is the current spectrum
  if lowSpectrum == scanNumber then return highSpectrum end
  if highSpectrum == scanNumber then return lowSpectrum end
  
  -- There are valid spectra on both sides, so return the closest
  if targetScanNumber-lowSpectrum < highSpectrum - targetScanNumber then
    return lowSpectrum
  else
    return highSpectrum
  end
end

function tabPage:ParentNotebook()
  -- PageControl's parent is the TabControl, and
  -- its Tag is the Lua mdiNotebook
  return self.pageControl.Parent.Tag
end

return tabPage
