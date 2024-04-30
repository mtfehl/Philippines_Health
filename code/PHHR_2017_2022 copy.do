
						**** OPEN FILE, CLEAN VARIABLES ****

use "data/PH_2017_DHS_08082023_1651_198114/PHKR71DT/PHKR71FL.DTA", clear
* The DHS datasets are labeled according to who the interviewee information is /// 
about. This file is labeled KR, which refers to children of interviewed mothers ///
ages 0-60 months. This dataset thus provides information about both the children ///
 of the interviewed mothers & of the interviewed mothers, which makes it useful ///
 to analyzing data related to children's health.

*Drop empty variables to clear up some memory
foreach var of varlist _all {
     capture assert mi(`var')
     if !_rc {
        drop `var'
     }
} 

* Learned about globals var_list command, going to attempt to try using that to ///
 make a global list of variables, which is updated and appended every time I ///
 rename a variable, that way i can store all the variables i rename and keep ///
 only those from the large data set.
global var_list ""

				*** Renaming & cleaning important variables in the data **
*** Clusters of people interviewed 
ren v001 cluster_number
global var_list "$var_list cluster_number"
sum cluster_number, detail
hist cluster_number, bin(100) freq
* We see that an average cluster group is around 0-15, with the highest being 39

*** Highest education level of the mother
ren v106 educ
global var_list "$var_list educ"

*** Ethnicity
ren v131 ethnicity
global var_list "$var_list ethnicity"

*** Sex of child
ren b4 sex
global var_list "$var_list sex"

*** Whether or not the child is alive (u5-mort rate)
ren b5 alive
global var_list "$var_list alive"

*** The length of the pregnancy in months of the child
ren b20 preg_length
global var_list "$var_list preg_length"

*** Aggregate wealth index
ren v190 wealth_index
global var_list "$var_list wealth_index"

*** Age of the mother at the time of their first child's birth
ren v212 agef_first_birth
global var_list "$var_list agef_first_birth"

*** Whether or not the mother smokes tobacco
ren v463z smoke
global var_list "$var_list smoke"

*** List of regions the mothers live in
ren v101 region
global var_list "$var_list region"

*** Number of births a mother has had in the last 5 years
ren v208 birth_5yr
global var_list "$var_list birth_5yr"

*** Total number of children born to a mother
ren v201 total_births
global var_list "$var_list total_births"

*** Age of the interviewed mother
ren v012 agef
global var_list "$var_list agef"

*** Birthweight of child, in kg
ren m19 bw
global var_list "$var_list bw"

*** Whether or not the child has received any type of vaccination
ren h10 any_vacc
global var_list "$var_list any_vacc"
tab any_vacc
tab any_vacc, nolabel

*** Whether the mother lives in an urban or rural setting
ren v025 rural
global var_list "$var_list rural"

*** Age of the mother at the time of her first birth, converted into months
gen agef_months = agef_first_birth*12
global var_list "$var_list agef_months"
label var agef_months "Mother's age in months"

*** This code below generates a variable where a mother has heard a family ///
planning message in the last 12 months from any source (radio, paper, etc).

* When browsing through the data, we see that the response of "Yes" corresponds /// 
to a value label of 1 and "No" a value label of 0. Using this, we can then  ///
directly write this code using 0 & 1, not having to worry about converting strings.
gen fpmess= 0
replace fpmess= 1 if v384a == 1 | v384b == 1 | v384c == 1 | v384d == 1 | v395 == 1 ///
 | v393a == 1
label var fpmess "Heard of a family planning message in last 12 months?"
global var_list "$var_list fpmess"
global var_list "$var_list v384a-v384d v395 v393a"

*** Vaccinations received by the child
* Tried experimenting with forval loops to rename variables faster --  ///
found some examples online that I used
local count = 1

forval i = 2/9 {
    local newname : word `count' of bcg dpt1 polio1 dpt2 polio2 dpt3 polio3 measles1
    rename h`i' `newname'
    local count = `count' + 1
}
ren h9a measles2
ren h33 vit_a

local count = 1

forval i = 50/66 {
	if `i' >= 57 & `i' <= 59 continue
    local newname : word `count' of hep_b_birth pent1 pent2 pent3 pneum1 pneum2 /// 
	pneum3 polio_inactive hep_b1 hep_b2 hep_b3 hib1 hib2 hib3
    rename h`i' `newname'
    local count = `count' + 1
}
// Now we have all the vaccinations relabeled
global var_list "$var_list bcg dpt1 polio1 dpt2 polio2 dpt3 polio3 measles1 measles2 vit_a hep_b_birth pent1 pent2 pent3 pneum1 pneum2 pneum3 polio_inactive hep_b1 hep_b2 hep_b3 hib1 hib2 hib3"

* Type of contraceptive method being used by mothers
ren v312 contr_method
global var_list "$var_list contr_method"

* Current use of contraception by method type
ren v313 cur_use
global var_list "$var_list cur_use"

* Place of delivery
ren m15 delivery_place
global var_list "$var_list delivery_place"

* Preceding birth interval of the mothers
ren b11 prec_birth_int
global var_list "$var_list prec_birth_int"

* Years of Education (continuous)
ren v107 educ_years
global var_list "$var_list educ_years"

* successfully brought our variable list waaay down.
local keep_vars
foreach var of global var_list {
    local keep_vars "`keep_vars' `var'"
}
keep `keep_vars'

save "data/PH_KR_17.dta", replace 


							 **** VARIABLE STATISTICS ****
						****************************************
						**  REGRESSION MODEL FOR BIRTH WEIGHT **
						****************************************
use "data/PH_KR_17.dta", clear

// DEPENDENT VARIABLE: birth weight of child (in kg) -- continuous variable
sum bw, detail
hist bw, freq
tab bw, sort
* lots of instances with just 1-2 obs -- most obs tend to be in increments of 100
tab bw if mod(bw, 100)==0 , sort plot
tab bw if bw > 6000
tab bw if bw > 6000, nolabel

** We see bw takes on values of 9996 for 'not weighed at birth' and 9998 for /// 
'don't know', which will skew our data as outliers if not dropped

* we have outlier values, which we will deal with in regression analysis. ///
For now, I do not choose to drop these values as it will lower our overall ///
sample size, which might not be ideal for all of our future regressions ///
(some other variables may have all data points, for example, so its unnecessary /// 
to already limit their scope)

* if we drop any missing data points, our sample size will decreased and we now /// 
may run into a problem of our regression not being as accurate as before -- /// 
perhaps the people we dropped are poorer, thus were unable to measure the baby's /// 
weight, or do not have access to a facility and thereby had to give home birth. 

* We will thus create a separate variable with all the dropped observations and /// 
see how that will affect our data set -- im interested in seeing if there are  /// 
patterns for people who do not report the child's birthweight, since these /// 
patterns might tell us that our new data set (with dropped values) is not  ///
accurate for the general population, i.e. our regression gives us results that ///
are different from reality.
gen bw_empty = 0
replace bw_empty = 1 if bw ==. | bw == 9996 | bw == 9998
label var bw_empty "whether or not a child's bw is reported missing by the mother"
br
** bw is unchanged here since we didnt drop the missing observations yet -- 	///
	bw_empty ==1 whenever its a confirmed missing value.

** Here, i wanted to create two way tables to see potential relationships between ///
mothers with missing observations for their children's birthweight & other related /// 
variables such as education level, wealth index, place of delivery, etc.
tab bw if bw > 6000
tab bw_empty

** Twoway: age of mothers and unreported birthweights
tab agef bw_empty, sum()
graph box agef, over(bw_empty)
corr(agef bw_empty)
*no obvious relationship

** Twoway: education level of mothers and unreported birthweights
tab educ bw_empty, sum()
graph bar, over(educ) stack ///
	by(bw_empty)
* we see a weak relationship exists here -- lower educ tend to not report their ///
child's bw in comparison to those who do report it.

** Twoway: wealth index of mothers and unreported birthweights
tab wealth_index bw_empty, sum()
graph bar, over(wealth_index) stack ///
	by(bw_empty)
* seems to be correlation between wealth of mother and reporting bw -- in the ///
case of women not reporting their child's bw, there exist an obvious negative ///
relationship with regards to wealth.

** Twoway: region of mothers and unreported birthweights
tab region bw_empty, sum()
graph bar, over(region) stack ///
	by(bw_empty)
* only skewed region in missing reports seems to be autonomous region 
* could provide some insight about autonomous regions & bw_empty -- ///
not close to health facility

** Decided to pull up place of delivery variable since it might be important here
tab delivery_place
tab delivery_place, nolabel
graph hbar (count), over(delivery_place) xsize(15) ///
	title("Bar Chart of Delivery Places") ///
    ytitle("Count") ///
    blabel(bar, color(bg))
	
** Twoway: delivery place of child and unreported birthweights
tab delivery_place bw_empty, sum()
graph hbar (count), over(delivery_place) stack ///
	by(bw_empty) ///
	xsize(15) ///
	title("Bar Chart of Delivery Places & Reported bw") ///
    ytitle("Count") ///
    blabel(bar, color(bg))
* ding ding ding -- home births and missing bw correlated

** Twoway: region of mothers & delivery place of child
tab region delivery_place, sum()
graph hbar (count), over(delivery_place) ///
	by(region) ///
	xsize(11) ///
	title("Delivery Places by Region") ///
    ytitle("Count") ///
    blabel(bar, color(bg))
*big relationship between autonomous, rural regions & home birth


graph bar, over(delivery_place) stack ///
	by(wealth_index)
	

*** Final insights on missing birthweight reports -- we see from our two-way ///
tables that women who are missing reports on the birthweights of their children ///
tend to be poorer, living in autonomous regions (thus likelier further from a ///
health facility), and often are having home births.

*** These insights allow us to understand that our regression model may be more ///
representative of the population of women who do not fall into these categories ///
so we must take the results with a grain of salt after we drop missing observations.


// Independent Variables:

	/// Length of Pregnancy
	sum preg_length, detail
	tab preg_length
	graph pie, over(preg_length) /// 
	cw title("Distribution of Pregnancy Lengths") /// 
	subtitle("in Months") /// 
	legend(on)
	* Over 97% of births are 9-month range, median = 9 mean = 8.97

	/// Urban binary variable
	tab rural
	tab rural, nolabel
* I see that Urban=1 and Rural=2; we usually like binary variables to be in 0 & 1 ///
for regression ease, and I personally prefer Urban to take on the value of 1. ///
Thus, we must recode the values for each label and generate a new dummy variable.
	recode rural (2=0), gen(urban)
	tab urban
	* We are now missing labels for 0 & 1, however, which we can now add in.
	label define Urban 0 "Rural" ///
		1 "Urban"
	label values urban Urban
	label var urban "mother lives in Urban region"
	tab urban
	tab urban, nolabel
	graph bar (count), over(urban) ///
		title("Bar Chart of Urban v Rural") ///
		ytitle("Count") ///
		blabel(bar)
	
	
	/// Sex of Child
	tab sex
	tab sex, nolabel
* Here, I see that male =1 and female =2. For simplicity in regression, I will ///
recode this to be 0 & 1, respectively.
	recode sex (2=0)
	tab sex
	label define Sex1 0 "female" ///
		1 "male"
	label values sex Sex1
	tab sex
	* about an equal distribution, 47.7% female & 52.3% male children.
	* 47.7% of children are female, 52.3% male -- pretty even distribution
	graph bar (count), over(sex) ///
		title("Bar Chart of Male v Female") ///
		ytitle("Count") ///
		blabel(bar)
	
	/// Ethnicity
	tab ethnicity
	graph bar (count), over(ethnicity) ///
		title("Bar Chart of Filipino Ethnicities") ///
		ytitle("Count") ////
		blabel(bar) ///
		xsize(12)
	*majority tagalog, cebuano, or other. might be interesting graphing this ///
	against region later to see if ethnicities are concentrated in various /// 
	regions of the Philippines.
	
	/// Region
	tab region
	tab region, nolabel
	graph hbar (count), over(region) ///
		blabel(bar) ///
		title("Mothers Interviewed in Regions in Philippines") ///
		scheme(meta)
	
	
	* Pretty equal distribution of mothers interviewed from 16 different regions
	tab region ethnicity, sum()
	*Some regions seem to be very skewed by ethnicity, such as tagalog in the /// 
	capital
	
	/// Mother's Education Level
	sum educ, detail
	tab educ
	tab educ, nolabel
	graph hbar (count), over(educ) ///
		blabel(bar, size(vsmall)) ///
		title("Highest Education Level of Mothers") ///
		scheme(s2color)
	*Most mothers hold some level of education -- less than 2% uneducated, ///
	nearly 50% with a secondary level 
	
	/// Age of mother at first childbirth
	sum agef_first_birth, detail
	tab agef_first_birth
	* Lowest range being 11 years old, highest being 46 years. Median = 21, mean = 21.5
	hist agef_first_birth, bin(30) freq
	
	/// Whether or not the mother smokes tobacco
	tab smoke
	tab smoke, nolabel
	* Nearly 5% of mothers
	* This table is backwards in understanding, since 0 means that the mother ///
	does smoke and 1 means they don't -- so I want to change this for ease of understanding.
	recode smoke (0=1) (1=0)
	tab smoke
	label define Smoke 0 "no" ///
		1 "yes"
	label values smoke Smoke
	label var smoke "mother smokes tobacco"
	tab smoke
	*much better
	graph bar (count), over(smoke) ///
		title("Mothers who Smoke") ///
		ytitle("Count") ///
		blabel(bar)
		
	
	/// The total number of births a mother has given
	sum total_births, detail
	*Median & mean amount is 3
	tab total_births
	hist total_births, bin(18) freq
	* 80% with total births <= 4 , nearly 50% with <=2
	
	/// Age of interviewed mother
	tab agef
	sum agef, detail
	*Avg age: 29.88, median: 29, total: 10,551 mothers interviewed
	hist agef, bin(34) freq
	* 20-40 range seems to be the most dense

save "data/PH_KR_17_new", replace
	
** Standard OLS regression with robust standard errors
reg bw preg_length agef educ sex smoke region urban ethnicity ///
agef_first_birth total_births , vce(r)

estat ic


** Instrumental variables approach -- not sure which model to select here -- ///
second model gives stronger instrument output
* IV Model 1
ivregress 2sls bw preg_length educ sex agef_first_birth smoke (total_births = region)
estat endog
* Strong evidence of rejecting H0 that variables are exogenous -- OLS doesnt work
estat firststage	
* Weak instrument test -- since F>10, we find the instrument to be strong

* IV Model 2
ivregress 2sls bw preg_length agef smoke ///
agef_first_birth (total_births = region)
estat endog
* Strong evidence of rejecting H0 that variables are exogenous -- OLS doesnt work
estat firststage	
* Weak instrument test -- since F>10, we find the instrument to be strong


*** Multilevel model analysis ***
********************************* 

* Declaring the data as panel data
xtset cluster_number
*** Random effects estimator w/ SE's -- multilevel data set (corr b/w groups)
xtreg bw preg_length educ sex smoke region any_vacc, mle
*** Fixed effects estimator -- for longitudinal data set (corr b/w same indiv)
xtreg bw preg_length educ sex smoke region any_vacc, fe


** Correlated Random Effects -- ///
we choose this model since we have multilevel data set, and we want to account ///
for corr b/w independent vars & community level error term
* This data set is grouped by clusters (cluster_number)

* MULTILEVEL MODEL 1 -- all variables
xtmixed bw preg_length educ sex smoke region || cluster_number:, cov(unstructured)
estat ic
* MULTILEVEL MODEL 2 -- drop high p-value variables
xtmixed bw agef educ smoke region urban ethnicity ///
agef_first_birth total_births || cluster_number:, cov(unstruct)
estat ic
* AIC & BIC Fall 66 points, suggesting a great improvement in model selection ///
with model 2. Rule of thumb: >2 decrease in AIC/BIC suggests model improvement


						****************************************
						** PROBIT MODEL FOR UNDER-5 MORTALITY **		
						****************************************
	
use "data/PH_KR_17_new", clear
	
*Hypothesis: UNDER-5 children with less vaccinations are more likely to die /// 
than those with more vaccinations

*** DEPENDENT VARIABLE *** /// 
whether or not the child is alive 0-60months after birth (binary)
tab alive

* We see here that the u5-mortality rate is about 2.41%, about 24 infants per 1,000


*** Independent Variables ***

	/// Mother's Education Level
	sum educ, detail
	tab educ
	tab educ, nolabel
	graph hbar (count), over(educ) ///
		blabel(bar, size(vsmall)) ///
		title("Highest Education Level of Mothers") ///
		scheme(s2color)
	* Most mothers hold some level of education -- less than 2% uneducated, ///
	nearly 50% with a secondary level
	* We want to treat education as a categorical variable rather than a ///
	continuous one, since their categories are likely to have a non-linear ///
	outcome with the outcome.
	
	/// Pregnancy length of the child
	sum preg_length, detail
	tab preg_length
	graph bar, over(preg_length) ///
		title("Distribution of Pregnancy Lengths") ///
		subtitle("in Months") ///
		ytitle("Percentage") ///
		blabel(bar)
	* Over 97% of births are 9-month range, median = 9 mean = 8.97
	
	/// Total number of births by a mother 
	sum total_births, detail
	tab total_births
	*80% of mothers have had <= 4 children born, =2 children being the most common
	* median = 3 mean = 3.1
	hist total_births, bin(18) freq

	/// Number of births in the last 5 years
	tab birth_5yr
	hist birth_5yr, bin(6) freq
	* 36.8% of mothers have had =2 births in last 5yr, 54.5% =1 birth in last 5yr

	/// Aggregate wealth index of the mother (or maybe the household), broken into 5 categories
	tab wealth_index
	tab wealth_index, nolabel
	sum wealth_index, detail
	* We see the median wealth index is "poorer", and the average is 2.3 which /// 
	is between "poorer" and "middle", likely translating to lower-middle class ///
	in U.S. terms.
	graph bar, over(wealth_index) ///
		blabel(bar)
	
	/// Whether or not the mother smokes tobacco
	tab smoke
	graph bar, over(smoke) ///
		title("Mothers who Smoke Tobacco") ///
		ytitle("percentage") ///
		blabel(bar)
	* Nearly 5% of women do
	
	/// Whether or not the child has received any vaccinations at all
	tab any_vacc
	tab any_vacc, nolabel
	gen any_vacc_binary = .
		replace any_vacc_binary = 0 if any_vacc == 0
		replace any_vacc_binary = 1 if any_vacc == 1
		label define Any_Vacc 0 "no" ///
			1 "yes"
		label values any_vacc_binary Any_Vacc
		label var any_vacc_binary "whether child has received vacc, excluding 'don't know'"
		tab any_vacc_binary
	graph bar, over(any_vacc_binary) ///
		blabel(bar)
* Here we see missing data points labeled as "don't know," which take on the ///
value of 8. Thus, we need to drop these observations to not skew our results.
* This, however, drops our sample size way down as we only observe 2160 responses ///
before dropping "don't know", bringing the total down to 2129.
						
probit alive educ preg_length wealth_index region total_births birth_5yr agef any_vacc
* When trying to add any_vacc variable into regression model, it falls apart.
 
*Upon inspection of the data, using the following command to generate a two-way ///
table between alive & any_vacc, I find the problem.
tab alive any_vacc, sum()
br

* Only children that are alive have data about their vaccination history. ///
I found this interesting, because since the range of children in the data set is ///
from 0-60 months, I would've expected to find results where there existed ///
deceased children who were previously vaccinated. Thus, I need to create a new ///
hypothesis for u5-mortality.

* This limits our regression capabilities a lot by the data set -- we cannot ///
fully explain u5_mortality rates without vaccination status, as literature ///
suggests this is a significant factor in the death of newborns. We also lack ///
data on nutrition in this case, so we can expect a model that works, but is not ///
the 'best fitting' of the data.
tab alive delivery_place, sum()
*Not much of a pattern between place of delivery and alive -- I think my new ///
hypothesis is that mothers that smoke tobacco tend to have a higher u5-mortality ///
rate with their children than those who don't smoke.


probit alive i.educ preg_length total_births birth_5yr agef i.smoke wealth_index 
* high LR chi2 and strong rejection of null (that all the regressors are jointly ///
zero) give evidence that the model outperforms a null model much better
estat gof, group(10)
* we want a low chi2 score and to not be statistically signficant -- which shows ///
 this regression model fits well.
*estat class

*** We see that whether a mother smokes or not has no statistically significant ///
impact on the log odds of whether or not a child is likelier to be alive 0-60 ///
months after birth. We see the most important factor is the length of pregnancy, ///
which has a positive impact -- i.e. the longer the pregnancy length, the likelier ///
the child is to be alive. This is supported by much of the literature online ///
about u5 mortality and the most significant factors.

* The total number of births by the mother, and the number of births in the last ///
5 years are all significant in the u-5 mortality rate, whereas the age of the ///
mother & her education level are not statistically significant.

					** Continuous Variables Marginal Effects ** 			
					
margins, dydx(preg_length)
* Here, we find that the marginal effect of being pregnant for one additional ///
month increases the likelihood of the child being alive by 3.8%; significant at ///
all standard levels. Huge test statistic indicates this is a significant factor ///
in u5-mortality. This follows literature that suggest that premature birth is a ///
significant risk factor in the u5-mortality rate.

margins, dydx(total_births)
* We can see here that one additional child being borne by a mother decreases ///
the log odds of child survival (0-60 months) by 0.28%.

margins, dydx(birth_5yr)
* Each additional child borne to a mother in the last 5 years decreases the log ///
odds of child survival (0-60 months) by 0.6%.


					** Binary Variable Marginal Effects **
margins smoke
margins smoke, contrast
* tiny chi2 & rejection of the null tells us that smoking is statistically ///
insignificant in the log odds of u5-mortality.
margins smoke, pwcompare
* We see that the difference between the log odds a child will be alive 0-60 ///
months after birth for mothers who smoke versus those who do not smoke is 0.14%, ///
an insignificant difference.
margins educ
marginsplot, xdimension(educ)
margins educ, contrast
margins educ, pwcompare



					***************************************************
					** MULTINOMIAL LOGIT MODEL FOR CONTRACEPTIVE USE **
					***************************************************
use "data/PH_KR_17_new", clear			
*Hypothesis1: Those who have heard of a family planning message within the last ///
12 months are more likely to be using contraception

*Hypothesis2: Those who have heard fpmess <= 12months are more likely to be ///
using a modern approach to contraception


***** independent variable of interest: i.fpmess
tab fpmess
sum fpmess, detail
*nearly 82% of women respondants have heard of a fpmess in the last 12 months, ///
by any of the possible means (radio, tv, fieldworker, health facility, etc) 
tab wealth_index fpmess
tab agef fpmess
tab urban fpmess
tab region fpmess
* no obvious relationships with hearing a fpmess

*** Model 1: fpmess effect on using different contraceptive forms ***
* Here we find the variable for the type of contraceptive method being used by ///
mothers of the interviewed children.
tab contr_method
tab contr_method, nolabel
* After inspecting the variable categories, we notice that there seem to be ///
random jumps in associated values. To make the value of each category more ///
intuitive with just a simple +1 increase, we need to recode the values.
recode contr_method (5=4) (6=5) (8=6) (9=7) (10=8) (11=9) (13=10) (14=11) (18=12) (20=13)
tab contr_method, nolabel
tab contr_method
label define contr_values 0 "not using" ///
	1 "pill" ///
	2 "iud" /// 
	3 "injections" ///
	4 "male condom" ///
	5 "female sterilization" ///
	6 "calendar or rhythm method/periodic abst" ///
	7 "withdrawal" /// 
	8 "other traditional method" /// 
	9 "implants/norplant" /// 
	10 "lactational amenorrhea (lam)" ///
	11 "female condom" /// 
	12 "standard days method (sdm)" ///
	13 "mucus/billing/ovulation"
label values contr_method contr_values
tab contr_method
* Now we find a uniform labeling of the categories, which will make looking at ///
marginal effects and ATEs much easier in our regression analysis.

mlogit contr_method urban i.educ i.fpmess wealth_index agef 

estimates store all
tab contr_method
tab contr_method, nolabel
* ATE on hearing fpmess on using pill relative to not using contraception 
margins fpmess,predict(outcome(1))
margins fpmess,predict(outcome(1)) contrast
margins fpmess,predict(outcome(1)) pwcompare

* ATE on hearing fpmess on using IUD relative to no use
margins fpmess,predict(outcome(2))
margins fpmess,predict(outcome(2)) contrast
margins fpmess,predict(outcome(2)) pwcompare

* Marginal effect of different educ levels on using pill relative to no use, ///
relative to no education
tab educ
margins educ, predict(outcome(1))
margins educ, predict(outcome(1)) contrast
margins educ, predict(outcome(1)) pwcompare
*statistically significant results, and we see that each increasing, relative ///
education category is more likely to use a pill rather than no contraceptive use, ///
other than higher vs secondary levels, which happens to have an inverse relationship.

* Marginal effect on age of mother on likelihood of using pill relative to no use
margins, dydx(agef) predict(outcome(1))
** we see for each +1yr in age, a mother is less likely to using a pill (relative ///
to no contraceptive use) by 0.34%, at all significant levels


*** Model 2: fpmess effect on contraceptive method type ***

* The next variable of interest is the currest use of contraception by method ///
type. This is a much simple multinomial logit dependent variable to analyze.
tab cur_use
tab cur_use, nolabel
* When we tabulate these results, we see two things right away -- the first ///
being that there are no respondants using folkloric methods of contraceptive use, ///
so we can recode the latter two responses to make the values more uniform. 
recode cur_use (2=1) (3=2)
label define cur_use_values 0 "no method" ///
	1 "traditional method" ///
	2 "modern method"
label values cur_use cur_use_values
tab cur_use
tab cur_use, nolabel
* Secondly, we see that there is a 100% response rate to this question, making ///
it great for analysis as we will not have to drop any missing values. My first ///
thought here is that this will be great for twoway tables; for example:
tab agef cur_use
tab urban cur_use
* we see autonomous regions tend to use no contraception
tab wealth_index cur_use

gen age15_24=agef<25
gen age25_34=agef>24&agef<35
gen age35_44=agef>34&agef<45
gen age45_plus=agef>44

gen age_cat=.
replace age_cat=1 if age15_24==1
replace age_cat=2 if age25_34==1
replace age_cat=3 if age35_44==1
replace age_cat=4 if age45_plus==1


mlogit cur_use i.educ i.wealth_index i.age_cat urban agef i.fpmess, baseoutcome(0)
* people in each higher educ level are likelier to be using a traditional ///
contraceptive method rather than no contraception, relative to those with no ///
education levels. same with wealth, urban, and fpmess.

* same educ results for modern contraceptive method type use compared to no use ///
at all. age and fpmess tend to be important factors to consider here as well. ///
The higher the age category, however, we notice that women are less likely to be ///
using modern contraceptive methods in comparison to no methods at all.
** could make sense -- older women might be less likely to bear children, ///
especially if already went through menopause

mlogit cur_use i.educ i.wealth_index i.age_cat urban agef i.fpmess, baseoutcome(1)
* when we compare using modern methods relative to using traditional methods, we ///
see that education is not an important factor, but rather wealth, age, and fpmess.

mlogit cur_use i.educ wealth_index i.age_cat urban agef i.fpmess, baseoutcome(0) rrr
* relative risk ratio -- if rrr > 1, for an increase in the given IV, there is ///
an increased risk that the outcome is in the compared category

* rule of thumb: if the coefficient b<0, rrr<1; b>0, rrr>1; b=0, rrr=1.

* for example, we see for fpmess for traditional method category the RRR >1, ///
indicating that people who have heard of a fpmess in the last 12 months are 1.32x ///
more likely ("at higher risk") to be using traditional contraceptive method type, ///
relative to no use.
* mothers who have heard a fpmess in the last 12 months are 1.68x more likely to ///
be using a modern contraceptive method type at all significance levels, relative ///
to not using any contraception.

margins fpmess, predict(outcome(1))
margins fpmess, predict(outcome(1)) contrast
margins fpmess, predict(outcome(1)) pwcompare
* no significant effect of fpmess on traditional use, relative to no use

margins fpmess, predict(outcome(2))
margins fpmess, predict(outcome(2)) contrast
margins fpmess, predict(outcome(2)) pwcompare
*significant effect of fpmess on modern use, relative to no use. 10.99% difference ///
in going from no use to a modern contraceptive type after hearing a ///
fpmess in <= 12months. important policy effectiveness finding!!


