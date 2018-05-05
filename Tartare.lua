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
local textPage = require("textPage")

-- Get constructors
local Button = luanet.import_type("System.Windows.Forms.Button")
local OpenDialog = luanet.import_type("System.Windows.Forms.OpenFileDialog")
local FolderBrowserDialog = luanet.import_type("System.Windows.Forms.FolderBrowserDialog")
local ProgressBar = luanet.import_type("System.Windows.Forms.ProgressBar")
local Form = luanet.import_type("System.Windows.Forms.Form")
local Label = luanet.import_type("System.Windows.Forms.Label")
local CheckedListBox = luanet.import_type("System.Windows.Forms.CheckedListBox")
local MainMenu = luanet.import_type("System.Windows.Forms.MainMenu")
local MenuItem = luanet.import_type("System.Windows.Forms.MenuItem")

-- Get enumerations
local DialogResult = luanet.import_type("System.Windows.Forms.DialogResult")
local ProgressBarStyle = luanet.import_type("System.Windows.Forms.ProgressBarStyle")
local ContentAlignment = luanet.import_type("System.Drawing.ContentAlignment")
local FormStartPosition = luanet.import_type("System.Windows.Forms.FormStartPosition")

-- forward declarations for local functions
local MenuCheck, ProcessList, ShowMenu, TrueFunction
local SelectAllCB, UnselectAllCB

-- Local variables
local cycleNumber = 1
local activeReportDialog = {}
local progressDialog = {}
local cancelProcessing = false
local registeredReports = {}
local errorMessage

-- Create the table for the Tartare module
-- It has one public function, which is register()
local Tartare = {}

-- Make a bin averaged plot of supplied data
-- Normally used to average over retention time
function Tartare.averagePlot(args)
  args = args or {}
  if not args.pane or not args.data or not args.yKey then
    print ("Usage: Tartare.averagePlot({data = dataTable, pane = zPane, yKey = string, [xKey = string, averageWidth = x, filterFunction = function]})")
    return nil
  end
  local pane = args.pane
  local data = args.data
  local yKey = args.yKey
  local xKey = args.xKey or "rt"              -- Retention tme is default
  local averageWidth = args.averageWidth or 1 -- RT is in minutes
  local filterFunction = args.filterFunction or TrueFunction
  
  for fileIndex, result in ipairs(data) do
    -- Make Time Plot Data Table
    local plotData = {}
    local sum = 0
    local count = 0
    local nextPoint = averageWidth
    local lastEntry = result[1]
    for _, entry in ipairs(result) do
      if filterFunction(entry) then
        if lastEntry[xKey] > entry[xKey] then
          print (string.format("tartare:averagePlot(): Data must be sorted on key '%s'", xKey))
          return
        end
        if entry[xKey] > nextPoint then
          if count > 0 then
            table.insert(plotData, {x = entry[xKey], y = sum / count})
          end
          nextPoint = entry[xKey] + averageWidth
          sum = 0
          count = 0
        end
        sum = sum + entry[yKey]
        count = count + 1
      end
    end
    -- Include the last time window
    if count > 0 then
      table.insert(plotData, {x = nextPoint, y = sum / count})
    end
    -- Plot the data
    pane:AddXYTable({data = plotData, xKey = "x", yKey = "y",
                    index = fileIndex, name = result.fileName})
    Application.DoEvents()
  end
end

-- Make a histogram plot of supplied data
function Tartare.histogram(args)
  args = args or {}
  if not args.pane or not args.data or not args.key then
    print ("Usage: Tartare.histogram({data = dataTable, pane = zPane, key = string [, filterFunction = function})")
    return nil
  end
  local pane = args.pane
  local data = args.data
  local key = args.key
  local filter = args.filterFunction or TrueFunction
  local maxValue = args.maxValue or -1
  local minValue = args.minValue or 1e10
  if maxValue == -1 then
    for _, result in ipairs(data) do
      for _, entry in ipairs(result) do
        if filter(entry) then
          maxValue = math.max(maxValue, entry[key])
          minValue = math.min(minValue, entry[key])
        end
      end
    end
  end
  if args.logScale then
    maxValue = math.log10(maxValue)
    minValue = math.log10(minValue)
  end
  local xRange = maxValue - minValue
  -- Special case of everything in one bin
  if xRange == 0 then
    if minValue == 0 then
      maxValue = 1
    else
      minValue = 0
    end
    xRange = maxValue - minValue
  end
  
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
      if filter(entry) then
        -- Add one because of zero bin in first position
        local value = entry[key]
        if args.logScale then value = math.log10(value) end
        local binIndex = math.ceil((value - minValue) / xRange * binCount) + 1
        if not histData[binIndex] then
          print (string.format("Bin Count: %d Bad Index: %d", #histData, binIndex))
          print (string.format("MinValue: %f MaxValue: %f", minValue, maxValue))
          print (string.format("This Value: %f XRange: %f", value, xRange))
          return
        end
        histData[binIndex].count = histData[binIndex].count + 1
      end
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
  -- Careful of the syntax here, we want nil to show up enabled
  if reportTable.enabled ~= false then reportTable.enabled = true end
  local items = activeReportDialog.listBox.Items
  items:Add(reportTable.name, reportTable.enabled)
  
  return true
end

function Tartare.reportError(newMessage)
  print (newMessage)
  -- Don't add a carriage return for the first error
  if string.len(errorMessage) > 0 then
    errorMessage = errorMessage .. "\r\n"
  end
  errorMessage = errorMessage .. newMessage
end

-- Reset to prior values
local function ActiveCancelCB()
  for index, reportTable in ipairs(registeredReports) do
    activeReportDialog.listBox:SetItemChecked(index-1, reportTable.enabled)
  end
  activeReportDialog.form:Hide()
end

-- Fetech new active reports
local function ActiveOKCB()
  for index, reportTable in ipairs(registeredReports) do
    reportTable.enabled = activeReportDialog.listBox:GetItemChecked(index-1)
  end
  activeReportDialog.form:Hide()
end

local function CancelCB()
  cancelProcessing = true
end

local function CreateActiveReportDialog()
  -- Create a dialog
  local form = Form()
  activeReportDialog.form = form
  form.Text = "Tartare Modules"
  form.Width = 300
  form.Height = 420
  form.StartPosition = FormStartPosition.CenterScreen
  
  -- Add Edit menu
  -- Attach the menu to the form
  local formMenu = MainMenu()
  form.Menu = formMenu
  local editItem = MenuItem("Edit")
  formMenu.MenuItems:Add(editItem)
  local selectItem = MenuItem("Select All")
  editItem.MenuItems:Add(selectItem)
  selectItem.Click:Add(SelectAllCB)
  local unselectItem = MenuItem("Unselect All")
  unselectItem.Click:Add(UnselectAllCB)
  editItem.MenuItems:Add(unselectItem)
  
  -- Add label
  local label = Label()
  label.Parent = form
  label.Left = 0
  label.Top = 10
  label.Height = 20
  label.Width = form.Width
  label.TextAlign = ContentAlignment.MiddleCenter
  label.Text = "Active Modules"
  
  -- Add CheckedListBox
  local listBox = CheckedListBox()
  activeReportDialog.listBox = listBox
  listBox.Parent = form
  listBox.Top = 35
  listBox.Height = 300
  listBox.Width = 260
  listBox.Left = 10
  listBox.ThreeDCheckBoxes = true
  listBox.IntegralHeight = true
  
  -- Add the OK Button
  local okButton = Button()
  okButton.Text = "OK"
  okButton.Left = 60
  okButton.Width = 80
  okButton.Top = 330
  okButton.Click:Add(ActiveOKCB)
  okButton.Parent = form
  
  -- Add the Cancel Button
  local cancelButton = Button()
  cancelButton.Text = "Cancel"
  cancelButton.Left = 160
  cancelButton.Width = 80
  cancelButton.Top = 330
  cancelButton.Click:Add(ActiveCancelCB)
  cancelButton.Parent = form
end

local function CreateProgressDialog()
  -- Create a dialog
  local form = Form()
  form.Text = "Tartare Progress"
  form.Width = 400
  form.Height = 250
  form.ControlBox = false
  form.StartPosition = FormStartPosition.CenterScreen
  progressDialog.form = form
  
  -- Add file label
  local fileLabel = Label()
  fileLabel.Parent = form
  fileLabel.Left = 0
  fileLabel.Top = 20
  fileLabel.Height = 40
  fileLabel.Width = form.Width
  fileLabel.TextAlign = ContentAlignment.MiddleCenter
  progressDialog.fileLabel = fileLabel
  
  -- Add process label
  local processLabel = Label()
  processLabel.Parent = form
  processLabel.Left = 0
  processLabel.Top = 70
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
  bar.Top = 90
  bar.Left = 50
  bar.Style = ProgressBarStyle.Continuous
  progressDialog.bar = bar
  
  -- Add the Cancel Button
  local cancelButton = Button()
  cancelButton.Text = "Cancel"
  cancelButton.Left = 160
  cancelButton.Width = 80
  cancelButton.Top = 150
  cancelButton.Click:Add(CancelCB)
  cancelButton.Parent = form
end

-- This has a forward declaration
function MenuCheck(sender, event)
  sender.Checked = not sender.Checked
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
  local startTime = os.time()
  
  --Create list of active reports
  local activeReports = {}
  local spectrumReports = {}
  for _, report in ipairs(registeredReports) do
    if report.enabled then
      table.insert(activeReports, report)
      if report.wantsLabelData or report.wantsSpectrum then
        table.insert(spectrumReports, report)
      end
    end
  end
  
  progressDialog.form:Show()
  local processSteps = #list * (#activeReports + 1)   -- Add one for spectrum processing step
  local step = 1
  progressDialog.bar.Maximum = processSteps
  progressDialog.bar.Value = 0
  Application.DoEvents()
  -- Clear past error messages
  errorMessage = ""
  
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
    for _, report in ipairs(activeReports) do
      local processText = string.format("%s Step %d of %d", report.name, step, processSteps)
      step = step + 1
      progressDialog.processLabel.Text = processText
      Application.DoEvents()
      -- Pcall the processing function, since we don't trust the creator
      local processPcall, errorMessage =  pcall(
            function() report.processFile(item.rawFileObject, shortFileName, fileIndex == 1) end)
      if not processPcall then
        Tartare.reportError(string.format("processFile() for %s failed on %s", report.name, shortFileName))
        Tartare.reportError (errorMessage)
      end
      progressDialog.bar:PerformStep()
      Application.DoEvents()
      if cancelProcessing then break end
    end
    
    -- Now loop through and run reports that require spectral data or label data
    -- Only fetch spectra or label data if required by the routine, and then share
    -- that spectrum instead of fetching multiple times
    if #spectrumReports > 0 then
      progressDialog.processLabel.Text = "Processing Spectra"
      Application.DoEvents()
      local rf = item.rawFileObject
      for scanNumber = rf.FirstSpectrumNumber, rf.LastSpectrumNumber do
        if scanNumber % 200 == 0 then
          Application.DoEvents()
          if cancelProcessing then break end
        end
        if scanNumber % 5000 == 0 then
          progressDialog.processLabel.Text = string.format("Processing Spectra %d of %d", scanNumber, rf.LastSpectrumNumber)
          Application.DoEvents()
        end
          
        local spectrum, labelData
        local description = {scanNumber = scanNumber, fineNumber = fileIndex}
        description.order = rf:GetMSNOrder(scanNumber)
        description.filter = rf:GetScanFilter(scanNumber)
        for _, report in ipairs(spectrumReports) do
          -- Pcall the processing functions, since we don't trust the creator
          if report.wantsSpectrum then
            local wantPcall, errorMsg =  pcall(
              function()
                if report.wantsSpectrum(description) then
                  if not spectrum then spectrum = rf.GetSpectrum(scanNumber) end
                  if spectrum then report.processSpectrum(spectrum, description) end
                end
              end)
            if not wantPcall then
              Tartare.reportError (string.forrmat("Spectral processing failed for %s", report.name))
              Tartare.reportError (errorMsg)
            end
          end
          -- Now repeat for label data
          if report.wantsLabelData then
            local wantPcall, errorMsg = pcall(
              function()
                if report.wantsLabelData(description) then
                  if not labelData then labelData = rf:GetLabelData(scanNumber) end
                  if labelData then report.processLabelData(labelData, description) end
                end
              end)
            if not wantPcall then
              Tartare.reportError (string.format("Label Data processing failed for %s", report.name))
              Tartare.reportError (errorMsg)
            end
          end
        end
      end
    end
    step = step + 1
    progressDialog.bar:PerformStep()
    Application.DoEvents()

    -- Close the raw file if we opened it
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
  resultNotebook.tabControl.ShowToolTips = true
  cycleNumber = cycleNumber + 1
  for _, report in ipairs(activeReports) do
    local result, errorMsg = pcall(
      function()
        report.generateReport(resultNotebook)
      end)
    if not result then
      Tartare.reportError (string.format("Report Generation failed for %s", report.name))
      Tartare.reportError (errorMsg)
    end
  end
  
  -- Display error messages if any generated
  if string.len(errorMessage) > 0 then
    local errorPage = textPage({name = "Tartare Errors"})
    resultNotebook:AddPage(errorPage)
    errorPage:Fill(errorMessage)
  end
    
  local runTime = os.time() - startTime
  print (string.format("Run time (sec): %0.1f", runTime))
end

-- This has a forward declaration
function SelectAllCB()
  local listBox = activeReportDialog.listBox
  local items = listBox.Items
  for i = 0, items.Count - 1 do
    listBox:SetItemChecked(i, true)
  end
end

local function ShowDialog()
  activeReportDialog.form:Show()
end

-- This function has a forward declaration
function ShowMenu()
  -- Set up the menu for accessing these routines
  local thisParentName = "Tartare"
  menu.AddMenu({name = thisParentName, parentName = "Tools"})   -- Add submenu to Tools
  menu.AddMenu({name = "All Notebooks", parentName = thisParentName, callBack = OnNotebooks})
  menu.AddMenu({name = "Files ...", parentName = thisParentName, callBack = OnFiles})
  menu.AddMenu({name = "Active Reports ...", parentName = thisParentName, callBack = ShowDialog})
end

-- This function has a forward declaration
function TrueFunction()
  return true
end

-- This has a forward declaration
function UnselectAllCB()
  local listBox = activeReportDialog.listBox
  local items = listBox.Items
  for i = 0, items.Count - 1 do
    listBox:SetItemChecked(i, false)
  end
end

CreateActiveReportDialog()
CreateProgressDialog()

-- Return the module
return Tartare
