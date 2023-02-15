*Calculating indirect taxes for policy year
* VAT indirect effect:
clear
matrix drop _all 

run "C:\Users\WB419055/OneDrive - WBG/Example_FiscalSim\02.Dofile\ados\vatmat.ado"


local n_sect 16
	
/*-------------------------------------------------------------------------------------
Load IO matrix and expanding IO sectors 
-------------------------------------------------------------------------------------*/	

import excel using "$xls_tool", sheet(IO) first clear //load technical coefficients 
mvencode VAT_rate_PY VAT_exempt_PY VAT_exempt_share_PY sect_*, mv(0) override // It will replace with zero all missing coefficients, so make sure to have as non missing all sector with non-zero VAT
replace VAT_exempt_share_PY=0 if VAT_exempt_PY==0 // If a sector has not exemptions the exemption share should be missing 

tempfile io_original 
save `io_original', replace 


vatmat sect_1-sect_16, exempt(VAT_exempt_PY) pexempt(VAT_exempt_share_PY) sector(sector)




exit 





























*-------------------------------------------------------------------------------                 
* Step 1 Define three lists: exempted, mixed, and non-mixed sectors 
*** Note: a mixed sector is a IO sector that has both exempted and non exempted products 
*-------------------------------------------------------------------------------
	
	// Number of sectors 
	
	// List of exempted products 
	levelsof sector if VAT_exempt_PY!=0 , local(excluded)
	dis "`excluded'"
	
	// List of IO sectors with mixed product 
	levelsof sector if VAT_exempt_PY==1 & VAT_exempt_share_PY>0 & VAT_exempt_share_PY<1 ,  local(noncollsecs)     
	
	dis "`noncollsecs'"  // expanded columns 
	
	
	levelsof sector if VAT_exempt_share_PY==0 | VAT_exempt_share_PY==1,  local(collsecs)
	dis "`collsecs'"    // columns that do not expand 
	
	local all_sects "`noncollsecs' `collsecs'" // 
	
	
	*Test that both noncollsecs and collsecs had all sectors
	foreach sectors of numlist 1/`n_sect' {
		
		local  macname : list sectors in all_sects
		dis "sectors `sectors' is in the list  (`macname') "
		
		if (`macname')==0 {  // if sector is not in mixed is not in noncollsecs) 
			dis as error "error `sectors' sector is missing"
			exit  
			
		}
	
	}
	


levelsof sector , local (aux_io_list)
foreach s of local aux_io_list  {
	local io_list "`io_list' sect_`s'"
}

/*
*Notice sectors should be organized
	foreach s of local aux_io_list  {
		local io_list "`io_list' sect_`s'"
	}
	order sector `io_list'

*Be sure you are not loading missing observation
assert  missing(sector)==0

*Notice it should be unique values by sector 
isid sector
*/ 


/* ------------------------------------
	First we extended all the sectors 
 --------------------------------------*/

mata 
	
	
	exempt_i=J(`n_sect'*2,1,0) // null vector of `n_sect' X 2
	
	ve=st_data(.,"VAT_exempt_share_PY",.)
	nve=J(`n_sect',1,1)-ve

	io=st_data(., "sect_1-sect_`n_sect'",.) // Store the IO in Mata: (.) returns in stata all observations,  for  sect_1, sect_2, ..., sect_14, sect_15, sect_16, (.) no conditions on the obs or rows that should be excluded

	extended=J(`n_sect'*2,`n_sect'*2,0) // null square matrix of (`n_sect' X 2) 
	
	for(n=1; n<=`n_sect'; n++)  {
	
		jj=2*n-1 // odd numbers 
		kk=jj+1  // paid numbers 
	
		for(i=1; i<=`n_sect'; i++)  {
			j=2*i-1 // odds
			k=j+1   // pairs 
			
			//extended[jj::kk,j::k]=J(2,2,io[n,i])/2
			 //take original coefficient by IO and split it by nve or ve 
			extended[jj::jj,j::k]=J(1,2,io[n,i]*ve[n,1])
			extended[kk::kk,j::k]=J(1,2,io[n,i]*nve[n,1])
		
		}
		
		exempt_i[jj,1]=1
		exempt_i[kk,1]=0
	}
	
	extended=extended,exempt_i
	st_matrix("extended",extended) // saving the stata matrix into stata

end

clear 
svmat extended // from mata to stata : extended is 70X (35+70)


rename extended* sector_* // index extended sectors 
gen sector=ceil(_n/2) // label each sector with same name (ceiling name)
order sector sector_*
local last_row = `n_sect'*2+1
rename sector_`last_row' exempted


/* ------------------------------------
	Limit matrix expansion to sectors with exemptions 
 --------------------------------------*/


*Limiting rows 
	gen aux=.
	
	foreach ii of local  collsecs {
		replace  aux=1    if  sector==`ii'       // sectors that collapse 
	}
	replace aux=0 if aux==.

	preserve 
	*saving sectors who will expand 
		keep if aux==0

		tempfile nocollapse
		save `nocollapse'

	restore 
	
	*Collapsing sectors who will not expand (could be non exempted or exempted 100%)
	keep if aux==1    // sectors that will not expand
	
	collapse (sum) sector_*  , by(sector)
	
	*Adding sector who expanded 
	append using `nocollapse' //
	sort sector exempted 

	drop aux 
	

*Limiting columns 
foreach var of local collsecs { // collsecs is a column that do not expand so any pair column from collsecs will be eliminated 
local ii =  `var'*2
drop sector_`ii'

}

/* ------------------------------------
	Adding shock, VAT, exempted sectors 
 --------------------------------------*/

*Renaming sectors 
merge m:1 sector using `io_original', assert(master matched) keepusing(VAT_exempt_PY) nogen
replace exempted=VAT_exempt_PY if exempted==.
drop VAT_exempt_PY


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
replace shock=0  if exempted==1
replace shock=0  if shock==.

*No price control sectors 
gen cp=1-fixed

*vatable sectors 
gen vatable=1-fixed-exempted

*Indirect effects 
gen indirect_effect_iva=0

//Creating matrix elements for indirect 
mata : st_view(YY=., ., "indirect_effect_iva",.)
mata: XX=st_data(., "sector_1-sector_32",.)
mata: cp=st_data(., "cp",.)'
mata: shock=st_data(., "shock",.)'
mata: vatable=st_data(., "vatable",.)'		
mata: exempt=st_data(., "exempted",.)'


*costpush sector_1-sector_69 ,fixed(fixed) priceshock(shock) genptot(ptot_ivashock) genpind(pind_ivashock) 


mata:  YY[.,.]=indirect(XX,cp,shock,vatable,exempt)'

replace indirect_effect_iva=0   if cp==0

keep sector indirect_effect_iva exempted

tempfile indirect
save `indirect'


exit 





/* ------------------------------------
	Reduce the matrix 
 --------------------------------------*/

	svmat extended 
	mat list extended



exit 
	
**--------------------- test checking specific matrix cells 
	clear
	matrix drop _all 
	import excel using "$xls_tool", sheet(IO) first clear 
	keep sect_1-sect_3
	keep in 1/3
	
	
	mata: io=st_data(., "sect_1-sect_3",.) // Store the IO 
	
	mata: extended=J(9,9,0) // null square matrix of (`n_sect' X 2) 
	
	*first loop
	//jj: 1, kk: 2, j: 1 k: 2, n:1 i:1
	
	mata: extended[1::3,1::3]=J(3,3,io[1,1])/2 // filling up from row 1:3 to colum 1:3 with a 3 by 3 matrix fill with a constant which is the coefficient 
	
	mata: st_matrix("extended",extended) 
	
	mata: st_matrix("io",io) 

	mat list extended
	mat list io
	
	
	forvalues n = 1(1)32 {
	
	local jj=2*`n'-1 // before the last observation 
	local kk=`jj'+1  // last observation 
	
	dis "JJ is `jj'"
	dis "KK is  `kk'"
	
	extended[jj::kk,j::k]=J(2,2,io[n,i])/2
		
		for(i=1; i<=`n_sect'; i++)  {
			j=2*i-1 // odds
			k=j+1   // pairs 
			
			extended[jj::kk,j::k]=J(2,2,io[n,i])/2
		}
	}
	






	
**---------------------










// Third we keep the sectors that collapse and then append the sectors that do not collapse 

keep if aux==1    

collapse (sum) sector_1-sector_70 if aux==1 , by(sector)

append using `nocollapse'

sort sector


// Fourth and finnaly we remove columns of the sectors that do not collapse 

drop aux

foreach var of local collsecs {

local ii =  `var'*2

drop sector_`ii'

}

//Now the matrix is a square matrix that only expanded sectors that include both exempted and non-exempted products

// we identify excluded sectors 

gen exempted=0

foreach var of local excluded {

replace exempted=1   if   sector==`var'

}

bys sector:  gen aux_size=_n
replace exempted=0  if aux_size==2
drop aux_size

}


































































*Define the shock 
gen double dp = - VAT_rate_PY

*Define the fixed sectors
gen fixed = 1 - VAT_exempt_PY // sectors whose price is not affected by input-output linkages of final goods oods produced locally (e.g., international prices, regulated)
	assert dp == 0 if fixed == 0









// Store the IO in Mata 

mata: io=st_data(., "C1-C35",.) // (.) returns in stata all observations,  for  variables between (C1-C35), (.) no conditions on the observations that should be excluded

// Matrix of ceros 

mata: extended=J(35*2,35*2,0)   // square matrix of 35X2 filled of zeros


// First we extended all the sectors 
	mata: 
	for(n=1; n<=35; n++)  {
	
		jj=2*n-1
		kk=jj+1
	
		for(i=1; i<=35; i++)  {
		j=2*i-1
		k=j+1
		
		extended[jj::kk,j::k]=J(2,2,io[n,i])/2
		
		}
	}
	
	st_matrix("extended",extended)
	
	end

clear

svmat extended // from mata to stata : extended is 70X (35+70)

rename extended* sector_* // index extended sectors 

gen sector=ceil(_n/2) // rename sectors with ceiling name

// Second we collapse sectors that do not extend 


gen aux=.

foreach ii of local  collsecs {
	replace  aux=1    if  sector==`ii'       // sectors that collapse 
}

replace aux=0 if aux==.

preserve 

keep if aux==0

tempfile nocollapse

save `nocollapse'

restore 

// Third we keep the sectors that collapse and then append the sectors that do not collapse 

keep if aux==1    

collapse (sum) sector_1-sector_70 if aux==1 , by(sector)

append using `nocollapse'

sort sector


// Fourth and finnaly we remove columns of the sectors that do not collapse 

drop aux

foreach var of local collsecs {

local ii =  `var'*2

drop sector_`ii'

}

//Now the matrix is a square matrix that only expanded sectors that include both exempted and non-exempted products

// we identify excluded sectors 

gen exempted=0

foreach var of local excluded {

replace exempted=1   if   sector==`var'

}

bys sector:  gen aux_size=_n
replace exempted=0  if aux_size==2
drop aux_size

}







































* Import rates (for direct effect)
import excel using "$xls_tool", sheet(VAT) first clear 
replace VAT_rate_PY = - VAT_rate_PY
keep exp_type sector VAT_rate_PY
isid exp_type
tempfile rates_PY
save `rates_PY', replace


use "${data}\02.intermediate\Example_FiscalSim_market_income_data_PY.dta", clear
merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_dem_data_PY.dta", nogen assert(match) keepusing(hh_size)
merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_SSC_direct_taxes_data.dta", nogen assert(match)
merge 1:1 hh_id p_id using "${data}\02.intermediate\Example_FiscalSim_pensions_direct_transfers_data.dta", nogen assert(match)

egen double disposable_income_orig = rowtotal(net_market_income_orig pens_trans_orig)
egen double disposable_income = rowtotal(${market_income} ${SSC} ${direct_taxes} ${pensions} ${direct_transfers})

*su disposable_income_orig net_market_income_orig pens_trans_orig disposable_income  ${market_income} ${SSC} ${direct_taxes} ${pensions} ${direct_transfers}

recast int hh_size

	if $SY_consistency_check == 1 { 
	    assert abs(disposable_income - disposable_income_orig) < 10 ^ (-9)
	}
	assert disposable_income >= 0

collapse (sum) disposable_income_orig disposable_income (mean) hh_size, by(hh_id)

isid hh_id

merge 1:m hh_id using "${data}\01.pre-simulation\Example_FiscalSim_exp_data.dta", nogen assert(match)

bysort hh_id: egen double total_exp_SY = total(exp_gross_SY)
	
* total exp adjustment to make consistent with income: ‘combined approach’ – identify hh, where incomes are lower than some reasonable level of dissaving (i.e. incomes are less than 50% of expenditures) and normalize (scale down) the expenditures for those. For these hh we assume 1:1 income to expenditure path through, while for the rest of observations, we keep the original ratio between incomes and expenditures we assume the path through from income to expenditures to equal the hh-specific apc.
gen double exp_net_adj_SY = exp_net_SY
	replace exp_net_adj_SY = exp_net_SY / total_exp_SY * disposable_income_orig if total_exp_SY > 2 * disposable_income_orig // We adjust the net expenditures, but the gross income should be consistent with disapobale
	bysort hh_id: egen double total_exp_net_adj_SY = total(exp_net_adj_SY)
	
gen double exp_net_PY = exp_net_adj_SY / disposable_income_orig * disposable_income // normalization to diposable income to adjust for income-exp link
	replace exp_net_PY = 0 if disposable_income_orig == 0
	assert !mi(exp_net_PY)
	
merge m:1 exp_type using `rates_PY', nogen assert(match)
merge m:1 sector using `ind_effect_PY', nogen assert(match using) keep(match)

gen double exp_gross_PY = exp_net_PY  * (1 - exp_form * VAT_rate_PY) * (1 - VAT_ind_eff_PY)

	if $SY_consistency_check == 1 { 
		assert abs(exp_net_SY  * (1 - exp_form * VAT_rate_PY) * (1 - VAT_ind_eff_PY) - exp_gross_SY) < 10 ^ (-10)
	}
	
gen double VAT = exp_net_PY - exp_gross_PY

* if we would like to separate the direct and indirect effect this can be done:
gen double VAT_dir = exp_net_PY  * exp_form * VAT_rate_PY
gen double VAT_ind = VAT - VAT_dir // the direct and indirect effects are rather cumulative than additive, but for simplicity we can assume the additivity

foreach var in $indirect_taxes {
	replace `var' = `var' / hh_size
}

isid hh_id exp_type exp_form
collapse (sum) ${indirect_taxes}, by(hh_id)
*groupfunction, sum(${indirect_taxes}) by(hh_id) norestore
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
