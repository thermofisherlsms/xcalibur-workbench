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

-- Tartare.lua
-- This is a framework to recreate RawMeat functionality

-- Load necessary libraries
local RawFile = require("LuaRawFile")
local menu = require("menu")
local mdiNoteBook = require("mdiNoteBook")

-- Get constructors
local Button = luanet.import_type("System.Windows.Forms.Button")
local OpenDialog = luanet.import_type("System.Windows.Forms.OpenFileDialog")
local FolderBrowserDialog = luanet.import_type("System.Windows.Forms.FolderBrowserDialog")
local ProgressBar = luanet.import_type("System.Windows.Forms.ProgressBar")
local Form = luanet.import_type("System.Windows.Forms.Form")
local Label = luanet.import_type("System.Windows.Forms.Label")

-- Get enumerations
local DialogResult = luanet.import_type("System.Windows.Forms.DialogResult")
local ProgressBarStyle = luanet.import_type("System.Windows.Forms.ProgressBarStyle")
local ContentAlignment = luanet.import_type("System.Drawing.ContentAlignment")
local FormStartPosition = luanet.import_type("System.Windows.Forms.FormStartPosition")

-- forward declarations for local functions
local MenuCheck, ProcessList, ShowMenu

-- Local variables
local cycleNumber = 1
local progressDialog = {}
local cancelProcessing = false
local modulesName = "Modules"
local registeredReports = {}

-- Create the table for the Tartare module
-- It has one public function, which is register()
local Tartare = {}

-- Make a histogram plot of supplied data
function Tartare.histogram(args)
  args = args or {}
  if not args.pane or not args.data or not args.key then
    print ("Usage: Tartare.histogram({data = dataTable, pane = zPane, key = string})")
    return nil
  end
  local pane = args.pane
  local data = args.data
  local key = args.key
  local maxValue = args.maxValue or -1
  local minValue = args.minValue or 1e10
  if maxValue == -1 then
    for _, result in ipairs(data) do
      for _, entry in ipairs(result) do
        maxValue = math.max(maxValue, entry[key])
        minValue = math.min(minValue, entry[key])
      end
    end
  end
  if args.logScale then
    maxValue = math.log10(maxValue)
    minValue = math.log10(minValue)
  end
  local xRange = maxValue - minValue
  
  local binCount
  if args.integer then
    binCount = math.floor(maxValue)
  else
    binCount = args.binCount or 100
  end
  
  for fileIndex, result in ipairs(data) do
    -- Make Histogram Data Table
    local histData = {}
    for n = 0, binCount + 1 do        -- Include a zero bin and sentry on top
      local xValue = minValue + (xRange * n) / binCount
      if args.integer then xValue = math.floor(xValue) end
      table.insert(histData, {x = xValue, count = 0})
    end
    for _, entry in ipairs(result) do
      -- Add one because of zero bin in first position
      local value = entry[key]
      if args.logScale then value = math.log10(value) end
      local binIndex = math.ceil((value - minValue) / xRange * binCount) + 1
      if not histData[binIndex] then
        print (string.format("Bin Count: %d Bad Index: %d", #histData, binIndex))
        print (string.format("MinValue: %f MaxValue: %f", minValue, maxValue))
        print (string.format("This Value: %f XRange: %f", value, xRange))
      end
      histData[binIndex].count = histData[binIndex].count + 1
    end
    -- Remove empty bins
    local i = 1
    while i <= #histData do
      if histData[i].count == 0 then
        table.remove(histData, i)
      else
        i = i + 1
      end
    end
    -- Plot the data
    pane:AddXYTable({data = histData, xKey = "x", yKey = "count",
                    seriesType = args.seriesType, index = fileIndex, name = result.fileName})
    Application.DoEvents()
  end
end

-- Register a table that will generate a page in the Tartare report notebook
function Tartare.register(reportTable)
  if type(reportTable.name) ~= "string" then
    print ("Tartare.register: Report is missing name")
    return nil
  end

  local requiredFunctions = {"processFile", "generateReport"}
  for _, functionName in ipairs(requiredFunctions) do
    if type(reportTable[functionName]) ~= "function" then
      print (string.format("Tartare.register: %s is missing %s function", reportTable.name, functionName))
      return nil
    end
  end
  
  -- If this is the first time register is called, display the menu options
  if #registeredReports == 0 then
    ShowMenu()
  end
  table.insert(registeredReports, reportTable)
  
  -- Add this report to the modules sub-menu
  reportTable.menuItem = menu.AddMenu({name = reportTable.name, parentName = modulesName, callBack = MenuCheck})
  -- Careful of the syntax here, we want nil to show up enabled
  if reportTable.enabled ~= false then
    reportTable.menuItem.Checked = true
  end
  
  return true
end

-- Make a time plot of supplied data
function Tartare.timePlot(args)
  args = args or {}
  if not args.pane or not args.data or not args.key then
    print ("Usage: Tartare.timePlot({data = dataTable, pane = zPane, key = string})")
    return nil
  end
  local pane = args.pane
  local data = args.data
  local key = args.key
  local averageTime = args.averageTime or 1 -- RT is in minutes
  
  for fileIndex, result in ipairs(data) do
    -- Make Time Plot Data Table
    local timeData = {}
    local sum = 0
    local count = 0
    local nextTime = averageTime
    for _, entry in ipairs(result) do
      if entry.rt > nextTime then
        if count > 0 then
          table.insert(timeData, {x = nextTime, y = sum / count})
        end
        nextTime = nextTime + averageTime
        sum = 0
        count = 0
      end
      sum = sum + entry[key]
      count = count + 1
    end
    -- Include the last time window
    if count > 0 then
      table.insert(timeData, {x = nextTime, y = sum / count})
    end
    -- Plot the data
    pane:AddXYTable({data = timeData, xKey = "x", yKey = "y",
                    index = fileIndex, name = result.fileName})
    Application.DoEvents()
  end
end

local function CancelCB()
  cancelProcessing = true
end

local function CreateProgressDialog()
  -- Create a modal dialog
  local form = Form()
  form.Text = "Tartare Progress"
  form.Width = 400
  form.Height = 200
  form.ControlBox = false
  form.StartPosition = FormStartPosition.CenterScreen
  progressDialog.form = form
  
  -- Add file label
  local fileLabel = Label()
  fileLabel.Parent = form
  fileLabel.Left = 0
  fileLabel.Top = 10
  fileLabel.Height = 20
  fileLabel.Width = form.Width
  fileLabel.TextAlign = ContentAlignment.MiddleCenter
  progressDialog.fileLabel = fileLabel
  
  -- Add process label
  local processLabel = Label()
  processLabel.Parent = form
  processLabel.Left = 0
  processLabel.Top = 30
  processLabel.Height = 20
  processLabel.Width = form.Width
  processLabel.TextAlign = ContentAlignment.MiddleCenter
  progressDialog.processLabel = processLabel
  
  -- Add the progress bar
  local bar = ProgressBar()
  bar.Parent = form
  bar.Visible = true
  bar.Minimum = 0
  bar.Step = 1
  bar.Height = 50
  bar.Width = 300
  bar.Top = 60
  bar.Left = 50
  bar.Style = ProgressBarStyle.Continuous
  progressDialog.bar = bar
  
  -- Add the Cancel Button
  local cancelButton = Button()
  cancelButton.Text = "Cancel"
  cancelButton.Left = 160
  cancelButton.Width = 80
  cancelButton.Top = 120
  cancelButton.Click:Add(CancelCB)
  cancelButton.Parent = form
end

-- This has a forward declaration
function MenuCheck(sender, event)
  sender.Checked = not sender.Checked
end

local function OnDirectory()
  --[[
  local dialog = FolderBrowserDialog()                                -- Create the dialog
  dialog.Description = "Tartare Folder Selector"
  print ("Attemping ShowDialog()")
  -- For some reason, this call hangs without showing the dialog
  -- I could not find anything on Google that would explain how to fix this
  local result = dialog:ShowDialog()                                  -- Show modal dialog
  if result ~= DialogResult.OK then return end
  local directory = dialog.SelectedPath
  print ("Directory: ", directory)
  dialog:Dispose()
  --]]
  -- This was suggested on the web, and it works, but is confusing
  -- because the user must know to go into the directory then click open
  -- without selecting a file
  local dialog = OpenDialog()                                         -- Create the dialog
  dialog.ValidateNames = false
  dialog.CheckFileExists = false
  dialog.CheckPathExists = true
  dialog.FileName = "Folder Selection."
  -- Due to some .NET anomoly, the file dialog will not show up when running
  -- with LuaJIT as the interpreter.  Lord Google suggested setting the ShowHelp
  -- property to resolve it.  Unbelievable, but it works
  dialog.ShowHelp = true                                              -- Workaround for dialog not being visible

  local result = dialog:ShowDialog()                                  -- Show modal dialog
  if result == DialogResult.OK then
    print ("Dialog returned OK")
  end
  dialog:Dispose()
  --ProcessList(rawFileList)
end

local function OnFiles()
  local dialog = OpenDialog()                                         -- Create the dialog
  dialog.Filter = "Raw files (*.raw)|*.raw|All files (*.*)|*.*"       -- Set the filter
  dialog.Multiselect = true                                           -- Allow selection of more than one file
  -- Due to some .NET anomoly, the file dialog will not show up when running
  -- with LuaJIT as the interpreter.  Lord Google suggested setting the ShowHelp
  -- property to resolve it.  Unbelievable, but it works
  dialog.ShowHelp = true                                              -- Workaround for dialog not being visible

  local result = dialog:ShowDialog()                                  -- Show modal dialog
  local rawFileList = {}
  if result == DialogResult.OK then
    -- Load Lua files one by one through the console
    for i = 1, dialog.FileNames.Length do
      table.insert(rawFileList, {fileName = dialog.FileNames[i-1]})      -- Get the file name
    end
  end
  dialog:Dispose()
  ProcessList(rawFileList)
end

local function OnNotebooks()
  -- Make a list of all open rawFiles
  local rawFileList = {}
  for _, noteBook in ipairs(mdiNoteBook.noteBookList) do
    local rawFile = noteBook.rawFile
    if rawFile then table.insert(rawFileList, {rawFileObject = rawFile,
                                              fileName = noteBook.fullFileName}) end
  end
  ProcessList(rawFileList)
end

-- This function has a forward declaration
function ProcessList(list)
  progressDialog.form:Show()
  progressDialog.bar.Maximum = #list * #registeredReports
  progressDialog.bar.Value = 0
  Application.DoEvents()
  
  --Create list of active reports
  local activeReports = {}
  for _, report in ipairs(registeredReports) do
    if report.menuItem.Checked then
      table.insert(activeReports, report)
    end
  end
  
  -- Process the files
  for fileIndex, item in ipairs(list) do
    -- Find a backslash followed by anthing other than a backslash,
    -- right before the end of the string
    local index = string.find(item.fileName, "\\[^\\]*$")
    local shortFileName
    if index then
      shortFileName = string.sub(item.fileName, index + 1)
    else
      shortFileName = item.fileName
    end
    progressDialog.fileLabel.Text = shortFileName
    Application.DoEvents()
    
    if not item.rawFileObject then
      progressDialog.processLabel.Text = "Opening"
      Application.DoEvents()
      item.rawFileObject = RawFile.New(item.fileName)
      if type(item.rawFileObject) ~= "userdata" then
        print ("Unable to open " .. item.fileName)
        print (item.rawFile)
        progressDialog.form:Hide()
        return nil
      end
      item.rawFileObject:Open()
      if not item.rawFileObject.IsOpen then
        print ("Unable to open " .. item.rawFileObject)
        progressDialog.form:Hide()
        return nil
      end
      item.needToClose = true
    end
    
    -- Loop through and have each report process this raw file
    for step, report in ipairs(activeReports) do
      local processText = string.format("%s Step %d of %d", report.name,
                        (fileIndex-1) * #activeReports + step, #activeReports * #list)
      progressDialog.processLabel.Text = processText
      Application.DoEvents()
      report.processFile(item.rawFileObject, shortFileName, fileIndex == 1)
      progressDialog.bar:PerformStep()
      Application.DoEvents()
      if cancelProcessing then break end
    end
    if item.needToClose then item.rawFileObject:Close() end
  end
  progressDialog.processLabel.Text = ""
  progressDialog.fileLabel.Text = ""
  progressDialog.form:Hide()
  
  if cancelProcessing then
    cancelProcessing = false
    return
  end
  
  --Generate the notebook pages for the reports
  local resultNotebook = mdiNoteBook({title = string.format("Tartare #%d", cycleNumber)})
  cycleNumber = cycleNumber + 1
  for _, report in ipairs(registeredReports) do
    report.generateReport(resultNotebook)
  end
end

-- This function has a forward declaration
function ShowMenu()
  -- Set up the menu for accessing these routines
  local thisParentName = "Tartare"
  menu.AddMenu({name = thisParentName, parentName = "Tools"})   -- Add submenu to Tools
  menu.AddMenu({name = "All Notebooks", parentName = thisParentName, callBack = OnNotebooks})
  menu.AddMenu({name = "Files ...", parentName = thisParentName, callBack = OnFiles})
  -- This doesn't work right so not allowing it as an option
  --menu.AddMenu({name = "Directory ...", parentName = thisParentName, callBack = OnDirectory})
  menu.AddMenu({name = modulesName, parentName = thisParentName})
end

CreateProgressDialog()


-- Return the module
return Tartare
