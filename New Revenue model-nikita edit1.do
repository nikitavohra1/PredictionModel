clear all
set more off

cd "J:\ZachM\12. INTERN PROJECTS\Nikita Project 1"

import excel "New Rev Model Data.xlsx", sheet("Monthly") firstrow case(lower)


gen mod = 0
replace mod=1 if mindex>=tm(2009m7)

tsset mindex, m

********************************************************************************
/*Building GDP Bridge Equation*/
********************************************************************************

local lastfy 2020
gen qdate = qofd(dofm(ym(cy, m)))
format %tq qdate
order qdate, first

foreach var of varlist emp-retail {
	replace `var'=. if `var'==0 /*replacing 0 values in variables*/
	
}
/*Because we only have data through April, which is the first month of Q2, we will
get silly results if we collapse by mean for each variable as we saw during our call.
This counts how many observations of the retail variable are NOT missing, and 
automatically stores it as a local macro called r(N). Then we can refer to that
later.*/
count if !missing(retail)


/*Here, we're replacing all the variables to have a missing value for the last 
observation (our r(N) from above). This will ensure we won't calculate an average 
value for Q2 which is the average of the first month and 0's for the last two months*/
foreach var of varlist emp-retail {
	replace `var'=. in `r(N)'
}

collapse (first) mindex (mean) retail consum inprod house hours, by(qdate)
save "quarter estimates2", replace

clear all 

import excel "New Rev Model Data.xlsx", sheet("Quarterly") firstrow case(lower)


/*I'm doing the same as above where we remove 0's from the data which shouldn't
have 0's*/
foreach var of varlist gdp-def {
	replace `var'=. if `var'==0
}

/*Our monthly data starts at 1992 q1, so we need to remove all older observations
the quarterly data. Otherwise the files won't merge properly*/
drop if cy<1992

merge 1:1 _n using "quarter estimates2"
drop _merge

tsset qdate, q
drop qindex mindex

order qdate rec, first

/*foreach loop to create natural logs of all variables*/
foreach var of varlist gdp-hours {
	gen ln`var'=ln(`var')
}


********************************************************************************
/* varsoc*/
********************************************************************************
/*This will help with the optimal lag selection for a regression model. 
For instace, you can run the code with a single variable to determine the number of lags 
to include in a Dickey-Fuller test for stationarity. This is what we did on our call.

Additionally, you can use this code to determine the optimal amount of lags for a VAR or
VEC model. The syntax is the same, except that you would include all of the variables
in the varsoc command. 

Remember to select the max amount of lags to consider in the varsoc command. Typically with
monthly data I wouldn't go beyond 12. You're free to use whatever selection criteria you'd like - AIC, BIC, etc...
Whatever the optimal selection, P*, turns out to be, set the lags in your model or dfuller test to P*-1

*Remember to log transfor your variables before doing this*/

tsset qdate

varsoc lnretail, m(8)
* Highest AIC for lnretail is in Lag1
tsline lnretail
* It follows a trend line

varsoc consum, m(8)
* Highest AIC for lnconsum is in Lag1
tsline consum
* It follows a drift line

varsoc lninprod, m(8)
* Highest AIC for lnconsum is in Lag1
tsline lninprod
* It follows a trend line

varsoc lnhouse, m(8)
* Highest AIC for lnconsum is in Lag7
tsline lnhouse
* It follows a drift line

varsoc lnhours, m(8)
* Highest AIC for lnconsum is in Lag1
tsline lnhours
* It follows a drift line

varsoc lnemp, m(8)
* Lag 1
varsoc lncea, m(8)
* Lag 8


********************************************************************************
/*dfuller
********************************************************************************
This is the test for stationarity. Syntax is dfuller "var", l(P*-1). You can also 
include the "trend" option if the data looks like it follows a trend stationary 
process - this looks like a straight line increase or decreasing over time, with 
the data bouncing around that line frequently. 

If the data looks like it is increasing but not bounding around a straight line
frequently, then it is likely a random walk with drift process. Instead of the "trend"
option, include "drift"

If the process looks like a random walk process without drift, use the option 
"nocons"*/

dfuller lnretail, trend lags(0)
*P value = 0.670 i.e. more than 0.05, Fail to reject
dfuller d.lnretail, trend lags(0)
* P value= 0.00 < 0.05, reject the null

dfuller consum, lags(0)
* P = 0.01 <0.05, reject null

dfuller lninprod, trend lags(0)
* P = 0.38>0.05, fail to reject
dfuller d.lninprod, trend lags(0)
* P value = 0, reject null

dfuller lnhouse, trend lags(6)
*P=0.52>0.05, fail to reject
dfuller d.lnhouse, trend lags(6)
*P=0.29>0.05, fail to reject
* First differene doesn't create stationarity in the data
tsline d.lnhouse

dfuller lnhours, nocons lags(0)
* P= Test stastic not the highest number, fail to reject null
dfuller d.lnhours, nocons lags(0)
* P= Test stastic the highest number, reject null
tsline d.lnhours

********************************************************************************
/* Need to run intermediate equations for independent variables and export to 
quarterly data. Then merge with quarterly data from XLSX file and run bridge 
equation for gdp and possibly pi. Export outputs to separate XLSX file for 
revenue forecasting

Forecast independent variables using intermediate equations out to end of current 
quarter.

Need to develop bridge equation for forecasting PI. 
Follow methods in Rossiter & Zheng, 2006*/

reg d.lngdp d.consum d.lnhours l.d.lnhours d.lnhouse d.lnretail l.d.lninprod l3.d.lninprod l3.d.lngdp
*hours is significant while lag1 siginificant at 10%, house rates- not significant at all. Retail prices significant, industrial prod significant (not lag3). gdp lag3- not

reg d.lngdp d.consum d.lnhours l.d.lnhours l.d.lnhouse d.lnretail l.d.lninprod l.d.lngdp
reg d.lngdp l.d.consum d.lnhours l.d.lnhours l.d.lnhouse d.lnretail l2.d.lninprod l.d.lngdp
*Seems like the above quation would be best suited for bridge: it has all variables significant 1% and consumer index and industrial production significant at 10%. 
reg d.lngdp l3.d.consum d.lnhours l.d.lnhours l.d.lnhouse d.lnretail l2.d.lninprod l.d.lngdp

/*Bridge Equation
gdp(t) = 0.00376 - 0.00023Consum(t-1) + 1.0874hours(t) -.347hours(t-1) -0.275house(t-1) + 0.2575retail(t) + 0.0783inprod(t-2) -0.347GDP(t-1)
*/

********ZACH EDITS****************

reg d.lngdp l3.consum d.lnhours l.d.lnhours l.d.lnhouse d.lnretail l2.d.lninprod l.d.lngdp


/*Nikita's model adjusted*/
reg d.lngdp l2.consum d.lnhours l.d.lnhouse l(0,2).d.lnretail l3.d.lninprod l.d.lngdp, robust nocons
estat ic


reg d.lngdp l2.consum d.lnhours l.d.lnhouse l(0,2).d.lnretail l3.d.lninprod, robust nocons
estat ic


xtbreak d.lngdp l2.consum d.lnhours l.d.lnhouse d.lnretail l2.d.lnretail l3.d.lninprod l.d.lngdp, nocons

xtbreak estimate d.lngdp l2.consum d.lnhours l.d.lnhouse d.lnretail l2.d.lnretail l3.d.lninprod l.d.lngdp, nocons breaks(5)
xtbreak estimate d.lngdp l2.consum d.lnhours l.d.lnhouse d.lnretail l2.d.lnretail l3.d.lninprod l.d.lngdp, nocons breaks(3)
xtbreak estimate d.lngdp l2.consum d.lnhours l.d.lnhouse d.lnretail l2.d.lnretail l3.d.lninprod l.d.lngdp, nocons breaks(2)
/*two breaks at 2000 and 2017 seem consistent and statistically strong based on estimation*/


xtbreak test d.lngdp l2.consum d.lnhours l.d.lnhouse d.lnretail l2.d.lnretail l3.d.lninprod l.d.lngdp, nocons breaks(2)
/*Test rejects the null of no breaks versus 2 breaks*/

xtbreak test d.lngdp l2.consum d.lnhours l.d.lnhouse d.lnretail l2.d.lnretail l3.d.lninprod l.d.lngdp, hypothesis(3) nocons breaks(3)
/*Test fails to reject the null of 2 breaks versus 3 breaks at 1% level*/

xtbreak estimate d.lngdp l2.consum d.lnhours l.d.lnhouse d.lnretail l2.d.lnretail l3.d.lninprod l.d.lngdp, nocons breaks(2)


reg d.lngdp l(2).consum d.lnhours l.d.lnhouse l(0,2).d.lnretail l3.d.lninprod l.d.lngdp, robust nocons 



***************BRIDGE EQUATION**************************************************
reg d.lngdp l(2).consum d.lnhours l.d.lnhouse l(0,2).d.lnretail l3.d.lninprod l.d.lngdp if qdate>=tq(2000q4), robust nocons
********************************************************************************

**************************************************************************************************
/*Monthly forecasts for explanatory variables*/
**************************************************************************************************

clear all
set more off

cd "J:\ZachM\12. INTERN PROJECTS\Nikita Project 1"

import excel "New Rev Model Data.xlsx", sheet("Monthly") firstrow case(lower) 


gen mod = 0
replace mod=1 if mindex>=tm(2009m7)

tsset mindex, m


local lastfy 2020
gen qdate = qofd(dofm(ym(cy, m)))
format %tq qdate
order qdate, first

foreach var of varlist emp-retail {
	replace `var'=. if `var'==0 /*replacing 0 values in variables*/
	gen ln`var'=ln(`var')
}



/*model for retail and hours*/
tsline lnretail
tsline d.lnretail
=-
ac d.lnretail
pac d.lnretail
** pac has 2 points out of the confidence band, p=1/2 and ac has 2 points outside band, q=2



/*The same goes for the model after this.*/
arima lnretail if mindex>=tm(2009m1) & mindex<=tm(2020m2), arima(2,1,2) robust
predict r1, resid
predict p1_lnretail
/*After restricting the timeframe for estimation, the sum of the AR terms and MA 
terms are roughly 1 and -1, respectively*/

replace p1_lnretail=lnretail if lnretail!=.
replace p1_lnretail=p1_lnretail[_n-1]+p1_lnretail if lnretail==.



arima lnretail if mindex>=tm(2009m1) & mindex<=tm(2020m2), arima(1,1,1) robust
predict r2, resid
predict p2_lnretail

replace p2_lnretail=lnretail if lnretail!=.
replace p2_lnretail=p2_lnretail[_n-1]+p2_lnretail if lnretail==.


la var p1_lnretail "ARIMA(2,1,2)"
la var p2_lnretail "ARIMA(1,1,1)"



/*Model 3 includes recession indicator*/
arima d.lnretail d_rec, arima(1,0,1) robust
predict r3, resid
predict p3_lnretail
replace p3_lnretail=lnretail if lnretail!=.
replace p3_lnretail=p3_lnretail[_n-1]+p3_lnretail if lnretail==.

la var p3_lnretail "ARIMA(1,1,1) w/ Recession"

tsline p1_lnretail p2_lnretail p3_lnretail

/*Model 3 provides flexibilty in allowing us to assume a recession sometime in
the forecast period. However, because it uses all data, the trend is higher than 
under model 2 or model 1. We prefer model 2*/







/*While 2 orders of differencing may be necessary in some applications, I do not
believe it is necessary here. Also, interpretation of the model becomes more complex
once we start adding higher orders of differencing. The process through which we 
translate this back to level data which we can interpret is also more complicated.

For instance, let y_t be lnretail at time t, and let p_t be the predicted value 
at time t that we got when we ran the predict command. When you run the predict 
code for the ARIMA(2,1,2) model on d.lnretail, each predicted observation is essentially...

p_t = d.y_t - d.y_t-1 = (y_t - y_t-1) - (y_t-1 - y_t-2) = y_t - 2y_t-1 + y_t-2

Then to solve for the level value given our predicted values (meaning, we take our
forecasts and translate them into values for lnretail) we would just solve for y_t,
which is y_t = p_t + 2y_t-1 - y_t-2.


Instead, if the model was correctly specified with a single order of differencing, 
calculating our forecast for lnretail in each time period would be simply...

y_t = p_t + y_t-1


There are several ways to do this. The easiest way is to just ammend our lnretail 
variable using our predicted values (which if correctly specified will be in first
differences). Put simply, we have missing observations for our lnretail variable 
past a certain point in time. We want to replace those missing observations with
our forecast given the model. The code for this is very simple.

Assume that our variable with the predicted values is called p_lnretail as above.
The code is as follows...

replace lnretail = lnretail[_n-1]+p_lnretail if lnretail==.

Here, we take the prior value of lnretail, and add the current prediction value. 
This makes perfect sense because our predicted values are in first differences,
which is the CHANGE from last period to this period. The "if" portion of the code 
specifies that we only make these changes for periods in which lnretail is missing.
Otherwise the entire lnretail variable would be changed.

The result is that you end up with your lnretail variable with actual data
all the way through the last period in which we had actual data, followed by 
forecasts based on our model. */

** p = 4, q=1
/*arima lnhours, arima(4,1,1)
arima lnhours, arima(3,1,1)
arima lnhours, arima(3,1,1)
arima lnhours, arima(2,1,1)
arima lnhours, arima(1,1,1) nocons 
*/

drop r1 r2 r3

arima d.lnhours d_rec, arima(1,0,0) robust 
predict r1, resid
estat ic

predict p1_lnhours
replace p1_lnhours=lnhours if lnhours!=.
replace p1_lnhours=p1_lnhours[_n-1]+p1_lnhours if lnhours==.


/*^^ residuals show significant negative AC and PAC plots for lag 2. Reject this 
model.*/



arima d.lnhours d_rec, arima(0,0,1) robust nocons
predict r2, resid
estat ic
predict p2_lnhours

replace p2_lnhours=lnhours if lnhours!=.
replace p2_lnhours=p2_lnhours[_n-1]+p2_lnhours if lnhours==.

/*^^ this model has no significant lags in AC and PAC plots for residuals. AIC 
and BIC selection criteria are more negative. We prefer this model*/

la var p1_lnhours "ARIMA(1,1,0) w/ recession"
la var p2_lnhours "ARIMA(0,1,1) w/ recession"


tsline p1_lnhours p2_lnhours if mindex>=tm(2021m1)



********************************************************************************
/*This secton will be used to test the model*/

clear all
set more off

cd "J:\ZachM\12. INTERN PROJECTS\Nikita Project 1"

import excel "New Rev Model Data.xlsx", sheet("Monthly") firstrow case(lower) 

tsset mindex, m

local lastfy 2020
gen qdate = qofd(dofm(ym(cy, m)))
format %tq qdate
order qdate, first

foreach var of varlist emp-retail {
	replace `var'=. if `var'==0 /*replacing 0 values in variables*/
	gen ln`var'=ln(`var')
}














