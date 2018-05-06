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

-- MethodDiff.lua
-- This is a Tartare report for generating "diffs" between instrument methods

-- Load necessary libraries
local tartare = require ("Tartare")
local gridPage = require("gridPage")
local textPage = require("textPage")
local webPage = require("webPage")
local diff = require("diff")

-- Local variables
local methodDiff = {name = "Method Diff"}
local allResults = {}
local toolTip = [[Comparing method differences]]

methodDiff.enabled = true

function methodDiff.generateReport(notebook)
  --if there are no results, or just one result , then the method diff is meaningless
  if #allResults == 0 or #allResults == 1 then return end
  
  --we'll want a separate tab, comparing each method to the first one
  local numTabs = #allResults -1
  
  for i=1,numTabs do
      
      local page = webPage{name = "Method Diff #"..i}
      notebook:AddPage(page)                        -- Add the page to the notebook
      Application.DoEvents()                        -- Let windows draw the page
      
      -- Create the header
      local header = {}
      for _, entry in ipairs(allResults[1]) do
        table.insert(header, entry.label)
      end
      
      --table to hold the individual method reports
      local methodReports = {}
      local fileNames = {}
      
      table.insert(methodReports,allResults[1][1]['value'])
      table.insert(fileNames,allResults[1][2]['value'])
      
      table.insert(methodReports,allResults[1+i][1]['value'])
      table.insert(fileNames,allResults[1+i][2]['value'])
      
      --perform the diff on the two files
      local diffResult = diff.diff(methodReports[1],methodReports[2],'\n')
      
      -- format the diff as HTML
      diffString = diff.format_as_html(diffResult)
      
      --the style headers
      local styles = [[
        <style type='text/css'>
            body{font-family: sans-serif;font-size: 0.9em;}
            ins,del{display:block;}
            table{table-layout: fixed;border-collapse: collapse;-ms-word-break: break-all;}
            td{word-wrap:break-word}
            td.empty{background-color:#ccc;}
            ins,td.in{background-color:#a6dbab;color:#115617;text-decoration:none}
            del,td.out{background-color:#e89b9b;color:#510e0e}
            td.same, td.key{background-color:#eee;}
            tr th{text-align:left;background: #333;color: #fff;padding: 0.25em;}
            td { border-bottom:1px solid #444;padding: 0.25em;}
        </style>
      ]]
      
      -- start the HTML string that we'll build up
      local diffHTML = [[<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">]]..'<html><head>'..styles..'</head><body><table width="100%" cellspacing="0" cellpadding="0"><tr>'
      
      --add cells for the two filenames
      for _,name in ipairs(fileNames) do
         diffHTML = diffHTML..'<th width="50%">'..name..'</th>'
      end 
      
      diffHTML = diffHTML .. '</tr></table>'..diffString..'</body></html>'
      page:Fill(diffHTML)
    
    end
  
  
end

--"process" the file, essentially just getting the instrumentmethod and filename
function methodDiff.processFile(rawFile, rawFileName, firstFile)
  if firstFile then allResults = {} end
  -- Set up the result table for this raw file
  local thisResult = {}
  local instrumentMethod = rawFile:GetInstrumentMethod(1)

  table.insert(thisResult, {label = "Instrument Method", value = instrumentMethod})
  table.insert(thisResult, {label = "Raw File", value = rawFileName})
  table.insert(allResults, thisResult)
end

-- Register this report
tartare.register(methodDiff)
