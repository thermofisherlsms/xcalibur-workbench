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

-- methodPage.lua
-- a textPage with the ability to display the method

-- Load necessary libraries
local textPage = require("textPage")

-- Get assemblies

-- Get constructors

-- Get enumerations

-- local variables

-- Forward declaration for local helper functions

-- local functions

-- Start of methodPage Object
local methodPage = {}
methodPage.__index = methodPage
setmetatable(methodPage, {
    __index = textPage,    -- this is the inheritance
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end, })

function methodPage:_init(args)
  args = args or {}
  textPage._init(self, args)
  local textBox = self.textControl
  self.rawFile = args.rawFile

  if not args.skipInit then self:ShowMethod() end
end

function methodPage:ShowMethod(args)
  args = args or {}
  if not self.rawFile then
    print ("No rawFile available")
    return nil
  end
  local rawFile = self.rawFile
  local method = rawFile:GetInstrumentMethod(1)   -- '1' is for mass spectrometer method
  if not method or string.len(method) == 0 then
    method = "No Method Data Available"
  end
  self:Fill(method)
end

return methodPage
