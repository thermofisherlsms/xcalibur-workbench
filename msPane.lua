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

-- msPane.lua
-- A zPane with the ability to plot spectra and chromatograms

-- Load necessary libraries
local configure = require("configure")
local zPane = require("zPane")

-- Get assemblies
luanet.load_assembly ("System.Drawing")
luanet.load_assembly ("ZedGraph")

-- Get constructors
local plotCtor = luanet.import_type("ZedGraph.ZedGraphControl")
local pointPairListCtor = luanet.import_type("ZedGraph.PointPairList")
local GraphPane = luanet.import_type("ZedGraph.GraphPane")

-- Get enumerations
local Color = luanet.import_type("System.Drawing.Color")
local SymbolType = luanet.import_type("ZedGraph.SymbolType")            -- This is an enum

-- local variables

-- forward declarations for local functions

-- local functions
-- Only non-chromatogram mode is spectrum, so for now
-- just compare against it.
local function isChromatogram(mode)
  return mode ~= "spectrum"
end

local function isSpectrum(mode)
  return mode == "spectrum"
end

local function isXIC(mode)
  return mode == "xic"
end

-- Start of the zPane object
local msPane = {}
msPane.__index = msPane

setmetatable(msPane, {
    __index = zPane,    -- this is the inheritance
    __call = function (cls, ...)
      local self = setmetatable({}, cls)
      self:_init(...)
      return self
    end,})

---Create a new object of the class
function msPane:_init(args)
  args = args or {}
  zPane._init(self, args)
  self.mode = args.mode or "tic"
  self.rawFile = args.rawFile
  self.scanNumber = 1
  self.startRT = 0
  self.stopRT = 1
  self.filter = ""
  self.massRange = ""
  self.paneControl.Title.Text = "msPane"
  -- Add properties, zPane already called properties.Inherit()
  local toolTipString = "spectrum, tic, bpc, xic"
  self:AddProperty({key = "mode", label = "Mode", toolTip = toolTipString,
                  options = {"spectrum", "tic", "bpc", "xic"}})
  local firstSN = self.rawFile.FirstSpectrumNumber
  local lastSN = self.rawFile.LastSpectrumNumber
  self:AddProperty({key = "startRT", label = "Start", modeTest = isChromatogram})
  self:AddProperty({key = "stopRT", label = "End", modeTest = isChromatogram})
  toolTipString = string.format("%d - %d", firstSN, lastSN)
  self:AddProperty({key = "scanNumber", label = "Scan Number",
                    min = firstSN, max = lastSN,
                    modeTest = isSpectrum, toolTip = toolTipString})
  self:AddProperty({key = "filter", label = "Filter"})
  self:AddProperty({key = "massRange", label = "Mass Range", modeTest = isXIC})
  
  if args.skipDraw then return end
  if self.mode ~= "spectrum" then
    self:PlotChromatogram()
  else
    self:PlotSpectrum()
  end
end

function msPane:GetChromatogramTitle(args)
  args = args or {}
  if args.title then return args.title end
  local mode = args.mode or self.mode or "tic"  -- TIC is default
  local title = mode                            -- Start with mode
  if mode == "xic" then
    title = string.format("%s: %s %s", title, self.filter, self.massRange)
  end
  return title
end

function msPane:GetPropertyTitle()
  if self.mode == "spectrum" then
    return "Spectrum"
  else
    return "Chromatogram"
  end
end

-- Required Arguments:
-- Optional Arguments:
-- rawFile: overrides self.rawFile
-- scanNumber
function msPane:GetSpectrum(args)
  -- if the spectrum is passed, just return it
  if args.spectrum then return args.spectrum end
  local rawFile = args.rawFile or self.rawFile
  if not rawFile then
    print ("msPane:GetSpectrum() No rawFile available")
    return nil
  end
  self.scanNumber = args.scanNumber or self.scanNumber
  
  if self.scanNumber < rawFile.FirstSpectrumNumber or
    self.scanNumber > rawFile.LastSpectrumNumber then
      print (string.format("msPane:GetSpectrum() scanNumber %d out of range", self.scanNumber))
      return nil
  end
  -- Get the spectrum and add some information that will help in plotting
  local spectrum = rawFile:GetSpectrum(self.scanNumber)
  spectrum.scanNumber = self.scanNumber
  local filter = rawFile:GetScanFilter(self.scanNumber)
  self:SetSpectrumMassRange(spectrum, filter)
  if filter:find(" c ") then
    spectrum.IsCentroid = true    -- Mark as centroid spectrum
  end
  return spectrum
end

function msPane:SetPropertiesFinalize()
  if self.mode == "spectrum" then
    self:PlotSpectrum()
  else
    self:PlotChromatogram()
  end
end

-- Required arguments
-- scanNumber
-- Optional arguments
-- rawFile - overrides self.rawFile
-- title - overrides automatic title
function msPane:GetSpectrumTitle(args)
  if args.title then return args.title end
  local rawFile = args.rawFile or self.rawFile
  if not rawFile or not args.scanNumber then return "" end
  return string.format("#%d: %0.3f min %s", args.scanNumber,
                        rawFile:GetRetentionTime(args.scanNumber),
                        rawFile:GetScanFilter(args.scanNumber))
end

-- This uses : syntax, since it's called by the page
function msPane:KeyDownCB(sender, args)
  if self.mode == "spectrum" then
    local newScanNumber = self.page:ChangeScanNumber(args, self.rawFile, self.scanNumber, self.filter)
    if newScanNumber then 
      self:PlotSpectrum({scanNumber = newScanNumber})
    end
  -- no chromatogram key press callback yet
  end
  return
end

-- Alter the spectrum so that it looks like a profile spectrum
-- by adding zeros for each point
function msPane:PlotCentroidSpectrum(args)
  args = args or {}
  local spectrum = args.spectrum
  if not spectrum then return end
  if spectrum.scanNumber then
    self.scanNumber = spectrum.scanNumber
    args.scanNumber = spectrum.scanNumber   -- Help with title
  end
  local pane = self.paneControl
  pane.Title.Text = self:GetSpectrumTitle(args)
  pane.XAxis.Title.Text = "m/z"
  pane.YAxis.Title.Text = "Intensity"
  -- Add a StickGraph to the pane
  local stickCurve = self.centroid or
          pane:AddStick("", pointPairListCtor(), configure.spectrumColor)
  self.centroid = stickCurve                -- In case is didn't already exist
  self:Clear()                              -- Clear all curves
  
  for index, point in ipairs(spectrum) do
    if not point.Mass or not point.Intensity then
      print ("Bad point at index ", index)
    else
      stickCurve:AddPoint(point.Mass, point.Intensity)
    end
  end
  pane.XAxis.Scale.Min = spectrum.firstMass
  pane.XAxis.Scale.Max = spectrum.lastMass
  pane.YAxis.Scale.MinAuto = true
  pane.YAxis.Scale.MaxAuto = true
  -- Refresh the graph
  local plotControl = self.plotControl
  if plotControl and not args.skipDraw then
    --print ("Refreshing Pane")
    plotControl:AxisChange()
    plotControl:Invalidate()
  end
  self:UpdatePropertyForm()
  self:PushProperties()
end

-- Optional arguments:
-- chromatogram: Plot the specified chromatogram
-- rawFile: overrides pane's rawFile
-- title: overrides GetChromatogramTitle()
function msPane:PlotChromatogram(args)
  args = args or {}
  local chromatogram, rawFile
  self.mode = args.mode or self.mode
  self.filter = args.filter or self.filter
  self.massRange = args.massRange or self.massRange
  
  if args.chromatogram then
    chromatogram = args.chromatogram
  else
    rawFile = args.rawFile or self.rawFile
    if not rawFile then
      print ("No raw file available")
      return nil
    end
    local chroType
    if self.mode == "xic" then
      chroType = 0
    elseif self.mode == "bpc" then
      chroType = 2
    else  -- "tic" is default
      chroType = 1
    end
    chromatogram = rawFile:GetChroData({ 	-- see MsFileReader doc for complete details
      Type = 				chroType,			-- 0 Mass Range, 1 TIC, Base Peak 2
      Operator = 			0,			    -- 0 None, 1 Minus, 2 Plus
      Type2 = 			0,			      -- 0 Mass Range, 1 Base Peak
      Filter = 			self.filter,	-- Scan Filter
      MassRange1 = 		self.massRange,	-- Mass Range for chro1
      MassRange2 = 		nil,		    -- Mass Range for chro2
      SmoothingType = 	0,			  -- 0 None, 1 Boxcar, 2 Gaussian
      SmoothingValue = 	3,			  -- Odd value between 3-15
      Delay = 			0,
      StartTime = 		args.startTime or 0,
      EndTime = 			args.endTime or 0,
      })
  end
  
  local pane = self.paneControl
  self:Clear()                                          -- Clear all data from pane
  pane.Title.Text = self:GetChromatogramTitle(args)
  pane.XAxis.Title.Text = "Retention Time (min)"
  pane.YAxis.Title.Text = "Intensity"
  local thisColor = args.color or configure.chromatogramColor
  self:AddXYTable({data = chromatogram, xKey = "Time", yKey = "Intensity", color = thisColor })
  self:UpdatePropertyForm()
  self:PushProperties()
end

function msPane:PlotProfileSpectrum(args)
  args = args or {}
  local spectrum = args.spectrum
  if not spectrum then return end
  if spectrum.scanNumber then
    self.scanNumber = spectrum.scanNumber
    args.scanNumber = spectrum.scanNumber   -- Help with title
  end
  
  local pane = self.paneControl
  self:Clear()                                        -- Clear all data from the pane
  pane.Title.Text = self:GetSpectrumTitle(args)
  pane.XAxis.Title.Text = "m/z"
  pane.YAxis.Title.Text = "Intensity"
  self:AddXYTable({data = spectrum, xKey = "Mass", yKey = "Intensity",
                    xMin = spectrum.firstMass, xMax = spectrum.lastMass,
                    color = configure.spectrumColor})
  self:UpdatePropertyForm()
  self:PushProperties()
end

function msPane:PlotSpectrum(args)
  args = args or {}
  args.spectrum = self:GetSpectrum(args)
  if not args.spectrum then
    print ("No Spectrum Available")
    return nil
  end
  if args.spectrum.IsCentroid then
    return self:PlotCentroidSpectrum(args)
  else
    return self:PlotProfileSpectrum(args)
  end
end

function msPane:SetRawFile(rawFile)
  self.rawFile = rawFile
end

function msPane:SetSpectrumMassRange(spectrum, filter)
  if not spectrum or not filter then return spectrum end
  spectrum.firstMass = tonumber(filter:match("%[(%d+%.%d+)%-"))
  spectrum.lastMass = tonumber(filter:match("%-(%d+%.%d+)%]"))
  return
end

-- User has clicked on this pane with a shift
function msPane:ShiftClick(pointF, activePane)
  if self == activePane then return end                             -- Do nothing if the active pane
  
  -- Get nearest point
  local paneControl = self.paneControl
  local curveList = paneControl.CurveList
  local index, curve = paneControl:FindNearestPoint(pointF, curveList)
  local point = curve[index]
  --print ("Point is ", point.X, point.Y)
  if isChromatogram(self.mode) then
    activePane:PlotSpectrum({scanNumber = activePane.rawFile:GetScanNumberFromRT(point.X)})
  else
    activePane:PlotChromatogram({mode = "xic", massRange = string.format("%0.3f", point.X)})
  end
end

return msPane
