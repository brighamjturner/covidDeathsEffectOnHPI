capture log close
cd C:\Users\bjt72\Box\dataProject3housePricesOnCovid
log using housePricesOnCovidDeaths.txt, replace text
clear

/*
NAME: Brigham Turner
Data Project 3 */
************************************


/////////////// step 1 getting rural urban continuum codes /////////////////////
//access this from: https://www.ers.usda.gov/data-products/rural-urban-continuum-codes/
import delimited using ruralurbancodes2013.csv, clear
keep rucc_2013 fips
gen rucc_squared = rucc_2013 * rucc_2013
save "urbanRuralCodes.dta", replace

/////////////// step 2 getting mortality rates /////////////////////
//      / part 1 - getting population estimates
//how to get 2021 data:
//https://www.census.gov/data/tables/time-series/demo/popest/2020s-counties-total.html
//click on datasets
//https://www.census.gov/data/tables/time-series/demo/popest/2020s-counties-total.html#par_textimage
//download
import delimited using co-est2021-alldata.csv, clear
gen fips = state * 1000 + county
save "raw2020Populations2.dta", replace
//      / part 2 - getting covid deaths from nytimes
// access this data from here: https://www.nytimes.com/article/coronavirus-county-data-us.html
import delimited using nytCountyDeaths.csv, clear
gen geographicarea = county + ", " + state
collapse (max) deaths  , by(fips)

merge 1:m fips   using raw2020Populations2.dta
 
drop if _merge != 3
//should be multiplied by 100,000 accordign to the cdc https://www.cdc.gov/csels/dsepd/ss1978/lesson3/section3.html
gen mortalityRate = 100000 * deaths / estimatesbase2020

tabstat mortalityRate deaths estimatesbase2020, stat(mean p25 p50 p75 min max)

keep mortalityRate fips
save "mortalityRateByCounty.dta", replace

///////////// step 3, converting zip codes to fip //////////////
// go to https://www.huduser.gov/portal/datasets/usps_crosswalk.html
// select zip-county, for most recent time period
import delimited using ZIP_COUNTY_122021.csv, clear
gen threedigitzipcode = floor(zip/100)
rename county fips // yes, these are fips codes, I checked
keep threedigitzipcode fips usps_zip_pref_state
save "zipToCounty.dta", replace

////////////// step 4, getting housing prices ///////////////
//how to get housing price data:
//go to:
//https://www.fhfa.gov/DataTools/Downloads/Pages/House-Price-Index-Datasets.aspx
//download Three-Digit ZIP Codes (Developmental Index; Not Seasonally Adjusted)
//delete first 6 rows in excel
import delimited using HPI_AT_BDL_ZIP3.csv, clear
//keep if year in (2021, 2019, 2020)
keep if year == 2021 | year == 2020 |year == 2019 | year == 2018 | year == 2017 
tab year
drop annualchange
drop hpiwith1990base
drop hpiwith2000base

reshape wide hpi, i(threedigitzipcode) j(year)

merge 1:m threedigitzipcode   using zipToCounty.dta

keep if _merge == 3
keep fips hpi2017 hpi2018 hpi2019 hpi2020 hpi2021 usps_zip_pref_state
collapse (mean) hpi2017 (mean) hpi2018 (mean) hpi2019 (mean) hpi2020 (mean)hpi2021 (first)usps_zip_pref_state  , by(fips)

////////////// step 5, combining mortality rates, house prices, and urban rural continuum codes ////////
merge 1:1 fips   using mortalityRateByCounty.dta
keep if _merge == 3
drop _merge
merge 1:m fips   using urbanRuralCodes.dta
keep if _merge == 3
drop _merge

tabstat hpi2017 hpi2018 hpi2019 hpi2020 hpi2021, stat(mean p25 p50 p75 min max)

////////////// step 6, generating state variable, do regression, and output results ////////
gen state = floor( fips / 1000)
reg hpi2021 mortalityRate hpi2017 hpi2018 hpi2019 rucc_2013 rucc_squared i.state  , robust
putexcel set resultsRegression.xlsx, sheet(absolutePrices) modify
matrix results = r(table)'
putexcel A1 = matrix(results), names nformat(number_d2)

histogram mortalityRate
rename rucc_2013  Rural_Urban_Continuum_Codes
histogram Rural_Urban_Continuum_Codes

log close


