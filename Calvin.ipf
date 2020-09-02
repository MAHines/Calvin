#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "Calvin Command Reader"
#include "Calvin Student Communication"
#include "Calvin Spectrum to Color"

//-----------------------------------------------------------------------------------
//
//     Calvin — Online Instruction in Acid-Base Chemistry
//		 © 2020, Melissa A. Hines	
//		 Melissa.Hines@cornell.edu
//
//-----------------------------------------------------------------------------------

Menu "Calvin"
	"Initialize Data"
	"Start Watching Folder"
	"Stop Watching Folder"
	"Save Calvin", SaveExperiment
	"-"
	"Make All TA Folders"
	"-"
	"Change Maximum Number of Commands"
	StrVarOrDefault("root:MAH:gCalvinAcidsMenuString","Disable Solid Acids"), /Q, ToggleSolidAcids()
	StrVarOrDefault("root:MAH:gCalvinBuffersMenuString","Disable Buffers"), /Q, ToggleBuffers()
	"-"
	StrVarOrDefault("root:MAH:gCalvinHideMenuString","Show All Igor Menus"), /Q, ToggleMenus()
	"-"
	"Randomize Unknown Indicators and Save", RandomizeUnkIndicatorsAndSave()
	"Randomize Unknown Acids and Save", RandomizeUnkAcidsAndSave()
	"Randomize Unknow Buffers and Save", RandomizeUnkBuffersAndSave()
	"-"
	"Quit Calvin", Quit/Y
End

Function ChangeMaximumNumberOfCommands()

	NVAR gMaxCommands = root:MAH:gMaxCommands
	variable newMax = gMaxCommands
	
	Prompt newMax, "Enter the new maximum number of commands: "
	DoPrompt "Maximum Commands", newMax
	if(V_flag)
		return -1	// User cancelled
	endif
	gMaxCommands = newMax
End
Function ToggleSolidAcids()

	NVAR gSolidAcidsEnabled = root:MAH:gSolidAcidsEnabled
	SVAR menuString = root:MAH:gCalvinAcidsMenuString
	
	if(gSolidAcidsEnabled)
		gSolidAcidsEnabled = 0
		menuString = "Enable Solid Acids"
	else
		gSolidAcidsEnabled = 1
		menuString = "Disable Solid Acids"
	endif
	BuildMenu "Calvin"
End
Function ToggleBuffers()

	NVAR gBuffersEnabled = root:MAH:gBuffersEnabled
	SVAR menuString = root:MAH:gCalvinBuffersMenuString
	
	if(gBuffersEnabled)
		gBuffersEnabled = 0
		menuString = "Enable Buffers"
	else
		gBuffersEnabled = 1
		menuString = "Disable Buffers"
	endif
	BuildMenu "Calvin"
End
Function ToggleMenus()

	NVAR gIgorMenusHidden = root:MAH:gIgorMenusHidden
	SVAR menuString = root:MAH:gCalvinHideMenuString
	
	if(gIgorMenusHidden)
		gIgorMenusHidden = 0
		menuString = "Hide All Igor Menus"
		ShowIgorMenus
	else
		gIgorMenusHidden = 1
		menuString = "Show All Igor Menus"
		HideIgorMenus
	endif
	BuildMenu "Calvin"
End

// ---------------------------- Titrate Solution -----------------------------------------

Function Titrate_Beaker_from_Buret_until_Color_Change(intoBeakerName)
string intoBeakerName

	variable indNum, thePH, startPct, curPct, err
	
	// Test for valid flask
	if(validVessel(intoBeakerName) < 1)
		return -1
	endif
	if(reservedName(intoBeakerName))
		WriteSimpleErrorToLog(kConflictingString, intoBeakerName)
		return -1
	endif

	// Make sure there is a valid indicator in the solution and that pH measurement is working
	indNum = indicatorNum(intoBeakerName)
	if(indNum < 0)
		WriteSimpleErrorToLog(kColorlessSolution, intoBeakerName)
		return -1
	endif
	thePH = pH(intoBeakerName)
	if(thePH < 0)
		WriteSimpleErrorToLog(kPHerror, intoBeakerName)
		return -1
	endif
	
	// We will use the protonation state of the indicator as a proxy for color change
	Observe_Color(intoBeakerName)
	Read_Buret_Volume()
	WriteToLog("Performing titration now.\r")
	startPct = pctIndProtonated(intoBeakerName)
	do
		err = Add_Soln_from_Buret(0.05, intoBeakerName)
		if(err > 0)
			curPct = pctIndProtonated(intoBeakerName)
		endif
	while((abs(curPct - startPct) < 0.40) && (err > 0))
	Read_Buret_Volume()
	Observe_Color(intoBeakerName)
	Observe_Color_Range(lookupIndicatorName(indNum), indConc(intoBeakerName))
End
Function pctIndProtonated(vesselName)
string vesselName

	return 1/(10^(pH(vesselName) - indPKa(indicatorNum(vesselName))) + 1)
End
// ---------------------------- pH Measurement -----------------------------------------
Function Measure_pH(vesselName)
string vesselName

	string theNote, pH_string
	
	if(!validVessel(vesselName))
		WriteSimpleErrorToLog(kInvalidVesselForPh, vesselName)
		return -1
	endif
	if(volume(vesselName) < 0.010)
		WriteSimpleErrorToLog(kLowVolForPh, vesselName)
		return -1	// This is OK because our solutions never get much below a pH of 1
	endif
	sprintf pH_string, "%.2f", pH(vesselName)
	theNote = "The pH of " + vesselName + " is " + pH_string + "\r"
	WriteToLog(theNote)
End
Function pH(vesselName)
string vesselName

	variable HA, A, OH, H, theKa, xx	// Actual concentrations in solution
	wave vessel = $vesselName
	
	OH = xsOHConc(vesselName)
	H = xsHConc(vesselName)
	
	if(H > 0)
		if(testNoAcid(vesselName))
			return -log(H)
		else
			HA = acidConc(vesselName)
			theKa = acidKaFromName(acidName(vesselName))
			return -log(H + (-theKa + sqrt(theKa^2 + 4 * theKa * HA))/2) // include contribution from HA
		endif
	elseif(OH > 0)
		return 14 + log(OH)
	elseif(testNoAcid(vesselName))
		return 7.0
	else
		HA = acidConc(vesselName)
		A = conjAcidConc(vesselName)
		theKa = acidKaFromName(acidName(vesselName))
		xx = (-(theKa + A) + sqrt((theKa + A)^2 + 4 * theKa * HA))/2
		return -log(xx)
	endif	
End

// ---------------------------- Making and Adding to Beakers -----------------------------------------
Function Make_H2O_Reservoir()

	variable pH
	MakeEmptyVessel("H2O_Reservoir_mah")
	SetMaxVolume("H2O_Reservoir_mah", 1000)
	setVolume("H2O_Reservoir_mah", 1000)
	pH = pH_of_H2O()
	if(pH > 7.0)
		setXsOHmoles("H2O_Reservoir_mah", 10^(pH-14) * 1000)
	else
		setXsHmoles("H2O_Reservoir_mah", 10^-pH * 1000)
	endif	
End
Function Make_50ml_Buret()

	string theNote
	
	// Make a wave to hold the solution
	MakeEmptyVessel("Buret_mah")
	SetMaxVolume("Buret_mah", 0.050)	
	return(1)
End
Function Make_New_Test_Tube(beakerName)
string beakerName

	string theNote
	
	// Make a wave to hold the solution
	if(exists(beakerName) == 1)
		WriteSimpleErrorToLog(kVesselExists, beakerName)
		return(-1)
	endif
	if(reservedName(beakerName))
		WriteSimpleErrorToLog(kConflictingString, beakerName)
		return -1
	endif

	MakeEmptyVessel(beakerName)
	SetMaxVolume(beakerName, 0.020)	
	theNote = "A clean test tube was named " + beakerName + ".\r"
	WriteToLog(theNote)
	return(1)
End
Function Make_New_100ml_Beaker(beakerName)
string beakerName

	string theNote
	
	// Make a wave to hold the solution
	if(exists(beakerName) == 1)
		WriteSimpleErrorToLog(kVesselExists, beakerName)
		return(-1)
	endif
	if(reservedName(beakerName))
		WriteSimpleErrorToLog(kConflictingString, beakerName)
		return -1
	endif
	MakeEmptyVessel(beakerName)
	SetMaxVolume(beakerName, 0.100)	
	theNote = "A clean 100 ml beaker was named " + beakerName + ".\r"
	WriteToLog(theNote)
	return(1)
End
Function Fill_Empty_100ml_Beaker_with_Unknown_Buffer(bufferName, beakerName)
string bufferName, beakerName
	
	string theNote, theConc
	variable bufferIndex
	
	if(Make_New_100ml_Beaker(beakerName) < 0)
		return -1
	endif
	
	bufferIndex = indexOfBuffer(bufferName)
	if(bufferIndex < 0)
		return(-1)
	endif
	
	wave/t realName = root:MAH:unk_buffer_acidRealName
	setAcidName(beakerName, realName[bufferIndex])
	setAcidMoles(beakerName, buffer_acidMolarity(bufferIndex) * 0.100)
	setConjAcidMoles(beakerName, buffer_baseMolarity(bufferIndex) * 0.100)
	setVolume(beakerName, 0.100)
	
	// Write a note in the log
	theNote = "The beaker " + beakerName + " was filled with 100 ml of " + bufferName + ".\r"
	WriteToLog(theNote)

End
Function Fill_Empty_100ml_Beaker_with_Standardized_Buffer(beakerName)
string beakerName
	
	string theNote, theConc
	
	if(Make_New_100ml_Beaker(beakerName) < 0)
		return -1
	endif
	
	setAcidName(beakerName, "Imidazolium")
	setAcidMoles(beakerName, concStandardizedBuffer() * 0.100)
	setConjAcidMoles(beakerName, concStandardizedBuffer() * 0.100)
	setVolume(beakerName, 0.100)
	
	// Write a note in the log
	sprintf theConc, "%.4f", concStandardizedBuffer()
	theNote = "The beaker " + beakerName + " was filled with 100 ml of standardized buffer\r"
	theNote += "   consisting of " + theConc +  " M imidazole and " + theConc + " M imidazolium chloride.\r"
	WriteToLog(theNote)

End
Function Fill_Empty_100ml_Beaker_with_Standardized_Base(beakerName)
string beakerName
	
	string theNote, theConc
	
	if(Make_New_100ml_Beaker(beakerName) < 0)
		return -1
	endif
	setXsOHmoles(beakerName, concStandardizedOH() * 0.100)
	setVolume(beakerName, 0.100)
	sprintf theConc, "%.4f", concStandardizedOH()
	theNote = "The beaker " + beakerName + " was filled with 100 ml of " + theConc +  " M standardized NaOH.\r"
	WriteToLog(theNote)

End
Function Fill_Empty_100ml_Beaker_with_Standardized_Acid(beakerName)
string beakerName
	
	string theNote, theConc
	
	if(Make_New_100ml_Beaker(beakerName) < 0)
		return -1
	endif
	setXsHmoles(beakerName, concStandardizedH() * 0.100)
	setVolume(beakerName, 0.100)
	sprintf theConc, "%.4f", concStandardizedH()
	theNote = "The beaker " + beakerName + " was filled with 100 ml of " + theConc +  " M standardized HCl.\r"
	WriteToLog(theNote)

End
Function Fill_Empty_100ml_Beaker_with_Standardized_KSCN(beakerName)
string beakerName
	
	string theNote, theConc
	
	if(Make_New_100ml_Beaker(beakerName) < 0)
		return -1
	endif
	setSCNmoles(beakerName, concStandardizedSCN() * 0.100)
	setVolume(beakerName, 0.100)
	sprintf theConc, "%.3e", concStandardizedSCN()
	theNote = "The beaker " + beakerName + " was filled with 100 ml of " + theConc +  " M standardized KSCN.\r"
	WriteToLog(theNote)

End
Function Fill_Empty_100ml_Beaker_with_Standardized_Ferric_Nitrate(beakerName)
string beakerName
	
	string theNote, theConc
	
	if(Make_New_100ml_Beaker(beakerName) < 0)
		return -1
	endif
	setFeMoles(beakerName, concStandardizedFe() * 0.100)
	setVolume(beakerName, 0.100)
	sprintf theConc, "%.4f", concStandardizedFe()
	theNote = "The beaker " + beakerName + " was filled with 100 ml of " + theConc +  " M standardized ferric nitrate.\r"
	WriteToLog(theNote)

End
Function Fill_Empty_100ml_Beaker_with_Standardized_Crystal_Violet(beakerName)
string beakerName
	
	string theNote, theConc
	
	if(Make_New_100ml_Beaker(beakerName) < 0)
		return -1
	endif
	setCVMoles(beakerName, concStandardizedCV() * 0.100)
	setVolume(beakerName, 0.100)
	sprintf theConc, "%.3e", concStandardizedCV()
	theNote = "The beaker " + beakerName + " was filled with 100 ml of " + theConc +  " M standardized crystal violet.\r"
	WriteToLog(theNote)

End
Function Fill_Empty_100ml_Beaker_with_H2O(beakerName)
string beakerName
	
	string theNote
	variable pH
	
	if(Make_New_100ml_Beaker(beakerName) < 0)
		return -1
	endif
	
	AddSolnToSoln("H2O_Reservoir_mah", beakerName, 0.100)

	theNote = "The beaker " + beakerName + " was filled with 100 ml of H2O.\r"
	WriteToLog(theNote)
End

Function Make_New_25ml_Volumetric_Flask(flaskName)
string flaskName

	variable err
	
	err = Make_New_Volumetric_Flask(flaskName, 0.025)
	return err
End

Function Make_New_50ml_Volumetric_Flask(flaskName)
string flaskName

	variable err
	
	err = Make_New_Volumetric_Flask(flaskName, 0.050)
	return err
End

Function Make_New_Volumetric_Flask(flaskName, volume)	// Volume in liters
string flaskName
variable volume

	string theNote
	
	// Make a wave to hold the solution
	if(exists(flaskName) == 1)
		WriteSimpleErrorToLog(kVesselExists, flaskName)
		return(-1)
	endif
	if(reservedName(flaskName))
		WriteSimpleErrorToLog(kConflictingString, "vesselName")
		return -1
	endif
	MakeEmptyVessel(flaskName)
	SetMaxVolume(flaskName, volume)	
	theNote = "A clean " + num2istr(volume * 1000) + " ml volumetric flask was named " + flaskName + ".\r"
	WriteToLog(theNote)
	return(1)
End


Function Add_Solid_Acid_to_Vessel(targetMass, nameOfAcid, vesselName)
string vesselName, nameOfAcid
variable targetMass
	
	string theNote, keyValue
	variable actualMass, iMolxsOH, actualMoles, err
	NVAR useErrors = root:MAH:useErrors
	
	if(reservedName(vesselName))
		WriteSimpleErrorToLog(kConflictingString, vesselName)
		return -1
	endif
	if(validVessel(vesselName) < 1)
		return -1
	endif
	
	if(targetMass < 0)
		WriteSimpleErrorToLog(kNegativeMass, "")
		return -1
	endif
	
	if(targetMass >= 4.0)
		WriteSimpleErrorToLog(kTooMuchAcid, num2str(targetMass))
		return -1
	endif
	
	if(!testNoAcid(vesselName))
		WriteSimpleErrorToLog(kConflictingAcid, acidName(vesselName))
		return(-1)
	endif
	
	if(indexOfAcid(nameOfAcid) < 0)
		return(-1)
	endif
	
	if(useErrors)
		actualMass = (1 + enoise(0.05)) * targetMass		// in g
	else
		actualMass = targetMass
	endif
	actualMoles = actualMass/molarMass(nameOfAcid)

	setAcidName(vesselName, nameOfAcid)
	setAcidMoles(vesselName, actualMoles)
	
	iMolxsOH = xsOHMoles(vesselName)
	if(iMolxsOH > actualMoles)
		setConjAcidMoles(vesselName, actualMoles)
		setXsOHMoles(vesselName, iMolxsOH - actualMoles)
	else
		setAcidMoles(vesselName, actualMoles - iMolxsOH)
		setConjAcidMoles(vesselName, iMolxsOH)
		setXsOHMoles(vesselName, 0)
	endif
	
	// Increase the total volume by the volume of the salt using benzoic acid as an exemplar
	err = setVolume(vesselName, volume(vesselName) + actualMass/1.27/1000) // density in g/cm3
	if(err < 0)
		return -1
	else
		// Write a note in the log
		sprintf keyValue, "%.4f", actualMass
		theNote = "Added " + keyValue + " g of " + nameOfAcid + " to " + vesselName + ".\r"
		WriteToLog(theNote)
		return 1
	endif
End

Function Fill_Volumetric_Flask_with_H2O(flaskName)
string flaskName

	variable err, iMolxsOH, newVol, oldVol, addedMolOH, iMolAcid, iMolConjAcid
	string theNote
	wave H2O_Reservoir_mah
	
	// Test for valid flask
	if(validVolumetricFlask(flaskName) < 0.1)
		return -1
	elseif(volume(flaskName) >= 0.99 * maxVolume(flaskName))
		WriteSimpleErrorToLog(kFlaskFull, flaskName)
		return 1
	else
		oldVol = volume(flaskName)
		newVol = maxVolume(flaskName) + VolumeError("vol_flask", maxVolume(flaskName))
		AddSolnToSoln("H2O_Reservoir_mah", flaskName, newVol - oldVol)
		theNote = "The flask named " + flaskName + " was filled with H2O to the mark.\r"
		WriteToLog(theNote)
		return 1
	endif
End

constant k_acidMolIndex = 0
constant k_conjAcidMolIndex = 1
constant k_xsOHmolIndex = 2
constant k_xsHMolIndex = 3
constant k_solnVolIndex = 4
constant k_indicatorIndex = 5
constant k_maxVolIndex = 6
constant k_indMolIndex = 7
constant k_FeMolIndex = 8
constant k_SCNmolIndex = 9
constant k_CVmolIndex = 10		// Crystal Violet

Function MakeEmptyVessel(vesselName)
string vesselName
	
	string keyStr
	
	make/n=11 $vesselName
	wave beaker = $vesselName
	
	keyStr = "acidName:" + "none" + ";"
	Note/NOCR $vesselName, keyStr
	
	beaker = 0
	setIndicatorNum(vesselName, -1)
End
Function Clean_and_Dry(vesselName)
string vesselName
	
	string theNote
	
	if(reservedName(vesselName))
		WriteSimpleErrorToLog(kConflictingString, "vesselName")
		return -1
	endif
	
	if(!validVessel(VesselName))
		return -1
	endif
	
	KillWaves $vesselName
	theNote = "Cleaned " + vesselName + ", erased its name, and returned it to storage.\r"
	WriteToLog(theNote)
		
End
Function Observe_Volume(vesselName)
string vesselName

	string theNote
	
	if(!validVessel(VesselName))
		return -1
	endif
	theNote = "By eye, the vessel contains ~" + num2str(round((1000 * volume(vesselName)))) + "ml of solution.\r"
	WriteToLog(theNote)
End
// ---------------------------- The Buret -----------------------------------------
Function Fill_50ml_Buret(fromVesselName)
string fromVesselName

	variable volToBeTransferred
	string theNote

	// Clean the buret of existing solution
	wave Buret_mah
	Buret_mah = 0
	setAcidName("Buret_mah", "none")
	setIndicatorNum("Buret_mah", -1)
	setMaxVolume("Buret_mah", 0.050)
	
	// Do the transfer
	if(Prepare_For_Transfer(fromVesselName, "Buret_mah") < 0)
		return -1
	endif
	
	volToBeTransferred = (volume(fromVesselName) >= 0.050) ? 0.0495 + enoise(0.0005) : volume(fromVesselName)	
		
	AddSolnToSoln(fromVesselName, "Buret_mah", volToBeTransferred)
	theNote = "Added solution from " + fromVesselName + " to your 50 ml buret.\r"
	WriteToLog(theNote)
	Read_Buret_Volume()
	
	return 1
End
Function Read_Buret_Volume()

	string theNote, output
		
	sprintf output, "%.2f", 50 - HalfRound(volume("Buret_mah") * 1000, 2)
	theNote = "The buret now reads " + output + " ml.\r"
	WriteToLog(theNote) 

End
Function Add_Soln_from_Buret(targetVolume, toVesselName)
string toVesselName
variable targetVolume

	variable err
	
	if(reservedName(toVesselName))
		WriteSimpleErrorToLog(kConflictingString, toVesselName)
		return -1
	endif
	if(validVessel(toVesselName) < 1)
		return -1
	endif

	targetVolume /= 1000
	if(volume("Buret_mah") <= 0.00005)
		WriteSimpleErrorToLog(kBuretEmpty, "")
		return -1
	endif
	if(maxVolume(toVesselName) < volume(toVesselName) + targetVolume)
		WriteSimpleErrorToLog(kBeakerFull, "")
		return -1
	endif

	err = Transfer_Soln("Buret_mah", toVesselName, targetVolume, "buret")
	return err
End
// ---------------------------- Transferring Solutions -----------------------------------------
Function Transfer_Soln_with_5ml_pipette(fromVesselName, toVesselName)
string fromVesselName, toVesselName

	variable err
	err = Transfer_Soln_with_pipette(fromVesselName, toVesselName, 0.005)
	return err
End
Function Transfer_Soln_with_10ml_pipette(fromVesselName, toVesselName)
string fromVesselName, toVesselName

	variable err
	err = Transfer_Soln_with_pipette(fromVesselName, toVesselName, 0.010)
	return err
End
Function Transfer_Soln_with_20ml_pipette(fromVesselName, toVesselName)
string fromVesselName, toVesselName

	variable err
	err = Transfer_Soln_with_pipette(fromVesselName, toVesselName, 0.020)
	return err
End
Function Transfer_Soln_with_pipette(fromVesselName, toVesselName, volume)	// Volume in liters
string fromVesselName, toVesselName
variable volume

	variable err
	string theNote

	if(reservedName(toVesselName))
		WriteSimpleErrorToLog(kConflictingString, toVesselName)
		return -1
	endif
	err = Transfer_Soln(fromVesselName, toVesselName, volume, "pipette")
	if(err > 0)
		theNote = "Pipetted " + num2istr(volume * 1000) + " ml of solution from " + fromVesselName + " to " + toVesselName + ".\r"
		WriteToLog(theNote)
	endif
	return err
End
Function Transfer_Soln_with_Graduated_Cylinder(targetVolume, fromVesselName, toVesselName)
string fromVesselName, toVesselName
variable targetVolume

	variable err, volToBeTransferred, nextTransfer
	string theNote
	
	if(reservedName(toVesselName))
		WriteSimpleErrorToLog(kConflictingString, toVesselName)
		return -1
	endif

	targetVolume /= 1000
	volToBeTransferred = targetVolume
	
	if(volToBeTransferred <= 0.010)
		err = Transfer_Soln(fromVesselName, toVesselName, volToBeTransferred, "graduated_cylinder")
		if(err > 0)
			WriteGradCylNoteToLog(fromVesselName, toVesselName,volToBeTransferred, 10)
		endif
	else
		do
			nextTransfer = volToBeTransferred > 0.025 ? 0.025 : volToBeTransferred
			err = Transfer_Soln(fromVesselName, toVesselName, nextTransfer, "graduated_cylinder")
			if(err > 0)
				WriteGradCylNoteToLog(fromVesselName, toVesselName,nextTransfer, 25)
			endif
			volToBeTransferred -= nextTransfer
		while((volToBeTransferred > 0) && (err > 0))
	endif
	
	return err
End
Function WriteGradCylNoteToLog(fromVesselName, toVesselName,volTransferred, cylVolume)
string fromVesselName, toVesselName
variable volTransferred, cylVolume
	string theNote
	
	theNote = "Used a " + num2istr(cylVolume) + " ml graduated cylinder to transfer " + num2str(1000 * volTransferred)
	theNote += " ml of solution from " + fromVesselName + " to " + toVesselName + ".\r"
	WriteToLog(theNote)
End
Function Prepare_For_Transfer(fromVesselName, toVesselName)	// Checks for compatible vessels
string fromVesselName, toVesselName

	if(!validVessel(fromVesselName))
		return -1
	endif
	
	if(!validVessel(toVesselName))
		return -1
	endif
		
	if(CmpStr(fromVesselName, toVesselName, 0) == 0)
		WriteSimpleErrorToLog(kTransferToSameVessel, fromVesselName)
		return -1
	endif
	
	if(compatibleAcids(fromVesselName, toVesselName) < 0)
		return -1
	endif
	
	if(compatibleIndicators(fromVesselName, toVesselName) < 0)
		return -1
	endif
	
	return 1
End
Function Transfer_Soln(fromVesselName, toVesselName, targetVol, method)
string fromVesselName, toVesselName, method
variable targetVol

	string theNote
	variable actualVolume
	
	if(Prepare_For_Transfer(fromVesselName, toVesselName) < 0)
		return -1
	endif
	
	if(volume(fromVesselName) < actualVolume)
		WriteSimpleErrorToLog(kInsufficientVol, fromVesselName)
		return -1
	endif
	
	if(targetVol < 0)
		WriteSimpleErrorToLog(kNegativeVolume, fromVesselName)
		return -1
	endif
	
	actualVolume = targetVol + VolumeError(method, targetVol)
	if(actualVolume < 0)		// The target volume was greater that 0, but the error made the volume negative
		actualVolume = 1/1000/20 + abs(enoise(2/1000/20)) // Somewhere between 1 and 3 drops
	endif
	
	actualVolume = actualVolume > volume(fromVesselName) ? volume(fromVesselName) : actualVolume
	
	if(1.02 * maxVolume(toVesselName) < volume(toVesselName) + actualVolume)
		WriteSimpleErrorToLog(kOverflow, toVesselName)
		wave overflowedVessel = $toVesselName
		KillWaves overflowedVessel
		setVolume(fromVesselName, volume(fromVesselName) - targetVol)
		return -1
	endif
		
	AddSolnToSoln(fromVesselName, toVesselName, actualVolume)
	return 1
End
Function AddSolnToSoln(fromVesselName, toVesselName, actualVolume) // Do error checking in calling function
string fromVesselName, toVesselName
variable actualVolume
	
	variable iVol, iMolHA, iMolA, iMolxsOH, iMolxsH, iMolH, newIndNum, iMolInd, iMolFe, iMolSCN, iMolCV
	variable newVol, newMol_HA, newMol_A, newMol_xsOH, newMol_xsH
	variable finished = 0
	wave vessel = $toVesselName
	
	if(testNoAcid(toVesselName))
		setAcidName(toVesselName, acidName(fromVesselName))
	endif
	
	iMolHA = acidConc(fromVesselName) * actualVolume
	iMolA = conjAcidConc(fromVesselName) * actualVolume
	iMolxsH = xsHconc(fromVesselName) * actualVolume
	iMolxsOH = xsOHConc(fromVesselName) * actualVolume
	iMolInd = indConc(fromVesselName) * actualVolume
	iMolFe = FeConc(fromVesselName) * actualVolume
	iMolSCN = SCNconc(fromVesselName) * actualVolume
	iMolCV = CVconc(fromVesselName) * actualVolume
	
	// First add all moles from first vessel to second vessel
	setAcidMoles(toVesselName, acidMoles(toVesselName) + iMolHA)
	setConjAcidMoles(toVesselName, conjAcidMoles(toVesselName) + iMolA)
	setXsHMoles(toVesselName, xsHMoles(toVesselName) + iMolxsH)
	setXsOHMoles(toVesselName, xsOHMoles(toVesselName) + iMolxsOH)
	setIndMoles(toVesselName, indMoles(toVesselName) + iMolInd)
	setFeMoles(toVesselName, FeMoles(toVesselName) + iMolFe)
	setSCNmoles(toVesselName, SCNmoles(toVesselName) + iMolSCN)
	setCVmoles(toVesselName, CVmoles(toVesselName) + iMolCV)
	
	// Now subtract moles from first vessel
	setAcidMoles(fromVesselName, acidMoles(fromVesselName) - iMolHA)
	setConjAcidMoles(fromVesselName, conjAcidMoles(fromVesselName) - iMolA)
	setXsHMoles(fromVesselName, xsHMoles(fromVesselName) - iMolxsH)
	setXsOHMoles(fromVesselName, xsOHMoles(fromVesselName) - iMolxsOH)
	setIndMoles(fromVesselName, indMoles(fromVesselName) - iMolInd)
	setFeMoles(fromVesselName, FeMoles(fromVesselName) - iMolFe)
	setSCNmoles(fromVesselName, SCNmoles(fromVesselName) - iMolSCN)
	setCVmoles(fromVesselName, CVmoles(fromVesselName) - iMolCV)
	
	// Update volumes, because they are needed for upcoming conc calculations
	setVolume(fromVesselName, volume(fromVesselName) - actualVolume)
	setVolume(toVesselName, volume(toVesselName) + actualVolume)
	
	// Now react things in second vessel
	iMolHA = acidMoles(toVesselName)
	iMolA = conjAcidMoles(toVesselName)
	iMolxsH = xsHmoles(toVesselName)
	iMolxsOH = xsOHmoles(toVesselName)
	
	if(iMolxsH > iMolxsOH)
		setXsOHMoles(toVesselName, 0)
		iMolxsH -= iMolxsOH
		if(iMolA > iMolxsH)
			setConjAcidMoles(toVesselName, iMolA - iMolxsH)
			setAcidMoles(toVesselName, acidMoles(toVesselName) + iMolxsH)
			setXsHMoles(toVesselName, 0)
		else
			setXsHMoles(toVesselName, iMolxsH - iMolA)
			setConjAcidMoles(toVesselName, 0)
			setAcidMoles(toVesselName, acidMoles(toVesselName) + iMolA)
		endif
	else
		setXsHMoles(toVesselName, 0)
		iMolXsOH -= iMolXsH
		if(iMolHA > iMolXsOH)
			setAcidMoles(toVesselName, iMolHA - iMolXsOH)
			setConjAcidMoles(toVesselName, conjAcidMoles(toVesselName) + iMolXsOH)
			setXsOHmoles(toVesselName, 0)
		else
			setAcidMoles(toVesselName, 0)
			setConjAcidMoles(toVesselName, conjAcidMoles(toVesselName) + iMolHA)
			setXsOHmoles(toVesselName, iMolXsOH - iMolHA)
		endif
	endif
		
	// Fix the indicator num. Already checked compatibility
	newIndNum = indicatorNum(fromVesselName) > indicatorNum(toVesselName) ? indicatorNum(fromVesselName) : indicatorNum(toVesselName)
	setIndicatorNum(toVesselName, newIndNum)
End
Function Add_One_Drop_of_Indicator(indicatorName, vesselName)
string vesselName, indicatorName

	string theNote
	variable indNum
	
	// Test for valid indicator
	if(abs(cmpstr(indicatorName, "crystal_violet")) < 0.1)
		WriteSimpleErrorToLog(kCrystalVioletError, "")
		return -1
	endif
	
	indNum = indexOfIndicator(indicatorName)
	if(indNum < 0)
		return -1
	endif
	
	// Test for valid flask
	if(reservedName(vesselName))
		WriteSimpleErrorToLog(kConflictingString, vesselName)
		return -1
	endif
	if(validVessel(vesselName) < 1)
		return -1
	endif
	
	if(testIndicator(vesselName, indicatorName) < 0)
		WriteSimpleErrorToLog(kConflictingIndicator, lookupIndicatorName(indicatorNum(vesselName)))
		return -1
	endif
	
	setIndicatorNum(vesselName, lookupIndicatorNum(indicatorName))
	setIndMoles(vesselName, indMoles(vesselName) + 1.0 * 0.050)
	theNote = "Added one drop of " + indicatorName + " to " + vesselName + ".\r"
	WriteToLog(theNote)

End
// ---------------------------- Color and Spectroscopy -------------------------------------
Function Observe_Color(vesselName)
string vesselName
	
	variable indNum, thePH, ironConc, theCVconc
	string theNote, topWindow
	STRUCT color theColor

	if(validVessel(vesselName) < 1)
		return -1
	endif

	// Make sure there is a valid indicator in the solution	
	indNum = indicatorNum(vesselName)
	ironConc = FeConc(vesselName)
	theCVconc = CVconc(vesselName)
	if((indNum < 0) && !(ironConc > 1e-6) && !(theCVconc > 1e-7))
		WriteSimpleErrorToLog(kColorlessSolution, vesselName)
		return -1
	endif
	thePH = pH(vesselName)
	if(thePH < 0)
		WriteSimpleErrorToLog(kPHerror, vesselName)
		return -1
	endif
	
	// Generate the spectrum and the color and write it to the notebook
	measureColor(vesselName, theColor)	
	make/n=(1,1,4)/o root:MAH:colorSquare
	wave colorSquare = root:MAH:colorSquare
	colorSquare[0][0][0] = theColor.rr
	colorSquare[0][0][1] = theColor.gg
	colorSquare[0][0][2] = theColor.bb
	colorSquare[0][0][3] = theColor.aa
	GraphColorSquare()
	topWindow = WinList("*", "", "WIN:")
	theNote = "The color of the solution in " + vesselName + " is:\r"
	WriteToLog(theNote)
	WriteTopGraphToLog()
	WriteBlankLineToLog()
	KillWindow $topWindow
End
Function measureColor(vesselName, theColor)	// No error checking
string vesselName
STRUCT color &theColor
	
	MakeSpectrum(vesselName)
	wave spectrum = root:MAH:curSpectrum
	calcColorOfSpectrum(spectrum, theColor, 1)
End
Function Observe_Color_Range(indicatorName, relativeConcentration)
string indicatorName
variable relativeConcentration

	// Make sure this is a valid indicator
	variable indNum, ii = 0
	string theNote, topWindow
	STRUCT color theColor

	if(abs(cmpstr(indicatorName, "crystal_violet")) < 0.1)
		WriteSimpleErrorToLog(kCrystalVioletNotIndicator, "")
		return -1
	endif

	indNum = indexOfIndicator(indicatorName)
	if(indNum < 0)
		WriteSimpleErrorToLog(kMissingIndicator, indicatorName)
		return -1
	endif
	
	// Generate the swatch
	make/n=(80,1,4)/o root:MAH:colorSwatch
	wave swatch = root:MAH:colorSwatch
	SetScale/P x indPKA(indNum)-2, 4/80,"", swatch
	MakeIndSpectrum(indNum, 1.0, indPKa(indNum), pnt2x(swatch, ii))
	do
		MakeIndSpectrum(indNum, relativeConcentration, indPKa(indNum), pnt2x(swatch, ii))
		wave spectrum = root:MAH:curSpectrum
		calcColorOfSpectrum(spectrum, theColor, 1)
		swatch[ii][0][0] = theColor.rr
		swatch[ii][0][1] = theColor.gg
		swatch[ii][0][2] = theColor.bb
		swatch[ii][0][3] = theColor.aa
		ii += 1
	while(ii < DimSize(swatch, 0))
	SetScale/P x -2, 4/80,"", swatch
	
	// Add to log
	GraphSwatch()
	topWindow = WinList("*", "", "WIN:")
	theNote = "The color range of the indicator " + indicatorName + " is:\r"
	WriteToLog(theNote)
	WriteTopGraphToLog()
	WriteBlankLineToLog()
	KillWindow $topWindow
End
Function Take_Spectrum(vesselName)
string vesselName

	string theNote, topWindow, fileName
	variable err, ii, refNum
	NVAR gSpectrumNumber = root:MAH:gSpectrumNumber
	
	// Test for valid flask
	if(validVessel(vesselName) < 1)
		return -1
	endif
	
	err = MakeSpectrum(vesselName)
	if(err < 0)
		return err
	endif

	wave spectrum = root:MAH:curSpectrum
	duplicate/o spectrum, root:MAH:clippedSpectrum
	wave clippedSpectrum = root:MAH:clippedSpectrum
	clippedSpectrum = spectrum + enoise(0.002) // Add noise because spectra taken at high conc
	if(wavemax(spectrum) > 4)
		WriteSimpleErrorToLog(kSpectrumClipping,"")
		clippedSpectrum = spectrum <= 4.0 ? spectrum : 4.0
	endif
	GraphSpectrum()
	topWindow = WinList("*", "", "WIN:")
	theNote = "The spectrum of the solution in " + vesselName + " is:\r"
	WriteToLog(theNote)
	WriteTopGraphToLog()
	WriteBlankLineToLog()
	KillWindow $topWindow

	// Save the spectrum as csv
	fileName = "Spectrum_" + num2istr(gSpectrumNumber) + ".csv"
	Open/P=tempFolder refNum as fileName
	fprintf refNum, "\"Wavelength (nm)\", \"Absorbance\"\r"
	ii = 0
	do
		fprintf refNum, "%.1f, %.6f\r", pnt2x(clippedSpectrum, ii), clippedSpectrum[ii]
		ii += 1
	while(ii < numpnts(spectrum))
	Close refNum
	theNote = "This spectrum has been saved as " + fileName + "\r"
	WriteToLog(theNote)
	gSpectrumNumber += 1
End
Function MakeSpectrum(vesselName)
string vesselName

	variable indNum, thePH, refNum, ii, ironConc, theCVconc, specExists
	NVAR gSpectrumNumber = root:MAH:gSpectrumNumber

	// Make sure there is either a valid indicator in the solution, some Fe, or some CV
	indNum = indicatorNum(vesselName)
	ironConc = FeConc(vesselName)
	theCVconc = CVconc(vesselName)
	if((indNum < 0) && !(ironConc > 1e-6) && !(theCVConc > 3e-8))
		WriteSimpleErrorToLog(kColorlessSolution, vesselName)
		return -1
	endif
	thePH = pH(vesselName)
	if(thePH < 0)
		WriteSimpleErrorToLog(kPHerror, vesselName)
		return -1
	endif
	
	// Generate the spectrum and write it to the notebook
	specExists = 0
	if(ironConc > 1e-6)
		MakeFeSpectrum(FeConc(vesselName), SCNconc(vesselName))
		specExists = 1
	endif
	if(theCVConc > 3e-8)
		if(specExists > 0)
			wave spectrum = root:MAH:curSpectrum
			duplicate/FREE spectrum, tempSpectrum
		endif
		MakeCVSpectrum(CVconc(vesselName))
		if(specExists > 0)
			spectrum += tempSpectrum
		endif 
		specExists = 1
	endif
	if(!(indNum < 0))
		if(specExists > 0)
			wave spectrum = root:MAH:curSpectrum
			duplicate/FREE spectrum, tempSpectrum
		endif
		MakeIndSpectrum(indNum, indConc(vesselName), indPKa(indNum), thePH)
		if(specExists > 0)
			spectrum += tempSpectrum
		endif 
	endif
	return 1
End
Function MakeFeSpectrum(FeConc, SCNconc)	// Unequilibrated concentrations
variable FeConc, SCNconc
	
	variable alpha, abeta, FeSCNconc, equilFeConc, ratFe, ratFeSCN, equilSCNConc
	alpha = FeConc + SCNconc + 1/139.732		// K = 140 M^–1
	abeta = FeConc * SCNconc
	FeSCNconc = 0.5 * (alpha - sqrt(alpha^2 - 4 * abeta))	// From solving quadratic equil eqn
	equilFeConc = FeConc - FeSCNconc
	equilSCNConc = SCNconc - FeSCNconc
	
	make/n=(800 - 380 + 1)/o root:MAH:curSpectrum
	wave curSpectrum = root:MAH:curSpectrum
	SetScale/I x 380,800,"nm", curSpectrum
	wave FeSpectrum = root:MAH:Ferric_ion, FeSCNspectrum = root:MAH:FeSCN
	ratFeSCN = FeSCNconc/(wavemax(FeSCNspectrum)/6120)
	ratFe = equilFeConc/0.01
	curSpectrum = ratFe * FeSpectrum + ratFeSCN * FeSCNspectrum
End
Function MakeCVSpectrum(CVconc)
variable CVconc
	
	make/n=(800 - 380 + 1)/o root:MAH:curSpectrum
	wave curSpectrum = root:MAH:curSpectrum
	SetScale/I x 380,800,"nm", curSpectrum
	wave CVSpectrum = root:MAH:Crystal_Violet_acid
	curSpectrum = CVconc/2e-5 * CVspectrum
End
Function Measure_Absorbance_Every_2_Min(vesselName, wavelength, maxTime)
string vesselName
variable wavelength, maxTime

	wave CVspec = root:MAH:crystal_violet_acid
	variable curTime = 0, curRate, actualTemp, OHconc, newCVconc, err, fracSec
	string outStr, theNote
	NVAR specTemp = root:MAH:spectromTemperature
	
	// Test for valid flask, wavelength, and maxTime
	if(validVessel(vesselName) < 1)
		return -1
	endif	
	if((wavelength < leftx(CVspec)) || (wavelength > pnt2x(CVspec, numpnts(CVspec)-1)))
		WriteSimpleErrorToLog(kWavelengthOutOfRange, num2istr(wavelength))
		return -1
	endif
	if(maxTime > 30)
		WriteSimpleErrorToLog(kTimeTooLong, num2istr(maxTime))
		maxTime = 30
	endif
	
	theNote = "Start measuring absorbance of " + vesselName + " at " + num2istr(wavelength) + " nm.\r"
	WriteToLog(theNote)
	sprintf outStr, "%.1f", specTemp
	theNote = "The current spectrometer temperature is " + outStr + "°C.\r"
	WriteToLog(theNote)

	do
		// Measure current spectrum
		err = MakeSpectrum(vesselName)
		if(err < 0)
			return -1
		endif
		wave spectrum = root:MAH:curSpectrum
		sprintf outStr, "%.4f", spectrum(wavelength)
		theNote = "\t" + num2istr(curTime) + " min\t Abs = " + outStr + "\r"
		WriteToLog(theNote)
		
		// Degrade CV for 2 min
		actualTemp = specTemp + enoise(0.25)
		OHconc = 10^-(14 - pH(vesselName))
		fracSec = 0
		do
			curRate = 1.06e12 * exp(-63.18/0.0083145/(actualTemp + 273.15)) * CVconc(vesselName) * OHconc		// in M min-1; Ea = -63.18 kJ/mol
			newCVconc = CVconc(vesselName) - curRate * 0.01
			setCVmoles(vesselName, newCVconc * volume(vesselName))
			fracSec += 0.01
		while(fracSec < 2)
		curTime += 2
	while(curTime < maxTime + 0.1)

End

Function MakeIndSpectrum(indicatorNum, indicatorConc, pKa, pH) // No error checking. Makes wave "curSpectrum"
variable indicatorNum, indicatorConc, pKa, pH

	variable pctDeprotonated

	make/n=(800 - 380 + 1)/o root:MAH:curSpectrum
	wave curSpectrum = root:MAH:curSpectrum
	SetScale/I x 380,800,"nm", curSpectrum
	wave/t ind_acidSpectrum = root:MAH:ind_acidSpectrum, ind_baseSpectrum = root:MAH:ind_baseSpectrum
	wave acidSpectrum = $("root:MAH:" + ind_acidSpectrum[indicatorNum])
	wave baseSpectrum = $("root:MAH:" + ind_baseSpectrum[indicatorNum])
	pctDeprotonated = 10^(pH-pKa)/(1 + 10^(pH-pKa))
	curSpectrum = indicatorConc * ((1 - pctDeprotonated) * acidSpectrum + pctDeprotonated * baseSpectrum)
End
Function GraphSpectrum()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:MAH:
	wave clippedSpectrum
	Display /W=(234,137,522,287) clippedSpectrum
	SetDataFolder fldrSav0
	ModifyGraph rgb=(52428,1,1)
	ModifyGraph mirror=2
	ModifyGraph axOffset(left)=-1
	ModifyGraph btLen=4
	Label left "Absorbance"
	Label bottom "Wavelength (nm) \\u#2"
EndMacro
Function GraphColorSquare()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:MAH:
	wave colorSquare
	Display /W=(40,45,104,109) //(40,45,196,201)
	AppendImage/T colorSquare
	ModifyGraph margin(left)=7,margin(bottom)=7,margin(top)=7,margin(right)=7
	ModifyGraph mirror=1,standoff=0
	ModifyGraph nticks=0
	SetDataFolder fldrSav0
EndMacro
Function GraphSwatch()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:MAH:
	wave colorSwatch
	SetScale/I x -2,2,"", colorSwatch
	Display /W=(40,45,292,106)
	AppendImage/T colorSwatch
	ModifyGraph margin(left)=5,margin(bottom)=5,margin(top)=27,margin(right)=5
	ModifyGraph mirror=2
	ModifyGraph nticks(left)=0,nticks(top)=4
	ModifyGraph minor=1
	ModifyGraph lblMargin(top)=4
	ModifyGraph standoff=0
	ModifyGraph tkLblRot(left)=90
	ModifyGraph btLen=3
	ModifyGraph tlOffset=-2
	Label top "\\f02p\\f00H – \\f02pK\\Ba\\M\\f00"
	SetDataFolder fldrSav0
EndMacro


// ---------------------------- Validating Names -----------------------------------------
Function testNoAcid(vesselName)	// returns 1 if there is no solid acid in solution
string vesselName

	if(abs(cmpstr(acidName(vesselName), "none", 0)) < 0.1)	
		return 1
	else
		return 0
	endif
End
Function testNoIndicator(vesselName)	// returns 1 if there is no indicator in solution
string vesselName

	if(indicatorNum(vesselName) < 0)	
		return 1
	else
		return 0
	endif
End
Function testIndicator(vesselName, indicatorName)	// returns -1 if incompatible, 1 if compatible
string vesselName, indicatorName

	if(indicatorNum(vesselName) < 0)		// No indicator in vessel
		return 1
	elseif (abs(indicatorNum(vesselName) - lookupIndicatorNum(indicatorName)) < 0.1) // Same indicator
		return 1
	else
		return -1
	endif
End
Function compatibleAcids(firstVessel, secondVessel)	// -1 if not compatible. Mixing solid acids is not allowed
string firstVessel, secondVessel

	string theNote
	variable sameAcid
	sameAcid = abs(cmpstr(acidName(firstVessel), acidName(secondVessel), 0)) < 0.1
	if(testNoAcid(firstVessel) || testNoAcid(secondVessel) || sameAcid)
		return 1
	else
		WriteDoubleErrorToLog(kMixingAcids, firstVessel, secondVessel)
		return -1
	endif
End
Function compatibleIndicators(firstVessel, secondVessel)	// -1 if not compatible. Mixing indicators is not allowed
string firstVessel, secondVessel

	string theNote
	variable sameInd
	sameInd = abs(indicatorNum(firstVessel) - indicatorNum(secondVessel)) < 0.1
	if(testNoAcid(firstVessel) || testNoAcid(secondVessel) || sameInd)
		return 1
	else
		WriteDoubleErrorToLog(kMixingIndicators, firstVessel, secondVessel)
		return -1
	endif

End
Function indexOfAcid(theName)	// returns index of acid if successful, -1 if not
string theName

	variable ii = 0
	string theInfo
	wave/t unk_acid_fakeName = root:MAH:unk_acid_fakeName
	
	do
		if(abs(cmpstr(theName, unk_acid_fakeName[ii], 0)) < 0.1)
			return ii
		endif
		ii += 1
	while(ii < numpnts(unk_acid_fakeName))
	WriteSimpleErrorToLog(kMissingAcid, theName)
	return -1
End
Function indexOfIndicator(theName)	// returns index of indicator if successful, -1 if not
string theName

	variable ii = 0
	string theInfo
	wave/t ind_fakeName = root:MAH:ind_fakeName
	
	do
		if(abs(cmpstr(theName, ind_fakeName[ii], 0)) < 0.1)
			return ii
		endif
		ii += 1
	while(ii < numpnts(ind_fakeName))
	WriteSimpleErrorToLog(kMissingIndicator, theName)
	return -1
End
Function indexOfBuffer(theName)	// returns index of buffer if successful, -1 if not
string theName

	variable ii = 0
	string theInfo
	wave/t unk_buffer_fakeName = root:MAH:unk_buffer_fakeName
	
	do
		if(abs(cmpstr(theName, unk_buffer_fakeName[ii], 0)) < 0.1)
			return ii
		endif
		ii += 1
	while(ii < numpnts(unk_buffer_fakeName))
	WriteSimpleErrorToLog(kMissingBuffer, theName)
	return -1
End
Function reservedName(theName)	// returns 1 if reserved name, 0 if not
string theName
	
	if(stringmatch(theName, "Buret_mah"))
		return 1
	elseif(stringMatch(theName, "H2O_Reservoir_mah"))
		return 1
	else
		return 0
	endif
End
Function validVessel(theName)	// returns 1 if valid, 0 if not
string theName

	string theInfo
	
	if(exists(theName) == 1)
		return(1)
	else
		WriteSimpleErrorToLog(kVesselMissing, theName)
		return(0)
	endif
End
Function validVolumetricFlask(theName)	// returns 1 if successful, 0 if not
string theName

	string theInfo
	
	if(reservedName(theName))
		WriteSimpleErrorToLog(kConflictingString, theName)
		return -1
	endif

	if(exists(theName) == 1)
		if(abs(maxVolume(theName) - 0.050) < 0.001)
			return(1)
		elseif(abs(maxVolume(theName) - 0.025) < 0.001)
			return(1)
		else
			WriteSimpleErrorToLog(kNotFlask, theName)
			return(0)
		endif
	else
		WriteSimpleErrorToLog(kVesselMissing, theName)
		return(0)
	endif
End
// ---------------------------- Querying Solutions and Vessels -----------------------------------------
Function setAcidName(solnName, newName)
string solnName, newName
	
	wave soln = $solnName
	string newNote
	newNote = ReplaceStringByKey("acidName", note($solnName), newName)
	Note/K $solnName
	Note/NOCR $solnName, newNote
End
Function setAcidMoles(solnName, newMoles)
string solnName
variable newMoles
	
	wave soln = $solnName
	soln[k_acidMolIndex] = newMoles
End
Function setConjAcidMoles(solnName, newMoles)
string solnName
variable newMoles
	
	wave soln = $solnName
	soln[k_conjAcidMolIndex] = newMoles
End
Function setXsOHMoles(solnName, newMoles)
string solnName
variable newMoles
	
	wave soln = $solnName
	soln[k_xsOHmolIndex] = newMoles
End
Function setXsHMoles(solnName, newMoles)
string solnName
variable newMoles
	
	wave soln = $solnName
	soln[k_xsHmolIndex] = newMoles
End
Function setIndMoles(solnName, newMoles)
string solnName
variable newMoles
	
	wave soln = $solnName
	soln[k_indMolIndex] = newMoles
End
Function setFeMoles(solnName, newMoles)
string solnName
variable newMoles
	
	wave soln = $solnName
	soln[k_FeMolIndex] = newMoles
End
Function setCVMoles(solnName, newMoles)
string solnName
variable newMoles
	
	wave soln = $solnName
	soln[k_CVMolIndex] = newMoles
End
Function setSCNmoles(solnName, newMoles)
string solnName
variable newMoles
	
	wave soln = $solnName
	soln[k_SCNmolIndex] = newMoles
End
Function setVolume(beakerName, newVol)		// returns 1 if OK, -1 if overfilled
string beakerName
variable newVol

	wave beaker = $beakerName

	if(1.02 * maxVolume(beakerName) < newVol)
		WriteSimpleErrorToLog(kOverflow, beakerName) 
		KillWaves beaker
		return -1
	endif
	beaker[k_solnVolIndex] = newVol
	return 1
End
Function setMaxVolume(beakerName, maxVol)
string beakerName
variable maxVol

	wave beaker = $beakerName
	beaker[k_maxVolIndex] = maxVol
End

Function acidMoles(solnName)
string solnName
	
	wave soln = $solnName
	return soln[k_acidMolIndex]
End
Function conjAcidMoles(solnName)
string solnName
	
	wave soln = $solnName
	return soln[k_conjAcidMolIndex]
End
Function xsOHMoles(solnName)
string solnName
	
	wave soln = $solnName
	return soln[k_xsOHmolIndex]
End
Function xsHMoles(solnName)
string solnName
	
	wave soln = $solnName
	return soln[k_xsHmolIndex]
End
Function indMoles(solnName)
string solnName
	
	wave soln = $solnName
	return soln[k_indMolIndex]
End
Function FeMoles(solnName)
string solnName
	
	wave soln = $solnName
	return soln[k_FeMolIndex]
End
Function SCNmoles(solnName)
string solnName
	
	wave soln = $solnName
	return soln[k_SCNmolIndex]
End
Function CVMoles(solnName)
string solnName
	
	wave soln = $solnName
	return soln[k_CVmolIndex]
End

Function acidConc(solnName)
string solnName
	
	wave soln = $solnName
	variable vol
	
	vol = soln[k_solnVolIndex]
	return vol > 0.001 ? soln[k_acidMolIndex]/vol : 0
End
Function conjAcidConc(solnName)
string solnName
	
	wave soln = $solnName
	variable vol
	
	vol = soln[k_solnVolIndex]
	return vol > 0.001 ? soln[k_conjAcidMolIndex]/vol : 0
End
Function xsOHConc(solnName)
string solnName
	
	wave soln = $solnName
	variable vol
	
	vol = soln[k_solnVolIndex]
	return vol > 0.001 ? soln[k_xsOHmolIndex]/vol : 0
End
Function xsHConc(solnName)
string solnName
	
	wave soln = $solnName
	variable vol
	
	vol = soln[k_solnVolIndex]
	return vol > 0.001 ? soln[k_xsHmolIndex]/vol : 0
End
Function indConc(solnName)
string solnName
	
	wave soln = $solnName
	variable vol
	
	vol = soln[k_solnVolIndex]
	return vol > 0.001 ? soln[k_indMolIndex]/vol : 0
End
Function FeConc(solnName)
string solnName
	
	wave soln = $solnName
	variable vol
	
	vol = soln[k_solnVolIndex]
	return vol > 0.001 ? soln[k_FeMolIndex]/vol : 0
End
Function SCNconc(solnName)
string solnName
	
	wave soln = $solnName
	variable vol
	
	vol = soln[k_solnVolIndex]
	return vol > 0.001 ? soln[k_SCNmolIndex]/vol : 0
End
Function CVconc(solnName)
string solnName
	
	wave soln = $solnName
	variable vol
	
	vol = soln[k_solnVolIndex]
	return vol > 0.001 ? soln[k_CVmolIndex]/vol : 0
End
Function buffer_acidMolarity(bufferNum)
variable bufferNum

	wave acidMolarity = root:MAH:unk_buffer_acidMolarity
	return acidMolarity[bufferNum]
End
Function buffer_baseMolarity(bufferNum)
variable bufferNum

	wave baseMolarity = root:MAH:unk_buffer_baseMolarity
	return baseMolarity[bufferNum]
End
Function/S acidName(vesselName)
string vesselName
	
	wave vessel = $vesselName
	return StringByKey("acidName", note($vesselName))
End
Function volume(beakerName)
string beakerName

	wave beaker = $beakerName
	return beaker[k_solnVolIndex]
End
Function maxVolume(beakerName)
string beakerName

	wave beaker = $beakerName
	return beaker[k_maxVolIndex]
End
Function setIndicatorNum(beakerName, indicatorNum)
string beakerName
variable indicatorNum

	wave beaker = $beakerName
	beaker[k_indicatorIndex] = indicatorNum
End
Function indicatorNum(beakerName)	// Returns -1 if no indicator
string beakerName

	wave beaker = $beakerName
	return beaker[k_indicatorIndex]
End
Function lookupIndicatorNum(indicatorName) // The indicator num is the index of root:MAH:ind_name or -1 for no indicator
string indicatorName

	wave/t ind_fakeName = root:MAH:ind_fakeName
	variable success = 0, ii
	string theNote
	
	for(ii = 0;ii < numpnts(ind_fakeName);ii += 1)
		if(cmpstr(indicatorName, ind_fakeName[ii]) == 0)
			success = 1
			break
		endif
	endfor
	if(success)
		return ii
	else
		WriteSimpleErrorToLog(kMissingIndicator, indicatorName)
		return -1
	endif
End
Function/S lookupBufferName(bufferNum)
variable bufferNum
	
	wave/t unk_buffer_fakeName = root:MAH:unk_buffer_fakeName
	return unk_buffer_fakeName[bufferNum]
End
Function lookupBufferNum(bufferName) // The indicator num is the index of root:MAH:ind_name or -1 for no indicator
string bufferName

	wave/t unk_buffer_fakeName = root:MAH:unk_buffer_fakeName
	variable success = 0, ii
	string theNote
	
	for(ii = 0;ii < numpnts(unk_buffer_fakeName);ii += 1)
		if(cmpstr(bufferName, unk_buffer_fakeName[ii]) == 0)
			success = 1
			break
		endif
	endfor
	if(success)
		return ii
	else
		WriteSimpleErrorToLog(kMissingBuffer, bufferName)
		return -1
	endif
End
Function/S lookupIndicatorName(indicatorNum)
variable indicatorNum
	
	wave/t ind_fakeName = root:MAH:ind_fakeName
	return ind_fakeName[indicatorNum]
End

// ---------------------------- Defining Volumetric Errors -----------------------------------------
Function VolumeError(Method, vol)
string Method
variable vol

	variable error
	NVAR useErrors = root:MAH:useErrors
	
	if(!useErrors)
		return 0
	endif
	
	strswitch(Method)
		case "pipette":								// 25 ml pipette
			error = enoise(0.03)
			break
		case "vol_flask":								// 100 ml vol flask
			error = enoise(0.08)
			break
		case "buret":
			error = enoise(0.05)
			break
		case "graduated_cylinder":
			error = (vol <= 0.010) ? enoise(0.1) : enoise(0.5)
			break
		default:			// Anything else is a graduated cylinder
			error = (vol <= 0.010) ? enoise(0.1) : enoise(0.5)
	endswitch
	return error/1000
End
Function refreshStandards(targetHOH, targetBuffer)
variable targetHOH, targetBuffer

	NVAR concStdOH = root:MAH:concStdOH,concStdH = root:MAH:concStdH, useErrors = root:MAH:useErrors	
	NVAR pHofStdH2O = root:MAH:pHofStdH2O, concStdBuffer = root:MAH:concStdBuffer
	NVAR concStdSCN = root:MAH:concStdSCN, concStdFe = root:MAH:concStdFe, concStdCV = root:MAH:concStdCV

	
	concStdOH = targetHOH + useErrors * enoise(0.15 * targetHOH)
	concStdH = targetHOH + useErrors * enoise(0.15 * targetHOH)
	if(useErrors)
		pHofStdH2O = 6.75 + enoise(0.75)		// Measured pH = 7.25 - 7.5
	else
		pHofStdH2O = 7.0
	endif
	concStdBuffer = targetBuffer + useErrors * enoise(0.15 * targetBuffer)
	concStdSCN = 2e-4 * (1 + useErrors * enoise(0.15))
	concStdFe = 0.20 * (1 + useErrors * enoise(0.15))
	concStdCV = 1.4e-4 * (1 + useErrors * enoise(0.15))	// Crystal Violet
End
Function concStandardizedOH()

	NVAR concStdOH = root:MAH:concStdOH
	return concStdOH
End
Function concStandardizedH()

	NVAR concStdH = root:MAH:concStdH
	return concStdH
End
Function concStandardizedSCN()

	NVAR concStdSCN = root:MAH:concStdSCN
	return concStdSCN
End
Function concStandardizedFe()

	NVAR concStdFe = root:MAH:concStdFe
	return concStdFe
End
Function concStandardizedCV()

	NVAR concStdCV = root:MAH:concStdCV
	return concStdCV
End
Function concStandardizedBuffer()

	NVAR concStdBuffer = root:MAH:concStdBuffer
	return concStdBuffer
End
Function pH_of_H2O()

	NVAR pHofStdH2O = root:MAH:pHofStdH2O 
	return pHofStdH2O 
End

Function errorsOff()

	NVAR useErrors = root:MAH:useErrors
	useErrors = 0
	print "Errors now off"
End
Function errorsOn()

	NVAR useErrors = root:MAH:useErrors
	useErrors = 1
	print "Errors now on"
End
// ---------------------------- Other -----------------------------------------

Function InitializeData()

	string tempName, desc, theList, theFilename, workingPath
	variable ii, temp, err
	
	// Check to make sure the experiment has been saved so we know where to make the tempFolder
	PathInfo home
	if(V_flag == 0)
		DoAlert 0, "Please save this experiment before initializing using the Save command in the Calvin menu."
		return -1
	endif
	
	// Make the tempFolder
	workingPath = ParseFilePath(5, S_path, ":", 1, 0) + "CalvinWorkingFolder"
	NewPath/o/C/q tempFolder, workingPath
	
	// Set up data waves in a subfolder
	DFREF savedDF= GetDataFolderDFR()
	NewDataFolder/o root:MAH
	SetDataFolder root:MAH
	
	err = SetTheLocations()
	if(err < 0)
		return -1	// User probably canceled out of path setting
	endif
	variable/g useErrors = 1, gVerboseReporting = 1, gSpectrumNumber, gTAnumber
	variable/g gGroupNumber, gMaxCommands, concStdBuffer, concStdOH, concStdH, pHofStdH2O
	variable/g concStdSCN, concStdFe, concStdCV, spectromTemperature
	variable/g gSolidAcidsEnabled, gBuffersEnabled, gLastLineWasComment, gIgorMenusHidden
	string/g gRunTime, gCmdFileName, gBadGroupName, gBadTAName, gGroupName
	string/g gCalvinAcidsMenuString, gCalvinBuffersMenuString, gCalvinHideMenuString
	
	gMaxCommands = 60
	gSolidAcidsEnabled = 1
	gBuffersEnabled = 1
	gIgorMenusHidden = 1
	gCalvinAcidsMenuString = "Disable Solid Acids"
	gCalvinBuffersMenuString = "Disable Buffers"
	gCalvinHideMenuString = "Show All Igor Menus"
	spectromTemperature = 30 + enoise(9.9)
	HideIgorMenus

	LoadWave/J/D/W/A/P=startup/K=0/V={","," $",0,0}/L={0,1,0,0,0}/o/q "Indicators.csv"
	LoadWave/J/D/W/A/P=startup/K=0/V={","," $",0,0}/L={0,1,0,0,0}/o/q "Acids.csv"
	LoadWave/J/D/W/A/P=startup/K=0/V={","," $",0,0}/L={0,1,0,0,0}/o/q "Buffers.csv"
	LoadWave/J/D/W/A/P=startup/K=0/V={","," $",0,0}/L={0,1,0,0,0}/o/q "TAs.csv"
	LoadWave/J/D/W/A/P=startup/K=0/V={","," $",0,0}/L={0,1,0,0,0}/o/q "Groups.csv"
	LoadWave/P=startup/o/q "CIE_x.ibw"
	LoadWave/P=startup/o/q "CIE_y.ibw"
	LoadWave/P=startup/o/q "CIE_z.ibw"
	wave CIE_x, CIE_y, CIE_z
	
	// Insert enough extra points in the CIE data if necessary
	temp = ceil(800 - pnt2x(CIE_x,numpnts(CIE_x)-1))/DimDelta(CIE_x, 0)
	if(temp > 0)
		InsertPoints (numpnts(CIE_x)-1), temp, CIE_x,CIE_y,CIE_z
	endif
	
	wave/t ind_acidSpectrum, ind_baseSpectrum
	
	// Load spectra of indicators
	ii = 0
	do
		if(!exists(ind_acidSpectrum[ii]))
			theFilename = ind_acidSpectrum[ii] + ".ibw"
			LoadWave/H/P=startup/O/q theFilename
		endif
		if(!exists(ind_baseSpectrum[ii]))
			theFilename = ind_baseSpectrum[ii] + ".ibw"
			LoadWave/H/P=startup/O/q theFilename
		endif
		ii = ii + 1		
	while(ii < numpnts(ind_acidSpectrum) - 1) // Last point in wave is error
	
	// Load other spectra
	LoadWave/H/P=startup/O/q "FeSCN.ibw"
	LoadWave/H/P=startup/O/q "Ferric_ion.ibw"
	
	SetDataFolder savedDF
	InitCommandReader()
End
Function SetTheLocations()
	
	PathInfo/S startup
	NewPath/o/q/M="Choose the folder containing startup data" startup
	if(V_flag != 0)
		return -1	// User hit cancel
	endif
	PathInfo/S cloudFolder
	NewPath/o/q/M="Choose the cloud outbox folder" cloudFolder
	if(V_flag != 0)
		return -1	// User hit cancel
	endif
	PathInfo/S watchedFolder
	NewPath/o/q/M="Choose the inbox to monitor" watchedFolder
	if(V_flag != 0)
		return -1	// User hit cancel
	endif
	return 1
End
Function NewExperiments()

	string exptName, desc, theList, theFilename
	variable numItems, ii
	NVAR useErrors = root:MAH:useErrors, gSpectrumNumber = root:MAH:gSpectrumNumber, gTAnumber = root:MAH:gTAnumber
	NVAR gMaxCommands = root:MAH:gMaxCommands, gLastLineWasComment = root:MAH:gLastLineWasComment
	NVAR spectromTemperature = root:MAH:spectromTemperature
	SVAR gRunTime = root:MAH:gRunTime, gGroupName = root:MAH:gGroupName
	SVAR gBadGroupName = root:MAH:gBadGroupName, gBadTAName = root:MAH:gBadTAName
	
	gSpectrumNumber = 1
	refreshStandards(0.100, 0.050) // H/OH conc, buffer conc
	gTAnumber = -1
	gRunTime = Secs2Date(DateTime,-2)[5,9] + "_" + Secs2Time(DateTime,3)
	gBadGroupName = "NoGroup"
	gBadTAName = "NoTA"
	gLastLineWasComment = 0
	spectromTemperature = 30 + enoise(9.9)

	SetupNewLog()
	
	// Clean old files from tempFolder
	theList = IndexedFile(tempFolder, -1, "????")
	numItems = ItemsInList(theList)
	for(ii = 0; ii < numItems; ii += 1)
		DeleteFile/P=tempFolder/Z StringFromList(ii, theList)
	endfor
	
	// Kill all graphs and tables
	do
		theList = WinList("*",";","WIN:3")
		if(strlen(theList) > 2)
			KillWindow $(StringFromList(0, theList))
		else
			break
		endif
	while(1)
	
	// Kill existing beakers and solutions	
	do
		theList = WaveList("*", ";", "")
		if(strlen(theList) > 2)
			KillWaves $(StringFromList(0, theList))
		else
			break
		endif
	while(1)
	Make_H2O_Reservoir()
	Make_50ml_Buret()
	Verbose_Reporting_On()
	Close/A	// in case there were any crashes previously
End
Function Verbose_Reporting_On()
	NVAR gVerboseReporting = root:MAH:gVerboseReporting
	gVerboseReporting = 1
End
Function Verbose_Reporting_Off()
	NVAR gVerboseReporting = root:MAH:gVerboseReporting
	gVerboseReporting = 0
End
Function Set_Spectrometer_Temperature(newTemp)
variable newTemp

	NVAR spectromTemperature = root:MAH:spectromTemperature
	string outStr, theNote
	
	// Make sure newTemp is in correct range
	if((newTemp > 40.0) || (newTemp < 20))
		WriteSimpleErrorToLog(kTempOutOfBounds, num2str(newTemp))
		return -1
	endif
	spectromTemperature = 0.1 * round(newTemp * 10)
	sprintf outStr, "%.1f", spectromTemperature
	theNote = "The spectrometer temperature was set to " + outStr +  "°C.\r"
	WriteToLog(theNote)
	
End
Function Set_Group_Name(groupName)
string groupName

	NVAR gGroupNumber = root:MAH:gGroupNumber
	SVAR gBadGroupName = root:MAH:gBadGroupName
	
	gGroupNumber = validateGroupName(groupName)
	if(gGroupNumber < 0)
		gBadGroupName = groupName
		WriteSimpleErrorToLog(kBadGroupName, groupName)
	endif
End
Function validateGroupName(groupName) // returns index of TA if validated, otherwise -1
string groupName

	variable ii
	wave/t Group_Names = root:MAH:Group_Names
	for(ii = 0; ii < numpnts(Group_Names); ii += 1)
		if(CmpStr(groupName, Group_Names[ii], 0) == 0)
			return ii
		endif
	endfor
	return -1
End
Function Set_TA_Name(TAname)
string TAname

	NVAR gTAnumber = root:MAH:gTAnumber
	gTAnumber = validateTAName(TAname)
	if(gTAnumber < 0)
		WriteSimpleErrorToLog(kBadTAname, TAname)
	endif

End
Function validateTAName(TAname) // returns index of TA if validated, otherwise -1
string TAname

	variable ii
	wave/t TA_Names = root:MAH:TA_Names
	for(ii = 0; ii < numpnts(TA_Names); ii += 1)
		if(CmpStr(TAName, TA_Names[ii], 0) == 0)
			return ii
		endif
	endfor
	return -1
End
Function HalfRound(num, digsWRTdecPt) // Rounds to nearest 0.5
variable num, digsWRTdecPt

	return round(2 * num * 10^(digsWRTdecPt-1))/2/10^(digsWRTdecPt-1)
End
Function molarMass(unkName)
string unkName

	variable ii
	wave/t unk_acid_fakeName = root:MAH:unk_acid_fakeName
	wave unk_acid_molarMass = root:MAH:unk_acid_molarMass
	for(ii = 0;ii < numpnts(unk_acid_fakeName);ii += 1)
		if(cmpstr(unkName, unk_acid_fakeName[ii]) == 0)
			break
		endif
	endfor
	return unk_acid_molarMass[ii]	
End
Function acidKaFromName(acidName)
string acidName

	variable ii
	wave unk_acid_pKa = root:MAH:unk_acid_pKa
	ii = indexOfAcid(acidName)
	if(ii < 0)
		WriteSimpleErrorToLog(kMissingAcid, acidName)
		return -1
	else
		return 10^(-unk_acid_pKa[ii])
	endif	
End
Function indPKa(indNum)
variable indNum

	wave ind_pKa = root:MAH:ind_pKa
	return ind_pKa[indNum]	
End
Function RandomizeUnkIndicatorsAndSave()
	
	variable ii, ran
	wave/t ind_fakeName = root:MAH:ind_fakeName,ind_realName = root:MAH:ind_realName
	wave/t ind_baseSpectrum = root:MAH:ind_baseSpectrum,ind_acidSpectrum = root:MAH:ind_acidSpectrum
	wave ind_pKa = root:MAH:ind_pKa
	string tempStr
	
	DoAlert 1, "Preparing to randomize all indicators named \"Dye_of_xxxx\" which will overwrite the csv files.\r\rContinue?"
	if(V_flag > 1)
		return -1
	endif
	make/n=(numpnts(ind_fakeName))/o/FREE sortOrder
	for(ii = 0; ii < numPnts(ind_fakeName); ii += 1) 
		if(strsearch(ind_fakeName[ii], "Dye_of_", 0, 2) == 0)
			sortOrder[ii] = 100 + enoise(1)
			ran = round(100 * (enoise(2.0)))/100
			ind_pKa[ii] = ran > 0 ? 8 + ran : 6 + ran
			ran = enoise(1)
			if(ran < 0)
				tempStr = ind_acidSpectrum[ii]
				ind_acidSpectrum[ii] = ind_baseSpectrum[ii]
				ind_baseSpectrum[ii] = tempStr
			endif
		else
			sortOrder[ii] = ii
		endif
	endfor
	Sort sortOrder, ind_pKa, ind_baseSpectrum, ind_acidSpectrum, ind_realName
	Save/J/M="\n"/DLIM=","/W/P=startup/o ind_fakeName,ind_realName,ind_pKa,ind_acidSpectrum, ind_baseSpectrum as "Indicators.csv"
End
Function RandomizeUnkAcidsAndSave()
	
	variable ii
	wave/t unk_acid_fakeName = root:MAH:unk_acid_fakeName, unk_acid_realName = root:MAH:unk_acid_realName
	wave unk_acid_pKa = root:MAH:unk_acid_pKa, unk_acid_molarMass = root:MAH:unk_acid_molarMass 
	
	DoAlert 1, "Preparing to randomize all acids named \"Acid_of_xxxx\" which will overwrite the csv files.\r\rContinue?"
	if(V_flag > 1)
		return -1
	endif
	make/n=(numpnts(unk_acid_fakeName))/o/FREE sortOrder
	for(ii = 0; ii < numPnts(unk_acid_fakeName); ii += 1) 
		if(strsearch(unk_acid_fakeName[ii], "Acid_of_", 0, 2) == 0)
			sortOrder[ii] = 100 + enoise(1)
		else
			sortOrder[ii] = ii
		endif
	endfor
	Sort sortOrder, unk_acid_realName, unk_acid_pKa, unk_acid_molarMass
	Save/J/M="\n"/DLIM=","/W/P=startup/o unk_acid_fakeName, unk_acid_realName, unk_acid_pKa, unk_acid_molarMass as "Acids.csv"
End
Function RandomizeUnkBuffersAndSave()
	
	wave/t unk_buffer_fakeName = root:MAH:unk_buffer_fakeName, unk_buffer_acidRealName = root:MAH:unk_buffer_acidRealName
	wave unk_buffer_acidMolarity = root:MAH:unk_buffer_acidMolarity, unk_buffer_baseMolarity = root:MAH:unk_buffer_baseMolarity
	
	DoAlert 1, "Preparing to randomize all buffers named \"Buffer_of_xxxx\" which will overwrite the csv files.\r\rContinue?"
	if(V_flag > 1)
		return -1
	endif
	
	// This is the range of concentrations used at Cornell
	unk_buffer_acidMolarity = round(1000 * (0.133 + enoise(0.037)))/1000
	unk_buffer_baseMolarity = round(1000 * (0.106 + enoise(0.034)))/1000

	Save/J/M="\n"/DLIM=","/W/P=startup/o unk_buffer_fakeName, unk_buffer_acidRealName, unk_buffer_acidMolarity, unk_buffer_baseMolarity as "Buffers.csv"
End
