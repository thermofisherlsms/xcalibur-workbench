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

-- gridPage.lua
-- a tabPage with a grid object

-- Load necessary libraries
local tabPage = require("tabPage")

-- Get assemblies
luanet.load_assembly ("System.Windows.Forms")

-- Get constructors
local Grid = luanet.import_type("System.Windows.Forms.DataGridView")

-- Get enumerations
local DockStyle = luanet.import_type("System.Windows.Forms.DockStyle")  -- Get the enumeration

-- local variables

-- forward declarations for local functions

-- local functions

-- Start of plotPage Object
local gridPage = {}
gridPage.__index = gridPage
setmetatable(gridPage, {
    __index = tabPage,    -- this is the inheritance
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end, })

function gridPage:_init(args)
  args = args or {}
  tabPage._init(self, args)
  self.gridControl = Grid()
  self.gridControl.Dock =  DockStyle.Fill
  self.pageControl.Controls:Add(self.gridControl)
end

-- Fill grid with a table formatted as
-- {{a1,a2}, {b1,b2}, {c1, c2}}
-- Must be a rectangular table
function gridPage:Fill(data)
  if #data < 1 then
    data[1] = {"No Data"}
  end
  local grid = self.gridControl
  grid.Rows:Clear()
  grid.ColumnCount = #data[1]     -- Width comes from size of first row
  grid.RowCount = #data
  for rowIndex, row in ipairs(data) do
    for columnIndex, value in ipairs(row) do
      grid.Rows[rowIndex-1].Cells[columnIndex-1].Value = tostring(value)
    end
  end
end

-- Fill Row Header with table data
function gridPage:FillHeaderRow(header)
  local grid = self.gridControl
  grid.ColumnCount = #header
  for columnIndex, value in ipairs(header) do
    grid.Columns[columnIndex-1].HeaderCell.Value = value
  end
end

return gridPage
