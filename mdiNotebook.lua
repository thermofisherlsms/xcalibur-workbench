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

-- mdiNotebook.lua
-- Container object for MDI dialog
-- OO structure from http://lua-users.org/wiki/ObjectOrientationTutorial

-- Load necessary libraries
local templates = require("templates")

local RawFile = require("ThermoRawFile")

-- Get assemblies

-- Get constructors
local Form = luanet.import_type("System.Windows.Forms.Form")
local TabControl = luanet.import_type("System.Windows.Forms.TabControl")

-- Get enumerations
local DockStyle = luanet.import_type("System.Windows.Forms.DockStyle")
local TabAlignment = luanet.import_type("System.Windows.Forms.TabAlignment")

-- local variables

-- forward declarations for local functions
local noteBookActivated, noteBookClosed

-- local functions


-- Start of the mdiPage object
local mdiNoteBook = {}
mdiNoteBook.__index = mdiNoteBook

-- Table for controlling all displayed pages
local noteBookList = {}                   -- Contains all notebooks
noteBookList.active = false         -- will contain the active notebook
-- The notebook list can be accessed either from any notebook
-- or it can be accessed directly from the results of the
-- require ("mdiNoteBook") return value
mdiNoteBook.noteBookList = noteBookList

setmetatable(mdiNoteBook, {
    __call = function (cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end,})

---Create a new object of the class
function mdiNoteBook:_init(args)
  args = args or {}
  
  self:CreateForm(args)          -- Create the MDI Form
  
  -- Add to the noteBookList
  -- Do this after creating the form
  table.insert(noteBookList, self)
  noteBookList.active = self
 
  -- Add page list
  self.pageList = {}
  self.pageList.active = false
  
  if args.rawFile then                          -- if rawfile specified
    self.rawFile = args.rawFile                 -- just use it
  elseif args.fileName then                     -- otherwise if fileName specified
    if  not self:OpenFile(args.fileName) then   -- try to open it
      return nil
    end
  end
  
  -- Add pages if function is provided
  if args.AddPages then args.AddPages(self) end
  self.form:Show()
end

-- Loop through the notebooks to find a match
-- and then set the active notebook
-- The sender is the MDI Form, so note the use of . instead of :
function mdiNoteBook.ActivatedCB(sender, args)
  noteBookList.active = sender.Tag
end

function mdiNoteBook:AddPage(page)
  self.tabControl.TabPages:Add(page.pageControl)
  table.insert(self.pageList, page)
  self.pageList.active = page
end

function mdiNoteBook:Close()
  -- This will trigger the ClosedCB() below
  self.form:Close()                                 -- Close the form
  return
end

-- The sender is the MDI Form, so note the use of . instead of :
function mdiNoteBook.ClosedCB(sender, args)
  local thisNoteBook = sender.Tag                 -- Get the parent notebook for the form
  
  -- Remove the notebook from the noteBookList
  for index, noteBook in ipairs(noteBookList) do
    if thisNoteBook == noteBook then
      table.remove(noteBookList, index)
      noteBookList.active = false
      break
    end
  end
  
  -- If no rawFile, then we are done
  local rawFile = thisNoteBook.rawFile
  if not rawFile then return end
  -- If the raw file is used anywhere else, we are done
  for index, noteBook in ipairs(noteBookList) do
      if noteBook.rawFile == rawFile then return end
  end
  -- Finally, close the raw file
  rawFile:Close()
  return
end

function mdiNoteBook:CreateForm(args)
  args = args or {}
  local mdiForm = Form()
  mdiForm.MdiParent = mainForm
  mdiForm.Activated:Add(mdiNoteBook.ActivatedCB)
  mdiForm.Closed:Add(mdiNoteBook.ClosedCB)
  mdiForm.Text = self:GetFormTitle(args)
  mdiForm.Height = args.height or 0.8 * mainForm.Height
  mdiForm.Width = args.width or 0.8* mainForm.Width
  mdiForm.Tag = self                                -- Set tag for referencing in callback
  self.form = mdiForm
  
  -- Create the Tab Control
  local tabControl = TabControl()
  self.tabControl = tabControl
  tabControl.Parent = mdiForm
  tabControl.Dock = DockStyle.Fill
  tabControl.Alignment = TabAlignment.Right
  tabControl.Tag = self
end

-- Dispose of all .NET objects
function mdiNoteBook:Dispose()
  print ("Disposing pages")
  for index, page in ipairs(self.pageList) do
    page:Dispose()
  end
end

function mdiNoteBook:GetFormTitle(args)
  args = args or {}
  local title
  if args.title then          -- Supplied title is most important
    title = args.title
  elseif args.fileName then   -- then use file name
    title = args.fileName
  else                        -- otherwise use a generic name
    title = "NoteBook"
  end
  -- Loop through and compare to current titles
  local testCount = 1
  while not titleOK do
    local testTitle = title
    local titleMatched = false
    if testCount > 1 then testTitle = testTitle .. "_" .. tostring(testCount) end
    for index, noteBook in ipairs(noteBookList) do
        if testTitle == noteBook.form.Text then
          titleMatched = true
          break
        end
    end
    if not titleMatched then return testTitle end
    testCount = testCount + 1
  end
end

function mdiNoteBook:GetUniquePageName(baseName)
  local i = 1
  while true do
    local pageName = string.format("%s_%d", baseName, i)
    local unique = true
    for index, page in ipairs(self.pageList) do
      if pageName == page.pageControl.Text then
        unique = false
        break
      end
    end
    if unique then return pageName end
    i = i + 1
  end
end

function mdiNoteBook:OpenFile(fileName)
  self.rawFile = RawFile.New(fileName)
  if type(self.rawFile) ~= "userdata" then
    print ("Unable to open " .. fileName)
    print (self.rawFile)
    return nil
  end
  self.rawFile:Open()
  if not self.rawFile.IsOpen then
    print ("Unable to open " .. self.rawFile)
    return nil
  end
  self.fullFileName = fileName
  -- Find a backslash followed by anthing other than a backslash,
  -- right before the end of the string
  local index = string.find(fileName, "\\[^\\]*$")
  if index then
    self.pathName = string.sub(fileName, 1, index)
    self.fileName = string.sub(fileName, index + 1)
  end
    
  return true
end

-- The following are not meant to be part of the mdiNoteBook object
-- but are instead ways to access the active objects.  Thus they
-- use "." notation instead of ":" notation, but can be called either way.
function mdiNoteBook.GetActiveNoteBook()
  return noteBookList.active
end

function mdiNoteBook.GetActivePage()
  local activeNotebook = mdiNoteBook.GetActiveNoteBook()
  if not activeNotebook then return false end
  return activeNotebook.pageList.active
end

function mdiNoteBook.GetActivePane()
  local activePage = mdiNoteBook.GetActivePage()
  if not activePage then return false end
  -- Not all pages have panes
  if not activePage.paneList then return false end
  return activePage.paneList.active
end

return mdiNoteBook