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

-- TuneDiff.lua
-- This is a Tartare report for generating "diffs" between tune data

-- Load necessary libraries
local tartare = require ("Tartare")
local gridPage = require("gridPage")
local textPage = require("textPage")
local webPage = require("webPage")
local diff = require("diff")

-- Local variables
local tuneDiff = {name = "Tune Diff"}
local allResults = {}
local toolTip = [[Comparing tune data differences]]

--function to compare two tune data reports and perform a diff on them
function tuneDiff.diff(report1,report2)
    
    local diffTable = {}
    local keysFound = {}
    local numDifferences = 0
    
    --loop through all the items in report 1 first, looking to see if any match in report 2
    for k,v in pairs(report1) do
        
        keysFound[k] = 1
        local result = {}
        result.value1 = report1[k]
        
        if report2[k] == nil then
          result.status = 'not found in #2'
          result.value2 = ''
          result.class1 = 'in'
          result.class2 = 'out'
          numDifferences = numDifferences + 1
        elseif report1[k] == report2[k] then
          result.status = 'same'
          result.value2 = report2[k]
          result.class1 = 'same'
          result.class2 = 'same'
        elseif report1[k] ~= report2[k] then
          result.status = 'different'
          result.value2 = report2[k]
          result.class1 = 'out'
          result.class2 = 'in'
          numDifferences = numDifferences + 1
        end
        
        diffTable[k] = result
        
    end
    
    --loop through all the items in report 2 next, in case there are some keys specific to it
    for k,v in pairs(report2) do
       
        if keysFound[k] == nil then
            keysFound[k] = 1
            local result = {}
            result.status = 'not found in #1'
            result.value1 = ''
            result.value2 = report2[k]
            result.class1 = 'out'
            result.class2 = 'in'
            diffTable[k] = result
            numDifferences = numDifferences + 1
        end
       
    end
    
    return diffTable, numDifferences
    
end

--function to sort array by keys
--https://www.lua.org/pil/19.3.html
function pairsByKeys (t, f)
      local a = {}
      for n in pairs(t) do table.insert(a, n) end
      table.sort(a, f)
      local i = 0      -- iterator variable
      local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
      end
      return iter
    end

--format the contents of the Lua table as HTML tags, and return in a Lua table
function tuneDiff.formatTable(results)
    local output = {}
    table.insert(output, '<table cellspacing="0" cellpadding="0">')
    
    for k,v in pairsByKeys(results) do
        table.insert(output, '<tr><td class="key" width="33%">'..k..'</td>')
        table.insert(output, '<td class="'..v.class1..'" width="33%">'..v.value1..'</td>')
        table.insert(output, '<td class="'..v.class2..'" width="33%">'..v.value2..'</td></tr>')
    end
    
    table.insert(output, '</table>')
    
    return output
    
end


function tuneDiff.generateReport(notebook)
  --if there are no results, or just one result , then the method diff is meaningless
  if #allResults == 0 or #allResults == 1 then return end
  
  --we'll want a separate tab, comparing each method to the first one
  local numTabs = #allResults -1
  
  for i=1,numTabs do
      
      local page = webPage{name = "Tune Diff #"..i}
      notebook:AddPage(page)                        -- Add the page to the notebook
      Application.DoEvents()                        -- Let windows draw the page
      
      -- Create the header
      local header = {}
      for _, entry in ipairs(allResults[1]) do
        table.insert(header, entry.label)
      end
      
      --table to hold the individual tune data reports
      local tuneReports = {}
      local fileNames = {}
      
      table.insert(tuneReports,allResults[1][1]['value'])
      table.insert(fileNames,allResults[1][2]['value'])
      
      table.insert(tuneReports,allResults[1+i][1]['value'])
      table.insert(fileNames,allResults[1+i][2]['value'])
      
      --perform the diff on the two tables
      local diffResult, numDifferences = tuneDiff.diff(tuneReports[1],tuneReports[2])
      
      --format the output as HTML
      local diffHTMLTable = tuneDiff.formatTable(diffResult)
      
      --the style headers
      local styles = [[
        <style type='text/css'>
            body{font-family: sans-serif;font-size: 0.9em;}
            ins,del{display:block;}
            table{table-layout: fixed;border-collapse: collapse;-ms-word-break: break-all;}
            td{word-wrap:break-word}
            td.empty{background-color:#ccc;}
            ins,td.in{background-color:#a6dbab;color:#115617;text-decoration:none}
            del,td.out{background-color:#e89b9b;color:#510e0e;text-decoration:none}
            td.same, td.key{background-color:#eee;}
            tr th{text-align:left;background: #333;color: #fff;padding: 0.25em;}
            td { border-bottom:1px solid #aaa;padding: 0.25em;}
        </style>
      ]]
      
      -- start the HTML string that we'll build up and eventually return as the page's content
      local diffHTML = {}
      table.insert(diffHTML,[[
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">]])
      table.insert(diffHTML, '<html><head>'..styles..'</head>')
      table.insert(diffHTML, '<body>')
      table.insert(diffHTML, '<h3>'..numDifferences..' Differences Found:</h3>')
      table.insert(diffHTML, '<table width="100%" cellspacing="0" cellpadding="0"><tr><th width="33%">Key</th>')
      
      --add cells for the two filenames
      for _,name in ipairs(fileNames) do
         table.insert(diffHTML, '<th width="33%">'..name..'</th>')
      end 
      
      table.insert(diffHTML, '</tr></table>')
      for i=1,#diffHTMLTable do
        table.insert(diffHTML,diffHTMLTable[i])
      end
      
      table.insert(diffHTML, '</body></html>')
      page:Fill(table.concat(diffHTML))
    
    end
  
  
end

--"process" the file, essentially just getting the tune data and filename
function tuneDiff.processFile(rawFile, rawFileName, firstFile)
  if firstFile then allResults = {} end
  -- Set up the result table for this raw file
  local thisResult = {}
  local tuneData = rawFile:GetTuneData(1)

  table.insert(thisResult, {label = "Tune Data", value = tuneData})
  table.insert(thisResult, {label = "Raw File", value = rawFileName})
  table.insert(allResults, thisResult)
end

--disable by default
tuneDiff.enabled = false

-- Register this report
tartare.register(tuneDiff)
