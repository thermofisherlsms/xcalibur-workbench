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

-- chromatogramPage.lua
-- a plotPage with the ability to plot spectra

-- Load necessary libraries
local msPane = require("msPane")
local multiPlotPage = require("multiPlotPage")

-- Get assemblies

-- Get constructors

-- Get enumerations

-- local variables

-- forward declarations for local functions

-- local functions

-- Start of plotPage Object
local chromatogramPage = {}
chromatogramPage.__index = chromatogramPage
setmetatable(chromatogramPage, {
    __index = multiPlotPage,    -- this is the inheritance
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end, })

function chromatogramPage:_init(args)
  args = args or {}
  args.panes = {msPane(args)}
  args.rows = 1
  args.columns = 1
  multiPlotPage._init(self, args)
  if not args.skipInit then self:PlotChromatogram() end
end

function chromatogramPage:PlotChromatogram(args)
  local pane = self.paneList.active
  if not pane then return end
  return pane:PlotChromatogram()
end

return chromatogramPage
