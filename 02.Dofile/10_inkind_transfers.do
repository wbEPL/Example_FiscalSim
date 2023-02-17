* Calculating inkind benefits for policy year
import excel using "$xls_tool", sheet(inkind)  first clear 
	destring _all, replace
	ds 
	foreach var in `r(varlist)' {
		global `var' = `var'[1]
	}

use "${data}\01.pre-simulation\Example_FiscalSim_exp_data_SY.dta", clear
decode exp_type, generate(exp_name)

keep if exp_type == 83 | exp_type == 84 // expenditures for education

keep hh_id  exp_type exp_net_SY
reshape wide exp_net_SY, i(hh_id) j(exp_type)
merge 1:m hh_id using "${data}\01.pre-simulation\Example_FiscalSim_dem_inc_data.dta", nogen assert(match using) keepusing(p_id ind_weight study med_ins hospital_days)
mvencode   exp_net_SY*  , mv(0) override 

*education status 
gen stud_prim = (study == 1)
gen stud_sec = (study == 2)
gen stud_post_sec = (study == 3) & exp_net_SY83 == 0 // we do not have question for paid eductions, so we have to rely on the expenditure info. 
gen stud_tert = inrange(study,4,5) & exp_net_SY84 == 0 // we assume that if hh has education exapnditure, than noone in the hh is on budget funding

foreach type in prim sec post_sec tert {
	
	su stud_`type' [aw = ind_weight]
	global stud_tot_`type' = r(sum)
	
	gen educ_`type' = stud_`type' / ${stud_tot_`type'} * ${educ_exp_`type'} * ${scale_factor}
}

* HEALTH (combined approach)
gen med_out = med_ins == 1 // indicator of having insurance
gen med_in = hospital_days if (med_ins == 1 ) // number of days in hospital

foreach type in in out {
	
	su med_`type' [aw = ind_weight]
	global med_tot_`type' = r(sum)
	
	gen health_`type' = med_`type' / ${med_tot_`type'} * ${health_exp_`type'} * ${scale_factor}
}

label variable health_in "In-hospital in-kind medical benefits"
label variable health_out "Out-hospital in-kind medical benefits"

label variable educ_prim "Primary in-kind education benefits"
label variable educ_sec "Secondary in-kind education benefits"
label variable educ_tert "Tertiary in-kind education benefits"

keep hh_id p_id ${health} ${education} 
mvencode ${health} ${education}  , mv(0) override 

isid hh_id p_id
save "${data}\02.intermediate\Example_FiscalSim_inkind_transefrs_data.dta", replace
