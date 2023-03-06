*Calculating indirect subsidies for policy year


import excel using "$xls_tool", sheet(subsidy)  first clear
	foreach var in electr_cost gas_subs {
	    global `var' = `var'[1]
	}
	
	drop if missing(electr_cutoff) | electr_cutoff == 0
		global electr_brackets = _N
		forvalues i = 1 / $electr_brackets {
			global electr_cutoff_`i' = electr_cutoff[`i']
			global electr_tariff_`i' = electr_tariff[`i']
		}


*****ELECTRICITY SUBSIDIES*****
use "${data}\01.pre-simulation\Example_FiscalSim_electr_data.dta", clear

* we assume that the industrial consumers pay full electricity tariff, that is why there is no indirect effect. We estimate the direct effect households only

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

gen electr_sub = ${electr_cost} * electr_cons - electr_exp_PY
	
if $SY_consistency_check == 1 { 
	assert abs(electr_exp_PY - electr_exp_SY) < 10 ^ (-5)
}

label variable electr_sub "Electricity subsidy"

tempfile electr_subsidies_data
save `electr_subsidies_data'

*****FUEL SUBSIDIES*****

*Fuel indirect effects
import excel using "$xls_tool", sheet(IO) first clear 
drop sector_name VAT*

isid sector
mvencode sect_*, mv(0) override // make sure that none of the coefficient is missing
gen dp = $gas_subs * 0.3 if sector==4 //Price shock: Subsidy removal on Energy sector. We assume that share of gas in the energy sector is 30%.
	replace dp = 0 if mi(dp)
gen fixed = (dp != 0) // Government controls prices on energy sector 
	assert dp == 0 if fixed == 0

costpush sect_*, fixed(fixed) price(dp) genptot(gas_sub_tot_eff_PY) genpind(gas_sub_ind_eff_PY) fix
keep sector gas_sub_ind_eff_PY

isid sector
tempfile ind_effect_gas_PY
save `ind_effect_gas_PY', replace

*Fuel Direct effects
use "${data}\02.intermediate\Example_FiscalSim_exp_data_PY.dta", clear
merge m:1 sector using `ind_effect_gas_PY', nogen assert(match using) keep(match)

gen gas_subs = ${gas_subs} if exp_type == 92
	replace gas_subs = 0 if mi(gas_subs)

gen exp_gross_subs_PY = exp_net_PY * (1 - gas_subs) * (1 - gas_sub_ind_eff_PY)

* if we would like to separate the direct and indirect effect this can be done:
gen gas_sub_tot = exp_net_PY - exp_gross_subs_PY
gen gas_sub_dir = exp_net_PY * gas_subs
gen gas_sub_ind = gas_sub_tot - gas_sub_dir // the direct and indirect effects are rather cumulative than additive, but need them to add up

isid hh_id exp_type exp_form
keep hh_id exp_type exp_form sector exp_gross_subs_PY gas_sub_dir gas_sub_ind hh_size
save "${data}\02.intermediate\Example_FiscalSim_indirect_subs_data_long.dta", replace

collapse (sum) gas_sub_dir gas_sub_ind (mean) hh_size, by(hh_id) //HH-level dataset with Fuel subsidies estimations
isid hh_id

label var gas_sub_dir "Gas subsidy (direct effects)"
label var gas_sub_ind "Gas subsidy (indirect effects)"

*Merge with Gas Subsidies dataset
merge 1:1 hh_id using `electr_subsidies_data', nogen assert(match)

foreach var in $indirect_subsidies {
	replace `var' = `var' / hh_size // we need to convert to per capita terms since me merge with individual-level data
}

keep hh_id ${indirect_subsidies} 
mvencode ${indirect_subsidies}, mv(0) override 

isid hh_id 
save "${data}\02.intermediate\Example_FiscalSim_indirect_subsidies_data.dta", replace