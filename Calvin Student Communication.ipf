#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//-----------------------------------------------------------------------------------
//
//     Calvin — Online Instruction in Acid-Base Chemistry
//		 © 2020, Melissa A. Hines	
//		 Melissa.Hines@cornell.edu
//
//-----------------------------------------------------------------------------------

// ---------------------------- Error Reporting -----------------------------------------
constant kInvalidVesselForPh = 1001
constant kLowVolForPH = 1002
constant kVesselExists = 1003
constant kConflictingAcid = 1004
constant kFlaskFull = 1005
constant kInsufficientVol = 1006
constant kOverflow = 1007
constant kMissingIndicator = 1008
constant kConflictingIndicator = 1009
constant kColorlessSolution = 1010
constant kPHerror = 1011
constant kMixingAcids = 1012
constant kMixingIndicators = 1013
constant kMissingAcid = 1014
constant kVesselMissing = 1015
constant kNotBeaker = 1016
constant kNotFlask = 1017
constant kNegativeVolume = 1018
constant kBuretEmpty = 1019
constant kBadCommand = 1020
constant kBeakerFull = 1021
constant kNegativeMass = 1022
constant kSpectrumClipping = 1023
constant kBadTAname = 1024
constant kBadGroupName = 1025
constant kMissingBuffer = 1026
constant kTooMuchAcid = 1027
constant kTooManyCommands = 1028
constant kNoSolidAcids = 1029
constant kNoBuffers = 1030
constant kTransferToSameVessel = 1031
constant kConflictingString = 103

Function WriteSimpleErrorToLog(errType, arg)
variable errType
string arg

	string theNote

	switch(errType)	// string switch
		case kInvalidVesselForPh:
			theNote = "The pH measurement could not be completed because the vessel " + arg + " does not exist.\r"
			break
		case kLowVolForPH:
			theNote = "There is not enough solution in " + arg + " for a pH measurement.\r"
			break
		case kVesselExists:
			theNote = "I'm sorry. A vessel by the name of " + arg + " already exists.\r"
			break
		case kVesselMissing:
			theNote = "I'm sorry. The vessel " + arg + " does not exist.\r"
			break
		case kConflictingAcid:
			theNote = "I'm sorry. This vessel already contains solid acid " + arg + ".\r"
			break
		case kFlaskFull:
			theNote = "The flask named " + arg + " appears to be full of H2O. Ignoring command.\r"
			break
		case kInsufficientVol:
			theNote = "There is not enough solution in " + arg + " for the transfer. Make sure your volume is in ml.\r"
			break
		case kOverflow:
			theNote = "Oh, no! You put too much solution in " + arg + ". What a mess! "
			theNote += "Clean and dry " + arg + ".\r"
			break
		case kMissingIndicator:
			theNote = "We do not have the indicator " + arg + ".\r"
			break
		case kMissingAcid:
			theNote = "We do not have the solid acid " + arg + ".\r"
			break
		case kMissingBuffer:
			theNote = "We do not have the buffer " + arg + ".\r"
			break
		case kConflictingIndicator:
			theNote = "This solution already contains " + arg + ". Adding a different indicator would be bad.\r"
			break
		case kColorlessSolution:
			theNote = "The solution in " + arg + " is colorless. Taking a spectrum would be pointless.\r"
			break
		case kPHerror:
			theNote = "Something is wrong. The pH of vessel " + arg + " is problematic. Aborting spectrum acquisition.\r"
			break
		case kNotBeaker:
			theNote = "I'm sorry. The vessel " + arg + " is not a beaker. Exiting now.\r"
			break
		case kNotFlask:
			theNote = "I'm sorry. The vessel " + arg + " is not a volumetric flask. Exiting now.\r"
			break
		case kNegativeVolume:
			theNote = "You cannot transfer a negative volume!\r"
			break
		case kBuretEmpty:
			theNote = "I'm sorry, but your buret is empty.\r"
			break
		case kBadCommand:
			theNote = "Bad Command Ignored: " + arg + "\r"
			WriteCommandErrorToLog(theNote)
			return 0
		case kBeakerFull:
			theNote = "The vessel into which you are titrating is full. Stopping titration.\r"
			break
		case kNegativeMass:
			theNote = "You cannot transfer a negative mass!\r"
			break
		case kSpectrumClipping:
			theNote = "Your solution is too concentrated! The spectrum is being clipped at some wavelengths.\r"
			break
		case kBadTAname:
			theNote = "There is no TA by the name of " + arg + ".\r"
			break
		case kBadGroupName:
			theNote = "There is no group by the name of " + arg + ".\r"
			break
		case kTooMuchAcid:
			theNote = "That is an excessive amount of acid. " + arg + " grams will not dissolve in any of your glassware.\r"
			break
		case kTooManyCommands:
			theNote = "You are limited to " + arg + " commands per input file.\r"
			break
		case kNoSolidAcids:
			theNote = "We are not working with solid acids today.\r"
			break
		case kNoBuffers:
			theNote = "We are not working with buffers today.\r"
			break
		case kTransferToSameVessel:
			theNote = "Transferring solution from " + arg + " to itself would be silly.\r"
			break
		case kConflictingString:
			theNote = "The name " + arg + " conflicts with Calvin. Please use a different name.\r"
			break
		default:			// optional default expression executed
			theNote = "Unknown error type. You shouldn't see this.\r"
	endswitch
	WriteErrorToLog(theNote)
End
Function WriteDoubleErrorToLog(errType, arg1, arg2)
variable errType
string arg1, arg2

	string theNote

	switch(errType)	// string switch
		case kMixingAcids:
			theNote = "Cannot combine solutions from " + arg1 + " and " + arg2
			theNote += ". Mixing solid acids is not allowed.\r"
			break
		case kMixingIndicators:
			theNote = "Cannot combine solutions from " + arg1 + " and " + arg2
			theNote += ". Mixing indicators is not allowed.\r"
			break
		default:			// optional default expression executed
			theNote = "Unknown error type. You shouldn't see this.\r"
	endswitch
	WriteErrorToLog(theNote)
End
// ---------------------------- Writing to the log -----------------------------------------
Function SetupNewLog()
	if(strlen(WinList("Experiment_Log", ";", "WIN:16")) > 10)
		Notebook Experiment_Log selection={startOfFile, endOfFile}, text=""
	else
		NewNotebook/ENCG=1/F=1/N=Experiment_Log
	endif
	Notebook Experiment_Log newRuler=headerRuler,margins={0,0,6.5*72},rulerDefaults={"Helvetica",11,0,(0,0,0)},spacing={0,0,0}
	Notebook Experiment_Log newRuler=cmdRuler,margins={0,0,6.5*72},rulerDefaults={"Helvetica",11,0,(0,0,0)},spacing={7,0,0}
	Notebook Experiment_Log newRuler=tightCmdRuler,margins={0,0,6.5*72},rulerDefaults={"Helvetica",11,0,(0,0,0)},spacing={0,0,0}
	Notebook Experiment_Log newRuler=outputRuler,margins={4,0,6.5*72},rulerDefaults={"Times New Roman",11,0,(0,0,0)},spacing={0,0,0}
	Notebook Experiment_Log headerControl={0, 0, 0} // Turn off default header since we cannot edit it
End
Function WriteToLog(theInfo)
string theInfo
	 
	NVAR gLastLineWasComment = root:MAH:gLastLineWasComment
	
	Notebook Experiment_Log selection={endOfFile, endOfFile}
	Notebook Experiment_Log ruler=outputRuler
	Notebook Experiment_Log text=theInfo
	gLastLineWasComment = 0
End
Function WriteErrorToLog(theInfo)
string theInfo
	 
	NVAR gLastLineWasComment = root:MAH:gLastLineWasComment
	
	Notebook Experiment_Log selection={endOfFile, endOfFile}
	Notebook Experiment_Log ruler=outputRuler
	Notebook Experiment_Log textRGB = (52428,1,1)
	Notebook Experiment_Log text=theInfo
	Notebook Experiment_Log textRGB = (0,0,0)
	gLastLineWasComment = 0
End
Function WriteCommandToLog(theInfo)
string theInfo
	 
	NVAR gLastLineWasComment = root:MAH:gLastLineWasComment
	
	Notebook Experiment_Log selection={endOfFile, endOfFile}
	if(gLastLineWasComment)
		Notebook Experiment_Log ruler=tightCmdRuler
	else
		Notebook Experiment_Log ruler=cmdRuler
	endif
	Notebook Experiment_Log textRGB = (1,16019,65535)
	Notebook Experiment_Log text=theInfo
	Notebook Experiment_Log textRGB = (0,0,0)
	gLastLineWasComment = 0
End
Function WriteCommentToLog(theInfo)
string theInfo
	 
	NVAR gLastLineWasComment = root:MAH:gLastLineWasComment
	
	Notebook Experiment_Log selection={endOfFile, endOfFile}
	if(gLastLineWasComment)
		Notebook Experiment_Log ruler=tightCmdRuler
	else
		Notebook Experiment_Log ruler=cmdRuler
	endif
	Notebook Experiment_Log textRGB = (2,39321,1)
	Notebook Experiment_Log text=theInfo
	Notebook Experiment_Log textRGB = (0,0,0)
	gLastLineWasComment = 1
End
Function WriteCommandErrorToLog(theInfo)
string theInfo
	 
	NVAR gLastLineWasComment = root:MAH:gLastLineWasComment

	Notebook Experiment_Log selection={endOfFile, endOfFile}
	if(gLastLineWasComment)
		Notebook Experiment_Log ruler=tightCmdRuler
	else
		Notebook Experiment_Log ruler=cmdRuler
	endif
	Notebook Experiment_Log textRGB = (52428,1,1)
	Notebook Experiment_Log text=theInfo
	Notebook Experiment_Log textRGB = (0,0,0)
	gLastLineWasComment = 0	
End
Function WriteTopGraphToLog()

	NVAR gLastLineWasComment = root:MAH:gLastLineWasComment
	string topWindow = WinList("*", "", "WIN:")
	 
	Notebook Experiment_Log selection={endOfFile, endOfFile}
	Notebook Experiment_Log picture = {$topWindow, -5, 1, 4}
End
Function WriteBlankLineToLog()
	string theInfo = "\r"
	 
	NVAR gLastLineWasComment = root:MAH:gLastLineWasComment

	Notebook Experiment_Log selection={endOfFile, endOfFile}
	Notebook Experiment_Log text=theInfo
	gLastLineWasComment = 0	
End
