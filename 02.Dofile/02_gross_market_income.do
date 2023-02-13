* Calculating direct taxes and gross income for the survey year (SY) 
* Order of taxes matters!


use "${data}\01.pre-simulation\Example_FiscalSim_dem_inc_data.dta" , clear

gen int tax_payer = (formal_wage == 1 | formal_self  == 1 ) // indication of being formal and paying taxes

* 1. Personal Income Tax (PIT)
global PIT_base_list wage self_inc  // we include here only components of market income that are subject to PIT

gen PIT_base_net = 0
	foreach var in $PIT_base_list {
		replace PIT_base_net = PIT_base_net + `var'_net
	}

gen PIT_base_deduct = max(0, PIT_base_net - 2000) // personal exemption for PIT purpose
	gen deduct = PIT_base_net - PIT_base_deduct
	assert deduct >= 0 & deduct <= 2000

	
dirtax PIT_base_deduct, netinput rates(0 5 10 15 20) tholds(0 10000 20000 30000 50000) gen(PIT_base_gross_deduct)  //Recover gross wage from net wage	
	gen PIT_0 = -1 * (PIT_base_gross_deduct - PIT_base_deduct)

gen PIT_base_gross = PIT_base_gross_deduct + deduct 

* we restore gross (after PIT) incomes from net proportionally to their contribution to PIT base
foreach var in $PIT_base_list {
	gen `var' = `var'_net * PIT_base_gross / PIT_base_net
}    

* 2 Social Contributions (SIC): SIC rate in baseline is 20%    
replace wage = wage  / (1 - 0.2) // restore gross wage out of net (of SIC)

foreach var in $PIT_base_list {
    replace `var' = `var'_net if tax_payer == 0 // no taxes for informal
}
	

* Agricultural and oter market incomes:
foreach var in cap_income agri_inc priv_trans {
    gen `var' = `var'_hh / hh_size
}

* Calculating the net original market incomes ( to be used later)
egen net_market_income_orig = rowtotal(wage_net self_inc_net cap_income agri_inc priv_trans)

label variable wage "Wage/salary, gross"
label variable self_inc "Self-employed income, gross"
label variable cap_income "Capital income, gross"
label variable agri_inc "Agricultural income, gross"
label variable priv_trans "Private transfers, gross"
label variable net_market_income_orig "Net market income for baseline scenario"

keep hh_id p_id ${market_income} tax_payer net_market_income_orig //PIT_0 SIC_0
mvencode ${market_income} tax_payer net_market_income_orig, mv(0) override 

isid hh_id p_id

save "${data}\01.pre-simulation\Example_FiscalSim_market_income_data_SY.dta", replace