*! vatpush v1
* Juan Pablo Baquero - WBG - Equity Policy Lab
* Daniel Valderrama - WBG - Equity Policy Lab

cap prog drop vatpush
cap set matastrict off
program define vatpush, rclass
	version 14.2
	#delimit ;
	syntax varlist (min=2 numeric) [if] [in], 
		EXEMpt(varlist max=1 numeric)
		COSTPush(varlist max=1 numeric)
		shock(varlist max=1 numeric)
		VATable(varlist max=1 numeric)
		gen(string)
		;
	#delimit cr		

	marksample touse
	keep if `touse'

	*Reading the matrix of technical coefficients 
	mata: A=st_data(., "`varlist'",.)
	mata: cp=st_data(., "`costpush'",.)'
	mata: shock=st_data(., "`shock'",.)'
	mata: vatable=st_data(., "`vatable'",.)'		
	mata: exempt=st_data(., "`exempt'",.)'
	
	//Creating matrix elements for indirect 
	gen double `gen'=0
	mata : st_view(YY=., ., "`gen'",.) // data will be modifying 
	mata:  YY[.,.]=indirect2(A,cp,shock,vatable,exempt)'
	
	replace `gen'=0   if cp==0 // *Price control sectors do not have indirect effect 
	lab var `gen' "Indirect shock"
	*drop cp
end 

mata:
	function indirect2(a,cp,shock,vatable,exempt) {
		
	alpha_cp=diag(cp) 
	
	alpha_vat=diag(vatable) 
	
	alpha_exempt=diag(exempt)
	
	K=pinv(I(cols(alpha_vat))-  alpha_cp*a)
	
	indirect=shock*alpha_vat*a*alpha_exempt*K
	return(indirect)
		
	}	
end







