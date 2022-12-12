clear all
set more off

cd "J:\ZachM\12. INTERN PROJECTS\Nikita Project 1"

import excel "New Rev Model Data.xlsx", sheet("Monthly") firstrow case(lower)


gen mod = 0
replace mod=1 if mindex>=tm(2009m7)

tsset mindex, m

gen qdate = qofd(dofm(ym(cy, m)))
format %tq qdate
order qdate, first

foreach var of varlist emp-retail {
	replace `var'=. if `var'==0
	gen ln`var'=ln(`var')
}


gen fm_lnretail=lnretail if mindex<=tm(2016m1)
gen fm_lnhours=lnhours if mindex<=tm(2016m1)
gen sm_lnretail=lnretail if mindex<=tm(2016m2)
gen sm_lnhours=lnhours if mindex<=tm(2016m2)


local t=tm(2016m1)

/*First month loop*/
while `t'<tm(2022m4) {
	
	quietly arima lnretail if mindex<=`t', arima(1,1,1) robust
	predict p_lnretail
	replace p_lnretail = lnretail if mindex<=`t'
	replace p_lnretail = p_lnretail[_n-1]+p_lnretail if mindex > `t'
	replace fm_lnretail = lnretail if mindex==`t'
	replace fm_lnretail = p_lnretail if mindex >`t' & mindex < `t'+3
	
	quietly arima d.lnhours d_rec if mindex<=`t', arima(0,0,1) robust nocons
	predict p_lnhours
	replace p_lnhours = lnhours if mindex<=`t'
	replace p_lnhours=p_lnhours[_n-1]+p_lnhours if mindex > `t'
	replace fm_lnhours = lnhours if mindex==`t'
	replace fm_lnhours = p_lnhours if mindex>=`t' & mindex < `t'+3
	
	local t=`t'+3
	drop p_lnretail
	drop p_lnhours

}

local t=tm(2016m2)

/*Second month loop*/
while `t'<tm(2022m4) {
	
	quietly arima lnretail if mindex<=`t', arima(1,1,1) robust
	predict p_lnretail
	replace p_lnretail = lnretail if mindex<=`t'
	replace p_lnretail = p_lnretail[_n-1]+p_lnretail if mindex > `t'
	replace sm_lnretail = lnretail if mindex>=`t'-1 & mindex < `t'+2
	replace sm_lnretail = p_lnretail if mindex >`t' & mindex < `t'+2
	
	quietly arima d.lnhours d_rec if mindex<=`t', arima(0,0,1) robust nocons
	predict p_lnhours
	replace p_lnhours = lnhours if mindex<=`t'
	replace p_lnhours=p_lnhours[_n-1]+p_lnhours if mindex > `t'
	replace sm_lnhours = lnhours if mindex>=`t'-1 & mindex < `t'+2
	replace sm_lnhours = p_lnhours if mindex>=`t' & mindex < `t'+2
	
	local t=`t'+3
	drop p_lnretail
	drop p_lnhours


}

foreach var of varlist fm_* sm_* {
	replace `var'=exp(`var')
}

collapse (first) mindex (mean) emp cea consum hours house inprod retail fm_* sm_*, by(qdate)

save "m to q loop data", replace



*
*

clear all
set more off

cd "J:\ZachM\12. INTERN PROJECTS\Nikita Project 1"

import excel "New Rev Model Data.xlsx", sheet("Quarterly") firstrow case(lower)

drop if cy<1992
merge 1:1 _n using "m to q loop data"
tsset qdate, q
drop mindex date qindex _merge /*dropping unneeded variables and reordering*/
order qdate rec, first


foreach var of varlist gdp-retail {
	replace `var'=0 if `var'==.
	gen ln`var'=ln(`var')
}

foreach var of varlist fm_* sm_* {
	replace `var'=ln(`var')
}

gen fm_lngdp=. if qdate<tq(2016q1)
gen sm_lngdp=. if qdate<tq(2016q1)

local t=tq(2016q1)

while `t'<tq(2022q2) {
	quietly reg d.lngdp l(2).consum d.fm_lnhours l.d.lnhouse l(0,2).d.fm_lnretail l3.d.lninprod l.d.lngdp if qdate<`t', robust nocons 
	predict p_lngdp
	replace p_lngdp=lngdp if qdate<`t'
	replace p_lngdp=p_lngdp[_n-1]+p_lngdp if qdate==`t'
	replace fm_lngdp=p_lngdp if qdate==`t'
	drop p_lngdp
	
	replace fm_lnretail=lnretail if qdate==`t'
	replace fm_lnhours=lnhours if qdate==`t'
	local t=`t'+1

}


local t=tq(2016q1)

while `t'<tq(2022q2) {
	quietly reg d.lngdp l(2).consum d.sm_lnhours l.d.lnhouse l(0,2).d.sm_lnretail l3.d.lninprod l.d.lngdp if qdate<`t', robust nocons 
	predict p_lngdp
	replace p_lngdp=lngdp if qdate<`t'
	replace p_lngdp=p_lngdp[_n-1]+p_lngdp if qdate==`t'
	replace sm_lngdp=p_lngdp if qdate==`t'
	drop p_lngdp
	
	replace sm_lnretail=lnretail if qdate==`t'
	replace sm_lnhours=lnhours if qdate==`t'
	local t=`t'+1

}


gen tm_lngdp=.
local t=tq(2016q1)

while `t'<tq(2022q2) {
	quietly reg d.lngdp l(2).consum d.lnhours l.d.lnhouse l(0,2).d.lnretail l3.d.lninprod l.d.lngdp if qdate<`t', robust nocons 
	predict p_lngdp
	replace p_lngdp=lngdp if qdate<`t'
	replace p_lngdp=p_lngdp[_n-1]+p_lngdp if qdate==`t'
	replace tm_lngdp=p_lngdp if qdate==`t'
	drop p_lngdp
	
	local t=`t'+1

}


gen fm_growth = fm_lngdp-lngdp[_n-1]
gen sm_growth = sm_lngdp-lngdp[_n-1]
gen tm_growth = tm_lngdp-lngdp[_n-1]
gen actual_growth = lngdp-lngdp[_n-1] if qdate>=tq(2016q1) & qdate<=tq(2022q2)


********************************************************************************

gen f_lngdp=.
gen f_lnc=.
gen f_lni=.
gen f_lng=.
gen f_lnx=.
gen f_lnm=.

local t=tq(2016q1)

while `t'<tq(2022q2) {
	quietly var d.lnc d.lng d.lni d.lnx d.lnm d.lndef if qdate<`t', lags(1/2) exog(rec)
	fcast compute f_, d(`t') step(3)
	foreach var of varlist lng lnc lni lnx lnm {
		replace f_`var'=`var'[_n-1]+f_D_`var' if qdate==`t'
		replace f_`var'=exp(f_`var')
	}
	replace f_lngdp = f_lnc+f_lng+f_lni+f_lnx-f_lnm if qdate==`t'
	local t=`t'+1
	drop f_D_*
	foreach var of varlist lng lnc lni lnx lnm {
		replace f_`var'=ln(f_`var')
	}

}

replace f_lngdp=ln(f_lngdp)
gen ospb_growth = f_lngdp-lngdp[_n-1]



keep qdate fm_* sm_* actual_growth lngdp tm_growth tm_lngdp ospb_growth f_lngdp


export excel "forecast comparison2", sheet("forecast") replace firstrow(variables) keepcellfmt