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

-- templates.lua
-- Notebooks templates and associated functions
-- name:  Shows up in template menu
-- AddPage method: Controls creation of pages for the notebook

-- Load necessary libraries
local menu = require("menu")
local zPane = require("zPane")
local msPane = require("msPane")
local headerPage = require("headerPage")
local multiPlotPage = require("multiPlotPage")
local spectrumPage = require("spectrumPage")
local chromatogramPage = require("chromatogramPage")
local statusPage = require("statusPage")
local tunePage = require("tunePage")
local methodPage = require("methodPage")
local errorPage = require("errorPage")

templates = {}
templates.templateList = {}

-- List of templates
local p2g = {}
p2g.name = "p2g"
-- Include these lines if you want to use a fixed size for the notebook
--p2g.height = 800
--p2g.width = 1000
function p2g.AddPages(noteBook)
  local multi = multiPlotPage{name = "Multi",
                                panes = {msPane({rawFile = noteBook.rawFile}),
                                          msPane({rawFile = noteBook.rawFile, mode = "spectrum"})},
                                rows = 2}
  noteBook:AddPage(multi)
  local header = headerPage{name = "Scan Header", rawFile = noteBook.rawFile}
  noteBook:AddPage(header)
end

local big = {}
big.name = "Big Notebook"
function big.AddPages(noteBook)
  -- Add some pages
  local spectrum = spectrumPage{name = "Spectrum", rawFile = noteBook.rawFile}
  noteBook:AddPage(spectrum)
  
  local chromatogram = chromatogramPage{name = "Chromatogram", rawFile = noteBook.rawFile}
  noteBook:AddPage(chromatogram)
  
  local generic = multiPlotPage{name = "Generic", rawFile = noteBook.rawFile}
  noteBook:AddPage(generic)
  generic:AddXYTable({data = {{1,1},{2,4},{3,9}}, xKey = 1, yKey = 2})
  
  local header = headerPage{name = "Scan Header", rawFile = noteBook.rawFile}
  noteBook:AddPage(header)
  
  local multi = multiPlotPage{name = "Multi",
                              panes = {zPane(), msPane({rawFile = noteBook.rawFile}),
                                        msPane({rawFile = noteBook.rawFile, mode = "spectrum"})},
                              rows = 3}
  noteBook:AddPage(multi)
  
  local status = statusPage{name = "Status", rawFile = noteBook.rawFile}
  noteBook:AddPage(status)
  
  local tune = tunePage{name = "Tune", rawFile = noteBook.rawFile}
  noteBook:AddPage(tune)
  
  local method = methodPage{name = "Method", rawFile = noteBook.rawFile}
  noteBook:AddPage(method)
  
  local errorLog = errorPage{name = "Error Log", rawFile = noteBook.rawFile}
  noteBook:AddPage(errorLog)
end

-- Template Methods
function templates.InitializeTemplates()
  templates.Register(p2g)
  templates.Register(big)
  templates.SetDefault(p2g)
end

function templates.Register(template)
  table.insert(templates.templateList, template)            -- Add to the template list
  template.menuItem = menu.AddMenu({name = template.name, parentName = "Templates",
                      callBack = templates.SelectCB})
  template.menuItem.Tag = template                          -- Set the tag for easy reverse referencing
end

-- Call back for when a new default template is selected
function templates.SelectCB(sender)
  templates.SetDefault(sender.Tag)
end

function templates.SetDefault(template)
  if templates.default then
    templates.default.menuItem.Checked = false    -- Uncheck the prior default
  end
  template.menuItem.Checked = true                -- Check the new default
  templates.default = template                    -- Set this as the default
end

return templates
