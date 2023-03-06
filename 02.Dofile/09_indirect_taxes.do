*Calculating incidence of indirect taxes VAT for policy year

/* ------------------------------------
 ------------------------------------
1. Indirect effects of VAT on prices 
 ------------------------------------
--------------------------------------*/

/* ------------------------------------
1.A Expanding IO matrix 
 --------------------------------------*/

import excel using "$xls_tool", sheet(IO) first clear //load technical coefficients 

local list ""

des VAT_rate_PY VAT_exempt_PY VAT_exempt_share_PY sect_1-sect_16 , varlist
foreach v in `r(varlist)'  { 
	assert `v'!=. // No variable should be missing 
	local list "`list' `v'"
}

keep `list' sector // to be sure we are using the SY or PY variables 

// Consistency between policies 
assert  VAT_exempt_share_PY>0   if VAT_exempt_PY==1 // all exempted sector should have a exemption share 
assert  VAT_exempt_share_PY==0  if VAT_exempt_PY==0 // all non exempted sector should have either zero or missing  

tempfile io_original 
save `io_original', replace 

vatmat sect_1-sect_16, exempt(VAT_exempt_PY) pexempt(VAT_exempt_share_PY) sector(sector)

/* ------------------------------------
1.B  Estimating indirect effects of VAT
 --------------------------------------*/

*Fixed sectors 
local thefixed 4 // Energy and basic services completely regulated. Also int trade sectors 
gen fixed=0
foreach var of local thefixed {
	replace fixed=1  if  sector==`var'
	replace exempted=0 if fixed==1 //  sector is either exempted or fixed  fixed 
}

*VAT rates (sector level VAT)
merge m:1 sector using `io_original', assert(master matched) keepusing(VAT_rate_PY) nogen

ren VAT_rate_PY shock
*replace shock=-shock // To match code that aggregates income 
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

tempfile ind_effect_VAT_PY
save `ind_effect_VAT_PY'



/* ------------------------------------
 ------------------------------------
1.C Direct effects of VAT on prices 
 ------------------------------------
--------------------------------------*/

import excel using "$xls_tool", sheet(VAT) first clear 
keep exp_type sector VAT_rate_PY VAT_exempt_PY
isid exp_type
tempfile VAT_rates_PY
save `VAT_rates_PY', replace

/* ------------------------------------
 ------------------------------------
1.D Excise
 ------------------------------------
--------------------------------------*/

import excel using "$xls_tool", sheet(excises) first clear

keep exp_type excise_rate_PY
isid exp_type
tempfile Excises_PY
save `Excises_PY', replace


/* ------------------------------------
 ------------------------------------
2. Welfare impacts of VAT
 ------------------------------------
--------------------------------------*/

use "${data}\02.intermediate\Example_FiscalSim_indirect_subs_data_long.dta", clear // What if SY activated 


/* ------------------------------------
 ------------------------------------
2.A Welfare impacts of Excise
 ------------------------------------
--------------------------------------*/

merge m:1 exp_type using `Excises_PY', nogen assert(match master) keep(master match) 
replace excise_rate_PY=0 if excise_rate_PY==.
gen exp_gross_excise_PY = exp_gross_subs_PY  * (1 + excise_rate_PY) 
gen excises = exp_gross_subs_PY - exp_gross_excise_PY

/* ------------------------------------
 ------------------------------------
2.B Welfare impacts of VAT
 ------------------------------------
--------------------------------------*/

merge m:1 exp_type using `VAT_rates_PY', nogen assert(match)
ren VAT_exempt_PY exempted
merge m:1 sector exempted using `ind_effect_VAT_PY', nogen assert(match using) keep(match)

gen exp_gross_PY = exp_gross_excise_PY  * (1 + exp_form * VAT_rate_PY) * (1 + VAT_ind_eff_PY)
	if $SY_consistency_check == 1 { 
		merge 1:1 hh_id exp_type exp_form using "${data}\01.pre-simulation\Example_FiscalSim_exp_data_SY.dta", nogen assert(match) keepusing(exp_net_SY exp_gross_SY)
		merge 1:1 hh_id exp_type exp_form using "${data}\02.intermediate\Example_FiscalSim_exp_data_PY.dta", nogen assert(match) keepusing(exp_net_PY)
		// we check that gross expenditures for SY and PY are indetical for baseline with income-expenditure adjustment:
		assert abs(exp_gross_PY - exp_gross_SY * exp_net_PY / exp_net_SY) < 10 ^ (-10) if exp_net_SY !=0
		assert exp_gross_PY == exp_gross_SY if exp_net_SY == 0
	}

gen VAT = exp_gross_excise_PY - exp_gross_PY


* if we would like to separate the direct and indirect effect this can be done:
gen VAT_dir = - exp_gross_excise_PY  * exp_form * VAT_rate_PY
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
label variable excises "Excises"

keep hh_id ${indirect_taxes}
mvencode ${indirect_taxes}, mv(0) override  

isid hh_id 
save "${data}\02.intermediate\Example_FiscalSim_indirect_taxes_data.dta", replace