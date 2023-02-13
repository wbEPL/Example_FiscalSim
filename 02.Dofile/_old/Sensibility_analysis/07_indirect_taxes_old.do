*Calculating indirect taxes for policy year

* VAT indirect effect:
import excel using "$xls_tool", sheet(IO) first clear 
drop sector_name

isid sector
mvencode VAT_rate_PY VAT_exempt_PY sect_*, mv(0) override // make sure that none of the coefficient is missing
gen dp = - VAT_rate_PY
gen fixed = 1 - VAT_exempt_PY // all except exempted sector
	assert dp == 0 if fixed == 0

costpush sect_*, fixed(fixed) price(dp) genptot(VAT_tot_eff_PY) genpind(VAT_ind_eff_PY) fix

keep sector VAT_ind_eff_PY
isid sector
tempfile ind_effect_VAT_PY
save `ind_effect_VAT_PY', replace

* Import rates (for direct effect)
import excel using "$xls_tool", sheet(VAT) first clear 
replace VAT_rate_PY = - VAT_rate_PY
keep exp_type sector VAT_rate_PY
isid exp_type
tempfile VAT_rates_PY
save `VAT_rates_PY', replace


use "${data}\02.intermediate\Example_FiscalSim_indirect_subs_data_long.dta", clear
	
merge m:1 exp_type using `VAT_rates_PY', nogen assert(match)
merge m:1 sector using `ind_effect_VAT_PY', nogen assert(match using) keep(match)

gen exp_gross_PY = exp_gross_subs_PY  * (1 - exp_form * VAT_rate_PY) * (1 - VAT_ind_eff_PY)

	if $SY_consistency_check == 1 { 
		merge 1:1 hh_id exp_type exp_form using "${data}\01.pre-simulation\Example_FiscalSim_exp_data_SY.dta", nogen assert(match) keepusing(exp_net_SY exp_gross_SY)
		assert abs(exp_net_SY  * (1 - exp_form * VAT_rate_PY) * (1 - VAT_ind_eff_PY) - exp_gross_SY) < 10 ^ (-10) if exp_type != 90 // this should be correct for the goods and services that are not subsidized
	}
	
gen VAT = exp_gross_subs_PY - exp_gross_PY

* if we would like to separate the direct and indirect effect this can be done:
gen VAT_dir = exp_gross_subs_PY  * exp_form * VAT_rate_PY
gen VAT_ind = VAT - VAT_dir // the direct and indirect effects are rather cumulative than additive, but need them to add up

foreach var in $indirect_taxes {
	replace `var' = `var' / hh_size // we need to convert to per capita terms since me merge with individual-level data
}

isid hh_id exp_type exp_form
keep hh_id exp_type exp_form sector ${indirect_taxes} exp_gross_PY 
save "${data}\02.intermediate\Example_FiscalSim_indirect_taxes_data_long.dta", replace

collapse (sum) ${indirect_taxes}, by(hh_id)
isid hh_id

foreach var in $indirect_taxes {
    assert `var' <= 10 ^ (-10) // they could be marginally positive due to rounding error
	replace `var' = 0 if `var' > 0
}

label variable VAT_dir "Value added tax (direct effect)"
label variable VAT_ind "Value added tax (indirect effect)"

keep hh_id ${indirect_taxes}
mvencode ${indirect_taxes}, mv(0) override  

isid hh_id 
save "${data}\02.intermediate\Example_FiscalSim_indirect_taxes_data.dta", replace
