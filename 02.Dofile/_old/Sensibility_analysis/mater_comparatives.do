
*===============================================================================
* Example FiscalSim - fiscal microsimulation model for hypothetical country. 
* Prepared by EPL team (Mikhail Matytsin with inputs from Daniel Valderrama Gonzalez, Haydeeliz Carrasco Nunez, Maya Goldman and Eduard Bukin)
* December 2022
*===============================================================================
	set more off
	clear all
	
	set type double, permanently
	
	*Please change this to your own path
	if "`c(username)'" == "WB395877" {
		global path "C:\Users\wb395877\GitHub\Example_FiscalSim" 
	}
	
	else if "`c(username)'" == "WB526693" {
		global path "C:\Users\wb526693\Github_projects\Example_FiscalSim" // PUT YOU PATH HERE!!!
	}
	else if "`c(username)'" == "wb532966" {
		global path "C:\Users\wb532966\CEQ\Example_FiscalSim" // PUT YOU PATH HERE!!!
	} 
	else if "`c(username)'" == "WB419055" {
	
		global path "C:/Users/`c(username)'/OneDrive - WBG/Example_FiscalSim" // PUT YOU PATH HERE!!!
	} 
	

	else if "`c(username)'" == "" {
		global path "" // PUT YOU PATH HERE!!!
	}
	

*===============================================================================
		*DO NOT MODIFY BEYOND THIS POINT
*===============================================================================		
	global data 	 "${path}\01.Data"    
	global thedo     "${path}\02.Dofile"            
	global theado    "${thedo}\ados"	     
	global xls_tool  "${path}\03.Tool\Example_FiscalSim.xlsx"
*===============================================================================
		*Run necessary ado files
*===============================================================================
	
	local files : dir "$theado" files "*.ado"
	foreach f of local files{
		dis in yellow "`f'"
		qui: run "$theado\\`f'"
	}

*===============================================================================
		*Do files in the tool
*===============================================================================


include "thedo/_old/Sensibility_analysis07_indirect_taxes_old.do"






Next steps:

Validate Using Misha method and my method

-Validate the inflation rates using misha method and my method

-Validate the inflation rates using misha method and my method

-Validate the inflation rates using misha method and my method
