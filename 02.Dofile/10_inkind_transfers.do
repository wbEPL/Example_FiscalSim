	******************************************************************************
	* Example FiscalSim - fiscal microsimulation model for hypothetical country.
	* Calculating inkind benefits for policy year
	* 24 February 2023 
	******************************************************************************
	* Steps: 
	* 1. Read in the administrative data

	* Education 
	* 2. Sum the education user-fees / co-payments 
	* 3. Identify those benefitting from education transfers in the survey
	* 4. Allocate the education subsidies per level of education 

	* Health 
	* 5. Identify those benefitting from health transfers in the survey
	******************************************************************************


	* 1. Read in the administrative data 
	******************************************************************************
	/* Import the health and education budget expenditure and enrollment/visit totals from the Excel spreadsheet and store as globals */
		import excel using "$xls_tool", sheet(inkind) cellrange(A1:K2) first clear 
		qui destring _all, replace
		
		ds 									//list all variables, and return varlist in the local r(varlist)
		foreach var in `r(varlist)' {
			global `var' = `var'[1]
			disp $`var'
		}

	* 2. Sum the user-fees / co-payments 
	******************************************************************************
		use "${data}\proc\Example_FiscalSim_exp_data.dta", clear
		g exp_educ_trns_hh = exp_net_SY if exp_type == 79
		g exp_educ_serv_hh = exp_net_SY if exp_type == 80
		g exp_educ_psec_hh = exp_net_SY if exp_type == 81
		g exp_educ_tert_hh = exp_net_SY if exp_type == 82

		collapse (sum) exp_educ_*, by(hh_id)

		lab var exp_educ_trns_hh "Exp educ. transport"
		lab var exp_educ_serv_hh "Exp educ. services"
		lab var exp_educ_psec_hh "Exp educ. post-secondary"
		lab var exp_educ_tert_hh "Exp educ. tertiary"

		egen fee_educ_hh = rowtotal(exp_educ_trns_hh exp_educ_serv_hh exp_educ_psec_hh exp_educ_tert_hh)
		
		merge 1:m hh_id using "${data}\proc\Example_FiscalSim_dem_inc_data.dta", nogen assert(match using) keepusing(p_id age hh_weight hh_weight study med_ins hospital_days)
		ren study educ_level
		lab var educ_level "Level of education"
		order hh_id p_id
		mvencode  fee_* , mv(0) override //replace missing values with 0


	* 3. Identify those benefitting from education transfers in the survey
	******************************************************************************
	/* To this we read in the post-secondary and tertiary education expenditures from the survey, because: 
		*a. we do not have question for paid eductions, so we have to rely on the expenditure info.  
		*b. we assume that if hh has education expenditure, then noone in the hh is on budget funding  //what does Misha mean by "budget funding", here? */

	 * 3.1. Identify those who should be enrolled (target individuals)
	 	/* This step is optional, but can be useful for additional complementary analysis later on */
		gen edu_prim_ti = inrange(age,6,11)
		gen edu_seco_ti = inrange(age,12,18)

		lab var edu_prim_ti "Primary school age [6-11]"
		lab var edu_seco_ti "Secondary school age [12-18]"

	 * 3.2. Identify those who are actually enrolled (receiving individuals)
		gen edu_prim_ri = (educ_level == 1)
		gen edu_seco_ri = (educ_level == 2)
		gen edu_psec_ri = (educ_level == 3) & exp_educ_psec_hh == 0 
		gen edu_tert_ri = inrange(educ_level,4,5) & exp_educ_tert_hh == 0 

		lab var edu_prim_ri "Primary school subsidy receipient"
		lab var edu_seco_ri "Secondary school subsidy receipient"
		lab var edu_psec_ri "Post-secondary school subsidy receipient"
		lab var edu_tert_ri "Tertiary school subsidy receipient" 

	* 4. Allocate the education subsidies per level of education 
	******************************************************************************	
		*4.1. Compare enrollment in the survey with enrollment in the admin numbers: 	
		foreach type in prim seco psec tert{
			qui su edu_`type'_ri [fw = int(hh_weight)]
			loc `type'_svytot = r(sum)
			disp round(``type'_svytot'/${edu_enroll_`type'},.01)
		}
			//Tertiary enrollment is low in the survey (in this fictional case, it is because the sample frame does not include education residences.)

		*4.2. Calculate the size of the subsidy 
		foreach type in prim seco psec tert{
			global ben_`type' = ${edu_exp_`type'}/${edu_enroll_`type'}
			disp ${ben_`type'}
		}

		*4.3. Allocate the subsidy to enrolled students 
		foreach type in prim seco psec tert{
			g edu_`type'_in = edu_`type'_ri*${ben_`type'}

			qui sum edu_`type'_in [fw = int(hh_weight)]
			global edu_`type'_modtot = r(sum)
			disp ${edu_`type'_modtot}/${edu_exp_`type'}
		}

		lab var edu_prim_in "Primary school benefit"
		lab var edu_seco_in "Secondary school benefit"
		lab var edu_psec_in "Post-secondary school benefit"
		lab var edu_tert_in "Tertiary school benefit" 

		*4.4 Check if the subsidy net of transport expenditures is negative 
		/* If we subtract transport fees from the household subsidy amount we get 44, 24, 62 and 54 negative subsidy amounts respectively. 
			Try allocating an average value per decile. */
		
		g exp_educ_trns_mean = 0
		assert !mi(exp_educ_trns_hh)
		qui sum exp_educ_trns_hh [fw=int(hh_weight)] if exp_educ_trns_hh > 0
		disp r(mean)
		replace exp_educ_trns_mean = r(mean) if exp_educ_trns_hh > 0

		foreach type in prim seco psec tert{
			bysort hh_id: egen edu_`type'_hh = total(edu_`type'_in)
		}
		egen edu_hh = rowtotal(edu_prim_hh edu_seco_hh edu_psec_hh edu_tert_hh)
		count if edu_hh < exp_educ_trns_hh  //18 negatives 
		count if edu_hh < exp_educ_trns_mean //18 negatives 

		//Conclusion: do not subtract user-fees from subsidy amount. 

	* 5. Identify those benefitting from health transfers in the survey
	******************************************************************************
	/* Here we use a combined approach: 
		a. We use the insurance-value approach to allocate outpatient based care, and 
		b. We use the actual-use appraoch to allocate inpatient care. 

	We do this because we don't have information on numbers of visits to outpatient services. 
	Note that administrative numbers on enrollment are not available here, and so we use the numbers in the survey multiplied by a scaling factor */

		*5.1. Insurance-value approach 
		gen hlt_outp_ri = (med_ins == 1) 
		lab var hlt_outp_ri "Outpatient healthcare recipient"

		*5.2. Actual-use approach 
		gen hlt_hosp_ri = (hospital_days > 0 & med_ins == 1)
		lab var hlt_hosp_ri "Inpatient (hospital) healthcare recipient" 
		gen hlt_hosp_days = hospital_days*hlt_hosp_ri
		lab var hlt_hosp_days "Use of hospital services (days)" 

	* 6. Allocate the health subsidies by level of healthcare
	******************************************************************************
		foreach type in outp_ri hosp_days {
			qui sum hlt_`type' [fw = int(hh_weight)]
			global hlt_`type'_tot = r(sum)
		}
		
		gen hlt_outp_in = hlt_outp_ri / ${hlt_outp_ri_tot} * ${hlt_exp_outp} * ${scale_factor}
		gen hlt_hosp_in = hlt_hosp_days / ${hlt_hosp_days_tot} * ${hlt_exp_hosp} * ${scale_factor}

		lab var hlt_hosp_in "Hospital health benefits"
		lab var hlt_outp_in "Out-patient health benefits"

	* 7. Save the dataset 
	******************************************************************************
		keep hh_id p_id ${health} ${education} ${educfees} 
		mvencode ${health} ${education} ${educfees}, mv(0) override 

		isid hh_id p_id
		save "${data}\02.intermediate\Example_FiscalSim_inkind_transfers_data.dta", replace


******************************************************************************
* End 
******************************************************************************
