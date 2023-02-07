*Calculating the direct taxes and social contributions for policy year (PY)

* PIT and Pension rates 
import excel using "$xls_tool", sheet(PIT_SIC)  first clear //PIT
	drop if missing(PIT_cutoff) | PIT_cutoff == 0
	global PIT_brackets = _N

	forvalues i = 1 / $PIT_brackets {
		global PIT_cutoff_`i' = PIT_cutoff[`i']
		global PIT_rate_`i' = PIT_rate[`i']
	}
	
	foreach var in PIT_deduction SIC_rate {
		global `var' = `var'[1]	
		
	}

import excel using "$xls_tool", sheet(check)  first clear 
	ds 
	foreach var in `r(varlist)' {
		global `var' = `var'[1]
	}

use "${data}\01.pre-simulation\Example_FiscalSim_dem_inc_data.dta" , clear
merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_market_income_data_PY.dta", nogen update replace

* Here the order is opposite to grossing up!

* 1. SIC
gen SIC = -1 * wage * ${SIC_rate} 

gen wage_PIT = wage + SIC 

* 2. PIT
global PIT_base_list wage_PIT self_inc  // Use wage_PIT instead of wage

gen PIT_base_gross = 0
	foreach var in $PIT_base_list {
		replace PIT_base_gross = PIT_base_gross + `var'
	}

gen PIT_base_gross_deduct = max(0, PIT_base_gross - ${PIT_deduction}) // personal deduction for PIT purpose
	gen deduct = PIT_base_gross - PIT_base_gross_deduct
	assert deduct >= 0 & deduct <= ${PIT_deduction}

// calculate PIT by brackets (this part may be done more efficiently with dirtax.ado)
gen PIT = 0
global PIT_cutoff_0 = 0
forvalues i = 1 / $PIT_brackets {
	local j = `i' - 1
	
		gen PIT_`i' = 0 																 if PIT_base_gross_deduct <= ${PIT_cutoff_`j'}
		replace PIT_`i' = -1 * ${PIT_rate_`i'} * (PIT_base_gross_deduct - ${PIT_cutoff_`j'}) if PIT_base_gross_deduct >  ${PIT_cutoff_`j'} & PIT_base_gross_deduct <= ${PIT_cutoff_`i'}
		replace PIT_`i' = -1 * ${PIT_rate_`i'} * (${PIT_cutoff_`i'} - ${PIT_cutoff_`j'}) 	 if PIT_base_gross_deduct >  ${PIT_cutoff_`i'} 
		
		replace PIT = PIT + PIT_`i'
		drop PIT_`i'
	}

foreach var in $SSC $direct_taxes {
	replace `var' = 0 if tax_payer == 0	
}	

if $SY_consistency_check == 1 { 
	egen net_market_income = rowtotal(${market_income} ${SSC} ${direct_taxes})
	assert abs(net_market_income_orig - net_market_income) < 10 ^ (-9) // this is to check that in baseline the original (survey based) and simulated net market incomes are identical
}				

label variable SIC "Social insurance contributions"
label variable PIT "Personal income tax"

keep hh_id p_id ${SSC} ${direct_taxes} 
mvencode ${SSC} ${direct_taxes}, mv(0) override 

isid hh_id p_id

save "${data}\02.intermediate\Example_FiscalSim_SSC_direct_taxes_data.dta", replace