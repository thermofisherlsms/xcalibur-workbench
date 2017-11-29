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

-- multiPlotPage.lua
-- A tabPage, but with a ZedGraphControl that supports multiple GraphPanes

-- Load necessary libraries
local zPane = require("zPane")
local tabPage = require("tabPage")
local properties = require("properties")

-- Get assemblies
luanet.load_assembly ("ZedGraph")
luanet.load_assembly ("Sytem.Drawing")    -- For PointF

-- Get constructors
local ZedGraphControl = luanet.import_type("ZedGraph.ZedGraphControl")
local PointF = luanet.import_type("System.Drawing.PointF")

-- Get enumerations
local DockStyle = luanet.import_type("System.Windows.Forms.DockStyle")  -- Get the enumeration
local Keys = luanet.import_type("System.Windows.Forms.Keys")

-- local declarations
-- This is used to get the modifier keys for mouse clicks
local control = luanet.import_type("System.Windows.Forms.Control")        -- Not a constructor

-- local functions

-- Start of plotPage Object
local multiPlotPage = {}
multiPlotPage.__index = multiPlotPage
setmetatable(multiPlotPage, {
    __index = tabPage,    -- this is the inheritance
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end, })

function multiPlotPage:_init(args)
  args = args or {}
  tabPage._init(self, args)
  
  -- Create the ZedGraphControl
  self.plotControl = ZedGraphControl()
  self.plotControl.Dock =  DockStyle.Fill
  self.plotControl.Tag = self
  self.pageControl.Controls:Add(self.plotControl)
  self.plotControl.PreviewKeyDown:Add(multiPlotPage.PlotKeyDownCB)
  self.plotControl.MouseClick:Add(multiPlotPage.MouseClickCB)
  self.plotControl.MouseDoubleClick:Add(multiPlotPage.MouseDoubleClickCB)
--  self.plotControl.ZoomEvent:Add(multiPlotPage.ZoomEventCB)
  
  -- Setup the master to support mulitple GraphPanes
  local master = self.plotControl.MasterPane
  master.PaneList:Clear()
  self.paneList = {}
  self.paneList.active = false
  if args.panes then
    for index, pane in ipairs(args.panes) do
      self:AddPane(pane)
    end
  else      -- Just one zPane by default
    self:AddPane(zPane(args))
  end
  self.plotControl:AxisChange()
  if #self.paneList > 1 then
    -- If there's more than one pane, but no formatting, just format in one column
    if not args.rows and not args.columns then args.rows = #self.paneList end
    self:SetLayout(args.rows, args.columns)
  end
end

function multiPlotPage:AddCurve(args)
  args = args or {}
  local pane = self.paneList.active
  if not pane then return end
  return pane:AddCurve(args)
end

function multiPlotPage:AddPane(pane)
  pane.page = self                                    -- Add a reference back to the page
  pane.plotControl = self.plotControl                 -- Add reference to plotControl for refreshing
  self.plotControl.MasterPane:Add(pane.paneControl)   -- Add the paneControl to the master
  table.insert(self.paneList, pane)                   -- Add pane to paneList
  self:SetActivePane(pane)                            -- Make it the active pane
end

-- Convenience for adding data
function multiPlotPage:AddXYTable(args)
  -- need to guide plot to the active plot
  args = args or {}
  local pane = self.paneList.active
  if not pane then return end
  return pane:AddXYTable(args)
end

function multiPlotPage:ChangeActivePane(direction)
  if #self.paneList <= 1 then return end                  -- Skip if only one active pane
  local activeIndex
  for index, pane in ipairs(self.paneList) do
    if pane == self.paneList.active then
      activeIndex = index
      break
    end
  end
  if not activeIndex then return end                        -- Shouldn't ever happen
  activeIndex = activeIndex + direction                     -- Increment the active index
  if activeIndex > #self.paneList then activeIndex = 1 end  -- Rotate to start
  if activeIndex < 1 then activeIndex = #self.paneList end  -- Rotate to back
  local pane = self.paneList[activeIndex]                   -- get the associated pane
  self:SetActivePane(pane)                                  -- activate the pane
  self.plotControl:Invalidate()                             -- Invalidate to update borders
end

-- Dispose of all .NET resources
function multiPlotPage:Dispose()
  for index, pane in ipairs(self.paneList) do
    pane:Dispose()
  end
  print ("Disposing Plot")
  self.plotControl:Dispose()
end

-- Sender is the plot control, so use . instead of : syntax
function multiPlotPage.MouseClickCB(sender, args)
  local self = sender.Tag                                           -- This is the page
  local pointF = PointF(args.X, args.Y)                             -- Convert click location to a PointF
  local paneControl = sender.MasterPane:FindPane(pointF)            -- Find the Zedgraph Pane that was clicked
  if not paneControl then return end                                -- Bail out if click outside a pane
  if control.ModifierKeys == Keys.Shift then
    local pane = paneControl.Tag                                      -- Get the zPane
    pane:ShiftClick(pointF, self.paneList.active)                     -- Do whatever action this pane desires
  end
end

-- Sender is the plot control, so use . instead of : syntax
function multiPlotPage.MouseDoubleClickCB(sender, args)
  local self = sender.Tag                                   -- This is the page
  local pointF = PointF(args.X, args.Y)                     -- Convert click location to a PointF
  local paneControl = sender.MasterPane:FindPane(pointF)    -- Find the Zedgraph Pane that was clicked
  if not paneControl then return end                        -- Bail out if click outside a pane
  local pane = paneControl.Tag                              -- Get the zPane
  self:SetActivePane(paneControl.Tag)                       -- Set it active
  self.plotControl:Invalidate()                             -- Invalidate to update borders
end

-- Sender is the plot control, so use . instead of : syntax
function multiPlotPage.PlotKeyDownCB(sender, args)
  local self = sender.Tag
  if not self then return end                       -- If no active page, return, shouldn't ever happen
  local pane = self.paneList.active
  if not pane then return end                       -- If not active pane, return, shouldn't ever happen
  local keyCode = args.KeyCode
  -- The order here may seem backwards, but the panes
  -- are indexed from top to bottom
  if keyCode == Keys.PageUp then
    self:ChangeActivePane(-1)
  elseif keyCode == Keys.PageDown then
    self:ChangeActivePane(1)
  elseif pane.KeyDownCB then
    pane:KeyDownCB(sender, args)
  end
  return
end

-- Set the active pane
function multiPlotPage:SetActivePane(pane)
  if pane == self.paneList.active then return end   -- Do nothing if already active
  if self.paneList.active then
    self.paneList.active:SetActive(false)           -- Deactivate the current pane
  end
  self.paneList.active = pane                       -- Set the active pane
  self.paneList.active:SetActive(true)              -- Active the new pane
  return
end

-- Set the layout based on rows and columns
function multiPlotPage:SetLayout(rows, columns)
  rows = rows or 1
  columns = columns or 1
  local graphics = self.plotControl:CreateGraphics()
  self.plotControl.MasterPane:SetLayout(graphics, rows, columns)
  graphics:Dispose()
end

-- This overrides the default method
function multiPlotPage:SetProperties()
  return self.paneList.active:SetProperties()
end

-- This redirectsto to the call for the active pane
function multiPlotPage:Undo()
  return self.paneList.active:Undo()
end

-- This redirects to the call to the active pane
function multiPlotPage:UpdatePropertyForm()
  return self.paneList.active:UpdatePropertyForm()
end

-- Sender is a GraphPane, so use . instead of : syntax
function multiPlotPage.ZoomEventCB(sender, oldState, newState)
  print ("Axis Change Detected")
end

return multiPlotPage
