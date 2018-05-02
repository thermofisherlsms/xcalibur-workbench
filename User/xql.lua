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

-- xql.lua
-- Dialog to execute XQL queries

-- Load necessary libraries
local menu = require("menu")
local mdiNoteBook = require("mdiNotebook")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Get assemblies

-- Get constructors
local Form = luanet.import_type("System.Windows.Forms.Form")
local Button = luanet.import_type("System.Windows.Forms.Button")
local Label = luanet.import_type("System.Windows.Forms.Label")
local TextBox = luanet.import_type("System.Windows.Forms.TextBox")
local MessageBox = luanet.import_type("System.Windows.Forms.MessageBox")

-- Get enumerations
local DockStyle = luanet.import_type("System.Windows.Forms.DockStyle")
local TabAlignment = luanet.import_type("System.Windows.Forms.TabAlignment")

-- local variables
local xqlDialog, selectText, whereText
local cancelButton, runButton

-- forward declarations for local functions
local RunCB

-- local functions
local function CancelCB()
  xqlDialog.Visible = false
end

local function InitializeButtons()
  -- Initialize buttons
  runButton = Button()
  runButton.Text = "Run"
  runButton.Width = 80
  -- Centered 1/3 of the way over
  runButton.Left = (xqlDialog.Width / 3) - runButton.Width / 2
  -- 10% up from bottom
  runButton.Top = xqlDialog.Height - 3 * runButton.Height
  --runButton.IsDefault = true
  runButton.Click:Add(RunCB)
  xqlDialog.Controls:Add(runButton)

  cancelButton = Button()
  cancelButton.Text = "Cancel"
  cancelButton.Width = 80
  -- Centered 2/3 of the way over
  cancelButton.Left = (2 * xqlDialog.Width / 3) - cancelButton.Width / 2
  cancelButton.Top = xqlDialog.Height - 3 * runButton.Height
  cancelButton.Click:Add(CancelCB)
  xqlDialog.Controls:Add(cancelButton)
  xqlDialog.AcceptButton = runButton
  xqlDialog.CancelButton = cancelButton
end

local function InitializeForm()
  xqlDialog = Form()
  xqlDialog.Text = "XQL Query"
  xqlDialog.Height = 300
  xqlDialog.Width = 600
  
  local selectLabel = Label()
  xqlDialog.Controls:Add(selectLabel)
  selectLabel.Text = "SELECT"
  selectLabel.Left = xqlDialog.Width / 40
  selectLabel.Top = 10
  
  selectText = TextBox()
  xqlDialog.Controls:Add(selectText)
  selectText.Text = ""
  selectText.Multiline = true
  selectText.Left = selectLabel.Left + selectLabel.Width
  selectText.Top = 10
  selectText.Width = xqlDialog.Width * 0.75
  selectText.Height = xqlDialog.Height / 3
  
  local whereLabel = Label()
  xqlDialog.Controls:Add(whereLabel)
  whereLabel.Text = "WHERE"
  whereLabel.Left = selectLabel.Left
  whereLabel.Top = xqlDialog.Height * 0.4
  
  whereText = TextBox()
  xqlDialog.Controls:Add(whereText)
  whereText.Text = ""
  whereText.Multiline = true
  whereText.Left = selectText.Left
  whereText.Top = whereLabel.Top
  whereText.Width = selectText.Width
  whereText.Height = selectText.Height
  
end

-- This has a forward declaration
function RunCB()
  local activeNotebook = mdiNoteBook.GetActiveNoteBook()
  if not activeNotebook then
    print ("No active Notebook")
    return
  end
  
  print ("Running XQL Query")
  local query = string.format("SELECT %s", selectText.Text)
  if whereText.Text ~= "" then
    query = query .. string.format(" WHERE %s", whereText.Text)
  end
  print (query)
  xqlDialog.Visible = false
end

local function RunQuery()
  xqlDialog.Visible = true
end

-- Set up the menu for accessing these routines
local thisParentName = "XQL"
local xqlMenu = menu.AddMenu({name = thisParentName, parentName = "Tools"})
local query = menu.AddMenu({name = "Run Query", parentName = thisParentName, callBack = RunQuery})

InitializeForm()
InitializeButtons()
