*Calculating the net expenditures for the survey year

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

des VAT_rate_SY VAT_exempt_SY VAT_exempt_share_SY sect_1-sect_16 , varlist
foreach v in `r(varlist)'  { 
	assert `v'!=. // No variable should be missing 
	local list "`list' `v'"
}
keep `list' sector // // to prevent not using variables from the policy year 

// Consistency between policies 
assert  VAT_exempt_share_SY>0   if VAT_exempt_SY==1 // all exempted sector should have a exemption share 
assert  VAT_exempt_share_SY==0  if VAT_exempt_SY==0 // all non exempted sector should have either zero or missing  

tempfile io_original_SY 
save `io_original_SY', replace 

vatmat sect_1-sect_16, exempt(VAT_exempt_SY) pexempt(VAT_exempt_share_SY) sector(sector)

/* ------------------------------------
1.B  Estimating indirect effects of VAT
 --------------------------------------*/

*Fixed sectors 
local thefixed 4 // Energy and basic services completely regulated. Also int trade sectors 
gen fixed=0
foreach var of local thefixed {
	replace fixed=1  if  sector==`var'
	replace exempted=0 if fixed==1 //  sector is either exempted or fixed 
}

*VAT rates (sector level VAT)
merge m:1 sector using `io_original_SY', assert(master matched) keepusing(VAT_rate_SY) nogen

ren VAT_rate_SY shock
replace shock=-shock // To match code that aggregates income 
replace shock=0  if exempted==1
replace shock=0  if shock==.

*No price control sectors 
gen cp=1-fixed

*vatable sectors 
gen vatable=1-fixed-exempted

*Indirect effects 
*gen indirect_effect_iva=0

vatpush sector_1-sector_31 , exempt(exempted) costpush(cp) shock(shock) vatable(vatable) gen(VAT_ind_eff_SY)

keep sector VAT_ind_eff_SY exempted

tempfile ind_effect_VAT_SY
save `ind_effect_VAT_SY'


/* ------------------------------------
 ------------------------------------
2. Direct effects of VAT on prices 
 ------------------------------------
--------------------------------------*/

import excel using "$xls_tool", sheet(VAT) first clear
 
replace VAT_rate_SY = - VAT_rate_SY
keep exp_type sector VAT_rate_SY VAT_exempt_SY
isid exp_type
tempfile VAT_rates_SY
save `VAT_rates_SY', replace

/* ------------------------------------
 ------------------------------------
3. Subsidy Indirect effects on prices 
 ------------------------------------
--------------------------------------*/

*Fuel indirect effects
import excel using "$xls_tool", sheet(IO) first clear 
drop sector_name VAT*

isid sector
mvencode sect_*, mv(0) override // make sure that none of the coefficient is missing
gen dp = 0.1 * 0.3 if sector == 4 //Price shock: Subsidy removal on Energy sector. We assume that share of gas in the energy sector is 30%. The size of subsidy is 10%
	replace dp = 0 if mi(dp)
gen fixed = (dp != 0) // Government controls prices on energy sector 
	assert dp == 0 if fixed == 0
	
costpush sect_*, fixed(fixed) price(dp) genptot(gas_sub_tot_eff_SY) genpind(gas_sub_ind_eff_SY) fix
keep sector gas_sub_ind_eff_SY

isid sector
tempfile ind_effect_gas_SY
save `ind_effect_gas_SY', replace



/* ------------------------------------
 ------------------------------------
4. Expenditures net from VAT 
 ------------------------------------
--------------------------------------*/

*Calculate net expenditure pre-VAT
use "${data}/Example_FiscalSim_exp_data_raw.dta", clear 

gen int exp_form = 2 - place_purchase
rename exp_value exp_gross_SY

	
merge m:1 exp_type using `VAT_rates_SY', nogen assert(match) // notice here we merge!! product level exemption 
ren VAT_exempt_SY exempted
replace VAT_rate_SY=0 if exempted==1 // this should not be needed 

merge m:1 sector exempted using `ind_effect_VAT_SY', nogen  assert(match using) keep(match)

gen exp_net_SY = exp_gross_SY  / ( (1 - exp_form * VAT_rate_SY) * (1 - VAT_ind_eff_SY) )

/* ------------------------------------
 ------------------------------------
5. Expenditures net from Subsidies
 ------------------------------------
--------------------------------------*/

*PREPARE PRE-FISCAL EXPENDITURES FOR INDIRECT SUBSIDIES 
*Calculate net expenditure (before fuel subsidy)
merge m:1 sector using `ind_effect_gas_SY', nogen assert(match using) keep(match)

//Net expenditure (before VAT and before subsidy)
replace exp_net_SY = exp_net_SY / (1 - gas_sub_ind_eff_SY) // indirect effect for all goods and services
replace exp_net_SY = exp_net_SY / (1 - 0.1)  if exp_type == 90 //direct effect for gas.

isid hh_id exp_type exp_form
keep hh_id exp_type exp_form exp_net_SY exp_gross_SY sector

save "${data}\01.pre-simulation\Example_FiscalSim_exp_data_SY.dta", replace

*****Electricity subsidy
* Imputing electricity consumption based on a block tariff structure
* we assume that the industrial consumers pay full electricity tariff, that is why there is no indirect effect.

keep if exp_type == 88 // electricity expenditures

* electricity expenditures are not subject to VAT (in our example, it might be different in your country), so we can use any of the net/gross expenditures to impute the electricity consumption
gen electr_exp = exp_net_SY / 12 // convert annual expenditures to monthly (norms are in monthly terms)
keep hh_id electr_exp 

* Block tariff are similar to progresisve tax system. Here we restore the natural quantity in kWh from the expenditures in monetary terms

gen electr_cons = 0

* tariff by blocks
global electr_tariff_0 = 0
global electr_tariff_1 = 2
global electr_tariff_2 = 4
global electr_tariff_3 = 6
global electr_tariff_4 = 8 

* electric cutoffs are defined in terms of quatity (kWh)
global electr_cutoff_0 = 0
global electr_cutoff_1 = 100
global electr_cutoff_2 = 200
global electr_cutoff_3 = 300
global electr_cutoff_4 = 10 ^ 6 // very large number

local lower = 0
local upper = 0

forvalues i = 1 / 4 {
	local j = `i' - 1
	
	local lower = `upper' // this threshold are defined in terms of expenditures
	local upper `lower' + (${electr_cutoff_`i'} - ${electr_cutoff_`j'}) * ${electr_tariff_`i'} // this threshold are defined in terms of expenditures
	
		gen electr_cons_`i' = 0 if inrange(electr_exp, . , `lower')
		replace electr_cons_`i' = (electr_exp  - `lower') / ${electr_tariff_`i'} if inrange(electr_exp, `lower',  `upper')
		replace electr_cons_`i' = (${electr_cutoff_`i'} - ${electr_cutoff_`j'}) if inrange(electr_exp, `upper', . )
		
		replace electr_cons = electr_cons + electr_cons_`i'
		drop electr_cons_`i'
	}

label var electr_cons "Electricity consumption, kHw per month"	
rename electr_exp electr_exp_SY

*keep hh_id electr_cons
isid hh_id
save "${data}\01.pre-simulation\Example_FiscalSim_electr_data.dta", replace	