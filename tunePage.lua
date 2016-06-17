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

-- tunePage.lua
-- a gridPage with the ability to display the tune parameters

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
  local self = sender.Tag                   -- Previously set Tag to the Lua tunePage
  if self.statusEntries[clickedItem] then
    local noteBook = self:ParentNotebook()
    --local name = self:UniqueName(noteBook)
    local page = trendPage({name = noteBook:GetUniquePageName("Trend"), rawFile = self.rawFile})
    local result = page:Plot(clickedItem)
    if result then
      noteBook:AddPage(page)
      -- Set the new page as the selected page in the notebook
      noteBook.tabControl.SelectedTab = page.pageControl
    end
  end
end

-- Start of tunePage Object
local tunePage = {}
tunePage.__index = tunePage
setmetatable(tunePage, {
    __index = gridPage,    -- this is the inheritance
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end, })

function tunePage:_init(args)
  args = args or {}
  gridPage._init(self, args)
  local grid = self.gridControl
  grid.AutoGenerateColumns = false
  grid.AutoSizeColumnsMode = AutoSizeColumnsMode.Fill
  grid.ColumnHeadersVisible = false
  grid.RowHeadersVisible = false
  self.rawFile = args.rawFile
  
  if not args.skipInit then self:ShowTune() end
end

function tunePage:ShowTune(args)
  args = args or {}
  if not self.rawFile then
    print ("No rawFile available")
    return nil
  end
  local rawFile = self.rawFile
  local tune = rawFile:GetTuneData(1)   -- '1' is for mass spectrometer tune file
  
  -- Since this is a key/value table, the order is indeterminate
  -- So alphabetize for consistent presentation
  local sorted = {}
  for key, value in pairs(tune) do
    table.insert(sorted, {key, value})
  end
  table.sort(sorted, function(a,b) return a[1] < b[1] end)

  self:Fill(sorted)
end

return tunePage
