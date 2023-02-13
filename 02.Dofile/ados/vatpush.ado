*! vat_mat v1
* Daniel Valderrama - WBG - Equity Policy Lab

cap prog drop vatpush
cap set matastrict off
program define vatpush, rclass
	version 15.2
	#delimit ;
	syntax varlist (min=2 numeric) [if] [in], 
		EXEMpt(varlist max=1 numeric)
		COSTPush(varlist max=1 numeric)
		shock(varlist max=1 numeric)
		VATable(varlist max=1 numeric)
		;
	#delimit cr		

	marksample touse
	keep if `touse'

	*Reading the matrix of technical coefficients 
	
	//Creating matrix elements for indirect 
	mata : st_view(YY=., ., "indirect_effect_iva",.)
	mata: A=st_data(., "`varlist'",.)
	mata: cp=st_data(., "`costpush'",.)'
	mata: shock=st_data(., "`shock'",.)'
	mata: vatable=st_data(., "`vatable'",.)'		
	mata: exempt=st_data(., "`exempt'",.)'
	
	
	mata:  YY[.,.]=indirect2(A,cp,shock,vatable,exempt)'

	*Price control sectors 
	replace indirect_effect_iva=0   if cp==0

end 

mata:
	
	function indirect2(a,cp,shock,vatable,exempt)
	
	{
		
	alpha_cp=diag(cp) 
	
	alpha_vat=diag(vatable) 
	
	alpha_exempt=diag(exempt)
	
	K=pinv(I(cols(alpha_vat))-  alpha_cp*a)
	
	indirect=shock*alpha_vat*a*alpha_exempt*K
	return(indirect)
		
	}
	
end







