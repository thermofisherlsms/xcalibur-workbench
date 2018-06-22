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

-- workbench.lua

-- TODO  I'm keeping one big TODO list here instead of scattering throughout the code
-- Drag and drop of raw files
-- Tab Control Context Menu
--  New Page with type selector
--  Split Notebook and Flip page
--  Tear out to its own Notebook
--  Bind to a Notebook
-- Data page
-- Save Notebook and Restore Notebook
--    Allow drag for averaging spectra
--    Add marker to most recently clicked point
-- Utilities
--  Get Apex for lc utilities
-- Copy Lua command history to configuration file.
-- Clean up crash on close for LFW interpretter
-- headerPage
--  Respond to arrow keys to move scan number
--    This conflicts with normal use of arrow keys
-- properties
--  Clear up problem with combo box value disappearing on first click
--  Capture change in combobox and update grid
--  Nil string should turn into empty string
--  Enable start and end for chromatogram properties
-- msPane
--  Make distinct stick, line, and marker series

-- Load LuaInterface first.  Loading the module creates a global, so no
-- reason to keep it local here
luannet = require ("luanet")

-- Load the primary assembly here to make them available
-- for all other items started with "require"
luanet.load_assembly ("System.Windows.Forms")

-- Load necessary libraries
local configure = require("configure")
local menu = require("menu")
local templates = require("templates")
local mdiNoteBook = require("mdiNoteBook")
local properties = require("properties")

-- Get assemblies
luanet.load_assembly("System.Drawing")

-- Get constructors
local Form = luanet.import_type("System.Windows.Forms.Form")
local ComboBox = luanet.import_type("System.Windows.Forms.ComboBox")
local Panel = luanet.import_type("System.Windows.Forms.Panel")
local Button = luanet.import_type("System.Windows.Forms.Button")
local OpenDialog = luanet.import_type("System.Windows.Forms.OpenFileDialog")
local Screen = luanet.import_type("System.Windows.Forms.Screen")
local Label = luanet.import_type("System.Windows.Forms.Label")
local Font = luanet.import_type("System.Drawing.Font")

-- Get enumerations
local AnchorStyle = luanet.import_type("System.Windows.Forms.AnchorStyles")
local DockStyle = luanet.import_type("System.Windows.Forms.DockStyle")
local DropDownStyle = luanet.import_type("System.Windows.Forms.ComboBoxStyle")
local DialogResult = luanet.import_type("System.Windows.Forms.DialogResult")  -- Get the enumeration
local MdiLayout = luanet.import_type("System.Windows.Forms.MdiLayout")
local Shortcut = luanet.import_type("System.Windows.Forms.Shortcut")
local FormStartPosition = luanet.import_type("System.Windows.Forms.FormStartPosition")
local FormBorderStyle = luanet.import_type("System.Windows.Forms.FormBorderStyle")
local ContentAlignment = luanet.import_type("System.Drawing.ContentAlignment")

-- local variables
local comboBox, aboutForm

-- Forward declarations for local helper functions
local OKCB, RunCommandCB
local TileHorizontalCB, TileVerticalCB
local UndoCB

-- local functions
local function AboutBoxSetup()
  local version
  if type(jit) == "table" then
    version = jit.version
  else
    version = _VERSION
  end

  aboutForm = Form()
  aboutForm.Text = "About Xcalibur Workbench"
  aboutForm.Width = 400
  aboutForm.Height = 250
  aboutForm.ControlBox = false
  aboutForm.StartPosition = FormStartPosition.CenterScreen
  aboutForm.FormBorderStyle = FormBorderStyle.FixedSingle
  
  -- Add main label
  local mainLabel = Label()
  mainLabel.Parent = aboutForm
  mainLabel.Left = 0
  mainLabel.Top = 20
  mainLabel.Height = 100
  mainLabel.Width = aboutForm.Width
  mainLabel.TextAlign = ContentAlignment.MiddleCenter
  --mainLabel.FontHeight = 40
  mainLabel.Font = Font("Arial", 20)
  mainLabel.Text =
  [[Xcalibur Workbench
  Copyright 2016-2018
  Thermo Fisher Scientific]]
  
  -- Add version label
  local versionLabel = Label()
  versionLabel.Parent = aboutForm
  versionLabel.Left = 0
  versionLabel.Top = 120
  versionLabel.Height = 40
  versionLabel.Width = aboutForm.Width
  versionLabel.TextAlign = ContentAlignment.MiddleCenter
  versionLabel.Text = "Running using " .. version
  
  -- Add OK Button
  local OKButton = Button()
  OKButton.Text = "OK"
  OKButton.Top = 175
  OKButton.Left = 175
  OKButton.Click:Add(OKCB)
  aboutForm.Controls:Add(OKButton)
end

local function AboutCB(sender, args)
    aboutForm:Show()
end

local function AddCommandBar()
  local panel = Panel()
  panel.Dock = DockStyle.Bottom
  panel.AutoSize = true
  mainForm.Controls:Add(panel)

  comboBox = ComboBox()
  comboBox.DropDownStyle = DropDownStyle.DropDown
  comboBox.Dock = DockStyle.Bottom
  panel.Controls:Add(comboBox)

  local button = Button()
  button.Text = "Execute"
  button.Dock = DockStyle.Left
  button.Click:Add(RunCommandCB)
  -- Don't show the button.  Just use for accepting Enter keystrokes
  --panel.Controls:Add(button)
  mainForm.AcceptButton = button    -- Make this the default button
end

local function CascadeCB(sender, args)
  mainForm:LayoutMdi(MdiLayout.Cascade)
end

local function CloseNotebookCB(sender, args)
  local noteBook = mainForm.ActiveMdiChild.Tag                   -- This is the active mdiNoteBook
  if noteBook then noteBook:Close() end
  return
end

-- When the parent form closes, all the Mdi Children should
-- have their close events triggered, so we don't really need
-- to do any cleanup here.  But it doesn't appear to work that way
-- so I'm going to close the pages manually
local function ClosingCB(sender, args)
  while mainForm.ActiveMdiChild do
    local noteBook = mainForm.ActiveMdiChild.Tag
    noteBook:Close()
  end
end

local function ConsoleCB(sender, args)
  print ("Breaking for ZBS Console")
  -- See if a debug hook is set.  If so, the debugger is running
  -- If so, pause, so the user doesn't have to set a breakpoint
  -- If not, start the debugger, which will force a break
  local debugging = debug.gethook()
  local mobdebug = mobdebug or require("mobdebug")  -- Load the debugging library
  if not debugging then
    mobdebug.start()                                  -- Start the debugger, this will break at the next line
    mobdebug.off()                                    -- Turn it back off to avoid speed issues
  else
    mobdebug.pause()                                  -- Just pause, this will break at the next line
  end
  print ("Restarting MessageQueue")
end

local function ExitCB(sender, args)
  mainForm:Close()
end

local function LoadLuaCB(sender, args)
  local dialog = OpenDialog()                                         -- Create the dialog
  dialog.Filter = "Lua files (*.lua)|*.lua|All files (*.*)|*.*"       -- Set the filter
  dialog.Multiselect = true                                           -- Allow selection of more than one file
  -- Due to some .NET anomoly, the file dialog will not show up when running
  -- with LuaJIT as the interpreter.  Lord Google suggested setting the ShowHelp
  -- property to resolve it.  Unbelievable, but it works
  dialog.ShowHelp = true                                              -- Workaround for dialog not being visible

  local result = dialog:ShowDialog()                                  -- Show modal dialog
  if result == DialogResult.OK then
    -- Load Lua files one by one through the console
    for i = 1, dialog.FileNames.Length do
      local fileName = dialog.FileNames[i-1]                          -- Get the file name
      fileName = fileName:gsub([[\]], [[\\]])                         -- replace single slash with double slash
      comboBox.Text = string.format("dofile('%s')", fileName)         -- put the command in the console
      RunCommandCB()                                                  -- trigger the execution
      Application.DoEvents()                                          -- Process the message queue to update the GUI
    end
  end
  dialog:Dispose()
end

local function LoadOtherFiles(directory)
	local lastChar = string.sub(directory, -1)			            -- check last character
	if lastChar ~= "\\" then directory = directory .. "\\" end	-- Add backslash if not includes
  local command = directory						                        -- set initial command
  command = command .. "*.lua"                                -- add filter to directory
  command = '"' .. command .. '"'                             -- put quotes around the directory and filter command
	command = "dir " .. command.. " /b"					                -- complete command
	--print ("Running command: ", command)
	local files = {}
	local popen = io.popen
	for fileName in popen(command):lines() do
		table.insert(files, fileName)
	end
  for index, fileName in ipairs(files) do
    print ("Loading file: ", fileName)
    dofile(directory .. fileName)
  end
end

-- This has a forward declaration
function OKCB(sender, args)
  aboutForm:Hide()
end

local function OpenCB(sender, args)
  local dialog = OpenDialog()                                         -- Create the dialog
  dialog.Filter = "Raw files (*.raw)|*.raw|All files (*.*)|*.*"       -- Set the filter
  dialog.Multiselect = true                                           -- Allow selection of more than one file
  -- Due to some .NET anomoly, the file dialog will not show up when running
  -- with LuaJIT as the interpreter.  Lord Google suggested setting the ShowHelp
  -- property to resolve it.  Unbelievable, but it works
  dialog.ShowHelp = true                                              -- Workaround for dialog not being visible

  local result = dialog:ShowDialog()                                  -- Show modal dialog
  if result == DialogResult.OK then
    -- Create a new notebook using the default template
    local args = {}
    for key, value in pairs(templates.default) do
        args[key] = value
    end
    for i = 1, dialog.FileNames.Length do
      args.fileName = dialog.FileNames[i-1]                           -- Use base-0 indexing here
      mdiNoteBook(args)
      Application.DoEvents()                                          -- Process the message queue so files are shown
    end
  end
  dialog:Dispose()
end

local function PropertiesCB(sender, args)
  properties.ShowForm()
end

-- This has a forward declaration
function RunCommandCB()
  local f, err = loadstring(comboBox.Text)
  if not f then
    print (err)
    return
  end
  local result, err = pcall(f)
  if not result then
    print (err)
    return
  end
  comboBox.Items:Add(comboBox.Text)
  print (comboBox.Text)                 -- Print the command
  print ("Result: ", err)               -- This is the result of the function execution, not really an error
  comboBox:Focus()                      -- Call Focus() method.  This will select all the text to simplify further editing.
  return
end

local function SetUpMenu()
  -- Attach the menu to the form
  mainForm.Menu = menu.mainMenu

  -- Create some menus, and add them to the main menu.
  menu.AddMenu({name = "File", label = "&File"})
  menu.AddMenu({name = "Edit"})
  menu.AddMenu({name = "Tools"})
  local mdiMenu = menu.AddMenu({name = "Windows"})
  mdiMenu.MdiList = true                                  -- Set MDI flag
  menu.AddMenu({name = "Help", label = "&Help"})

  -- Add menu items to File
  menu.AddMenu({name = "Open", label = "&Open...", parentName = "File", callBack = OpenCB})
  menu.AddMenu({name = "Templates", parentName = "File"})
  menu.AddMenu({name = "Sep1", label = "-", parentName = "File"})
  menu.AddMenu({name = "Close Notebook", parentName = "File", callBack = CloseNotebookCB})
  menu.AddMenu({name = "Sep2", label = "-", parentName = "File"})
  menu.AddMenu({name = "Load", label = "Load Lua...", parentName = "File", callBack = LoadLuaCB})
  menu.AddMenu({name = "Exit", label = "E&xit", parentName = "File", callBack = ExitCB})

  -- Add menu items to Edit
  menu.AddMenu({name = "Undo", label = "Undo", parentName = "Edit", callBack = UndoCB,
                  shortCut = Shortcut.CtrlZ})
  menu.AddMenu({name = "Properties", label = "Properties...", parentName = "Edit", callBack = PropertiesCB})

  -- Add menu items to Tools
  menu.AddMenu({name = "ZBS Console", parentName = "Tools", callBack = ConsoleCB})

  -- Add menu items to Windows
  menu.AddMenu({name = "Cascade", parentName = "Windows", callBack = CascadeCB})
  menu.AddMenu({name = "Tile Horizontal", parentName = "Windows", callBack = TileHorizontalCB})
  menu.AddMenu({name = "Tile Vertical", parentName = "Windows", callBack = TileVerticalCB})
  menu.AddMenu({name = "Sep3", label = "-", parentName = "Windows"})
  
  -- Add menu items to Help
  menu.AddMenu({name = "About...", parentName = "Help", callBack = AboutCB})
  
end

-- This has a forward declaration
function TileHorizontalCB(sender, args)
  mainForm:LayoutMdi(MdiLayout.TileHorizontal)
end

-- This has a forward declaration
function TileVerticalCB(sender, args)
  mainForm:LayoutMdi(MdiLayout.TileVertical)
end

-- This has a foward declaration
function UndoCB(sender, args)
  local noteBook = mainForm.ActiveMdiChild.Tag                   -- This is the active mdiNoteBook
  if not noteBook then return end
  local page = noteBook.pageList.active
  if not page then return end
  page:Undo()
  return
end

-- This is a global so that slow Lua routines can call Application.DoEvents()
-- This is not an instance of the class, so use "." notation for methods, not ":"
Application = luanet.import_type("System.Windows.Forms.Application")

mainForm = Form()
mainForm.Text = "Xcalibur Workbench"
mainForm.IsMdiContainer = true
SetUpMenu()
mainForm.Closing:Add(ClosingCB)
-- Can't seem to do drag and drop in Win7
-- Something about different privaleges between
-- Explorer and Lua
--mainForm.AllowDrop = true
--mainForm.DragDrop:Add(DragDropCB)
templates.InitializeTemplates()
-- Set to eat up a bunch of the screen
local workingArea = Screen.FromControl(mainForm).WorkingArea
mainForm.Height = workingArea.Height * 0.8
mainForm.Width = workingArea.Width * 0.8

AddCommandBar()
AboutBoxSetup()


-- Users can load the utilities with require()
-- This will make sure they are found by the search path
package.path = package.path .. ";".. configure.utilityDirectory .. "/?.lua"
LoadOtherFiles(configure.userDirectory)
LoadOtherFiles(configure.tartareDirectory)

-- Calling mainForm:ShowDialog() does not reliably show the form.
-- This appears to be related to the form being a Mdi Parent.  To
-- get the form started reliably, show it then start the message
-- queue with Application.Run()
mainForm.StartPosition = FormStartPosition.CenterScreen
mainForm.Visible = true
mainForm:Show()

-- Load files if passed as arguments
local fileNumber = 1
while arg[fileNumber] do
  -- Create a new notebook using the default template
  mdiNoteBook({fileName = arg[fileNumber], AddPages = templates.default.AddPages})
  fileNumber = fileNumber + 1
end

-- Start the Message Queue with a pcall, using anonymous function syntax
local success, result = pcall (function() Application.Run(mainForm); return true end)
print ("Success: ", success)
print ("Result: ", result)

-- Is this required?
--mainForm:Dispose()
print ("Program Complete")


