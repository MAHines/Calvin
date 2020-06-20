#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//-----------------------------------------------------------------------------------
//
//     Calvin — Online Instruction in Acid-Base Chemistry
//		 © 2020, Melissa A. Hines	
//		 Melissa.Hines@cornell.edu
//
//-----------------------------------------------------------------------------------

Structure color
	float rr
	float gg
	float bb
	float aa
EndStructure

Function getX(theSpectrum)
wave theSpectrum

	wave CIE_x = root:MAH:CIE_x
	
	duplicate/FREE theSpectrum, temp
	temp = theSpectrum * CIE_x(x)
	return area(temp)
End
Function getY(theSpectrum)
wave theSpectrum

	wave CIE_y = root:MAH:CIE_y
	
	duplicate/FREE theSpectrum, temp
	temp = theSpectrum * CIE_y(x)
	return area(temp)
End
Function getZ(theSpectrum)
wave theSpectrum

	wave CIE_z = root:MAH:CIE_z
	
	duplicate/FREE theSpectrum, temp
	temp = theSpectrum * CIE_z(x)
	return area(temp)
End
Function gammaCorrect(value)
variable value
	
	if(value <= 0.0031308)
		return (12.92 * value)
	else
		return (1.055 * value^0.416666 - 0.055)
	endif
End
Function calcColorOfSpectrum(spectrum, theColor, absorbance)
wave spectrum
STRUCT color &theColor
variable absorbance		// 1 if absorption spectrum, 0 if emission spectrum

	variable XX, YY, ZZ, xxx, yyy, zzz, rr, gg, bb, theMin, theMax, scale
	variable avgAbsorbance, darken
	
	duplicate/o/FREE spectrum, spec_clean,transmitted
	
	spec_clean = spectrum > 0 ? spectrum : 0
	if(absorbance)
		transmitted = 10^-(10 * spec_clean)	// 10 is a phenomenological constant
	else
		transmitted = spec_clean
	endif
	
	XX = getX(transmitted)
	YY = getY(transmitted)
	ZZ = getZ(transmitted)
	
	xxx = XX/(XX + YY + ZZ)
	yyy = YY/(XX + YY + ZZ)
	zzz = ZZ/(XX + YY + ZZ)

	// Calc avg absorbance
	avgAbsorbance = mean(spec_clean)
	darken = (avgAbsorbance > 0.33) ? 1/(3 * avgAbsorbance) : 1
	theColor.rr = (3.240479 * xxx - 1.537150 * yyy - 0.498535 * zzz) * darken
	theColor.gg = (-0.969256 * xxx + 1.875992 * yyy + 0.0415556 * zzz) * darken
	theColor.bb = (0.055648 * xxx - 0.204043 * yyy + 1.057311 * zzz) * darken
	theColor.aa = ((420 - area(transmitted))/420)^0.5 // 420 = all light transmitted
//	theColor.aa = ((420 - area(transmitted))/200)^1 // 420 = all light transmitted
//	theColor.aa = theColor.aa > 1 ? 1 : theColor.aa

//	Dealing with negative (r, g, b) as suggested by Walker
//    https://www.fourmilab.ch/documents/specrend/
//	theMin = theColor.rr < theColor.gg ? theColor.rr : theColor.gg
//	theMin = theColor.bb < theMin ? theColor.bb : theMin
//	if(theMin < 0)
//		theColor.rr += -theMin
//		theColor.gg += -theMin
//		theColor.bb += -theMin
//	endif

// Modified method of Walker, based on comments by Andrew Young
//   https://aty.sdsu.edu/explain/optics/rendering.html
	theMin = theColor.rr < theColor.gg ? theColor.rr : theColor.gg
	theMin = theColor.bb < theMin ? theColor.bb : theMin
	if(theMin < 0)
		theColor.rr = 1 - (1 - theColor.rr)/(1 - theMin)
		theColor.gg = 1 - (1 - theColor.gg)/(1 - theMin)
		theColor.bb = 1 - (1 - theColor.bb)/(1 - theMin)
	endif

// Method of reproducing spectrum by Andrew Young
// Makes a nice spectrum, but not really what is needed here.
//	theMin = theColor.rr < theColor.gg ? theColor.rr : theColor.gg
//	theMin = theColor.bb < theMin ? theColor.bb : theMin
//	if(theMin < 0)
//		scale = 1.85 * yyy/(yyy-theMin)
//		theColor.rr = yyy + scale * (theColor.rr - yyy)
//		theColor.gg = yyy + scale * (theColor.gg - yyy)
//		theColor.bb = yyy + scale * (theColor.bb - yyy)
//	endif
	
// Soft clipping of too high values
//	theMax = theColor.rr > theColor.gg ? theColor.rr : theColor.gg
//	theMax = theColor.bb > theMax ? theColor.bb : theMax
//	if(theMax > 1)
//		theColor.rr /= theMax
//		theColor.gg /= theMax
//		theColor.bb /= theMax
//	endif

	theColor.rr = 65535 * gammaCorrect(theColor.rr)
	theColor.gg = 65535 * gammaCorrect(theColor.gg)
	theColor.bb = 65535 * gammaCorrect(theColor.bb)
	theColor.aa *= 65535

	theColor.rr = theColor.rr > 65535 ? 65535 : theColor.rr
	theColor.gg = theColor.gg > 65535 ? 65535 : theColor.gg
	theColor.bb = theColor.bb > 65535 ? 65535 : theColor.bb
	
End
Function FillSwatch()

	wave colorSwatch
	variable pt = 0, pH
	STRUCT color theColor
	wave theSpectrum = $"spectrum"
	
	do
		pH = pnt2x(colorSwatch,pt)
		calcColorOfSpectrum(theSpectrum, theColor, 1)
		colorSwatch[pt][0][0] = theColor.rr
		colorSwatch[pt][0][1] = theColor.gg
		colorSwatch[pt][0][2] = theColor.bb
		pt += 1
	while(pt < DimSize(colorSwatch, 0))
End
Function FillWavelength()

	wave colorOfWavelength, spectrum
	variable pt = 0, wavelength
	STRUCT color theColor
	
	do
		wavelength = pnt2x(colorOfWavelength, pt)
		spectrum = exp(-(x-wavelength)^2/10)
		calcColorOfSpectrum(spectrum, theColor, 0)
		colorOfWavelength[pt][0][0] = theColor.rr
		colorOfWavelength[pt][0][1] = theColor.gg
		colorOfWavelength[pt][0][2] = theColor.bb
		print wavelength, theColor.rr, theColor.gg, theColor.bb
		pt += 1
	while(pt < DimSize(colorOfWavelength, 0))
End

