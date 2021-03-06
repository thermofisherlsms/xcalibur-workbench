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

-- headerPage.lua
-- a gridPage with the ability to display the scan headers

-- Load necessary libraries
local gridPage = require("gridPage")
local properties = require("properties")
local trendPage = require("trendPage")

-- Get assemblies
luanet.load_assembly("System.Drawing")

-- Get constructors
local ContextMenuStrip = luanet.import_type("System.Windows.Forms.ContextMenuStrip")
local ToolStripMenuItem = luanet.import_type("System.Windows.Forms.ToolStripMenuItem")

-- Get enumerations
local AutoSizeColumnsMode = luanet.import_type("System.Windows.Forms.DataGridViewAutoSizeColumnsMode")
local MouseButtons = luanet.import_type("System.Windows.Forms.MouseButtons")

-- local variables
local clickedItem

-- Forward declaration for local helper functions
local CellMouseEnterCB, ShowTrendCB

-- local functions
local function AddMenu(self)
  local menu = ContextMenuStrip()                           -- Get a ContextMenuStrip
  self.gridControl.ContextMenuStrip = menu                  -- Set the grids ContextMenuStrip
  local item = ToolStripMenuItem("Create Trend Page")       -- Get a ToolStripMenuItem
  item.Click:Add(ShowTrendCB)                               -- Add a callback
  item.Tag = self                                           -- Set tag to the page
  menu.Items:Add(item)                                      -- Add it to the menu
  self.gridControl.CellMouseEnter:Add(CellMouseEnterCB)     -- Add callback for cell enter
end

-- This has a forward declaration
function CellMouseEnterCB(sender, args)
  -- Fetch entry in column 0, which will be the label
  clickedItem = sender.Rows[args.RowIndex].Cells[0].Value
end

-- This has a forward declaration
-- Sender is the toolStripItem
function ShowTrendCB(sender, args)
  local self = sender.Tag                   -- Previously set Tag to the Lua headerPage
  if self.headerEntries[clickedItem] or 
    self.trailerEntries[clickedItem] then
    local noteBook = self:ParentNotebook()
    local page = trendPage({name = noteBook:GetUniquePageName("Trend"), rawFile = self.rawFile})
    local result = page:Plot(clickedItem)
    if result then
      noteBook:AddPage(page)
      -- Set the new page as the selected page in the notebook
      noteBook.tabControl.SelectedTab = page.pageControl
    end
  end
end

-- Start of headerPage Object
local headerPage = {}
headerPage.__index = headerPage
setmetatable(headerPage, {
    __index = gridPage,    -- this is the inheritance
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end, })

function headerPage:_init(args)
  args = args or {}
  gridPage._init(self, args)
  local grid = self.gridControl
  grid.AutoGenerateColumns = false
  grid.AutoSizeColumnsMode = AutoSizeColumnsMode.Fill
  grid.ColumnHeadersVisible = false
  grid.RowHeadersVisible = false
  self.rawFile = args.rawFile
  self.scanNumber = self.rawFile.FirstSpectrumNumber
  self.filter = ""
  
  AddMenu(self)
  -- Set properties
  
  properties.Inherit(self)        -- Inherit capabilities of the properties table
  self:AddProperty({key = "scanNumber", label = "Scan Number"})
  self:AddProperty({key = "filter", label = "Filter"})
  
  if not args.skipInit then self:ShowHeader() end
end

function headerPage:GetPropertyTitle()
  return "Scan Header"
end

function headerPage:SetPropertiesFinalize()
  self:ShowHeader()
end

function headerPage:ShowHeader(args)
  args = args or {}
  self.scanNumber = args.scanNumber or self.scanNumber
  if not self.rawFile then
    print ("No rawFile available")
    return nil
  end
  local rawFile = self.rawFile
  local scanHeader = rawFile:GetScanHeader(self.scanNumber)
  
  -- fill table of header entries if not done previously
  if not self.headerEntries then
    self.headerEntries = {}
    for key, value in pairs(scanHeader) do
      self.headerEntries[key] = true
    end
  end
  
  local sorted = {}
  for key, value in pairs(scanHeader) do
    table.insert(sorted, {key, value})
  end
  table.sort(sorted, function(a,b) return a[1] < b[1] end)
  local finalTable = {}
  table.insert(finalTable, {"Header", "........"})
  for index, value in ipairs(sorted) do
    table.insert(finalTable, value)
  end
  
  local scanTrailer = rawFile:GetScanTrailer(self.scanNumber)
  -- fill table of trailer entries if not done previously
  if not self.trailerEntries then
    self.trailerEntries = {}
    for key, value in pairs(scanTrailer) do
      self.trailerEntries[key] = true
    end
  end
  
  sorted = {}
  for key, value in pairs(scanTrailer) do
    table.insert(sorted, {key, value})
  end
  table.sort(sorted, function(a,b) return a[1] < b[1] end)
  table.insert(finalTable, {"Trailer", "........"})
  for index, value in ipairs(sorted) do
    table.insert(finalTable, value)
  end
  self:Fill(finalTable)
  self:UpdatePropertyForm()
  self:PushProperties()
end

return headerPage
