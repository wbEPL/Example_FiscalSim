********************************************************************************
* INCOME CONCEPTS: merging together
********************************************************************************
clear
use "${data}\02.intermediate\Example_FiscalSim_dem_data_PY.dta"

merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_market_income_data_PY.dta", nogen

merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_SSC_direct_taxes_data.dta", nogen

merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_pensions_direct_transfers_data.dta", nogen

merge m:1 hh_id using "${data}\02.intermediate\Example_FiscalSim_indirect_taxes_data.dta", nogen

merge m:1 hh_id using "${data}\02.intermediate\Example_FiscalSim_indirect_subsidies_data.dta", nogen

merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_inkind_transefrs_data.dta", nogen

global program_list 
foreach aggregate in market_income $comp_list {
	foreach var in $`aggregate' {
		mvencode  `var', mv(0) override 
		global program_list ${program_list} `var'
	}
	egen `aggregate' = rowtotal(${`aggregate'}) 
}

gen net_market_income = market_income + direct_taxes + SSC

gen market_pens_income = market_income + pensions + SSC

gen gross_income = market_income + direct_transfers + pensions

gen disposable_income = market_income + direct_transfers + pensions + direct_taxes + SSC

assert abs(disposable_income - (market_pens_income + direct_transfers + direct_taxes))  < 10^(-9)
assert abs(disposable_income - (net_market_income + direct_transfers + pensions)) < 10^(-9)
assert disposable_income == gross_income + direct_taxes + SSC

gen consumable_income = disposable_income + indirect_subsidies + indirect_taxes

gen final_income = consumable_income + health + education

*converting individual-level data to average per capita values
foreach var in $income_list {
    rename `var' `var'_ind
	bysort hh_id: egen `var'_hh=total(`var'_ind)
	gen `var' = `var'_hh / hh_size
	assert  `var' >= 0
	drop `var'_ind `var'_hh
}

label variable market_income "Market income"

label variable SSC "Social contributions"
label variable direct_taxes "All direct taxes other than social contributions"

label variable pensions "Contributory pensions"
label variable direct_transfers "Direct transfers and non-contributory pensions"

label variable indirect_taxes "Indirect taxes"
label variable indirect_subsidies "Indirect subsidies"

label variable health "In-kind health benefits"
label variable education "In-kind education benefits"

label variable net_market_income "Net market income"
label variable market_pens_income "Market income plus pensions"
label variable gross_income "Gross income"
label variable disposable_income "Disposable income"
label variable consumable_income "Consumable income"
label variable final_income "Final income"

isid hh_id p_id
keep  hh_id p_id ${dem_list} ${income_list} ${comp_list} ${program_list}
order hh_id p_id ${dem_list} ${income_list} ${comp_list} ${program_list}

save "${data}\03.simulation-results\Example_FiscalSim_output_data.dta", replace
