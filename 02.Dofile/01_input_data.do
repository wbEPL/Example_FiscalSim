* Preparing input data

use "${data}\Example_FiscalSim_dem_inc_data_raw.dta", clear

rename wage wage_net
rename self_inc self_inc_net

* hh size (we count inly those who are present)
bysort hh_id: egen hh_size_test = count(p_id)
	assert hh_size == hh_size_test //if !mi(weight)
	
* weight
rename weight ind_weight
gen hh_weight = ind_weight / hh_size
label variable hh_weight "Household weight"

* age
gen kid_age=(age<18) if !mi(ind_weight)
gen pens_age=(age>64) if !mi(ind_weight)
gen work_age=1-kid_age-pens_age if !mi(ind_weight)

* number of members
foreach var in kid_age work_age pens_age  {
bysort hh_id: egen n_`var'=total(`var')
}

assert n_kid_age+n_work_age+n_pens_age == hh_size if !mi(ind_weight)

**household type
gen hh_type=.
replace hh_type=1 if n_kid_age==1 & n_work_age+n_pens_age>=2
replace hh_type=2 if n_kid_age==2 & n_work_age+n_pens_age>=2
replace hh_type=3 if n_kid_age>2 & n_work_age+n_pens_age>=2
replace hh_type=4 if n_kid_age>0 & n_work_age+n_pens_age<2
replace hh_type=5 if n_work_age==hh_size //& n_pens_age==0 & n_kid_age==0
replace hh_type=6 if n_pens_age==hh_size //& n_work_age==0 & n_kid_age==0
replace hh_type=7 if n_work_age+n_pens_age==hh_size & n_pens_age>0 & n_work_age>0 //& n_kid_age==0
assert !missing(hh_type)

#delimit ;
label def hh_type
1	"two adults (or more) and 1 child"
2	"two adults (or more) and 2 children"
3	"two adults (or more) and 3+ children"
4	"one adult and child(ren)"
5	"only working age adults"
6	"only pensioners"
7	"mixed adults, no children"
, replace ;
#delimit cr
la val hh_type hh_type
label variable hh_type "Household composition"

*Poverty lines
global icp_2011 = 4 // put values for your country
global cpi_cumulative = 2 // cumulative CPI between 2011 and Survey Year (SY)

gen povline_nat = 1500  * 12 
gen povline_int32 = 3.2 * 365 * ${icp_2011} * ${cpi_cumulative}
gen povline_int55 = 5.5 * 365 * ${icp_2011} * ${cpi_cumulative} 

label variable povline_nat "National poverty line per capita for 12 months"
label variable povline_int32 "International povert line 3.2 USD/day in 2011 PPP, annualized"
label variable povline_int55 "International povert line 5.5 USD/day in 2011 PPP, annualized"

isid hh_id p_id
save "${data}\01.pre-simulation\Example_FiscalSim_dem_inc_data.dta", replace

keep hh_id p_id ${dem_list}
save "${data}\01.pre-simulation\Example_FiscalSim_dem_data_SY.dta", replace