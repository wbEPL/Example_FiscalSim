*Calculating indirect subsidies for policy year

import excel using "$xls_tool", sheet(subsidy)  first clear
	global electr_cost = electr_cost[1]	
	drop if missing(electr_cutoff) | electr_cutoff == 0
		global electr_brackets = _N
		forvalues i = 1 / $electr_brackets {
			global electr_cutoff_`i' = electr_cutoff[`i']
			global electr_tariff_`i' = electr_tariff[`i']
		}


use "${data}\01.pre-simulation\Example_FiscalSim_electr_data.dta", clear

* we assume that the industrial consumers pay full electricity tariff, that is why there is no indirect effect. We estimate the direct effect households only

gen fuel=0 //DELETE LATER

gen electr_exp_PY = 0
global electr_cutoff_0 = 0
forvalues i = 1 / $electr_brackets {
	local j = `i' - 1

		gen electr_exp_PY_`i' = 0 if electr_cons < ${electr_cutoff_`j'}
		replace electr_exp_PY_`i' = (electr_cons - ${electr_cutoff_`j'}) * ${electr_tariff_`i'} if electr_cons >= ${electr_cutoff_`j'} & electr_cons < ${electr_cutoff_`i'}
		replace electr_exp_PY_`i' = (${electr_cutoff_`i'} - ${electr_cutoff_`j'}) * ${electr_tariff_`i'} if electr_cons >= ${electr_cutoff_`i'}

		replace electr_exp_PY = electr_exp_PY + electr_exp_PY_`i'
		drop electr_exp_PY_`i'
	}

gen electr_subs = ${electr_cost} * electr_cons - electr_exp_PY
	
if $SY_consistency_check == 1 { 
	assert abs(electr_exp_PY - electr_exp_SY) < 10 ^ (-5)
}

label variable electr_subs "Electricity subsidies"

keep hh_id ${indirect_subsidies} 
mvencode ${indirect_subsidies}, mv(0) override 

isid hh_id 
save "${data}\02.intermediate\Example_FiscalSim_indirect_subsidies_data.dta", replace
