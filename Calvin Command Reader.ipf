#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//-----------------------------------------------------------------------------------
//
//     Calvin — Online Instruction in Acid-Base Chemistry
//		 © 2020, Melissa A. Hines	
//		 Melissa.Hines@cornell.edu
//
//-----------------------------------------------------------------------------------

Function InitCommandReader()
	
	DFREF savedDF= GetDataFolderDFR()
	NewDataFolder/o root:MAH
	SetDataFolder root:MAH
	
	make/n=0/o/t validCommands
	wave/t validCommands
	InsertCommand("Make_New_25ml_Volumetric_Flask")
	InsertCommand("Make_New_50ml_Volumetric_Flask")
	InsertCommand("Fill_Volumetric_Flask_with_H2O")
	InsertCommand("Make_New_Test_Tube")
	InsertCommand("Make_New_100ml_Beaker")
	InsertCommand("Fill_Empty_100ml_Beaker_with_Standardized_Base")
	InsertCommand("Fill_Empty_100ml_Beaker_with_Standardized_Acid")
	InsertCommand("Fill_Empty_100ml_Beaker_with_Standardized_KSCN")
	InsertCommand("Fill_Empty_100ml_Beaker_with_Standardized_Ferric_Nitrate")
	InsertCommand("Fill_Empty_100ml_Beaker_with_H2O")
	InsertCommand("Fill_Empty_100ml_Beaker_with_Standardized_Buffer")
	InsertCommand("Fill_Empty_100ml_Beaker_with_Unknown_Buffer")
	InsertCommand("Transfer_Soln_with_5ml_Pipette")
	InsertCommand("Transfer_Soln_with_10ml_Pipette")
	InsertCommand("Transfer_Soln_with_20ml_Pipette")
	InsertCommand("Transfer_Soln_with_Graduated_Cylinder")
	InsertCommand("Fill_50ml_Buret")
	InsertCommand("Add_Soln_from_Buret")
	InsertCommand("Read_Buret_Volume")
	InsertCommand("Add_Solid_Acid_to_Vessel")
	InsertCommand("Add_One_Drop_of_Indicator")
	InsertCommand("Measure_pH")
	InsertCommand("Observe_Color")
	InsertCommand("Observe_Color_Range")
	InsertCommand("Titrate_Beaker_from_Buret_until_Color_Change")
	InsertCommand("Take_Spectrum")
	InsertCommand("Clean_and_Dry")
	InsertCommand("Verbose_Reporting_On")
	InsertCommand("Verbose_Reporting_Off")
	InsertCommand("Observe_Volume")
	InsertCommand("Set_Group_Name")
	InsertCommand("Set_TA_Name")
	SetDataFolder savedDF

End
Function InsertCommand(cmd)
string cmd

	wave/t validCommands = root:MAH:validCommands	
	InsertPoints 0, 1, validCommands
	validCommands[0] = cmd
End
Function StartWatchingFolder()
	
	Variable numTicks = 2 * 60		// Run every 2 seconds (120 ticks)
	variable/g root:MAH:gFilesProcessed = 0, root:MAH:gCalvinWorking = 0
	CtrlNamedBackground WatchFolder, period=numTicks, proc=ExamineFolder
	CtrlNamedBackground WatchFolder, start
End
Function StopWatchingFolder()
	CtrlNamedBackground WatchFolder, stop
End
Function ExamineFolder(s)
STRUCT WMBackgroundStruct &s

	NVAR calvinWorking = root:MAH:gCalvinWorking
	if(calvinWorking == 0)
		doExamineFolder()
	endif
	return 0
End
Function doExamineFolder()
	string theList, nextFile, tempStr
	variable numToProcess = 0
	NVAR filesProcessed = root:MAH:gFilesProcessed
	NVAR calvinWorking = root:MAH:gCalvinWorking

	calvinWorking = 1
	theList = IndexedFile(watchedFolder, -1, "????")
	theList = RemoveFromList(".DS_Store", theList, ";", 0)
	numToProcess = ItemsInList(theList, ";")
	if(numToProcess == 0)
		calvinWorking = 0
		return 0
	endif

	do
		nextFile = StringFromList(numToProcess - 1, theList)
		GetFileFolderInfo/P=watchedFolder/Z/Q nextFile		// Does the file exist
		if(V_flag != 0)												// No, it does not. Assume there is a file with one or more ";" in the filename
			do
				numToProcess -= 1
				tempStr = nextFile
				nextFile = StringFromList(numToProcess - 1, theList) + ";" + tempStr
				GetFileFolderInfo/P=watchedFolder/Z/Q nextFile
			while((V_flag != 0) && numToProcess > -0.5)
		endif
		if(V_flag == 0)
			RunCommandFile(nextFile)
			DeleteFile/P=watchedFolder nextFile
			numToProcess -= 1
			filesProcessed += 1
			print "Processed file " + nextFile + ". Total files processed = " + num2istr(filesProcessed)
		else
			print "There is an unexpected error in StartWatchingFolder."
		endif
	while(numToProcess > 0)
	calvinWorking = 0
End
Function RunCommandFile(fileName)
string fileName
	
	string buffer, cmd, igorCmd, outputFilename, theNote, cwd, cloudPath
	variable refNum, len, dotPosition
	NVAR gVerboseReporting = root:MAH:gVerboseReporting, gTANumber = root:MAH:gTAnumber
	NVAR gGroupNumber = root:MAH:gGroupNumber, gMaxCommands = root:MAH:gMaxCommands
	SVAR gCmdFileName = root:MAH:gCmdFileName, gRunTime = root:MAH:gRunTime

	// Strip extension from fileName
	dotPosition = StrSearch(fileName, ".", 0)
	if(dotPosition > -1)
		gCmdFileName = fileName[0, dotPosition - 1]
	else
		gCmdFileName = fileName
	endif
	NewExperiments()	// Closes any open files

	Open/P=watchedFolder/R refNum as fileName
	string fullPath = S_fileName
	
	variable ii = 0, numCommands = 0
	do
		FReadLine refNum, buffer
		if(strlen(buffer) == 0)
			break
		endif
		if (CmpStr(buffer[len-1],"\r") != 0)	// Last line has no CR ?
			buffer += "\r"
		endif
		ii += 1
		
		// Echo lines starting with / to the Notebook, but don't process
		if(strsearch(buffer, "/", 0) != 0)
			cmd = CleanCommandLine(buffer)
			if(strlen(cmd) > 0)	// Got a command
				igorCmd = RemovePrompts(cmd)
				igorCmd = ValidatedIgorCommand(igorCmd)
				if(strlen(igorCmd) > 0)
					if(gVerboseReporting)
						WriteCommandToLog(cmd)
					endif
					Execute/Z igorCmd
					numCommands += 1
				else
					WriteSimpleErrorToLog(kBadCommand, cmd)
				endif			
			endif
		else
			if(gVerboseReporting)
				buffer = ReplaceString("\r", buffer, "")
				buffer += "\r"
				WriteCommentToLog(buffer)
			endif
		endif

	while(ii < 500 && numCommands < gMaxCommands)
	Close refNum

	if(numCommands == gMaxCommands)
		WriteSimpleErrorToLog(kTooManyCommands, num2istr(gMaxCommands))
	endif
	if(numCommands < 1)	// The file was probably not text, and nothing useful came out
		return -1
	endif
	
	// Save the experiment
	wave/t Group_Names = root:MAH:Group_Names
	SVAR gBadGroupName = root:MAH:gBadGroupName, gBadTAName = root:MAH:gBadTAName
	if(gGroupNumber < 0)
		outputFileName = gBadGroupName + "_" + gCmdFileName + "_" + gRunTime
	else
		outputFileName = Group_Names[gGroupNumber] + "_" + gCmdFileName + "_" + gRunTime
	endif
	outputFileName = StripBadCharacters(outputFileName)
	theNote = "Calvin command file: " + fileName + "\r"
	theNote += "Output file: " + outputFilename + "\r" 
	Notebook Experiment_Log selection={startOfFile, startOfFile}
	Notebook Experiment_Log fStyle = 1, fSize = 13
	Notebook Experiment_Log ruler=headerRuler
	Notebook Experiment_Log textRGB = (0, 0, 0)
	Notebook Experiment_Log text=theNote

	SaveNotebook/P=tempFolder/O/S=4 Experiment_Log as "Experiment_Log.rtf"
	PathInfo tempFolder
	string newFolder = ParseFilePath(1, S_path, ":", 1,0) + outputFileName
	
	CopyFolder/i=0/o S_path as newFolder
	
	// Zip the folder, then delete the unzipped
	PathInfo tempFolder
	cwd = ParseFilePath(9, ParseFilePath(1, S_path, ":", 1, 0), "*", 0, 0)	
	cmd = "cd '" + cwd + "';zip -r -X '" + outputFileName + ".zip' '" + outputFileName + "'"
	ExecuteUnixShellCommand(cmd)
	cmd = "cd '" + cwd + "';rm -rf '" + outputFileName + "'"
	ExecuteUnixShellCommand(cmd)
	
	// Copy the zipped file to Box
	wave/t TA_Names = root:MAH:TA_Names
	pathInfo cloudFolder
	if(gTAnumber < 0)
		cloudPath = ParseFilePath(9, S_path, ":", 1,0) + "_Lost&Found" + "/" 
	else
		cloudPath = ParseFilePath(9, S_path, ":", 1,0) + TA_Names[gTAnumber] + "/"
	endif
	if(gGroupNumber < 0)
		cloudPath += "_Lost&Found" + "/"
	else
		cloudPath += Group_names[gGroupNumber] + "/"
	endif
	
	// Check to make sure no one renamed the folder
	if(CheckPath(cloudPath) < 0)
		print "The path " + cloudPath + " does not exist."
		print "ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR!"
		print "ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR!"
		print "ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR!"
	else
		cmd = "cd '" + cwd + "';mv '" + outputFileName + ".zip' '" + cloudPath + "'"
		ExecuteUnixShellCommand(cmd)
	endif
End
Function/S StripBadCharacters(fileName)
string fileName

	fileName = ReplaceString(":", fileName, "_")
	fileName = ReplaceString("/", fileName, "_")
	fileName = ReplaceString("\\", fileName, "_")
	fileName = ReplaceString(" ", fileName, "_")
	fileName = ReplaceString("?", fileName, "_")
	fileName = ReplaceString("%", fileName, "_")
	fileName = ReplaceString("*", fileName, "_")
	fileName = ReplaceString("|", fileName, "_")
	fileName = ReplaceString("\"", fileName, "_")
	fileName = ReplaceString("<", fileName, "_")
	fileName = ReplaceString(">", fileName, "_")
	fileName = ReplaceString("'", fileName, "")		// Added to fix problems with Beer's Law
	return fileName
End
Function MakeAllTAFolders()

	variable ii, jj
	string cloudPath, theTApath, theGroupPath, cmd
	wave/t TA_Names = root:MAH:TA_Names, Group_Names = root:MAH:Group_Names
	
	pathInfo cloudFolder
	cloudPath = ParseFilePath(9, S_path, ":", 1,0)
	for(ii = 0; ii < numpnts(TA_Names); ii += 1)
		theTApath = cloudPath + TA_Names[ii] + "/"
		cmd = "mkdir -p '" + theTApath + "'"
		ExecuteUnixShellCommand(cmd)
		for(jj = 0; jj < numpnts(Group_Names); jj += 1)
			theGroupPath = theTApath + Group_Names[jj] + "/"
			cmd = "mkdir -p '" + theGroupPath + "'"
			ExecuteUnixShellCommand(cmd)
		endfor
		theGroupPath = theTApath + "_Lost&Found" + "/"
		cmd = "mkdir -p '" + theGroupPath + "'"
		ExecuteUnixShellCommand(cmd)
	endfor
	theTApath = cloudPath + "_Lost&Found" + "/"
	cmd = "mkdir -p '" + theTApath + "'"
	ExecuteUnixShellCommand(cmd)
	for(jj = 0; jj < numpnts(Group_Names); jj += 1)
		theGroupPath = theTApath + Group_Names[jj] + "/"
		cmd = "mkdir -p '" + theGroupPath + "'"
		ExecuteUnixShellCommand(cmd)
	endfor
	theGroupPath = theTApath + "_Lost&Found" + "/"
	cmd = "mkdir -p '" + theGroupPath + "'"
	ExecuteUnixShellCommand(cmd)
End
Function/S ExecuteUnixShellCommand(unixCmd)
String unixCmd
	// Paths must be POSIX paths (using /).
	// Paths containing spaces or other nonstandard characters
	// must be single-quoted. 
	String igorCmd
	
	sprintf igorCmd, "do shell script \"%s\"", unixCmd
//	Print igorCmd		// For debugging only

	ExecuteScriptText/UNQ/Z igorCmd
	if(V_flag != 0)
		print "Command: " + igorCmd
		print "EUSC Error: " + S_value
		print "ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR!"
		print "ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR!"
		print "ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR!"
	endif

//	Print S_value		// For debugging only
	return S_value
End
Function CheckPath(unixCmd)
String unixCmd
	// Paths must be POSIX paths (using /).
	// Paths containing spaces or other nonstandard characters
	// must be single-quoted. 
	String igorCmd
	
	sprintf igorCmd, "do shell script \"ls '%s'\"", unixCmd

	ExecuteScriptText/UNQ/Z igorCmd
	if(V_flag != 0)
		print "Command: " + igorCmd
		print "Check Path Error: " + S_value
		print "ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR!"
		print "ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR!"
		print "ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR! ERROR!"
		return -1
	else
		return 1
	endif
End

Function/S CleanCommandLine(buffer)
string buffer

	variable openParenPos, closeParenPos, ii
	string cmd, doubleQuote = "\"", tab = "\t"
	wave/t validCommands = root:MAH:validCommands
	
	buffer = TrimString(buffer, 1)	// Remove leading and trailing whitespace
	if(strlen(buffer) < 1)
//		WriteBlankLineToLog()
		return ""
	endif
	closeParenPos = strsearch(buffer,")",0)
	openParenPos = strsearch(buffer, "(", 0)
	if((closeParenPos < 0) || (openParenPos < 0))
		WriteSimpleErrorToLog(kBadCommand, buffer)
		return ""
	endif
	
	cmd = buffer[0, openParenPos - 1]
	for(ii = 0; ii < numpnts(validCommands);ii = ii + 1)
		if(CmpStr(cmd, validCommands[ii], 0) == 0)
			break
		endif
	endfor

	if(ii == numpnts(validCommands))
		WriteSimpleErrorToLog(kBadCommand, cmd)
		return ""
	endif
	
	// Truncate everything after the closing paren
	cmd = buffer[0, closeParenPos]
	
	// Get rid of curly quotes and other troublemakers
	cmd = ReplaceString("“", cmd, doubleQuote)
	cmd = ReplaceString("”", cmd, doubleQuote)
	cmd = ReplaceString("‘", cmd, doubleQuote)
	cmd = ReplaceString("’", cmd, doubleQuote)
	cmd = ReplaceString("'", cmd, doubleQuote)
	cmd = ReplaceString("—", cmd, "-")
	cmd = ReplaceString("bromcresol_green", cmd, "bromocresol_green")
	
	// Get rid of any spaces before semicolons
	if(strsearch(cmd, " :", 0) > 0)
		do
			cmd = ReplaceString(" :", cmd, ":")
		while(strsearch(cmd, " :", 0) > 0)
	endif
	
	// Add a CR
	cmd += "\r"
	
	return cmd
End
Function/S RemovePrompts(cmd)
string cmd

	string igorCmd
	
	igorCmd = ReplaceString("indicator:", cmd, "")
	igorCmd = ReplaceString("newName:", igorCmd, "")
	igorCmd = ReplaceString("buffer:", igorCmd, "")
	igorCmd = ReplaceString("grams:", igorCmd, "")
	igorCmd = ReplaceString("name:", igorCmd, "")
	igorCmd = ReplaceString("into:", igorCmd, "")
	igorCmd = ReplaceString("from:", igorCmd, "")
	igorCmd = ReplaceString("acid:", igorCmd, "")
	igorCmd = ReplaceString("of:", igorCmd, "")
	igorCmd = ReplaceString("to:", igorCmd, "")
	igorCmd = ReplaceString("mL:", igorCmd, "")
	igorCmd = ReplaceString("at:", igorCmd, "")
	return igorCmd
End
Function/S ValidatedIgorCommand(line)
string line

	variable openParenPos, closeParenPos, err = 0
	string cmd, args, cleanArgs
	NVAR gSolidAcidsEnabled = root:MAH:gSolidAcidsEnabled
	NVAR gBuffersEnabled = root:MAH:gBuffersEnabled

	closeParenPos = strsearch(line,")",0)
	openParenPos = strsearch(line, "(", 0)
	cmd = line[0, openParenPos - 1]
	args = line[openParenPos + 1, closeParenPos - 1]
	args = RemoveSpacesInStrings(args)
	
	// Check if experiment is running today
	if(!gSolidAcidsEnabled)
		if(CmpStr(cmd, "Add_Solid_Acid_to_Vessel", 0) == 0)
			WriteSimpleErrorToLog(kNoSolidAcids, "")
			return ""
		endif
	endif
	if(!gBuffersEnabled)
		if(CmpStr(cmd, "Fill_Empty_100ml_Beaker_with_Standardized_Buffer", 0) == 0)
			WriteSimpleErrorToLog(kNoBuffers, "")
			return ""
		endif
		if(CmpStr(cmd, "Fill_Empty_100ml_Beaker_with_Unknown_Buffer", 0) == 0)
			WriteSimpleErrorToLog(kNoBuffers, "")
			return ""
		endif
	endif	

	strswitch(cmd)
		case "Read_Buret_Volume":
		case "Verbose_Reporting_On":
		case "Verbose_Reporting_Off":
			err = (NumArgs(args) == 0) ? 0 : -1
			cleanArgs = ""
			break
		case "Make_New_25ml_Volumetric_Flask":
		case "Make_New_50ml_Volumetric_Flask":
		case "Fill_Volumetric_Flask_with_H2O":
		case "Make_New_Test_Tube":
		case "Make_New_100ml_Beaker":
		case "Fill_Empty_100ml_Beaker_with_Standardized_Base":
		case "Fill_Empty_100ml_Beaker_with_Standardized_Acid":
		case "Fill_Empty_100ml_Beaker_with_Standardized_KSCN":
		case "Fill_Empty_100ml_Beaker_with_Standardized_Ferric_Nitrate":
		case "Fill_Empty_100ml_Beaker_with_Standardized_Buffer":
		case "Fill_Empty_100ml_Beaker_with_H2O":
		case "Fill_50ml_Buret":
		case "Measure_pH":
		case "Observe_Color":
		case "Take_Spectrum":
		case "Titrate_Beaker_from_Buret_until_Color_Change":
		case "Take_Spectrum":
		case "Clean_and_Dry":
		case "Observe_Volume":
		case "Set_Group_Name":
		case "Set_TA_Name":
			if(NumArgs(args) == 1)
				cleanArgs = ValidateStr(args)
				err = strlen(cleanArgs) == 0 ? -1 : 0
			else
				err = -1
			endif
			break
		case "Transfer_Soln_with_5ml_Pipette":
		case "Transfer_Soln_with_10ml_Pipette":
		case "Transfer_Soln_with_20ml_Pipette":
		case "Fill_Empty_100ml_Beaker_with_Unknown_Buffer":
		case "Add_One_Drop_of_Indicator":
			if(NumArgs(args) == 2)
				cleanArgs = ValidateStrStr(args)
				err = strlen(cleanArgs) == 0 ? -1 : 0
			else
				err = -1
			endif
			break
		case "Transfer_Soln_with_Graduated_Cylinder":
		case "Add_Solid_Acid_to_Vessel":
			if(NumArgs(args) == 3)
				cleanArgs = ValidateNumStrStr(args)
				err = strlen(cleanArgs) == 0 ? -1 : 0
			else
				err = -1
			endif
			break
		case "Add_Soln_from_Buret":
			if(NumArgs(args) == 2)
				cleanArgs = ValidateNumStr(args)
				err = strlen(cleanArgs) == 0 ? -1 : 0
			else
				err = -1
			endif
			break
		case "Observe_Color_Range":
			if(NumArgs(args) == 2)
				cleanArgs = ValidateStrNum(args)
				err = strlen(cleanArgs) == 0 ? -1 : 0
			else
				err = -1
			endif
			break
	endswitch
	if(err < 0)
		return ""
	else
		return cmd + "(" + cleanArgs + ")\r"
	endif
End
Function/S ValidateStr(arg)
string arg

	string str1
	arg = ReplaceString(",", arg, " ")
	arg = ReplaceString("\"", arg, " ")
	sscanf arg, "%s", str1
	if(V_flag == 1 && !CheckIfNum(str1))
		if(CheckIfValidStr(str1))
			return "\"" + str1 + "\""
		endif
	endif
	return ""
End
Function CheckIfValidStr(arg)	// returns 1 if valid, 0 if not
// Only allow strings that start with a letter, then contain letters, numbers, and _
// This is not so much for Igor compatibility as for filename and Box compatibility
// Don't allow strings that conflict with Igor commands
string arg

	if(GrepString(arg,"([A-Za-z]+[A-Za-z0-9_]+)") ? 1 : 0)
		if(exists(arg) > 1)
			WriteSimpleErrorToLog(kConflictingString, arg)
			return 0
		else
			return 1
		endif
	else
		return 0
	endif
End
Function CheckIfNum(arg) // 1 if number, 0 if not
string arg
	variable num
	sscanf arg, "%f", num 
	return V_flag
End 
Function/S RemoveSpacesInStrings(arg)
string arg

	variable ii, endString, inString
	endString = strlen(arg)
	if(endString < 1)
		return ""
	else
		inString = 0
		ii = 0
		do
			if(CmpStr(arg[ii], "\"") == 0)
				inString = (inString == 0) ? 1 : 0
			elseif(inString > 0 && CmpStr(arg[ii], " ") == 0)
				arg = arg[0, ii-1] + "_" + arg[ii+1,endString - 1]
			endif
			ii += 1
		while(ii < endString)	
		return arg
	endif
End
Function/S ValidateStrStr(arg)
string arg
	
	string str1, str2
	arg = ReplaceString(",", arg, " ")
	arg = ReplaceString("\"", arg, " ")
	sscanf arg, "%s %s", str1, str2
	if(V_flag == 2 && !CheckIfNum(str1) && !CheckIfNum(str2))
		if(CheckIfValidStr(str1) && CheckIfValidStr(str2))
			return "\"" + str1 + "\", \"" + str2 + "\""
		endif
	endif
	return ""
End
Function/S ValidateNumStrStr(arg)
string arg
	string str1, str2
	variable num
	arg = ReplaceString(",", arg, " ")
	arg = ReplaceString("\"", arg, " ")
	sscanf arg, "%f %s %s", num, str1, str2
	if(V_flag == 3 && !CheckIfNum(str1) && !CheckIfNum(str2))
		if(CheckIfValidStr(str1) && CheckIfValidStr(str2))
			return num2str(num) + ", \"" + str1 + "\", \"" + str2 + "\""
		endif
	endif
	return ""
End
Function/S ValidateNumStr(arg)
string arg
	string str1
	variable num
	arg = ReplaceString(",", arg, " ")
	arg = ReplaceString("\"", arg, " ")
	sscanf arg, "%f %s", num, str1
	if(V_flag == 2 && !CheckIfNum(str1))
		if(CheckIfValidStr(str1))
			return num2str(num) + ", \"" + str1 + "\""
		endif
	endif
	return ""
End
Function/S ValidateStrNum(arg)
string arg
	string str1
	variable num
	arg = ReplaceString(",", arg, " ")
	arg = ReplaceString("\"", arg, " ")
	sscanf arg, "%s %f", str1, num
	if(V_flag == 2 && !CheckIfNum(str1))
		if(CheckIfValidStr(str1))
			return "\"" + str1 + "\", " + num2str(num)
		endif
	endif
	return ""
End
Function NumArgs(arg)
string arg
	
	string str1, str2, str3, str4
	arg = ReplaceString(",", arg, " ")
	arg = ReplaceString("\"", arg, " ")
	sscanf arg, "%s %s %s %s", str1, str2, str3, str4
	return V_flag
End
