-- PDResults.lua
-- Read results from PD exported as text into a table
PDResults = {}

-- Convert the line into a table with column labels
-- The PD Text Export s tab delimited with quotes around each column entry
-- The header and data rows are formatted the same
local function ParseLine(line)
  local row = {}
  while true do
    local labelStart = line:find('"')
    local labelEnd = line:find('"', labelStart + 1)
    if not (labelStart and labelEnd) then return row end
    local label = line:sub(labelStart+1, labelEnd-1)
    table.insert(row, label)
    local tab = line:find("\t")
    if not tab then return row end
    line = line:sub(tab + 1)
  end
end

function PDResults.Read(fileName)
  local fh = io.open(fileName, "r")
  if not fh then
    print (string.format("File Not Found: %s", fileName))
    return nil
  end
  -- The PD Text Export header is tab delimited with quotes around each column header
  local header = ParseLine(fh:read("*line"))
  if #header <= 0 then return nil end
  -- Create the result table, with subtables for each column
  local result = {}
  for index, label in ipairs(header) do
    result[label] = {}
  end
  local line = fh:read("*line")
  local lineCount = 1
  while line do
    local row = ParseLine(line)
    for index, value in ipairs(row) do
      result[header[index]][lineCount] = tonumber(value) or value
    end
    line = fh:read("*line")
    lineCount = lineCount + 1
  end
  return result
end
