*Calculating direct benefits and pensions for the policy year

* Transfers
import excel using "$xls_tool", sheet(transfers)  first clear //PIT
	ds 
	foreach var in `r(varlist)' {
		global `var' = `var'[1]	
	}



use "${data}\01.pre-simulation\Example_FiscalSim_dem_inc_data.dta" , clear
merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_market_income_data_PY.dta", nogen assert(match) 
merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_SSC_direct_taxes_data.dta", nogen assert(match) 

egen pens_other_trans_orig = rowtotal(${pensions} soc_pens other_ben)

* Uprating to the policy year those programs that are not simulated 
foreach var in $pensions soc_pens unem_ben other_ben {
	replace `var' = `var' * ${pensions_uprating}
}

* child benefits
gen child = (age <= 16) // define children
bysort hh_id: egen n_child = total(child) // count number of children in the household
gen n_elig_child = min(n_child, ${max_child_elig}) //restrict number of children using the information from the parameter sheet
gen child_ben = ${child_benefit} * n_elig_child * 12 // Calculate the amount of the benefit. Do not forget to convert monthly paramenetrs to annual values if relevant

gen n_elig_child_orig = min(n_child, 3) 
gen child_ben_orig = 100 * n_elig_child_orig * 12 // We calculate the original amount of benefits for the baseline separately


* simulating increase in enrollment in unemployemnt benefits
gen unem_potent = (unem_ben == 0 & wage == 0 & self_inc == 0 & inrange(age,17,60)) // we define who are potential recepient of unemplyment benefits
gen unem_ben_orig = unem_ben

su unem_ben [aw = ind_weight] if unem_ben > 0
	global unem_ben = r(mean) // we will impute average value of unemployment ot the new recipients

gen unem_weight = ind_weight
	replace unem_weight = 0 if unem_ben > 0 // we exclude those who are already in the program
		
	set seed 1000
	gen rank = runiform() if unem_potent == 1 // instead of random allocation, we may use predicted probabilities if there is information
	
	gen all = 1
	bysort all (rank hh_id p_id): gen cumulative_unem_weight = sum(unem_weight)	  
	replace unem_ben = ${unem_ben} if cumulative_unem_weight <= ${unempl_coverage_increase} & unem_ben == 0
	replace unem_ben_orig = ${unem_ben} if cumulative_unem_weight <= 1000  & unem_ben_orig == 0 // this is for baseline scenario
	
* GMI program (may depend on other programs)
gen GMI = 0
egen pre_GMI_income = rowtotal(${market_income} ${SSC} ${direct_taxes} ${pensions} ${direct_transfers}) // include only those that are used to for GMI administrative income (GMI is put as zero for time-being)
bysort hh_id: egen pre_GMI_income_hh = total(pre_GMI_income) 
gen pre_GMI_income_pc = pre_GMI_income_hh / hh_size
replace GMI = max(0, ${GMI_threshold} * 12 - pre_GMI_income_pc) // This programs cover the income upto the threshold

* GMI program for the basline
egen pre_GMI_income_orig = rowtotal(net_market_income_orig pens_other_trans_orig unem_ben_orig child_ben_orig) 
bysort hh_id: egen pre_GMI_income_hh_orig = total(pre_GMI_income_orig) // count number of children in the household
gen pre_GMI_income_pc_orig = pre_GMI_income_hh_orig / hh_size
gen  GMI_orig = max(0, 1200 * 12 - pre_GMI_income_pc_orig) // This programs cover the income upto the threshold

if $SY_consistency_check == 1 {
	foreach var in child_ben unem_ben GMI {
	    assert abs(`var' - `var'_orig) < 10 ^ (-10)
	}
}		

egen pens_trans_orig = rowtotal(child_ben_orig unem_ben_orig GMI_orig pens_other_trans_orig)

label variable lab_pens "Labor pensions"
label variable soc_pens "Social pensions"
label variable unem_ben "Unemployment benefits"
label variable child_ben "Child benefits"
label variable GMI "Guaranteed minimum income benefits"
label variable other_ben "Other benefits"

label variable pens_trans_orig "Total pensions and transfesr for baseline scenario"

keep hh_id p_id ${pensions} ${direct_transfers} pens_trans_orig
mvencode ${pensions} ${direct_transfers} pens_trans_orig, mv(0) override 

isid hh_id p_id

save "${data}\02.intermediate\Example_FiscalSim_pensions_direct_transfers_data.dta", replace

