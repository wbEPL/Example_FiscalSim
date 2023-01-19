*! directtax v1
* Paul Corral - WBG POV GP- Equity Policy Lab

cap prog drop dirtax
cap set matastrict off
program define dirtax, rclass
	version 11.2
	#delimit ;
	syntax varlist (max=1 numeric) [if] [in],
	Rates(numlist >=0 min=1)
	GENerate(string)
	THolds(numlist >=0 min=1) 
	[
	NETinput
	GROSSinput
	taxfree(varlist max=1 numeric)
	];
#delimit cr		
set more off
qui{	
	if ("`netinput'"!="" & "`grossinput'"!=""){
		display as error "Only one option is allowed, netinputs or grossinputs"
		error 111
		exit
	}
	if ("`netinput'"=="" & "`grossinput'"==""){
		dis as error "At least one option must be specified, netinputs or grossinputs"
	}
	numlist "`tholds'", sort
	local tholds `r(numlist)'
	numlist "`rates'", sort
	local rates `r(numlist)'
	
	local stholds: list sizeof tholds
	local srates : list sizeof rates
	
	//Check if rates need to be divided by 100
	tokenize `rates'
	if (``srates''>1) {
		forval z=1/`srates'{
			local f = ``z''/100
			local myrates `myrates' `f'
		}
	}
	else{
		forval z=1/`srates'{
			local myrates `myrates' `f'
		}	
	}
	local rates `myrates'
	//Check thresholds...
	if ((`stholds')!=`srates'){
		display as error "Your thresholds and rates data are not accurate, please check"
		error 111
		exit
	}
	/*
	//IS 0 among thresholds?
	local ch 0
	local ch: list tholds & ch
	if ("`ch'"==""){
		dis as error "0 should be among "
	}
	*/

	marksample touse	
	gen double `generate' = .
	
	/*
	if ("`filter'"!=""){
		cap replace `touse' = `touse'*(`filter')
		if _rc{
			dis as error "Please revise your filter option: `filter'"
			error 111
			exit
		}
	}
	*/
	if ("`taxfree'"!=""){
	//ONLY valid for gross inputs!!, ie when you want to netdown!
	//WHen you want to grossup, you need to subtract the deduction
		tempvar mivar dcount
		gen double `mivar' = `varlist' - `taxfree' if `touse' & ((`varlist'-`taxfree')>0)
			replace `mivar'= 0 if `touse' & ((`varlist'-`taxfree')<=0)
			gen double `dcount' = `varlist' if `touse' & ((`varlist'-`taxfree')<=0)
			replace `dcount' = `taxfree' if `touse' & ((`varlist'-`taxfree')>0)
		local lhs `mivar'
	}
	else{
		local lhs `varlist'
	}
	
	if (`srates'==1 & `stholds'==1){
		if (`thold'==0){
			if ("`grossinput'"!="") replace `generate' = `lhs'*(1-`rates')
			if ("`netinput'"!="")   replace `generate' = `lhs'/(1-`rates')
			if ("`taxfree'"!="")    replace `generate' = `generate'+`dcount' if `touse'==1
			exit
		}
	}
	else{
		replace `generate' = 0	if `touse'==1	
	}

	if ("`grossinput'"!=""){ //When you give gross inputs, and want to get NET
		local a    = 1
		local maxi = 0
		foreach rate of local rates{			
			tokenize `tholds'
			local bot ``a''
				local ++a
			if (`a'<=`srates') local up ``a''
			else local up .
						
			if (`a'==2){ //2 because of tokenization, you increased a just above
				local up  = `up'
				local bot = `bot'+1e-15
				replace `generate' = `lhs' *(1 - `rate') if inrange(`lhs',`bot',`up') & `touse'==1 
				
				local maxi = `maxi' + (`up'-`bot')*`rate'
			}
			else{
				local up  = `up'
				local bot = `bot'+1e-15
				replace `generate' = `lhs' - (`lhs'-`bot')*(`rate') - `maxi' if inrange(`lhs', `bot', `up') & `touse'==1
				
				local maxi = `maxi' + (`up'-`bot')*`rate'
			}
		}
	}
	if ("`netinput'"!=""){  //This means we need to gross up
		local a    = 1
		local maxi = 0
		foreach rate of local rates{		
			tokenize `tholds'
			if (`a'==1){
				local bot ``a''
			}
			else{
				local bot =`up'
				local b1 = ``a''
			}
			local ++a
			if (`a'<=`srates'){
				local up ``a''
				local u1 ``a''
			}
			else{
				local up .
				local u1 .
			}
				
			if (`a'==2){
				local bot = `bot'
				local up  = `up'*(1-`rate')
				replace `generate' = `lhs'/(1-`rate') if inrange(`lhs',`bot',`up') & `touse'==1 
				local maxi = `up'*`rate'/(1-`rate')+`maxi'
			}
			else{				
				local bot = (`bot')+1e-15
				local up = `bot'+(`u1'-`b1')*(1-`rate')	
				replace `generate' = (`lhs'+`maxi' - `b1'*`rate')/(1-`rate') if inrange(`lhs',`bot',`up') & `touse'==1 
				local maxi = (`u1'-`b1')*`rate'+`maxi'
				//if ("`up'"!=".") 
			}
		}
	}
	if ("`taxfree'"!="")    replace `generate' = `generate'+`dcount' if `touse'==1 
}
end
	