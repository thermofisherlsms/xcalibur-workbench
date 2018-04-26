--[[

This utility is designed to load the PD search results into a handy table/library/class/whatever.
Currently it only supports results from PD 1.4.
 
GCM - 1/15/2017

Example usage:

	-- Open the connection to the PD database
	local dbConnection = pdResult:New()
	dbConnection:Open{fileName = "fileName", directory = "directory"}
	
	-- Read in the search results from the opened MSF database
	-- Return a table of PSMs indexed by scan number
	local searchResults = dbConnection:QueryDb{queryType = "OptimizedFull", 				-- Query spectra and search results
													confidence = "High",					-- Only return hits with a "High" confidence
													firstScan = false,						-- Don't restrict search results by a first scan filter
													lastScan = false,						-- Don't restrict search results by a last scan filter
													returnDecoy = false,					-- Return either the forward or decoy results (false or true, respectively)
													}


To Do:
	Add support for PD 2.1
	Add support for proteins
	Figure out a way to speed up the fetch
	Add the additional functions
		collapseToUniqueLcMsFeatures
	Add support for the following during format
		PSM ambiguity
		Delta CN
		Delta Score
		Delta Mass
]]


---- Load the general purpose libraries
---- These aren't necessary unless you are using this module in stand alone development
--package.path = [[C:\Users\graeme.mcalister\Desktop\Work\ZeroBraneStudio\userFiles\?.lua;]]..package.path
--package.path = [[C:\Users\graeme.mcalister\Desktop\Work\ZeroBraneStudio\userFiles\LuaBrowser\Examples\?.lua;]]..package.path
--require("ut_Print")
--require("socket")


-- Create the global table
sqLiteConnection = {}
-- Basic key/values for sql connection
sqLiteConnection.connection = false
sqLiteConnection.err = false

-- Load the lua sql library
local hasModule, err = pcall(require, "luasql.sqlite3")
if not hasModule then
	print("SQLite 3 Logging SKIP (missing luasql.sqlite3)")
elseif not luasql or not luasql.sqlite3 then
	print("Missing LuaSQL SQLite 3 driver!")
else
	print("Loaded LuaSQL SQLite 3 driver")
	sqLiteConnection.connection = luasql.sqlite3()
end

-- Return a function for handling the pdResult
pdResult = {}
function pdResult:New(parameters)
	
	-- Initialize a few parameters for the pdResult table
	tbl = {}
	tbl.database = false
	tbl.databaseName = false
	
	-- Create a few entries for storing the data analysis method parameters
	tbl.methodParameters = {}
	tbl.methodParameters.HighConfidenceThreshold = false
	tbl.methodParameters.MiddleConfidenceThreshold = false
	
	tbl.queries = {["forward"] = {baseQuery = [[SELECT sh.FirstScan AS FirstScan, 
													pep.PeptideID AS PeptideID,
													sh.charge AS PrecursorCharge, 
													sh.LastScan AS LastScan, 
													sh.RetentionTime AS RT, 
													sh.Mass AS PrecursorMH, 
													mp.IonInjectTime AS IonInjectionTime, 
													mp.Mass AS PrecursorMZ, 
													mp.PercentIsolationInterference AS IsolationInterference,
													pep.ConfidenceLevel AS ConfidenceLevel,
													pep.Sequence AS Sequence,
													pep.SearchEngineRank AS SearchEngineRank,
													pep.MissedCleavages AS MissedCleavages,
													pep.MatchedIonsCount AS IonsMatched,
													pep.PeptideID AS PeptideID
													
													FROM Peptides as pep
														INNER JOIN SpectrumHeaders AS sh  ON sh.SpectrumID = pep.SpectrumID 
														INNER JOIN MassPeaks as mp ON sh.MassPeakID = mp.MassPeakID 
														
													]],
									scoreQuery = [[SELECT sh.FirstScan AS FirstScan, 
													pep.PeptideID AS PeptideID,
													pep.Sequence AS Sequence,
													ps.ScoreValue AS XCorr,
													cd.FieldID AS CustomScoreType,
													cd.FieldValue AS CustomScoreValue
													
													FROM PeptideScores as ps
														INNER JOIN CustomDataPeptides as cd ON ps.PeptideID = cd.PeptideID 
														INNER JOIN Peptides as pep ON pep.PeptideID = ps.PeptideID
														INNER JOIN SpectrumHeaders AS sh  ON sh.SpectrumID = pep.SpectrumID
														
													WHERE (cd.FieldID = 4 or cd.FieldID = 5 or cd.FieldID = 6 or cd.FieldID = 7 or cd.FieldID IS NULL) AND]],
									modQuery = [[SELECT sh.FirstScan AS FirstScan,
													pep.PeptideID AS PeptideID,
													pep.Sequence AS Sequence,
													mods.Position AS ModificationPosition,
													modTypes.ModificationName AS ModificationName,
													modTypes.DeltaMass AS ModDeltaMass
													
													FROM PeptidesAminoAcidModifications as mods
														INNER JOIN AminoAcidModifications as modTypes on mods.AminoAcidModificationID = modTypes.AminoAcidModificationID
														INNER JOIN Peptides as pep ON pep.PeptideID = mods.PeptideID
														INNER JOIN SpectrumHeaders AS sh  ON sh.SpectrumID = pep.SpectrumID 
														
													]],
									},
				["decoy"] = {baseQuery = [[SELECT sh.FirstScan AS FirstScan, 
													pep.PeptideID AS PeptideID,
													sh.charge AS PrecursorCharge, 
													sh.LastScan AS LastScan, 
													sh.RetentionTime AS RT, 
													sh.Mass AS PrecursorMH, 
													mp.IonInjectTime AS IonInjectionTime, 
													mp.Mass AS PrecursorMZ, 
													mp.PercentIsolationInterference AS IsolationInterference,
													pep.ConfidenceLevel AS ConfidenceLevel,
													pep.Sequence AS Sequence,
													pep.SearchEngineRank AS SearchEngineRank,
													pep.MissedCleavages AS MissedCleavages,
													pep.MatchedIonsCount AS IonsMatched,
													pep.PeptideID AS PeptideID
													
													FROM Peptides_decoy as pep
														INNER JOIN SpectrumHeaders AS sh  ON sh.SpectrumID = pep.SpectrumID 
														INNER JOIN MassPeaks as mp ON sh.MassPeakID = mp.MassPeakID 
														
													]],
									scoreQuery = [[SELECT sh.FirstScan AS FirstScan, 
													pep.PeptideID AS PeptideID,
													pep.Sequence AS Sequence,
													ps.ScoreValue AS XCorr,
													cd.FieldID AS CustomScoreType,
													cd.FieldValue AS CustomScoreValue
													
													FROM PeptideScores_decoy as ps
														INNER JOIN CustomDataPeptides_decoy as cd ON ps.PeptideID = cd.PeptideID 
														INNER JOIN Peptides_decoy as pep ON pep.PeptideID = ps.PeptideID
														INNER JOIN SpectrumHeaders AS sh  ON sh.SpectrumID = pep.SpectrumID
														
													WHERE (cd.FieldID = 4 or cd.FieldID = 5 or cd.FieldID = 6 or cd.FieldID = 7 or cd.FieldID IS NULL) AND]],
									modQuery = [[SELECT sh.FirstScan AS FirstScan,
													pep.PeptideID AS PeptideID,
													pep.Sequence AS Sequence,
													mods.Position AS ModificationPosition,
													modTypes.ModificationName AS ModificationName,
													modTypes.DeltaMass AS ModDeltaMass
													
													FROM PeptidesAminoAcidModifications_decoy as mods
														INNER JOIN AminoAcidModifications as modTypes on mods.AminoAcidModificationID = modTypes.AminoAcidModificationID
														INNER JOIN Peptides_decoy as pep ON pep.PeptideID = mods.PeptideID
														INNER JOIN SpectrumHeaders AS sh  ON sh.SpectrumID = pep.SpectrumID 
														
													]],
									}				
					}
	
	
	-- Open the connection to the specific MSF database
	function tbl:Open(parameters)
		
		-- Initialize the local parameters
		parameters = parameters or {}
		local fileName = parameters.fileName or false
		local directory = parameters.directory or false
		
		-- Check the parameters passed into the function and the state of the SQL connection
		if not fileName then
			print("usage: tbl:Open{fileName = name,directory = default}")
			return false
		end
		if not sqLiteConnection.connection then
			print("The SQL driver isn't currently loaded - game over")
			return false
		end
		
		-- Open the database
		local fullFileName = directory .. fileName
		print("Opening MSF database: " .. fullFileName)
		self.database, self.err = sqLiteConnection.connection:connect(fullFileName)
		
		-- Return the result of the database connection
		if tbl:IsOpen() then 
			print("Database opened")
		else 
			print("Database connection failed")
		end
		return(tbl:IsOpen())
	end

	-- Check the database connection
	function tbl:IsOpen()	
		if self.database then
			return true
		else
			return self.err
		end
	end

	-- Check the database connection
	function tbl:Query(parameters)
		
		-- Initialize the local parameters
		parameters = parameters or {}
		local queryString = parameters.string or false
		
		-- Check the parameters passed into the function and the state of the SQL connection
		if not queryString then
			print("usage: tbl:query{string = string}")
			return false
		end
		if not self:IsOpen() then
			print("No SQLite database currently loaded")
			return false
		end

		-- Execute the query
		local queryResult,err = assert (self.database:execute(queryString),"failed to query the database - might want to check the string")
		if not queryResult then
			print(err)
			return false
		end
		-- Insert the query result into a table
		local resultTable = {}
		-- Fetch the first row of the query result
		local queryRow = queryResult:fetch ({}, "a")
		while queryRow do
			-- Insert the row into a result table
			--PrintInfo(queryRow)
			local formatedRow = {}
			for key,value in pairs(queryRow) do
				-- All query results are strings.  Go ahead a typecast to num in certain cases
				if key == "ConfidenceLevel" or
					key == "FirstScan" or
					key == "IonInjectionTime" or
					key == "IonsMatched" or
					key == "IsolationInterference" or
					key == "LastScan" or
					key == "MSOrder" or
					key == "MissedCleavages" or
					key == "ModDeltaMass" or
					key == "ModificationPosition" or
					key == "PeptideID" or
					key == "PrecursorCharge" or
					key == "PrecursorMH" or
					key == "PrecursorMZ" or
					key == "RT" or
					key == "SearchEngineRank" or
					key == "XCorr" or
					key == "CustomScoreValue"
					then
						
					value = value + 0.0
				end
				
				formatedRow[key]=value
			end
			table.insert(resultTable,formatedRow)
			-- Fetch the next row from the query
			queryRow = queryResult:fetch ({}, "a")
		end
		
		-- Return the result table
		if #resultTable > 0 then
			return resultTable
		else
			return false
		end
	end

	-- Get the data analysis method parameters
	function tbl:GetMethodParameters(parameters)
		print("Get the data analysis parameters")
		
		-- Initialize a few local variables
		local query,queryResult
		
		-- Initialize and execute the high confidence query
		query = [[SELECT * FROM ProcessingNodeParameters WHERE ParameterName = "TargetFPRHigh"]]
		queryResult = self:Query{string = query}
		if queryResult then
			self.methodParameters.HighConfidenceThreshold =  queryResult[1].ParameterValue
		end
		
		-- Initialize and execute the middle confidence query
		query = [[SELECT * FROM ProcessingNodeParameters WHERE ParameterName = "TargetFPRMiddle"]]
		queryResult = self:Query{string = query}
		if queryResult then
			self.methodParameters.MiddleConfidenceThreshold =  queryResult[1].ParameterValue
		end
	end

	-- Perform a full query on the data
	function tbl:QueryFull(parameters)
		print("Query spectra and search results")
		
		-- Initialize a few local variables
		parameters = parameters or {}
		local firstScan = parameters.firstScan or false
		local lastScan = parameters.lastScan or false
		local searchRank = parameters.searchRank or false
		local confidence = parameters.confidence or false
		local excludeMods = parameters.excludeMods or false
		local query,queryResult
		
		-- Create the query string
		query = [[SELECT sh.charge AS PrecursorCharge, 
					sh.FirstScan AS FirstScan, 
					sh.LastScan AS LastScan, 
					sh.RetentionTime AS RT, 
					sh.Mass AS PrecursorMH, 
					mp.IonInjectTime AS IonInjectionTime, 
					mp.Mass AS PrecursorMZ, 
					mp.PercentIsolationInterference AS IsolationInterference,
					pep.ConfidenceLevel AS ConfidenceLevel,
					pep.Sequence AS Sequence,
					pep.SearchEngineRank AS SearchEngineRank,
					pep.MissedCleavages AS MissedCleavages,
					pep.MatchedIonsCount AS IonsMatched,
					pep.PeptideID AS PeptideID,
					ps.ScoreValue AS XCorr,
					cd.FieldID AS CustomScoreType,
					cd.FieldValue AS CustomScoreValue,
					se.MSLevel AS MSOrder,
					se.ActivationType AS ActivationType,
					se.MassAnalyzer AS MassAnalyzer,
					fi.PhysicalFileName AS SpectrumFile,
					mods.Position AS ModificationPosition,
					modTypes.ModificationName AS ModificationName,
					modTypes.DeltaMass AS ModDeltaMass
					
					FROM SpectrumHeaders AS sh 
					LEFT OUTER JOIN MassPeaks as mp ON sh.MassPeakID = mp.MassPeakID 
					LEFT OUTER JOIN Peptides as pep ON sh.SpectrumID = pep.SpectrumID 
					LEFT OUTER JOIN PeptideScores as ps ON pep.PeptideID = ps.PeptideID 
					LEFT OUTER JOIN CustomDataPeptides as cd ON pep.PeptideID = cd.PeptideID 
					LEFT OUTER JOIN PeptidesAminoAcidModifications as mods ON pep.PeptideID = mods.PeptideID
					LEFT OUTER JOIN AminoAcidModifications as modTypes on mods.AminoAcidModificationID = modTypes.AminoAcidModificationID
					LEFT OUTER JOIN ScanEvents as se ON sh.ScanEventID = se.ScanEventID
					LEFT OUTER JOIN FileInfos as fi on mp.FileID = fi.FileID
					WHERE (cd.FieldID = 4 or cd.FieldID = 5 or cd.FieldID = 6 or cd.FieldID = 7 or cd.FieldID IS NULL) 
					]]
		-- Append any additional filters to the query
		if firstScan then
			query = query .. [[ AND sh.FirstScan > ]] .. firstScan
		end
		if lastScan then
			query = query .. [[ AND sh.LastScan < ]] .. lastScan
		end
		if searchRank then
			query = query .. [[ AND pep.SearchEngineRank = ]] .. searchRank
		end
		if confidence == "High" then
			query = query .. [[ AND pep.ConfidenceLevel = 3]]
		elseif confidence == "Middle" then
			query = query .. [[ AND (pep.ConfidenceLevel = 2 or pep.ConfidenceLevel = 3)]]
		end
		if excludeMods then
			query = query .. [[ AND mods.Position IS NULL]]
		end
		--print(query)
		
		--Execute the query
		queryResult = self:Query{string = query}
		
		-- Return the query result
		return queryResult
	end	
	
	-- Perform a query on a single MS/MS spectrum
	function tbl:QuerySpectrum(parameters)
		print("Query spectra and search results")
		
		-- Initialize a few local variables
		parameters = parameters or {}
		local scan = parameters.scanNumber or false
		local searchRank = parameters.searchRank or false
		local confidence = parameters.confidence or false
		local excludeMods = parameters.excludeMods or false
		local query,queryResult
		if not scan then
			print("usage: tbl:QueryScan{scanNumber = number}")
		end
		
		-- Create the query string
		query = [[SELECT sh.charge AS PrecursorCharge, 
					sh.FirstScan AS FirstScan, 
					sh.LastScan AS LastScan, 
					sh.RetentionTime AS RT, 
					sh.Mass AS PrecursorMH, 
					mp.IonInjectTime AS IonInjectionTime, 
					mp.Mass AS PrecursorMZ, 
					mp.PercentIsolationInterference AS IsolationInterference,
					pep.ConfidenceLevel AS ConfidenceLevel,
					pep.Sequence AS Sequence,
					pep.SearchEngineRank AS SearchEngineRank,
					pep.MissedCleavages AS MissedCleavages,
					pep.MatchedIonsCount AS IonsMatched,
					pep.PeptideID AS PeptideID,
					ps.ScoreValue AS XCorr,
					cd.FieldID AS CustomScoreType,
					cd.FieldValue AS CustomScoreValue,
					se.MSLevel AS MSOrder,
					se.ActivationType AS ActivationType,
					se.MassAnalyzer AS MassAnalyzer,
					fi.PhysicalFileName AS SpectrumFile,
					mods.Position AS ModificationPosition,
					modTypes.ModificationName AS ModificationName,
					modTypes.DeltaMass AS ModDeltaMass
					
					FROM SpectrumHeaders AS sh 
					LEFT OUTER JOIN MassPeaks as mp ON sh.MassPeakID = mp.MassPeakID 
					LEFT OUTER JOIN Peptides as pep ON sh.SpectrumID = pep.SpectrumID 
					LEFT OUTER JOIN PeptideScores as ps ON pep.PeptideID = ps.PeptideID 
					LEFT OUTER JOIN CustomDataPeptides as cd ON pep.PeptideID = cd.PeptideID 
					LEFT OUTER JOIN PeptidesAminoAcidModifications as mods ON pep.PeptideID = mods.PeptideID
					LEFT OUTER JOIN AminoAcidModifications as modTypes on mods.AminoAcidModificationID = modTypes.AminoAcidModificationID
					LEFT OUTER JOIN ScanEvents as se ON sh.ScanEventID = se.ScanEventID
					LEFT OUTER JOIN FileInfos as fi on mp.FileID = fi.FileID
					WHERE (cd.FieldID = 4 or cd.FieldID = 5 or cd.FieldID = 6 or cd.FieldID = 7 or cd.FieldID IS NULL) 
					]]
		-- Append any additional filters to the query
		if scan then
			query = query .. [[ AND sh.FirstScan = ]] .. scan
		end
		if searchRank then
			query = query .. [[ AND pep.SearchEngineRank = ]] .. searchRank
		end
		if confidence == "High" then
			query = query .. [[ AND pep.ConfidenceLevel = 3]]
		elseif confidence == "Middle" then
			query = query .. [[ AND (pep.ConfidenceLevel = 2 or pep.ConfidenceLevel = 3)]]
		end
		if excludeMods then
			query = query .. [[ AND mods.Position IS NULL]]
		end
		--print(query)
		
		--Execute the query
		queryResult = self:Query{string = query}
		
		-- Return the query result
		return queryResult
	end		
	
	-- Perform a query of the MS/MS spectra (no search results)
	function tbl:QuerySpectra(parameters)
		print("Query just the spectra")
		-- Initialize a few local variables
		parameters = parameters or {}
		local firstScan = parameters.firstScan or false
		local lastScan = parameters.lastScan or false
		local query,queryResult
		
		-- Create the query string
		query = [[SELECT sh.charge AS PrecursorCharge, 
					sh.FirstScan AS FirstScan, 
					sh.LastScan AS LastScan, 
					sh.RetentionTime AS RT, 
					sh.Mass AS PrecursorMH, 
					mp.IonInjectTime AS IonInjectionTime, 
					mp.Mass AS PrecursorMZ, 
					mp.PercentIsolationInterference AS IsolationInterference,
					se.MSLevel AS MSOrder,
					se.ActivationType AS ActivationType,
					se.MassAnalyzer AS MassAnalyzer,
					fi.PhysicalFileName AS SpectrumFile
					
					FROM SpectrumHeaders AS sh 
					LEFT OUTER JOIN MassPeaks as mp ON sh.MassPeakID = mp.MassPeakID 
					LEFT OUTER JOIN Peptides as pep ON sh.SpectrumID = pep.SpectrumID 
					LEFT OUTER JOIN ScanEvents as se ON sh.ScanEventID = se.ScanEventID
					LEFT OUTER JOIN FileInfos as fi on mp.FileID = fi.FileID
					]]
		-- Append any additional filters to the query
		if firstScan then
			query = query .. [[ WHERE sh.FirstScan > ]] .. firstScan
		end
		if not firstScan and lastScan then
			query = query .. [[ WHERE sh.LastScan < ]] .. lastScan
		elseif lastScan then
			query = query .. [[ AND sh.LastScan < ]] .. lastScan
		end		
		--print(query)
		
		--Execute the query
		queryResult = self:Query{string = query}
		
		-- Return the query result
		return queryResult
	end	
	
	-- Query the basic search results.  Returns very little, but is quite fast
	function tbl:QueryBasic(parameters)
		print("Quickly query just the basic search results")
		-- Initialize a few local variables
		parameters = parameters or {}
		local firstScan = parameters.firstScan or false
		local lastScan = parameters.lastScan or false
		local query,queryResult
		
		-- Create the query string
		query = [[SELECT sh.charge AS PrecursorCharge, 
					sh.FirstScan AS FirstScan, 
					sh.LastScan AS LastScan, 
					sh.RetentionTime AS RT, 
					sh.Mass AS PrecursorMH, 
					pep.ConfidenceLevel AS ConfidenceLevel,
					pep.Sequence AS Sequence,
					pep.SearchEngineRank AS SearchEngineRank,
					pep.MissedCleavages AS MissedCleavages,
					pep.MatchedIonsCount AS IonsMatched,
					pep.PeptideID AS PeptideID

					FROM Peptides as pep
					INNER JOIN SpectrumHeaders AS sh  ON sh.SpectrumID = pep.SpectrumID 
					
					
					]]
		-- Append any additional filters to the query
		if firstScan then
			query = query .. [[ AND sh.FirstScan > ]] .. firstScan
		end
		if lastScan then
			query = query .. [[ AND sh.LastScan < ]] .. lastScan
		end
		if searchRank then
			query = query .. [[ AND pep.SearchEngineRank = ]] .. searchRank
		end
		if confidence == "High" then
			query = query .. [[ AND pep.ConfidenceLevel = 3]]
		elseif confidence == "Middle" then
			query = query .. [[ AND (pep.ConfidenceLevel = 2 or pep.ConfidenceLevel = 3)]]
		end
		if excludeMods then
			query = query .. [[ AND mods.Position IS NULL]]
		end
		--print(query)
		
		--Execute the query
		queryResult = self:Query{string = query}
		
		-- Return the query result
		return queryResult
	end		
	
	-- Perform a optimized full query
	function tbl:QueryFullOptimized(parameters)
		
		print("Optimized query spectra and search results")
		
		-- Initialize a few local variables
		parameters = parameters or {}
		local firstScan = parameters.firstScan or false
		local lastScan = parameters.lastScan or false
		local searchRank = parameters.searchRank or false
		local confidence = parameters.confidence or false
		local excludeMods = parameters.excludeMods or false
		local returnDecoy = parameters.returnDecoy or false
		local queryType,query,queryResult
		if returnDecoy then 
			queryType = "forward"
		else
			queryType = "decoy"
		end
		local resultTable = {}
		
		-- Perform the first query
		local baseQueryString = self.queries[queryType].baseQuery
		
		-- Append any additional filters
		if firstScan or lastScan or searchRank or confidence then
			baseQueryString = baseQueryString .. [[WHERE]]
		end
		if firstScan then
			baseQueryString = baseQueryString .. [[ sh.FirstScan > ]] .. firstScan .. [[ AND]]
		end
		if lastScan then
			baseQueryString = baseQueryString .. [[ sh.LastScan < ]] .. lastScan .. [[ AND]]
		end
		if searchRank then
			baseQueryString = baseQueryString .. [[ pep.SearchEngineRank = ]] .. searchRank .. [[ AND]]
		end
		if confidence == "High" then
			baseQueryString = baseQueryString .. [[ pep.ConfidenceLevel = 3 AND]]
		elseif confidence == "Middle" then
			baseQueryString = baseQueryString .. [[ (pep.ConfidenceLevel = 2 or pep.ConfidenceLevel = 3) AND]]
		end
		-- Trim the last AND
		baseQueryString = string.sub(baseQueryString,1,-5)
--		print(baseQueryString)
		
		--Execute the query
		local baseQueryResult = self:Query{string = baseQueryString}
		
		-- Create the result table
		self:OptimizedQueryFormatBaseQuery{resultTable = resultTable,queryResult = baseQueryResult}
		
		-- Perform the second query
		local scoreQueryString = self.queries[queryType].scoreQuery
		
		-- Append any additional filters
		if firstScan then
			scoreQueryString = scoreQueryString .. [[ sh.FirstScan > ]] .. firstScan .. [[ AND]]
		end
		if lastScan then
			scoreQueryString = scoreQueryString .. [[ sh.LastScan < ]] .. lastScan .. [[ AND]]
		end
		if searchRank then
			scoreQueryString = scoreQueryString .. [[ pep.SearchEngineRank = ]] .. searchRank .. [[ AND]]
		end
		if confidence == "High" then
			scoreQueryString = scoreQueryString .. [[ pep.ConfidenceLevel = 3 AND]]
		elseif confidence == "Middle" then
			scoreQueryString = scoreQueryString .. [[ (pep.ConfidenceLevel = 2 or pep.ConfidenceLevel = 3) AND]]
		end
		-- Trim the last AND
		scoreQueryString = string.sub(scoreQueryString,1,-5)
--		print(scoreQueryString)
		
		--Execute the query
		local scoreQueryResult = self:Query{string = scoreQueryString}
		
		-- Append the scores to the results table
		self:OptimizedQueryFormatScoreQuery{resultTable = resultTable,queryResult = scoreQueryResult}
		
		-- Perform the second query
		local modQueryString = self.queries[queryType].modQuery
		
		-- Append any additional filters
		if firstScan or lastScan or searchRank or confidence then
			modQueryString = modQueryString .. [[ WHERE ]]
		end
		if firstScan then
			modQueryString = modQueryString .. [[ sh.FirstScan > ]] .. firstScan .. [[ AND]]
		end
		if lastScan then
			modQueryString = modQueryString .. [[ sh.LastScan < ]] .. lastScan .. [[ AND]]
		end
		if searchRank then
			modQueryString = modQueryString .. [[ pep.SearchEngineRank = ]] .. searchRank .. [[ AND]]
		end
		if confidence == "High" then
			modQueryString = modQueryString .. [[ pep.ConfidenceLevel = 3 AND]]
		elseif confidence == "Middle" then
			modQueryString = modQueryString .. [[ (pep.ConfidenceLevel = 2 or pep.ConfidenceLevel = 3) AND]]
		end
		-- Trim the last AND
		modQueryString = string.sub(modQueryString,1,-5)
		--print(modQueryString)
		
		--Execute the query
		local modQueryResult = self:Query{string = modQueryString}
		
		-- Append the scores to the results table
		self:OptimizedQueryFormatModQuery{resultTable = resultTable,queryResult = modQueryResult}
		
		-- Return the result table
		return resultTable
	end
	
	-- Format the base query for the optimized query into the scan table structure
	function tbl:OptimizedQueryFormatBaseQuery(parameters)
		print("  Format the optimized base query into a table indexed by scan number")
		
		-- Initialize a few local variables
		parameters = parameters or {}
		if not parameters.queryResult then
			print("usage: tbl:OptimizedQueryFormatBaseQuery{resultTable = table,queryResult = result}")
			return false
		end
		local resultTable = parameters.resultTable
		local queryResult = parameters.queryResult
		
		-- Add a few handy functions to the results table
		resultTable["TotalPSMs"] = function(self)
			local totalPSMs = 0
			for _,scan in pairs(self) do
				if type(scan) == "table" and scan.NumberIdentifiedPeptides then
					totalPSMs = totalPSMs + scan.NumberIdentifiedPeptides 
				end
			end
			return totalPSMs
		end
		
		-- Add a few handy functions to the results table
		resultTable["RetrieveScan"] = function(self,scanNumber)
			local scan = false
			if self[scanNumber] then
				scan = self[scanNumber]
			else
				print("Error scan doesn't exist")
			end
			
			return scan
		end
		
		-- Parse the query results, and append results that belong to the same scan (multiple matches with multiple search results)
		for _,queryResult in ipairs(parameters.queryResult) do
			-- Check to see if this is the first result for this scan
			-- Create a new entry if it is, otherwise append to the current entry
			if not resultTable[queryResult.FirstScan] then
				resultTable[queryResult.FirstScan] = {}
				-- Set the "global" scan parameters
				resultTable[queryResult.FirstScan].FirstScan = queryResult.FirstScan
				resultTable[queryResult.FirstScan].LastScan = queryResult.LastScan
				resultTable[queryResult.FirstScan].RT = queryResult.RT
				resultTable[queryResult.FirstScan].IonInjectionTime = queryResult.IonInjectionTime
				resultTable[queryResult.FirstScan].IsolationInterference = queryResult.IsolationInterference
				resultTable[queryResult.FirstScan].PrecursorCharge = queryResult.PrecursorCharge
				resultTable[queryResult.FirstScan].PrecursorMH = queryResult.PrecursorMH
				resultTable[queryResult.FirstScan].PrecursorMZ = queryResult.PrecursorMZ
				resultTable[queryResult.FirstScan].NumberIdentifiedPeptides = 0
				-- Create the first search result entry
				-- Only bother in cases where a PeptideID was assigned (otherwise we are just looking at scan info)
				if queryResult.PeptideID then
					resultTable[queryResult.FirstScan].SearchResults = {}
					resultTable[queryResult.FirstScan].SearchResults[1] = {}
					resultTable[queryResult.FirstScan].SearchResults[1].PeptideID = queryResult.PeptideID
					resultTable[queryResult.FirstScan].SearchResults[1].Sequence = queryResult.Sequence
					resultTable[queryResult.FirstScan].SearchResults[1].MissedCleavages = queryResult.MissedCleavages
					resultTable[queryResult.FirstScan].SearchResults[1].ConfidenceLevel = queryResult.ConfidenceLevel
					resultTable[queryResult.FirstScan].SearchResults[1].SearchEngineRank = queryResult.SearchEngineRank
					resultTable[queryResult.FirstScan].SearchResults[1].Modifications = {}
					resultTable[queryResult.FirstScan].SearchResults[1].XCorr = false
					resultTable[queryResult.FirstScan].SearchResults[1].qValue = false
					resultTable[queryResult.FirstScan].SearchResults[1].pep = false
					resultTable[queryResult.FirstScan].NumberIdentifiedPeptides = #resultTable[queryResult.FirstScan].SearchResults
				end
			-- If the scan is already in the results table, and a PeptideID doesn't exis, then this is just a repeat of the
			-- scan information.  Don't bother assigning any more information to the table
			elseif queryResult.PeptideID then
				-- Check to see if the PeptideID already exists in the search result table.  If it does then we need to append some additional fields
				-- (e.g., score or modifications).  If it doesnt then we need to create a new search result entry
				local containsPeptideID,indexPeptideID = false,false
				for index,searchResult in ipairs(resultTable[queryResult.FirstScan].SearchResults) do
					if queryResult.PeptideID == searchResult.PeptideID then
						containsPeptideID = true
						indexPeptideID = index
						break
					end
				end
				if not containsPeptideID then
					local indexNextSearchResult = #resultTable[queryResult.FirstScan].SearchResults + 1
					resultTable[queryResult.FirstScan].SearchResults[indexNextSearchResult] = {}
					resultTable[queryResult.FirstScan].SearchResults[indexNextSearchResult].PeptideID = queryResult.PeptideID
					resultTable[queryResult.FirstScan].SearchResults[indexNextSearchResult].Sequence = queryResult.Sequence
					resultTable[queryResult.FirstScan].SearchResults[indexNextSearchResult].MissedCleavages = queryResult.MissedCleavages
					resultTable[queryResult.FirstScan].SearchResults[indexNextSearchResult].ConfidenceLevel = queryResult.ConfidenceLevel
					resultTable[queryResult.FirstScan].SearchResults[indexNextSearchResult].SearchEngineRank = queryResult.SearchEngineRank
					resultTable[queryResult.FirstScan].SearchResults[indexNextSearchResult].Modifications = {}
					resultTable[queryResult.FirstScan].SearchResults[indexNextSearchResult].XCorr = false
					resultTable[queryResult.FirstScan].SearchResults[indexNextSearchResult].qValue = false
					resultTable[queryResult.FirstScan].SearchResults[indexNextSearchResult].pep = false
					resultTable[queryResult.FirstScan].NumberIdentifiedPeptides = #resultTable[queryResult.FirstScan].SearchResults
				end
			end
		end
		
		-- Return the scan sequence, formated result table
		return resultTable
	end
	
	-- Format the base query for the optimized query into the scan table structure
	function tbl:OptimizedQueryFormatScoreQuery(parameters)
		print("  Format the optimized score query into a table indexed by scan number")
		
		-- Initialize a few local variables
		parameters = parameters or {}
		if not parameters.queryResult then
			print("usage: tbl:OptimizedQueryFormatScoreQuery{resultTable = table,queryResult = result}")
			return false
		end
		local resultTable = parameters.resultTable
		local queryResult = parameters.queryResult
		
		-- Parse the query results, and append results that belong to the same scan (multiple matches with multiple search results)
		for _,queryResult in ipairs(parameters.queryResult) do
			
			-- Check to see if the first scan already exist.  It should because the base query should have grabbed this result
			-- Create a new entry if it is, otherwise append to the current entry
			if resultTable[queryResult.FirstScan] then
				-- Check to see if the PeptideID already exists in the search result table.  Again, it really should.  All we are doing is adding scores
				local containsPeptideID,indexPeptideID = false,false
				for index,searchResult in ipairs(resultTable[queryResult.FirstScan].SearchResults) do
					if queryResult.PeptideID == searchResult.PeptideID then
						containsPeptideID = true
						indexPeptideID = index
						break
					end
				end
				if containsPeptideID then
					-- Add any additional scores (don't bother checking, just overwrite whatever is there)
					if queryResult.XCorr then
						resultTable[queryResult.FirstScan].SearchResults[indexPeptideID].XCorr = queryResult.XCorr
					end
					if queryResult.CustomScoreType and (queryResult.CustomScoreType == "4" or queryResult.CustomScoreType == "6") then
						resultTable[queryResult.FirstScan].SearchResults[indexPeptideID].qValue = queryResult.CustomScoreValue
					end
					if queryResult.CustomScoreType and (queryResult.CustomScoreType == "5" or queryResult.CustomScoreType == "7") then
						resultTable[queryResult.FirstScan].SearchResults[indexPeptideID].pep = queryResult.CustomScoreValue
					end
				else
					print("Warning - you shouldn't be loading a score into a scan that doesn't have a matching peptide ID")
				end
			else
				print("Warning - you shouldn't have scan result from the score query that doesn't already have a matching scan from the base query")
			end
		end
		
		-- Return the scan sequence, formated result table
		return resultTable
	end	
	
	-- Format the base query for the optimized query into the scan table structure
	function tbl:OptimizedQueryFormatModQuery(parameters)
		print("  Format the optimized mode query into a table indexed by scan number")
		
		-- Initialize a few local variables
		parameters = parameters or {}
		if not parameters.queryResult then
			print("usage: tbl:OptimizedQueryFormatModQuery{resultTable = table,queryResult = result}")
			return false
		end
		local resultTable = parameters.resultTable
		local queryResult = parameters.queryResult
		
		-- Parse the query results, and append results that belong to the same scan (multiple matches with multiple search results)
		for _,queryResult in ipairs(parameters.queryResult) do
			
			-- Check to see if the first scan already exist.  It should because the base query should have grabbed this result
			-- Create a new entry if it is, otherwise append to the current entry
			if resultTable[queryResult.FirstScan] then
				
				-- Check to see if the PeptideID already exists in the search result table.  If it does then we need to append some additional fields
				-- (e.g., score or modifications).  If it doesnt then we need to create a new search result entry
				local containsPeptideID,indexPeptideID = false,false
				for index,searchResult in ipairs(resultTable[queryResult.FirstScan].SearchResults) do
					if queryResult.PeptideID == searchResult.PeptideID then
						containsPeptideID = true
						indexPeptideID = index
						break
					end
				end
				
				if containsPeptideID then
					
					-- Add any additional modifications
					if queryResult.ModificationPosition then
						local containsModificationPosition = false
						for _,searchResult in ipairs(resultTable[queryResult.FirstScan].SearchResults[indexPeptideID].Modifications) do
							if queryResult.ModificationPosition == searchResult.ModificationPosition then
								containsModificationPosition = true
								break
							end
						end
						if not containsModificationPosition then
							table.insert(resultTable[queryResult.FirstScan].SearchResults[indexPeptideID].Modifications,
																			{ModificationName = queryResult.ModificationName,
																				ModDeltaMass = queryResult.ModDeltaMass,
																				ModificationPosition = queryResult.ModificationPosition})
						end
					end
					
				else
					print("Warning - you shouldn't be loading a mod into a scan that doesn't have a matching peptide ID")
				end
			else
				print("Warning - you shouldn't have mod result from the mod query that doesn't already have a matching scan from the base query")
			end
		end
		
		-- Return the scan sequence, formated result table
		return resultTable
	end	
	
	-- Format the query result into a table index by scan
	-- This adds some additional functionality to the result as well
	-- (e.g., totalPSMs())
	function tbl:FormatQueryResultIntoScanTable(parameters)
		print("Format the query results into a table indexed by scan number")
		
		-- Initialize a few local variables
		parameters = parameters or {}
		if not parameters.queryResult then
			print("usage: tbl:FormatQueryResultToScanTable{queryResult = result}")
			return false
		end
		local formatedResult = {}
		
		-- Add a few handy functions to the results table
		function formatedResult:TotalPSMs()
			local totalPSMs = 0
			for _,scan in pairs(self) do
				if type(scan) == "table" and scan.NumberIdentifiedPeptides then
					totalPSMs = totalPSMs + scan.NumberIdentifiedPeptides 
				end
			end
			
			return totalPSMs
		end
		
		-- Parse the query results, and append results that belong to the same scan (multiple matches with multiple search results)
		for _,queryResult in ipairs(parameters.queryResult) do
			-- Check to see if this is the first result for this scan
			-- Create a new entry if it is, otherwise append to the current entry
			if not formatedResult[queryResult.FirstScan] then
				formatedResult[queryResult.FirstScan] = {}
				-- Set the "global" scan parameters
				formatedResult[queryResult.FirstScan].SpectrumFile = queryResult.SpectrumFile
				formatedResult[queryResult.FirstScan].FirstScan = queryResult.FirstScan
				formatedResult[queryResult.FirstScan].LastScan = queryResult.LastScan
				formatedResult[queryResult.FirstScan].RT = queryResult.RT
				formatedResult[queryResult.FirstScan].MSOrder = queryResult.MSOrder
				formatedResult[queryResult.FirstScan].ActivationType = queryResult.ActivationType
				formatedResult[queryResult.FirstScan].MassAnalyzer = queryResult.MassAnalyzer
				formatedResult[queryResult.FirstScan].IonInjectionTime = queryResult.IonInjectionTime
				formatedResult[queryResult.FirstScan].IsolationInterference = queryResult.IsolationInterference
				formatedResult[queryResult.FirstScan].PrecursorCharge = queryResult.PrecursorCharge
				formatedResult[queryResult.FirstScan].PrecursorMH = queryResult.PrecursorMH
				formatedResult[queryResult.FirstScan].PrecursorMZ = queryResult.PrecursorMZ
				formatedResult[queryResult.FirstScan].NumberIdentifiedPeptides = 0
				-- Create the first search result entry
				-- Only bother in cases where a PeptideID was assigned (otherwise we are just looking at scan info)
				if queryResult.PeptideID then
					formatedResult[queryResult.FirstScan].SearchResults = {}
					formatedResult[queryResult.FirstScan].SearchResults[1] = {}
					formatedResult[queryResult.FirstScan].SearchResults[1].PeptideID = queryResult.PeptideID
					formatedResult[queryResult.FirstScan].SearchResults[1].Sequence = queryResult.Sequence
					formatedResult[queryResult.FirstScan].SearchResults[1].MissedCleavages = queryResult.MissedCleavages
					formatedResult[queryResult.FirstScan].SearchResults[1].IonsMatched = queryResult.IonsMatched
					formatedResult[queryResult.FirstScan].SearchResults[1].Modifications = {}
					if queryResult.ModificationPosition then
						table.insert(formatedResult[queryResult.FirstScan].SearchResults[1].Modifications,
																		{ModificationName = queryResult.ModificationName,
																			ModDeltaMass = queryResult.ModDeltaMass,
																			ModificationPosition = queryResult.ModificationPosition})
					end
					formatedResult[queryResult.FirstScan].SearchResults[1].ConfidenceLevel = queryResult.ConfidenceLevel
					formatedResult[queryResult.FirstScan].SearchResults[1].SearchEngineRank = queryResult.SearchEngineRank
					formatedResult[queryResult.FirstScan].SearchResults[1].XCorr = queryResult.XCorr
					if queryResult.CustomScoreType and (queryResult.CustomScoreType == "4" or queryResult.CustomScoreType == "6") then
						formatedResult[queryResult.FirstScan].SearchResults[1].qValue = queryResult.CustomScoreValue
					end
					if queryResult.CustomScoreType and (queryResult.CustomScoreType == "5" or queryResult.CustomScoreType == "7") then
						formatedResult[queryResult.FirstScan].SearchResults[1].pep = queryResult.CustomScoreValue
					end
					formatedResult[queryResult.FirstScan].NumberIdentifiedPeptides = #formatedResult[queryResult.FirstScan].SearchResults
				end
			-- If the scan is already in the results table, and a PeptideID doesn't exis, then this is just a repeat of the
			-- scan information.  Don't bother assigning any more information to the table
			elseif queryResult.PeptideID then
				-- Check to see if the PeptideID already exists in the search result table.  If it does then we need to append some additional fields
				-- (e.g., score or modifications).  If it doesnt then we need to create a new search result entry
				local containsPeptideID,indexPeptideID = false,false
				for index,searchResult in ipairs(formatedResult[queryResult.FirstScan].SearchResults) do
					if queryResult.PeptideID == searchResult.PeptideID then
						containsPeptideID = true
						indexPeptideID = index
						break
					end
				end
				if containsPeptideID then
					-- Add any additional scores (don't bother checking, just overwrite whatever is there)
					if queryResult.CustomScoreType and (queryResult.CustomScoreType == "4" or queryResult.CustomScoreType == "6") then
						formatedResult[queryResult.FirstScan].SearchResults[indexPeptideID].qValue = queryResult.CustomScoreValue
					end
					if queryResult.CustomScoreType and (queryResult.CustomScoreType == "5" or queryResult.CustomScoreType == "7") then
						formatedResult[queryResult.FirstScan].SearchResults[indexPeptideID].pep = queryResult.CustomScoreValue
					end
					-- Add any additional modifications
					if queryResult.ModificationPosition then
						local containsModificationPosition = false
						for _,searchResult in ipairs(formatedResult[queryResult.FirstScan].SearchResults[indexPeptideID].Modifications) do
							if queryResult.ModificationPosition == searchResult.ModificationPosition then
								containsModificationPosition = true
								break
							end
						end
						if not containsModificationPosition then
							table.insert(formatedResult[queryResult.FirstScan].SearchResults[indexPeptideID].Modifications,
																			{ModificationName = queryResult.ModificationName,
																				ModDeltaMass = queryResult.ModDeltaMass,
																				ModificationPosition = queryResult.ModificationPosition})
						end
					end
				else
					local indexNextSearchResult = #formatedResult[queryResult.FirstScan].SearchResults + 1
					formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult] = {}
					formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult].PeptideID = queryResult.PeptideID
					formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult].Sequence = queryResult.Sequence
					formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult].MissedCleavages = queryResult.MissedCleavages
					formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult].IonsMatched = queryResult.IonsMatched
					formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult].Modifications = {}
					if queryResult.ModificationPosition then
						table.insert(formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult].Modifications,
																		{ModificationName = queryResult.ModificationName,
																			ModDeltaMass = queryResult.ModDeltaMass,
																			ModificationPosition = queryResult.ModificationPosition})
					end
					formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult].ConfidenceLevel = queryResult.ConfidenceLevel
					formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult].SearchEngineRank = queryResult.SearchEngineRank
					formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult].XCorr = queryResult.XCorr
					if queryResult.CustomScoreType and (queryResult.CustomScoreType == "4" or queryResult.CustomScoreType == "6") then
						formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult].qValue = queryResult.CustomScoreValue
					end
					if queryResult.CustomScoreType and (queryResult.CustomScoreType == "5" or queryResult.CustomScoreType == "7") then
						formatedResult[queryResult.FirstScan].SearchResults[indexNextSearchResult].pep = queryResult.CustomScoreValue
					end
					formatedResult[queryResult.FirstScan].NumberIdentifiedPeptides = #formatedResult[queryResult.FirstScan].SearchResults
				end
			end
		end
		
		-- Return the scan sequence, formated result table
		return formatedResult
	end
	
	-- Main function for querying results from PD DB
	function tbl:QueryDb(parameters)
		
		-- Initialize a few local parameters
		parameters = parameters or {}
		parameters.queryType = parameters.queryType or "Full"
		
		-- Perform the database query
		local queryResult
		if parameters.queryType == "Full" then
			queryResult = self:QueryFull(parameters)
		elseif parameters.queryType == "Spectrum" then
			queryResult = self:QuerySpectrum(parameters)
		elseif parameters.queryType == "Spectra" then
			queryResult = self:QuerySpectra(parameters)
		elseif parameters.queryType == "OptimizedFull" then 
			return self:QueryFullOptimized(parameters)
		else
			print("usage: tbl:QueryDb{queryType = type [,optional parameters]}")
		end
		
		-- Format the DB query result
		local formatedResult
		if queryResult then
			formatedResult = self:FormatQueryResultIntoScanTable{queryResult = queryResult}
		else
			print("Warning the query didn't return any results!!!")
			formatedResult = false
		end

		-- Return the formated result
		return formatedResult
	end
	
	-- Check to see what parameters were passed into the pdResult constructor
	-- Call the appropriate functions
	parameters = parameters or {}
	if parameters.fileName then
		tbl:Open{fileName = parameters.fileName, directory = parameters.directory}
	end
	
	-- Return the new pdResult
	return tbl
end


-- Perform basic testDb operations

--testDb = pdResult:New()
--testDb:Open{fileName = "Test.msf", directory = "C:/Users/graeme.mcalister/Desktop/Work/Projects/MIPS development/"}
--local time_01 = socket.gettime()
----local testResult = testDb:QueryDb{queryType = "Full", firstScan = 1, lastScan = 20, excludeMods = false}
----local testResult = testDb:QueryDb{queryType = "Spectra", firstScan = 1, lastScan = 10}
----local testResult = testDb:QueryDb{queryType = "Spectrum", scanNumber=43117, searchRank = 1}
--local testResult = testDb:QueryDb{queryType = "OptimizedFull", 
----									firstScan = 1, 
----									lastScan = 20, 
----									confidence = "High",
--									returnDecoy = false,
--									}
--local time_02 = socket.gettime()

--print("Total time to fetch the query result: " .. time_02 - time_01)
--print(testResult:TotalPSMs())
--PrintInfo(testResult:RetrieveScan(45000),true)




