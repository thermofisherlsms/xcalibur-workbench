-- transients.lua
-- routines for extracting transients from data files
-- This requires LuaJIT
-- Bail out if FFI library is not available.
local ffi
if not pcall (function() ffi = require("ffi") end) then return end
-- Bail out if complex global from GSLShell is not available.
if not complex then return end

local transients = {}

-- Declare all c functions that will be used to read data
ffi.cdef[[
  FILE *fopen(const char * filename, const char * mode);
  int fclose( FILE *fp );
  int fscanf ( FILE * stream, const char * format, ... );
  char * fgets ( char * str, int num, FILE * stream );
  size_t strlen (const char *s);
  size_t fread ( void * ptr, size_t size, size_t count, FILE * stream );
]]

-- local functions
local function trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1")
end

function transients.openMIDAS(args)
  args = args or {}
  if not args.fileName then
    print ("No file name specified")
    return nil
  end

  local cFile = ffi.C.fopen(args.fileName, "rb")          -- Open the file
  -- TODO Figure out how to tell when cFile is NULL
  local cLine = ffi.new("char[1000]", "")                 -- Create a character buffer
  local tempHeader = {}                                   -- Create place to store header lines
  while true do
    local tempLine                                        -- string to read lines into
    ffi.C.fgets(cLine, 1000, cFile)                       -- Read a line from the file, up to 1000 characters
    local lineLength = ffi.C.strlen(cLine)                -- Get its length
    if lineLength == 0 then return end
    for i = 0, lineLength - 2 do                          -- C-indexing, skip the end of string character
      if not tempLine then                                -- if no character yet
        tempLine = string.char(cLine[i])                  -- make the line the new character
      else                                                -- otherwise
        tempLine = tempLine .. string.char(cLine[i])      -- append the new character
      end
    end
    if string.find(tempLine, "Data:") then break end      -- this is the last line of a MIDAS file
    table.insert(tempHeader, tempLine)                    -- add the line to the header
  end

  local midasHeader = {}                                  -- Create new structure for header information
  for _, line in ipairs(tempHeader) do
    local pos = string.find(line, ":")                    -- Hunt for separator
    if pos then                                           -- if found
      --print (line)
      local key = string.sub(line, 1, pos - 1)            -- extract label and use as key
      local value = trim(string.sub(line, pos + 1))       -- extract the value
      value = tonumber(value) or value                    -- convert to number if possible
      midasHeader[key] = value                            -- add to header
    end
  end

  -- Debug only
  --for key, value in pairs(midasHeader) do
  --  print (key, value)
  --end
  
  -- Read the data in small buffers.  This is necessary
  -- because you can't easily declare a large FFI buffer
  local bufferCount = 1024
  local cData = ffi.new("short[1024]")                            -- create a c buffer
  local luaData = {}                                              -- create the Lua table for storage
  while true do
    local actualCount = ffi.C.fread(cData, 2, bufferCount, cFile) -- read data into the C-buffer
    if actualCount == 0 then break end                            -- if no data read, bail out
    for i = 0, actualCount - 1 do                                 -- for each point read
      luaData[#luaData+1] = cData[i]                              -- copy into the Lua table
    end
    if args.maxCount and #luaData >= args.maxCount then break end
  end
  
  -- Pad to power of 2 unless explicity declined
  local newCount = #luaData                                       -- default size
  if args.pad or args.pad == nil then
    newCount = math.log(#luaData) / math.log(2)                     -- Get power of 2
    if math.floor(newCount) ~= newCount then                        -- If not even power of 2
      newCount = math.ceil(newCount)                                -- Round up
    end
    newCount = math.pow(2, newCount)                                -- Now get actual number
    if args.maxCount then                                           -- if maxCount specified
      newCount = math.min(args.maxCount, newCount)                  -- limit count
    end
    local start = #luaData + 1
    for i = start, newCount do luaData[i] = 0 end
  end
  
  if args.zeroFill then
    newCount = newCount * 2
    local start = #luaData + 1
    for i = start, newCount do luaData[i] = 0 end
  end
  
  --print ("Total Size: ", #luaData)
  ffi.C.fclose(cFile)                                              -- close the file
  if args.useMatrix then                                            -- return a GSL Shell matrix
    local newData = matrix.new(newCount, 1, 
                        function(n) return luaData[n] or 0 end)     -- create the matrix
    return {header = midasHeader, matrix = newData}
  else
    return{header = midasHeader, data = luaData}                     -- return the header and data
  end
end

return transients