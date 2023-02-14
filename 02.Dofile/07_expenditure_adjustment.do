* total exp adjustment to make consistent with income: `combined approach' – identify hh, where incomes are lower than some reasonable level of dissaving (i.e. incomes are less than 50% of expenditures) and normalize (scale down) the expenditures for those. For these hh we assume 1:1 income to expenditure path through, while for the rest of observations, we keep the original ratio between incomes and expenditures we assume the path through from income to expenditures to equal the hh-specific average propencity to consume (a.p.c.)

use "${data}\02.intermediate\Example_FiscalSim_market_income_data_PY.dta", clear
merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_dem_data_PY.dta", nogen assert(match) keepusing(hh_size)
merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_SSC_direct_taxes_data.dta", nogen assert(match)
merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_pensions_direct_transfers_data.dta", nogen assert(match)

egen disposable_income_orig = rowtotal(net_market_income_orig pens_trans_orig)
egen disposable_income = rowtotal(${market_income} ${SSC} ${direct_taxes} ${pensions} ${direct_transfers})

recast int hh_size

	if $SY_consistency_check == 1 { 
	    assert abs(disposable_income - disposable_income_orig) < 10 ^ (-9)
	}
	assert disposable_income >= 0

collapse (sum) disposable_income_orig disposable_income (mean) hh_size, by(hh_id)

isid hh_id

merge 1:m hh_id using "${data}\01.pre-simulation\Example_FiscalSim_exp_data_SY.dta", nogen assert(match)

bysort hh_id: egen total_exp_SY = total(exp_gross_SY)
	

gen exp_net_adj_SY = exp_net_SY
	replace exp_net_adj_SY = exp_net_SY / total_exp_SY * disposable_income_orig if total_exp_SY > 2 * disposable_income_orig // We adjust the net expenditures, but the gross income should be consistent with disapobale
	bysort hh_id: egen total_exp_net_adj_SY = total(exp_net_adj_SY)
	
gen exp_net_PY = exp_net_adj_SY / disposable_income_orig * disposable_income // normalization to diposable income to adjust for income-exp link
	replace exp_net_PY = 0 if disposable_income_orig == 0
	assert !mi(exp_net_PY)

keep hh_id exp_type exp_form sector exp_net_PY hh_size
mvencode exp_net_PY, mv(0) override  

isid hh_id exp_type exp_form
	
save "${data}\02.intermediate\Example_FiscalSim_exp_data_PY.dta", replace
