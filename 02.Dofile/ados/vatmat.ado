*! vatmat v1
* Juan Pablo Baquero - WBG - Equity Policy Lab
* Daniel Valderrama - WBG - Equity Policy Lab

*mata: mata clear 
cap prog drop vatmat
cap set matastrict off
program define vatmat, rclass
	version 15.2
	#delimit ;
	syntax varlist (min=2 numeric) [if] [in], 
		EXEMpt(varlist max=1 numeric)
		PEXEMpt(varlist max=1 numeric)
		SECTor(varlist max=1 numeric)
		;
	#delimit cr		

	marksample touse
	keep if `touse'

	tempfile odata 
	save `odata', replace 


	*Reading the matrix of technical coefficients 
		mata: _io=st_data(., "`varlist'","`touse'") // Store the IO in Mata: (.) returns in stata all observations,  for  sect_1, sect_2, ..., sect_14, sect_15, sect_16, (.) no conditions on the obs or rows that should be excluded
		mata: 	st_local("rows", strofreal(rows(_io)))
		mata: 	st_local("cols", strofreal(cols(_io)))
		
		if (`rows'!=`cols'){
				dis as error "Not a square matrix"
				error 345566
				exit
		}
	
	*Reading the matrix of technical coefficients 
			mata: _ve=st_data(.,"`pexempt'",.)
		
		
	* Define lists of sectors : exempted, mixed, and non-mixed sectors 
			levelsof `sector' if `exempt'!=0 , local(excluded) // List of exempted products 
			levelsof `sector' if `exempt'==1 & `pexempt'>0 & `pexempt'<1 ,  local(noncollsecs) // List of IO sectors to be expanded 
			levelsof `sector' if `pexempt'==0 | `pexempt'==1,  local(collsecs) // List of IO sectors to be expanded 
	
	
	
	dis "Program ended "
	dis "list of sectors to be expanded : `collsecs'"
	dis "list of sectors to be expanded : `noncollsecs'"
	
/* ------------------------------------
	First we extended all the sectors 
 --------------------------------------*/
	
	mata: io=_io
	mata: ve=_ve
	

	mata: n_sect = strofreal(rows(io))
	
	mata: exempt_i=J(rows(io)*2,1,0) // null vector of `n_sect' X 2
	mata: nve=J(rows(io),1,1)-ve
	mata: extended=J(rows(io)*2,rows(io)*2,0) // null square matrix of (`n_sect' X 2) 
		
	forvalues n=1(1)`rows' {
		
		mata: jj=2*`n'-1 // odd numbers 
		mata: kk=jj+1  // paid numbers 
	
		forvalues i=1(1)`rows' {
			mata: j=2*`i'-1 // odds
			mata: k=j+1   // pairs 
			
			//extended[jj::kk,j::k]=J(2,2,io[n,i])/2
			 //take original coefficient by IO and split it by nve or ve 
			mata: extended[jj::jj,j::k]=J(1,2,io[`n',`i']*ve[`n',1])
			mata: extended[kk::kk,j::k]=J(1,2,io[`n',`i']*nve[`n',1])
		
		}
		mata: exempt_i[jj,1]=1
		mata: exempt_i[kk,1]=0
	}
	mata: extended=extended,exempt_i
	mata: st_matrix("extended",extended) // saving the stata matrix into stata

	clear 
	
	svmat extended // from mata to stata : extended is 70X (35+70)
	rename extended* sector_* // index extended sectors 
	gen sector=ceil(_n/2) // label each sector with same name (ceiling name)
	order sector sector_*
	local last_row = `rows'*2+1
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



*Renaming sectors 
merge m:1 sector using `odata', assert(master matched) keepusing(`exempt') nogen
replace exempted=`exempt' if exempted==.
drop `exempt'










end 