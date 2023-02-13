*Calculating indirect taxes for policy year
* VAT indirect effect:



/* ------------------------------------
1. Indirect effects 
--------------------------------------*/
/* ------------------------------------
1.A Expanding IO matrix 
 --------------------------------------*/

import excel using "$xls_tool", sheet(IO) first clear //load technical coefficients 
mvencode VAT_rate_PY VAT_exempt_PY VAT_exempt_share_PY sect_*, mv(0) override // It will replace with zero all missing coefficients, so make sure to have as non missing all sector with non-zero VAT
replace VAT_exempt_share_PY=0 if VAT_exempt_PY==0 // If a sector has not exemptions the exemption share should be missing 

tempfile io_original 
save `io_original', replace 


vatmat sect_1-sect_16, exempt(VAT_exempt_PY) pexempt(VAT_exempt_share_PY) sector(sector)

/* ------------------------------------
1.B  Defining components of the VAT push 
 --------------------------------------*/

*Fixed sectors 
local thefixed 4 // Energy and basic services completely regulated. Also int trade sectors 
gen fixed=0
foreach var of local thefixed {
	replace fixed=1  if  sector==`var'
	replace exempted=0 if fixed==1 // replace You are either exempted or fixed 
}

*VAT rates (sector level VAT)
merge m:1 sector using `io_original', assert(master matched) keepusing(VAT_rate_PY) nogen

ren VAT_rate_PY shock
replace shock=-shock // To match code that aggregates income 
replace shock=0  if exempted==1
replace shock=0  if shock==.

*No price control sectors 
gen cp=1-fixed

*vatable sectors 
gen vatable=1-fixed-exempted

*Indirect effects 
*gen indirect_effect_iva=0

vatpush sector_1-sector_32 , exempt(exempted) costpush(cp) shock(shock) vatable(vatable) gen(VAT_ind_eff_PY)

keep sector VAT_ind_eff_PY exempted

tempfile ind_effect_PY
save `ind_effect_PY'



/* ------------------------------------
2. Direct effects 
--------------------------------------*/

import excel using "$xls_tool", sheet(VAT) first clear 
replace VAT_rate_PY = - VAT_rate_PY
keep exp_type sector VAT_rate_PY VAT_exempt_PY
isid exp_type
tempfile rates_PY
save `rates_PY', replace


/* ------------------------------------
3. Computing effects of taxes and transfers 
--------------------------------------*/
use "${data}\02.intermediate\Example_FiscalSim_indirect_subs_data_long.dta", clear // What if SY activated 
	
merge m:1 exp_type using `rates_PY', nogen assert(match)
ren VAT_exempt_PY exempted
merge m:1 sector exempted using `ind_effect_PY', nogen assert(match using) keep(match)

gen exp_gross_PY = exp_gross_subs_PY  * (1 - exp_form * VAT_rate_PY) * (1 - VAT_ind_eff_PY)

	if $SY_consistency_check == 1 { 
		merge 1:1 hh_id exp_type exp_form using "${data}\01.pre-simulation\Example_FiscalSim_exp_data_SY.dta", nogen assert(match) keepusing(exp_net_SY exp_gross_SY)
		assert abs(exp_net_SY  * (1 - exp_form * VAT_rate_PY) * (1 - VAT_ind_eff_PY) - exp_gross_SY) < 10 ^ (-10) if exp_type != 90 // this should be correct for the goods and services that are not subsidized
	}
	
gen VAT = exp_gross_subs_PY - exp_gross_PY


* if we would like to separate the direct and indirect effect this can be done:
gen VAT_dir = exp_gross_subs_PY  * exp_form * VAT_rate_PY
gen VAT_ind = VAT - VAT_dir // the direct and indirect effects are rather cumulative than additive, recasting indirect effects in this ways assures additivity

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