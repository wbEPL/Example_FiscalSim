*Nowcasting/updaring: converting the [gross] market income distribution from survey year (SY) to policy year (PY)

*Read parameters from excel and assign these parameters to global variables
import excel using "$xls_tool", sheet(uprating)  first clear 
	destring _all, replace
	ds 
	foreach var in `r(varlist)' {
		global `var'_uprating = `var'[1]
	}

* Nowcasting of weights (adjust for population growth)
use "${data}\01.pre-simulation\Example_FiscalSim_dem_data_SY.dta" , clear

* simple way to adjust for population growth
foreach var in ind_weight hh_weight {
	replace `var' = `var' * ${population_uprating}
}

* adjust poverty line to the cumulative CPI growth
foreach var in $povline {
	replace `var' = `var' * ${CPI_uprating}
}

isid hh_id p_id
save "${data}\02.intermediate\Example_FiscalSim_dem_data_PY.dta", replace


* Nowcasting of market incomes
use "${data}\01.pre-simulation\Example_FiscalSim_market_income_data_SY.dta", clear

* incomes may be uprated using different factors
foreach var in wage self_inc {
	replace `var' = `var' * ${wage_uprating}
}

foreach var in cap_income agri_inc priv_trans {
	replace `var' = `var' * ${other_income_uprating}
}

save "${data}\02.intermediate\Example_FiscalSim_market_income_data_PY.dta", replace