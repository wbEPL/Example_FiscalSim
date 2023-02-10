*Calculating indirect subsidies for policy year

*****FUEL SUBSIDIES***** [MODIFIED BY HC]

****Fuel subsidy 
clear all
global fuel_sub=0.15 //Subsidy rate of gas in the policy year [Misha: Could you please link this to Excel parameters]
global nowcasting=1.2 //Misha: Sorry- Can you delete this? And adjust with disposable income nowcasted? [like you did for indirect taxes]

*For fuel subsidy we need to calculate direct and indirect effects. Direct effect (from hh's consumption of gas) and indirect effects (from gas used as a production input)

*Indirect effects
import excel using "$xls_tool", sheet(IO) first clear 
drop sector_name VAT*

isid sector
mvencode sect_*, mv(0) override // make sure that none of the coefficient is missing
gen dp = -$fuel_sub if sector==4 //Price shock: Subsidy removal on Energy sector 
gen fixed = 1 if sector==4 // Government controls prices on energy sector 

costpush sect_*, fixed(fixed) price(dp) genptot(sub_gas_tot) genpind(sub_gas_ind) fix
keep sector sub_gas_ind
sum sub //PENDING: why indirect effect zero now?
isid sector
tempfile ind_effect_gas_PY
save `ind_effect_gas_PY', replace

*Direct effects
use "${data}\01.pre-simulation\Example_FiscalSim_gas_data.dta", clear
merge m:m hh_id using "${data}\01.pre-simulation\Example_FiscalSim_exp_data.dta" //merge with disposable income_adj for nowcasting [maybe I should have do m:1 if I collapse using data]

gen gas_sub_dir = gas_exp_SY*$fuel_sub*$nowcasting ///PENDING: Do nowcasting like Misha does for IndTaxes (using ratio between dispy_PY/dispy_SY)

*TOTAL: Direct and indirect effects
merge m:1 exp_type using `rates_PY', nogen assert(match) //Merge with COICOP- IO mapping [PENDING: To confirm with Misha]
merge m:1 sector using "${data}\02.intermediate\Gas_indirect_effects_data.dta", nogen assert(match using) keep(match) //Merge with Indirect effects

gen gas_sub_ind=-sub_gas_ind*gas_exp_SY*$nowcasting //PENDING: Do nowcasting like Misha does for IndTaxes (using ratio between dispy_PY/dispy_SY)

gen gas_sub_tot=gas_sub_dir+gas_sub_ind
keep hh_id  gas_sub_tot gas_sub_dir gas_sub_ind
label var gas_sub_tot "Total gas subsidy (direct and indirect effects), policy year"
label var gas_sub_dir "Total gas subsidy (direct effects), policy year"
label var gas_sub_ind "Total gas subsidy (indirect effects), policy year"
isid hh_id
collapse (sum) gas_sub_tot gas_sub_dir gas_sub_ind, by(hh_id) //HH-level dataset with Fuel subsidies estimations
save "${data}\02.intermediate\Example_FiscalSim_gas_subsidies_data.dta", replace	


*****ELECTRICITY SUBSIDIES*****

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

label variable electr_subs "Electricity subsidies, policy year"

keep hh_id ${indirect_subsidies} 
mvencode ${indirect_subsidies}, mv(0) override 

isid hh_id 
save "${data}\02.intermediate\Example_FiscalSim_indirect_subsidies_data.dta", replace
