local RawFile = require("LuaRawFile.core")

-- This function will add the pattern matching escape
-- character to all punctuation characters.  At least
-- that's what Google says.
local function escape(s)
  return (s:gsub("%p", "%%%1"))
end

-- Trim out leading and trailing spaces
local function trim(s)
  return s:match "^%s*(.-)%s*$"
end

-- Find the parameter with the matching label below a series of lines
-- The below functionality allows access to events that are part of
-- experiments.  This is required because event names are reused.
-- If the below table is empty, then the search will start at the
-- beginning of the method report
local function GetMethodParameterBelow(rawFile, below, label, partial)
  if type(below) ~= "table" then
    print ("Usage: GetMethodParameterBelow(rawFile, belowTable, label)")
    return nil
  end
  local l_method = rawFile:GetInstrumentMethod(1)     -- Get the method, base zero
  local l_start, l_end
  for _, value in ipairs(below) do
    l_start, l_end = l_method:find(escape(value), l_end)      -- Find the below string
    if not l_end then
      print ("Could not find below line: ", value)    -- print error message
      return nil                                      -- return nil
    end
    l_end = l_end + 1
  end
  
  l_start, l_end = l_method:find(escape(label), l_end)-- find first occurence of label after below line
  if not l_end then
    print ("Could not find label: ", label)           -- print error message
    return nil
  end
  
  local l_eol = l_method:find("\n", l_end + 1)        -- find next end-of-line
  if not l_eol then
    print ("Could not find label EOL")
    return nil
  end
	-- If partial is not set, then we've matched the full label and can just
	-- return what's between the label and the end of the line
	if not partial then return trim(l_method:sub(l_end + 1, l_eol - 1)) end
	-- if 'partial' is set, then we've matched only a partial piece of the label in the method report
	-- therefore, to find the value we need to find the separator
  local l_parameter = l_method:sub(l_end + 1, l_eol - 1)
	-- Find the last '=' or ':'
	local l_lastStart
	l_start = 1
	repeat 
		l_lastStart = l_start + 1
		l_start, l_end = l_parameter:find("[=:]", l_lastStart)
	until not l_start
	if not l_lastStart then
		print ("Could not find separator for partial match")
		return nil
	end
  return trim(l_parameter:sub(l_lastStart))
end

-- handy way to get the rawfile metatable to wrap your own functions
local rawFileMT = RawFile.GetRawFileMetaTable()

-- Simple example to show how to set the __len (#) operator for userdata
function rawFileMT:__len() 
	return self.LastSpectrumNumber - self.FirstSpectrumNumber
end

-- Get an event parameter from the method
-- Use this with some caution, since the event name can appear
-- as part of the decision, and event names get recycled
-- for each experiment
function rawFileMT:GetMethodScanParameter(l_args)
  l_args = l_args or {}
  -- Must supply rawFile and label
  if not l_args.label then
    print ("Usage: RawFile:GetMethodEventParameter({label = xxx [, event = yyy, experiment = zzz]})")
    return nil
  end
  l_args.event = l_args.event or "Event 1"            -- default to event 1
  l_args.experiment = l_args.experiment or 1          -- default to experiment 1
  local l_below = {string.format("Experiment %s", tostring(l_args.experiment)),
                    string.format("Scan %s", tostring(l_args.event))}
  return GetMethodParameterBelow(self, l_below, l_args.label, l_args.partial)
end

function rawFileMT:GetMethodExperimentParameter(l_args)
  l_args = l_args or {}
  -- Must supply rawFile and label
  if not l_args.label then
    print ("Usage: RawFile:GetMethodExperimentParameter({label = xxx [, experiment = yyy]})")
    return nil
  end
  l_args.experiment = l_args.experiment or 1          -- default to experiment 1
  local l_below = {string.format("Experiment %s", tostring(l_args.experiment))}
  return GetMethodParameterBelow(self, l_below, l_args.label, l_args.partial)
end

-- Get a global parameter from the method
function rawFileMT:GetMethodGlobalParameter(l_args)
  l_args = l_args or {}
  -- Must supply rawFile and label
  if not l_args.label then
    print ("Usage: RawFile:GetMethodGlobalParameter({label = xxx})")
    return nil
  end
  local l_below = {"Global Settings"}
  return GetMethodParameterBelow(self, l_below, l_args.label, l_args.partial)
end


--[[
	One way to get parameters from the method summary is to just ask for all matches
	of a certain type.  Then you'll have to know that you want the first, second, third, etc
	
			+--<< return an array of matches
			|								+--- string match pattern
			|								|			+--- conversion function for the match
			|								|			|
			v								v			v
--]]
function rawFileMT:GetArrayOfMethodMatches( pattern, converter )
	local matches = {}
	for mch in string.gmatch(self:GetInstrumentMethod(1), pattern) do
		table.insert(matches, converter(mch))
	end	
	return matches
end

function rawFileMT:GetMaxInjectTimes()
	return self:GetArrayOfMethodMatches("Maximum Injection Time %(ms%) = (%d+.?%d*)", tonumber)
end

function rawFileMT:GetIsolationMZ(sn, msn)
	msn = msn or 2
	local scanFilter = self:GetScanFilter(sn)
	local m = scanFilter:match("([%d.]+)@")
	return tonumber(m)
end

--[[
	helper function to get things from the filter
							+--- string filter
							|		+--- string pattern to search for 
							|		|		+--- optional function, say to convert to a number
							|		|		|
							v		v		v
--]]
local function _Extract( filter, pattern, Converter )
	Converter = Converter or function(x) return x end

	local values = {}
	for match in string.gmatch(filter,pattern) do
		table.insert(values,Converter(match))
	end
	return values
end

function rawFileMT:GetPrecursors(sn)
	return _Extract( self:GetScanFilter(sn), "(%d+%.%d+)@", tonumber )
end

function rawFileMT:GetPrecursor(sn)
	local values = self:GetPrecursors(sn)
	return values and values[1]
end

function rawFileMT:GetActivationTypes(sn)
	return _Extract( self:GetScanFilter(sn), "%d+@(%a+)%d+")
end

function rawFileMT:GetActivationType(sn)
	local values = self:GetActivationTypes( sn )
	return values and values[1]
end

function rawFileMT:GetCollisionEnergies(sn)
	return _Extract( self:GetScanFilter(sn), "@%a+(%d+%.%d+)", tonumber )
end

function rawFileMT:GetCollisionEnergy(sn)
	local values = self:GetCollisionEnergies( sn )
	return values and values[1]	
end

function rawFileMT:GetFirstMass(sn)
	return string.match( self:GetScanFilter(sn), "%[(%d+.%d+)-")
end

function rawFileMT:GetLastMass(sn)
	return string.match( self:GetScanFilter(sn), "-(%d+.%d+)]")
end

function rawFileMT:IsSIMScan(sn)
	return string.match( self:GetScanFilter(sn), "SIM")
end

function rawFileMT:IsFullScan(sn)
	-- this is the characters ms followed by a space, ie no number
	-- SIM scan also puts ms into the name, so we have to differentiate that
	return string.match( self:GetScanFilter(sn), "ms ") and not self:IsSIMScan(sn)
end

function rawFileMT:IsMSNScan(sn)
	-- this is the characters ms then a number, then a space
	return string.match( self:GetScanFilter(sn), "ms%d")
end

return RawFile