*! costpush v1
* Paul Corral - WBG - Equity Policy Lab

cap prog drop costpush
cap set matastrict off
program define costpush, rclass
	version 11.2
	#delimit ;
	syntax varlist (min=2 numeric) [if] [in], 
		FIXed(varlist max=1 numeric)
		PRICEshock(varlist max=1 numeric)
		genptot(string)
		genpind(string)
		[fix];
	
	#delimit cr		
marksample touse

mata: st_view(_A=., ., "`varlist'","`touse'")
mata: st_local("rows", strofreal(rows(_A)))
mata: st_local("cols", strofreal(cols(_A)))

if (`rows'!=`cols'){
	dis as error "Not a square matrix"
	error 345566
	exit
}

mata: st_view(_fixed=.,.,"`fixed'","`touse'")
mata: st_view(_dp=.,.,"`priceshock'","`touse'")


qui:gen double `genpind' = .
	lab var `genpind' "Indirect shock"
qui:gen double `genptot' = . 
	lab var `genptot' "Total shock"
mata: st_store(.,tokens("`genptot' `genpind'"),"`touse'", _indeff(_A,_fixed,_dp))
end


mata
function _indeff(A,fixed,dp){
	
	alfa    		                 = I(rows(fixed)) - diag(fixed)
	k       						 = luinv(I(rows(fixed)) - quadcross(alfa',A))
	if (st_local("fix")=="") dptilda = quadcross(quadcross(dp,A)',k)
	else 					 dptilda = quadcross(quadcross(dp,A)',k):*(fixed:==0)'
	deltap                           = quadcross(dp,diag(fixed)) + quadcross((dptilda + dp')',alfa)
	
	return((deltap',dptilda'))
	
}
end
