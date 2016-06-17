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

-- textPage.lua
-- a tabPage with a TextBox object

-- Load necessary libraries
local tabPage = require("tabPage")

-- Get assemblies
luanet.load_assembly ("System.Windows.Forms")

-- Get constructors
local TextBox = luanet.import_type("System.Windows.Forms.TextBox")

-- Get enumerations
local DockStyle = luanet.import_type("System.Windows.Forms.DockStyle")  -- Get the enumeration

-- local variables

-- forward declarations for local functions

-- local functions

-- Start of textPage Object
local textPage = {}
textPage.__index = textPage
setmetatable(textPage, {
    __index = tabPage,    -- this is the inheritance
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end, })

function textPage:_init(args)
  args = args or {}
  tabPage._init(self, args)
  self.textControl = TextBox()
  self.textControl.Dock =  DockStyle.Fill
  self.textControl.Multiline = true
  self.pageControl.Controls:Add(self.textControl)
end

function textPage:Fill(text)
  self.textControl.Text = text
end

return textPage
