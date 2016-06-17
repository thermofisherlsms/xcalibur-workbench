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

-- properties.lua
-- Object for filling and retrieving values in a property page
-- Not to be used as a direct object, but methods should be inherited

-- Load necessary libraries

-- Get assemblies
luanet.load_assembly("System.Data")

-- Get constructors
local Button = luanet.import_type("System.Windows.Forms.Button")
local Form = luanet.import_type("System.Windows.Forms.Form")
local Grid = luanet.import_type("System.Windows.Forms.DataGridView")
local Panel = luanet.import_type("System.Windows.Forms.Panel")
local ComboCell = luanet.import_type("System.Windows.Forms.DataGridViewComboBoxCell")
local Cell = luanet.import_type("System.Windows.Forms.DataGridViewCell")
local Row = luanet.import_type("System.Windows.Forms.DataGridViewRow")

-- Get enumerations
local AutoSizeColumnsMode = luanet.import_type("System.Windows.Forms.DataGridViewAutoSizeColumnsMode")
local DockStyle = luanet.import_type("System.Windows.Forms.DockStyle")  -- Get the enumeration
local RowHeaderModes = luanet.import_type("System.Windows.Forms.DataGridViewRowHeadersWidthSizeMode")

-- local variables
local properties = {}
local currentPropertyList
local cancelButton
local propertyForm
local grid
local okButton
local panel
local useCombo = true

-- forward declarations for local functions
local OKCB, ValidateCB

-- local functions
local function CancelCB(sender, args)
  propertyForm.Visible = false        -- Hide the form
  properties.UpdatePropertyForm()     -- Redraw to overwrite any changes
end

-- Use the convoluted method of getting the active page
-- instead of a call to mdiNoteBook.noteBookList.active,
-- since require("mdiNotebook") results in a circular reference
local function GetActivePage()
  local mdiChild = mainForm.ActiveMdiChild
  if not mdiChild or not mdiChild.Tag
    or not mdiChild.Tag.pageList.active then
      return nil
  end
  return mdiChild.Tag.pageList.active
end

-- Data grid cells with comboboxes throw an
-- odd exception which doesn't seem to matter
-- so I'll just capture and ignore for now
local function IgnoreErrorCB()
  return
end

local function InitializeButtons()
  -- Intialize the panel
  panel = Panel()
  propertyForm.Controls:Add(panel)
  panel.Dock = DockStyle.Bottom
  panel.Height = 40

  -- Initialize buttons
  okButton = Button()
  okButton.Text = "OK"
  okButton.Left = 25
  okButton.Width = 80
  okButton.Top = 10
  okButton.IsDefault = true
  okButton.Click:Add(OKCB)
  panel.Controls:Add(okButton)

  cancelButton = Button()
  cancelButton.Text = "Cancel"
  cancelButton.Left = 130
  cancelButton.Width = 80
  cancelButton.Top = 10
  cancelButton.Click:Add(CancelCB)
  panel.Controls:Add(cancelButton)
  propertyForm.AcceptButton = okButton
  propertyForm.CancelButton = cancelButton
end

local function InitializeGrid()
  grid = Grid()
  propertyForm.Controls:Add(grid)
  grid.Dock =  DockStyle.Fill
  grid.RowHeadersWidthSizeMode = RowHeaderModes.AutoSizeToAllHeaders
  grid.ColumnHeadersVisible = false
  grid.AllowUserToAddRows = false
  grid.AutoGenerateColumns = false
  grid.ShowCellToolTips = true
  grid.AutoSizeColumnsMode = AutoSizeColumnsMode.Fill
  grid.ColumnCount = 1
  --grid.CellValidating:Add(ValidateCB)
  grid.DataError:Add(IgnoreErrorCB)
end

-- This has a forward declaration
function OKCB(sender, args)
  local page = GetActivePage()
  if page then page:SetProperties() end
end

-- This has a forward declaration
function ValidateCB(sender, args)
  local gridRow = grid.Rows[args.RowIndex]
  local validValue = gridRow.Cells[0].Value
  local propertyIndex = args.RowIndex + 1         -- Convert back to base 1
  local property = currentPropertyList[propertyIndex]
  if property.min or property.max then validValue = tonumber(validValue) end
  if property.min then validValue = math.max(property.min, validValue) end
  if property.max then validValue = math.min(property.max, validValue) end
  property.value = validValue
  -- I've validate the value, but I don't seem to be able to change the display
  -- with the following line or any of the lines below it
  gridRow.Cells[0].Value = tostring(validValue)
  --grid:InvalidateCell(0,args.RowIndex)
  --grid:RefreshEdit()
  --grid:Invalidate()
end

function properties:AddProperty(args)
  args = args or {}
  local function trueFunction() return true end

  args.modeTest = args.modeTest or trueFunction
  table.insert(self.propertyList, args)
  -- Duplicate the entries using the label as a key
  -- This makes working back from the grid fairly simple
  -- Keep the original integer indexing, because this controls
  -- the order the properties are displayed
  self.propertyList[args.label] = args
  -- Create a grid row and populate here.
  -- The just add rows to the grid on update
end

-- self here is the table that will inherit methods
-- from properties.  Only inherit methods that don't
-- already exist, so that we have the concept of
-- overriding methods.  This should be called with the
-- . notation, not the : notation
function properties.Inherit(self)
  self.propertyList = {}
  self.undoStack = {}
  
  for key, value in pairs(properties) do
    if type(value) == "function" and        -- If the entry in the properties table is a function AND
      not self[key] then                    -- the function does not exist in the inheriting table then
        self[key] = value                   -- inherit the function
    end
  end
end

-- Pop the current properties from the undo stack
function properties:PopProperties(apply)
  local pop = table.remove(self.undoStack)
  if apply then
    for key, value in pairs(pop) do
      self[key] = value
    end
  end
end

-- Push the current properties to the undo stack
function properties:PushProperties()
  local undo = {}
  for index, property in ipairs(self.propertyList) do
    undo[property.key] = self[property.key]
  end
  table.insert(self.undoStack, undo)
  --print ("Push Called for Self ", self, " with size", #self.undoStack)
end

-- Copy values out of the grid into the object
function properties:SetProperties()
  for i = 0, grid.RowCount - 1 do     -- Convert to base-0 for C
    local row = grid.Rows[i]
    local cell = row.Cells[0]
    local value = cell.Value
    -- Don't use the Tag.  It appears to cause memory
    -- access issues for some reason
    -- Instead I've set up keyed access to the propertyList based on the label
    local property = self.propertyList[row.HeaderCell.Value]
    if property.min or property.max then
      -- Validate a numeric value
      local newValue = tonumber(value)
      if not newValue then
        print (string.format("%s entry %s is not a number", row.HeaderCell.Value, value))
      else
        if property.min then newValue = math.max(newValue, property.min) end
        if property.max then newValue = math.min(newValue, property.max) end
        self[property.key] = newValue   -- Try to convert to a number
      end
    elseif property.options then
      -- Validate a string with limited options
      local match = false
      for index, option in ipairs(property.options) do
        if option == value then
          match = true
          break
        end
      end
      if not match then
        print (string.format("%s entry %s is not a valid option", row.HeaderCell.Value, value))
      else
        self[property.key] = value
      end
    else
      -- No validation required
      self[property.key] = tonumber(value) or value   -- Try to convert to a number
    end
  end
  self:SetPropertiesFinalize()
end

-- This will most likely be overridden by
-- the inheriting object
function properties:SetPropertiesFinalize()
end

function properties.ShowForm()
  propertyForm:Show()
end

function properties:Undo()
  local size = #self.undoStack
  if size <= 1 then return end          -- Don't ever undo the last set of properties
  self:PopProperties()                  --  Pop the current settings
  self:PopProperties(true)              -- Pop the prior settings and apply
  self:SetPropertiesFinalize()          -- This will push these settings again
end

-- Update the display of the property page
function properties:UpdatePropertyForm()
  --if true then return end
  grid.Rows:Clear()
  -- This can either be called from the object (ie. page:UpdatePropertyForm())
  -- or can be called directly (ie. properties.UpdatePropertyForm())
  -- If called directly, use the currently active page
  self = self or GetActivePage()
  if not self then return end
  propertyForm.Text = self:GetPropertyTitle() or "Page Properties"
  
  -- Now fill the grid with the active properties
  for index, property in ipairs(self.propertyList) do
    if property.modeTest(self.mode) then
      -- To include a combo box, you need to create a row
      -- add the combo box, and then add it to the grid
      -- This currently causes a whole bunch of problems, so
      -- for now it's disabled
      if useCombo then
        local thisRow = Row()
        if useCombo and property.options then
          local comboCell = ComboCell()           -- Create a DataGridViewComboBoxCell
          for _, option in ipairs(property.options) do
            comboCell.Items:Add(option)
          end
          thisRow.Cells:Add(comboCell)            -- Add this cell to the row
        end
        -- If we just use thisRow, it's considered shared and has restricted access
        -- Grabbing it below turns it into an unshared row
        grid.Rows:Add(thisRow)                    -- Add the row to the grid
      else
        grid.Rows:Add()
      end
      local row = grid.Rows[grid.RowCount - 1]
      row.HeaderCell.Value = tostring(property.label)
      row.ReadOnly = property.readOnly
      local cell = row.Cells[0]
      cell.Value = tostring(self[property.key])
      cell.ToolTipText = property.toolTip
      -- Don't use the Tag.  It appears to cause some corruption
      -- in .NET memory
      --cell.Tag = property                   -- Link back to the property
    end
  end

end

-- Code below here executes when require() is called
propertyForm = Form()
propertyForm.Text = "Page Properties"
propertyForm.ControlBox = false
propertyForm.TopMost = true
InitializeButtons()
InitializeGrid()

return properties
