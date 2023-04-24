*===============================================================================
* Example FiscalSim - fiscal microsimulation model for hypothetical country. 
* Prepared by EPL team (Mikhail Matytsin with inputs from Daniel Valderrama, Haydeeliz Carrasco Nunez, Maya Goldman and Eduard Bukin)
* December 2022 - January-February 2023
*===============================================================================
	set more off
	macro drop _all
	clear all
	
	set type double, permanently
	
	*Please change this to your own path
	if "`c(username)'" == "WB395877" {
		global path "C:\Users\wb395877\GitHub\Example_FiscalSim" // Misha's path
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

	else if "`c(username)'" == "Maya" {
		global path "C:\Users\User\Documents\GitHub\WB-EPL\Example_FiscalSim" // PUT YOU PATH HERE!!!
	} 
	
	else if "`c(username)'" == "" {
		global path "" // PUT YOU PATH HERE!!!
	}
	

*===============================================================================
		*DO NOT MODIFY BEYOND THIS POINT
*===============================================================================		
	global data 		"${path}\01.Data"    
	global do_files     "${path}\02.Dofile"            
	global ado_files    "${do_files}\ados"	     
	global xls_tool  	"${path}\03.Tool\Example_FiscalSim.xlsx"
*===============================================================================
		*Run necessary ado files
*===============================================================================
	
	local files : dir "${ado_files}" files "*.ado"
	foreach f of local files{
		dis in yellow "`f'"
		qui: run "${ado_files}\\`f'"
	}

*===============================================================================
		*Do files in the tool
*===============================================================================


global market_income 				wage self_inc cap_income agri_inc priv_trans

global SSC							SIC
global direct_taxes 				PIT	

global pensions 					lab_pens  
global direct_transfers 			soc_pens unem_ben child_ben GMI other_ben

global indirect_taxes 				VAT_dir VAT_ind	excises									   
global indirect_subsidies 			electr_sub gas_sub_dir gas_sub_ind

global health  						hlt_outp_in hlt_hosp_in 									   
global education					edu_prim_in edu_seco_in edu_psec_in edu_tert_in fee_educ_ps

global weight 						ind_weight
global povline 						povline_nat //povline_int32 povline_int55 // you may choose between a few available poverty lines (for example, national and international)
global rank_var 					market_income //choose between market income and market plus pensions - this is similar for PGT and PDI scenarios to some extent 

global dem_list 					hh_size ind_weight hh_weight /*age*/ hh_type strata region povline_*
global income_list  				market_income market_pens_income net_market_income gross_income disposable_income consumable_income final_income  
global comp_list 					SSC direct_taxes pensions direct_transfers indirect_taxes indirect_subsidies health education educfees

	
	*Pre-simulation stage (needs to be run only once to get the input data)

	do "${do_files}\01_input_data.do"
	do "${do_files}\02_gross_market_income.do"
	do "${do_files}\03_net_expenditures.do"
	
	*Simulation stage (needs to be run for every scneario)
	
	do "${do_files}\04_income_uprating.do"
	do "${do_files}\05_SSC_direct_taxes.do"
	do "${do_files}\06_pensions_direct_transfers.do"
	do "${do_files}\07_expenditure_adjustment.do"
	do "${do_files}\08_indirect_subsidies.do"
	do "${do_files}\09_indirect_taxes.do"
	do "${do_files}\10_inkind_transfers.do"
	do "${do_files}\11_income_concepts.do"
	
	*Post-simulation stage (needs to be run for every scneario)
	
	do "${do_files}\12_output.do"
	
	
	
