-- TMTRepeat.lua
-- Routines for repetitive TMT experiments

-- Load necessary libraries
local menu = require("menu")
local mdiNoteBook = require("mdiNoteBook")
local multiPlotPage = require("multiPlotPage")
local zPane = require("zPane")

-- Local variables
local noteBookList = mdiNoteBook.noteBookList
local reporterMasses = {126, 127, 128, 129, 130, 131}
local finalGroups, ratios, avgRatios, maxRatios, sumRatios
local activeNoteBook, rawFile
--local stopScan = 100000
--local stopScan = 200000
local PDDirectory = "C:\\Users\\michael.senko\\Documents\\Mike\\Algorithms\\TMT DIA\\PD\\"
local PDFile = "Thorium_20161220_140min_rapidMS375_1200_ddMS2Turbo_rep5_HCD40_1pt0qd_InjTime5ms_paraON_1E4_110-1410_2_PSMs.txt"

local Color = luanet.import_type("System.Drawing.Color")
local SymbolType = luanet.import_type("ZedGraph.SymbolType")

local defaultColors = {Color.Black, Color.Red, Color.Blue, Color.Green, Color.Brown, Color.Orange,
                        Color.Violet, Color.Pink, Color.Aqua, Color.Cyan, Color.DarkBlue, Color.DarkGray,
                        Color.DarkGreen, Color.DarkOrange, Color.DarkRed, Color.LightBlue}

local defaultSymbols = {SymbolType.Square, SymbolType.Diamond, SymbolType.Triangle,
                        SymbolType.Circle, SymbolType.XCross, SymbolType.Plus}

-- Forward declarations for local functions
local GetIndexFromMass, GetPeak, GetReporters, Group, SelectGroups
local SumGroup
local PlotCorrelations, PlotHistogram, PlotRatios

local function Correlate(x, y)
  local sx, sy, sxy = 0, 0, 0
  local ssx, ssy = 0, 0
  local xValue, yValue
  
  local n = #x
  if n <= 1 then return 0 end
  
  for i = 1, n do
    xValue = x[i]
    yValue = y[i]
    sx = sx + xValue
    ssx = ssx + xValue * xValue
    sy = sy + yValue
    ssy = ssy + yValue * yValue
    sxy = sxy + xValue * yValue
  end
  local numerator =  n * sxy - sx * sy
  local denominator = math.sqrt(n * ssx  - (sx * sx)) * math.sqrt(n * ssy - (sy * sy))
  return numerator / denominator
end

local function CorrelateGroup(group)
  -- Build the x table
  local x = {}
  for index, ms2 in ipairs(group) do
    x[index] = ms2.bp
  end
  
  -- Correlate each reporter indivisually
  local r = {}
  for _, reporterMass in ipairs(reporterMasses) do
    local y = {}
    for index, ms2 in ipairs(group) do
      y[index] = ms2[reporterMass]
    end
    r[reporterMass] = Correlate(x, y)
  end
  group.r = r
  return
end

-- Pull data out for each group
local dataExtracted = false
local function ExtractData()
  if dataExtracted then return end
  -- Sort the data in order of scan number
  -- Randomly accessing big files is really slow
  print ("Resorting in order of scan number")
  table.sort(finalGroups, function (a,b) return a[1].scanNumber < b[1].scanNumber end)
  
  for groupIndex, group in ipairs(finalGroups) do
    if groupIndex % 1000 == 0 then
      print (string.format("Extracting Group %d of %d", groupIndex, #finalGroups))
    end
    -- Loop through and find the largest base peak
    -- This will be used as the chromatogram
    -- We are in trouble if this is one of the reporters
    local bpMass, bpIntensity = 0,0
    for _, ms2 in ipairs(group) do
      local header = rawFile:GetScanHeader(ms2.scanNumber)
      if header.BasePeakIntensity > bpIntensity then
        bpMass = header.BasePeakMass
        bpIntensity = header.BasePeakIntensity
      end
    end
  
    -- Now loop through and extract the reporters and base peak
    for ms2Index, ms2 in ipairs(group) do
      local spectrum = rawFile:GetSpectrum(ms2.scanNumber)
      local basePeak = GetPeak(spectrum, bpMass)
      if basePeak then
        ms2.bp =  basePeak.Intensity
      else
        ms2.bp = 0
      end
      local reporters = GetReporters(spectrum)
      -- Iterate with pairs because the table has holes in the index
      for key, value in pairs(reporters) do
        ms2[key] = value
      end
    end
  end
  dataExtracted = true
  return
end

-- This will do linear fit of base peak XIC
-- to each reporter XIC
local function FitGroup(group)
  -- Build the GSL Shell matrices
  local xData = matrix.new(#group, 1)        -- Vector of intensities for the group base peak
  local reporterData = {}                    -- Table of vectors to store the reporter intensities
  for index, ms2 in ipairs(group) do
    xData[index] = ms2.bp or 0
    for _, reporterMass in ipairs(reporterMasses) do
      if not reporterData[reporterMass] then reporterData[reporterMass] = matrix.new(#group,1) end
      reporterData[reporterMass][index] = ms2[reporterMass]
    end
  end
  
  local fit = {}
  for _, reporterMass in ipairs(reporterMasses) do
    -- GSL Shell syntactic sugar
    --local X = matrix.new(#group, 2, |i,j| j == 1 and 1 or xData[i])
    local X = matrix.new(#group, 2, function(i,j) return j == 1 and 1 or xData[i] end)
    local c, chisq, cov = num.linfit(X, reporterData[reporterMass])
    fit[reporterMass] = c[2]                      -- This is the slope
  end
  group.fit = fit
  return
end

local function FitGroups()
  if not finalGroups then Group() end               -- If no groups, then group
  if not SelectGroups() then return end             -- Select groups from PD Results
  ExtractData()                                     -- Now extract relevant data

  for groupIndex, group in ipairs(finalGroups) do
    if groupIndex % 1000 == 0 then
      print (string.format("Processing group %d of %d", groupIndex, #finalGroups))
    end
    CorrelateGroup(group)
    FitGroup(group)
    SumGroup(group)
  end
  
  -- Create new notebook for result
  local resultNoteBook = mdiNoteBook()
  local generic = multiPlotPage{name = "Ratios", rows = 2,
                                panes = {zPane(), zPane()}}
  resultNoteBook:AddPage(generic)
  
  PlotRatios("fit", generic.paneList[1])      -- Histogram of fit ratios
  PlotRatios("sums", generic.paneList[2])    -- Histogram of sum ratios
  
  
  generic = multiPlotPage{name = "Correlations", rows = 1, panes = {zPane()}}
  resultNoteBook:AddPage(generic)
  PlotCorrelations(generic.paneList[1])
end

local function FitSpectrum()
  -- Get the active notebook
  local activeNoteBook = noteBookList.active
  if not activeNoteBook then
    print ("No active notebook")
    return
  end
  rawFile = activeNoteBook.rawFile
  
  -- Now get the active page
  local activePage = activeNoteBook.pageList.active
  if not activePage then
    print ("No active page")
    return
  end
  
  -- Next get the active pane
  local activePane = activePage.paneList.active
  if not activePane then
    print ("No active pane")
    return
  end
  
  -- Finally get the spectrum number
  local scanNumber = activePane.scanNumber
  if not scanNumber then
    print ("No spectrum in active pane")
    return
  end
  
  -- Find the group for this scan number
  if not finalGroups then Group() end
  local thisGroup
  for groupIndex, group in ipairs(finalGroups) do
    for ms2Index, ms2 in ipairs(group) do
      if ms2.scanNumber == scanNumber then
        thisGroup = group
        break
      elseif ms2.scanNumber > scanNumber then break end
    end
    if thisGroup then break end
  end
  if not thisGroup then
    print ("Could not find matching group")
    return
  end
  
  print (string.format("Spectrum #%d group count: %d", scanNumber, #thisGroup))
  local result = FitGroup(thisGroup)
  
  -- Create new notebook for result
  local resultNoteBook = mdiNoteBook()
  local generic = multiPlotPage{name = "Ratios", rows = 2, columns = 2,
                                panes = {zPane(), zPane(), zPane()}}
  resultNoteBook:AddPage(generic)
  
  -- Plot reporters
  local pane = generic.paneList[1]
  local control = pane.paneControl
  control.XAxis.Title.Text = "Retention Time (min)"
  control.YAxis.Title.Text = "Intensity"
  control.Title.Text = "XIC's"
  local names = {"126", "127", "128", "129", "130", "131"}
  local plotData = {}
  local maxReporter = 0
  for _, ms2 in ipairs(thisGroup) do table.insert(plotData, {x = ms2.RT}) end
  -- Export the data to the console
  print(string.format("Reporter Information for group with scan #%d", scanNumber))
  for i = 1, #result.reporters[1] do
    print (string.format("%0.3f\t%0.1f\t%0.1f\t%0.1f\t%0.1f\t%0.1f\t%0.1f\t%0.1f",
                        thisGroup[i].RT, result.bpXIC[i],
                        result.reporters[1][i],result.reporters[2][i],
                        result.reporters[3][i],result.reporters[4][i],
                        result.reporters[5][i],result.reporters[6][i]))
  end
  for reporterIndex, reporterVector in ipairs(result.reporters) do
    for i = 1, #reporterVector do
      plotData[i].y = reporterVector[i]
      maxReporter = math.max(maxReporter, reporterVector[i])
    end
    pane:AddXYTable({data = plotData, xKey = "x", yKey = "y", index = reporterIndex,
                      name = names[reporterIndex], symbol = defaultSymbols[reporterIndex]})
  end
  
  -- Plot base peak
  local maxBP = 0
  for i = 1, #result.bpXIC do
    plotData[i].y = result.bpXIC[i]
    maxBP = math.max(maxBP, plotData[i].y)
  end
  --for index, point in ipairs(plotData) do
  --  point.y = point.y / maxBP * maxReporter
  --end
  pane:AddXYTable({data = plotData, xKey = "x", yKey = "y", index = #result.reporters + 1,
                    name = "Base Peak", symbol = SymbolType.TriangleDown})
  
  -- Plot ratios
  pane = generic.paneList[2]
  control = pane.paneControl
  control.XAxis.Title.Text = "Reporter"
  control.YAxis.Title.Text = "Intensity"
  control.Title.Text = "Reporters"
  plotData = {}
  for index, sum in ipairs(result.sums) do
    -- Normalize to 128
    plotData[index] = {x = 125 + index, y = sum / result.sums[3]}
  end
  pane:AddXYTable({data = plotData, xKey = "x", yKey = "y", index = 1, name = "sums"})
  print (string.format("Sum: %0.2f\t%0.2f\t%0.2f\t%0.2f\t%0.2f\t%0.2f",
                      result.sums[1]/result.sums[3],result.sums[2]/result.sums[3],
                      result.sums[3]/result.sums[3],result.sums[4]/result.sums[4],
                      result.sums[5]/result.sums[4],result.sums[6]/result.sums[4]))
  
  for index, slope in ipairs(result.fit) do
    -- Normalize to 128
    plotData[index] = {x = 125 + index, y = slope[2] / result.fit[3][2]}
  end
  pane:AddXYTable({data = plotData, xKey = "x", yKey = "y", index = 2, name = "fit"})
  print (string.format("Fit: %0.2f\t%0.2f\t%0.2f\t%0.2f\t%0.2f\t%0.2f",
                      result.fit[1][2]/result.fit[3][2],result.fit[2][2]/result.fit[3][2],
                      result.fit[3][2]/result.fit[3][2],result.fit[4][2]/result.fit[4][2],
                      result.fit[5][2]/result.fit[4][2],result.fit[6][2]/result.fit[4][2]))
                  
  -- Scatter plot
  pane = generic.paneList[3]
  control = pane.paneControl
  control.XAxis.Title.Text = "Base Peak"
  control.YAxis.Title.Text = "Reporter"
  control.Title.Text = "Fits"
  plotData = {}
  for index = 1, #result.bpXIC do
    plotData[index] = {x = result.bpXIC[index]}
  end
  for reporterIndex, reporterVector in ipairs(result.reporters) do
    for i = 1, #reporterVector do
      plotData[i].y = reporterVector[i]
    end
    pane:AddXYTable({data = plotData, xKey = "x", yKey = "y", index = reporterIndex,
                      name = names[reporterIndex], symbol = defaultSymbols[reporterIndex],
                      color = defaultColors[reporterIndex], noLine = true})
  end
  -- Plot best fit line
  -- Use same color as above
  for i = 1, #result.fit do
    for j = 1, #result.bpXIC do
      plotData[j].y = plotData[j].x * result.fit[i][2] + result.fit[i][1]
    end
    pane:AddXYTable({data = plotData, xKey = "x", yKey = "y", index = i + #result.fit,
                      color = defaultColors[i]})
  end
end

-- Find the base peak in the specified mass range
local function GetBasePeak(spectrum, firstMass, lastMass)
  local index = GetIndexFromMass(spectrum, firstMass)
  if not index then return nil end
  if spectrum[index].Mass > lastMass then return nil end
  
  local maxIntensity = spectrum[index].Mass
  local maxIndex = index
  index = index + 1
  while index <= #spectrum and spectrum[index].Mass <= lastMass do
    if spectrum[index].Intensity > maxIntensity then
      maxIntensity = spectrum[index].Intensity
      maxIndex = index
    end
    index = index + 1
  end
  return spectrum[maxIndex]
end

-- Get the index for the first peak above a specified mass
-- This has a forward declaration
function GetIndexFromMass(spectrum, searchMass)
  if not searchMass then return false end
  if #spectrum == 0 then return false end
  
  -- Take care of simple possibilities first
  if searchMass < spectrum[1].Mass then             -- first peak is above search mass
    return 1                                        -- just return first index
  elseif searchMass > spectrum[#spectrum].Mass then -- last peak is below search mass
    return false                                    -- return no index
  end
  
  -- binary search into array to find required peak
  local lowIndex = 1
  local highIndex = #spectrum
  local thisIndex = math.floor((lowIndex + highIndex) / 2)
  local thisMass
  while highIndex - lowIndex > 1 do
    thisMass = spectrum[thisIndex].Mass
    if thisMass < searchMass then
      lowIndex = thisIndex
      thisIndex = math.floor((lowIndex + highIndex) / 2)
    else
      highIndex = thisIndex
      thisIndex = math.floor((lowIndex + highIndex) / 2)
    end
  end
  return highIndex
end

-- Find the largest peak within +=0.5 Da of mass
-- This has a forward declaration
function GetPeak(spectrum, mass)
  return GetBasePeak(spectrum, mass - 0.5, mass + 0.5)
end

-- This will return just 126, 127, 128, 129, 130, and 131
-- If there is no reporter, it will create a 0 intensity peak
-- This has a forward declaration
function GetReporters(spectrum)
  local reporters = {}
  
  -- Get the index for the first reporter
  local spectrumIndex = GetIndexFromMass(spectrum, reporterMasses[1] - 0.5) or #spectrum + 1
  local endMass, maxIntensity, thisPeak
  for _, reporterMass in ipairs(reporterMasses) do
    -- At the first point in the loop, the spectrumIndex is above the start mass for the reporter
    -- but may be above the end mass for the reporter, or may be an invalid index
    maxIntensity = 0
    thisPeak = spectrum[spectrumIndex]
    endMass = reporterMass + 0.5
    while thisPeak and thisPeak.Mass <= endMass do
      maxIntensity = math.max(maxIntensity, thisPeak.Intensity)
      spectrumIndex = spectrumIndex + 1
      thisPeak = spectrum[spectrumIndex]
    end
    reporters[reporterMass] = maxIntensity
  end
  return reporters
end

-- This has a forward declaration
function Group()
  activeNoteBook = noteBookList.active
  if not activeNoteBook then
    print ("No active notebook")
    return
  end
  rawFile = activeNoteBook.rawFile
  local ms1Count = 0
  local ms1s, ms2s = {}, {}
  local marked = {}
  -- Make a big table that has all ms2 scans, including precursor mass and master scan
  print ("Collecting Scan Order")
  for i = rawFile.FirstSpectrumNumber, stopScan or rawFile.LastSpectrumNumber do      -- For every spectrum
    if i % 20000 == 0 then
      print (string.format("Scan number: %d", i))
    end
    local order = rawFile:GetMSNOrder(i)                                  -- Get order
    if order == 1 then
      ms1Count = ms1Count + 1
      -- Insert with scan number, this will make looking up
      -- the master scans much simpler later on
      ms1s[i] = ms1Count
    else
      table.insert(ms2s, {scanNumber = i,
                  precursor = rawFile:GetPrecursorMass(i),
                  master = rawFile:GetScanTrailer(i, "Master Scan Number:"),
                  IT = rawFile:GetScanTrailer(i, "Ion Injection Time (ms):"),
                  RT = rawFile:GetRetentionTime(i),
                  TIC = rawFile:GetScanHeader(i).TIC})
                  --label = rawFile:GetScanTrailer(i, "Multi Inject Info:")})
    end
  end
  -- Sort in order of precursor mass.  This will group all similar precursors
  print (string.format("MS1 Count: %d", ms1Count))
  print (string.format("MS2 Count: %d", #ms2s))
  print ("Sorting")
  table.sort(ms2s, function(a,b) return a.precursor < b.precursor end)  -- Sort in order of precursor mass
  
  finalGroups = {}
  local repeats = {}
  for i = 1, 100 do repeats[i] = 0 end
  -- Make new groups for matching precursors
  print ("Grouping")
  local precursorCount = 0
  local splitCount = 0
  local i = 1
  while i <= #ms2s do
    if i % 10000 == 0 then
      print (string.format("Scan number: %d", i))
    end
    local firstEntry = ms2s[i]
    local firstIndex = i
    local subgroup = {firstEntry}
    i = i + 1
    while ms2s[i] and firstEntry.precursor == ms2s[i].precursor do
      table.insert(subgroup, ms2s[i])
      i = i + 1
    end
    precursorCount = precursorCount + 1
    -- Sort in order of scan number.
    table.sort(subgroup, function (a,b) return a.scanNumber < b.scanNumber end)

    local priorMS2 = subgroup[1]
    local newGroup = {priorMS2}
    local thisMS2
    for j = 2, #subgroup do
      thisMS2 = subgroup[j]
      if ms1s[thisMS2.master] == ms1s[priorMS2.master] + 1 then
        table.insert(newGroup, thisMS2)
      else
        splitCount = splitCount + 1
        table.insert(finalGroups, newGroup)
        repeats[#newGroup] = repeats[#newGroup] + 1
        newGroup = {thisMS2}
      end
      priorMS2 = thisMS2
    end
    table.insert(finalGroups, newGroup)
    if #newGroup > #repeats then
      print (string.format("New Group of size %d Found", #newGroup))
    else
      repeats[#newGroup] = repeats[#newGroup] + 1
    end
  end
  -- print some statistics
  print (string.format("Number of Precursors: %d", precursorCount))
  print (string.format("Number of groups: %d", #finalGroups))
  print (string.format("Split Precursors: %d", splitCount))
end

local function LinFit()
  local x0, x1, n = 0, 12.5, 32
  local a, b = 0.55, -2.4
  --local xsmp = |i| (i-1)/(n-1) * x1
  -- Rewritten in more tradtional Lua
  -- Returns series from ~0 to 12.5 with 32 steps
  local xsmp = function (i) return (i-1)/(n-1) * x1 end

  local r = rng.new()                                         -- Get a random number generator object
  local x = matrix.new(n, 1, xsmp)                            -- Create a new n x 1 matrix, filled with the xsmp function
  print ("x:")
  print (x)
  -- Create a new n x 1 matrix, filled ax + b + gaussian noise (0.4 sigma)
  -- GSL Shell syntactic sugar
  --local y = matrix.new(n, 1, |i| a*xsmp(i) + b + rnd.gaussian(r, 0.4))
  local y = matrix.new(n, 1, function (i) return a*xsmp(i) + b + rnd.gaussian(r, 0.4) end)
  print ("y:")
  print (y)

  -- model matrix for the linear fit
  -- Create a new n x 2 matrix, in first column, put 1, in second column, put x[i]
  -- GSL Shell syntactic sugar
  --local X = matrix.new(n, 2, |i,j| j == 1 and 1 or x[i])
  local X = matrix.new(n, 2, function(i,j) return j == 1 and 1 or x[i] end)
  print ("X:")
  print (X)

  print('Linear fit coefficients: ')
  local c, chisq, cov = num.linfit(X, y)
  print ("c:")
  print(c)

  -- This function will draw the best fit line
  local fit = function(x) return c[1]+c[2]*x end

  local p = graph.fxplot(fit, x0, x1)
  p:addline(graph.xyline(x, y), 'blue', {{'marker', size=5}})
  p.title = 'Linear Fit'
end

-- This has a forward declaration
function MakeHistogram(data, binWidth, binCount, start)
  start = start or 0
  local histogram = {}
  -- Fill the histogram with x axis and zero intensity columns for each column in the data
  for i = 1, binCount do
    local row = {xAxis = binWidth * i + start}
    for key, _ in pairs(data[1]) do
      row[key] = 0
    end
    histogram[i] = row
  end
  
  for index1, dataRow in ipairs(data) do
    for key, value in pairs(dataRow) do
      local histogramRowIndex = math.ceil((value - start) / binWidth)
      local histogramRow = histogram[histogramRowIndex]
      if histogramRow then
        histogramRow[key] = histogramRow[key] + 1
      end
    end
  end
  return histogram
end

local function NonLinFit()
  -- These can be undone by calling restore_env()
  use 'math'                                        -- This makes all math functions available in the file namespace
  use 'graph'                                       -- This makes all graph functions available in the file namespace

  local n = 40                                      -- Number of points to fit
  local sigrf = 0.1
  local yrf
  
  local function fdf(x, f, J)
     for i=1, n do
        local A, lambda, b = x[1], x[2], x[3]
        local t, y, sig = i-1, yrf[i], sigrf
        local e = exp(- lambda * t)
        if f then f[i] = (A*e+b - y)/sig end
        if J then
          J:set(i, 1, e / sig)
          J:set(i, 2, - t * A * e / sig)
          J:set(i, 3, 1 / sig)
        end
     end
  end

  -- This is the primary function
  -- f(t) = A * exp(-lamda * t) + b
  local function model(x, t)
     local A, lambda, b = x[1], x[2], x[3]
     return A * exp(- lambda * t) + b
  end

  local xref = matrix.vec {5, 0.1, 1}     -- This is a vector with starting values

  local r = rng.new()

  -- This is GSL Shell "short function" syntax
  -- really function (i) return model(xref, i-1) + rnd.gaussian(r,0.1) end
  -- GSL Shell syntactic sugar
  --yrf = matrix.new(n, 1, |i| model(xref, i-1) + rnd.gaussian(r, 0.1))
  yrf = matrix.new(n, 1, function(i) return model(xref, i-1) + rnd.gaussian(r, 0.1) end)

  local s = num.nlinfit {n= n, p= 3}

  s:set(fdf, matrix.vec {1, 0, 0})
  print(s.x, s.chisq)

  for i=1, 10 do
     s:iterate()
     print('ITER=', i, ': ', s.x, s.chisq)
     if s:test(0, 1e-8) then break end
  end

  local p = plot('Non-linear fit example')
  local pts = ipath(iter.sequence(function(i) return i-1, yrf[i] end, n))
  local fitln = fxline(function(t) return model(s.x, t) end, 0, n-1)
  p:addline(pts, 'blue', {{'marker', size=5}})
  p:addline(fitln)
  p.clip = false
  p.pad  = true
  p:show()
end

-- This has a forward declaration
function PlotCorrelations(pane)
  local control = pane.paneControl
  control.XAxis.Title.Text = "r"
  control.YAxis.Title.Text = "Frequency"
  control.Title.Text = "Reporter Correlations"
  local plotData = {}
  for index, group in ipairs(finalGroups) do
    local entry = {}
    for _, reporterMass in ipairs(reporterMasses) do
      -- Plot r for now.  I want to see the negative correlations
      entry[reporterMass] = group.r[reporterMass] --  * group.r[reporterMass]
    end
    plotData[index] = entry
  end
  local binWidth = 0.01
  local binCount = 201
  local histogram = MakeHistogram(plotData, binWidth, binCount, -1)
  for reporterIndex, reporterMass in ipairs(reporterMasses) do
    pane:AddXYTable({data = histogram, xKey = "xAxis", yKey = reporterMass, index = reporterIndex,
                  name = tostring(reporterMass)})
  end
end

-- This has a forward declaration
function PlotHistogram(histogram, pane, title)
  local control = pane.paneControl
  control.XAxis.Title.Text = "Ratio"
  control.YAxis.Title.Text = "Counts"
  control.Title.Text = title
  local names = histogram.names or {}
  local columns = #histogram[1]
  for i = 1, columns do
    pane:AddXYTable({data = histogram, xKey = "xAxis", yKey = i, index = i, name = names[i]})
  end
end

-- This has a forward declaration
function PlotRatios(key, pane)
  local ratios = {}
  for index, group in ipairs(finalGroups) do
    ratios[index] = {group[key][126]/group[key][128],
                        group[key][127]/group[key][128],
                        group[key][131]/group[key][129],
                        group[key][130]/group[key][129]}
  end
  local binWidth = 0.1
  local binCount = 100
  local histogram = MakeHistogram(ratios, binWidth, binCount)
  histogram.names = {"10:3b", "12:3b", "10:3", "12:3"}
  PlotHistogram(histogram, pane, key)
end

-- This has a forward declaration
function SelectGroups()
  -- Read in the PD Results
  if not (PDDirectory and PDFile) then return end
  local pdResults = PDResults.Read(PDDirectory .. PDFile)
  
  -- Create an index for faster parsing
  print ("Building Yeast Index")
  local index = {}
  for _, entry in ipairs(pdResults["First Scan"]) do
      index[entry] = true
  end
  
  print (string.format("Yeast Index size: %d", #pdResults["First Scan"]))
  print (string.format("Initial Group Count: %d", #finalGroups))
  local groupIndex = 1
  while finalGroups[groupIndex] do
    local discardGroup = true
    for _, ms2 in ipairs(finalGroups[groupIndex]) do
      if index[ms2.scanNumber] then
        discardGroup = false
        break
      end
    end
    if discardGroup then
      table.remove(finalGroups, groupIndex)
    else
      groupIndex = groupIndex + 1
    end
  end
  print (string.format("Yeast Groups Remaining: %d", #finalGroups))
  if #finalGroups == 0 then
    print ("All groups have been eliminated.  Aborting ...")
    return
  else
    return true
  end
end

-- This has a forward declaration
function SumGroup(group)
  local sums = {}
  for _, ms2 in ipairs(group) do
    for _, reporterMass in ipairs(reporterMasses) do
      sums[reporterMass] = sums[reporterMass] or 0 + ms2[reporterMass] or 0
    end
  end
  group.sums = sums
  return
end

-- Use the LinFit() function to try and fit TMT data
local function TMTFit()
  local n = 40
  local bpScale = 1000
  local lcSigma = 0.02
  local function direct(i) return i end
  local center = n / 2
  local step = 10 / n    -- This will result in 5 standard deviations on each side
  local function centered(x) return (x - center) * step end
  --local x = matrix.new(n, 1, centered)
  local function gauss(x) return sf.erf_Z(centered(x)) end
  local r = rng.new()
  local function lcPeak(x) return bpScale * (sf.erf_Z(centered(x)) + math.abs(rnd.gaussian(r, lcSigma))) end
  -- Create a Gaussian LC peak
  local rt = matrix.new(n, 1, centered)
  local bpXIC = matrix.new(n, 1, lcPeak)
  print ("bpXIC:")
  print (bpXIC)
  
  local p = graph.plot("bpXIC")
  p:addline(graph.xyline(rt, bpXIC))
  
  local reporterScale = {10, 4, 1, 1, 4, 10}
  local ms2Efficiency = 0.04
  local reporterSigma = bpScale * ms2Efficiency * 0.1
  local bgBase = 1
  local bgScale = {bgBase, bgBase, bgBase, 0, 0, 0}
  local reporters = {}
  for index, scale in ipairs(reporterScale) do
    local newReporter = ms2Efficiency * scale * bpXIC     -- Make initial intensity
    local noise = matrix.new(n, 1, function(x) return math.abs(rnd.gaussian(r, reporterSigma)) end) -- Create fresh noise
    newReporter = newReporter + noise                     -- Add the noise
    newReporter = newReporter + bgScale[index] * ms2Efficiency * bpScale
    p:addline(graph.xyline(rt,newReporter), 'blue')
    reporters[index] = newReporter
  end
  p:show()
  
  -- Now try and extract
  -- model matrix for the linear fit
  -- Create a new n x 2 matrix, in first column, put 1, in second column, put x[i]
  local results = {}
  for index, reporter in ipairs(reporters) do
    -- GSL Shell syntactic sugar
    --local X = matrix.new(n, 2, |i,j| j == 1 and 1 or bpXIC[i])
    local X = matrix.new(n, 2, function(i,j) return j == 1 and 1 or bpXIC[i] end)
    local c, chisq, cov = num.linfit(X, reporter)
    print (string.format("%d c:", index))
    print(c)
    results[index] = c
  end
  local i = 20
  print (string.format("Apex:  %f %f %f %f %f %f", reporters[1][i] / reporters[3][i],
                        reporters[2][i] / reporters[3][i],reporters[3][i] / reporters[3][i],
                        reporters[4][i] / reporters[4][i],reporters[5][i] / reporters[4][i],
                        reporters[6][i] / reporters[4][i]))
  i = 16
  print (string.format("Half Height:  %f %f %f %f %f %f", reporters[1][i] / reporters[3][i],
                        reporters[2][i] / reporters[3][i],reporters[3][i] / reporters[3][i],
                        reporters[4][i] / reporters[4][i],reporters[5][i] / reporters[4][i],
                        reporters[6][i] / reporters[4][i]))
  print (string.format("Corrected: %f %f %f %f %f %f", results[1][2] / results[3][2],
                        results[2][2] / results[3][2], results[3][2] / results[3][2],
                        results[4][2] / results[4][2], results[5][2] / results[4][2],
                        results[6][2] / results[4][2]))
  print (string.format("Background: %f %f %f %f %f %f", results[1][1], results[2][1],
                        results[3][1], results[4][1], results[5][1], results[6][1]))
  
  
end

-- Set up the menu for accessing these routines
local thisParentName = "TMT Repeats"
local thisParent = menu.AddMenu({name = thisParentName, parentName = "Tools"})
local group = menu.AddMenu({name = "Group", parentName = thisParentName, callBack = Group})
local fit = menu.AddMenu({name = "Fit Test", parentName = thisParentName, callBack = TMTFit})
local fitGroups = menu.AddMenu({name = "Fit Groups", parentName = thisParentName, callBack = FitGroups})
local fitSpectrum = menu.AddMenu({name = "Fit Spectrum", parentName = thisParentName, callBack = FitSpectrum})
