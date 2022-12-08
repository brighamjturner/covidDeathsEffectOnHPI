capture log close
cd C:\Users\bjt72\Box\dataProject3housePricesOnCovid
log using housePricesOnDeaths2015.txt, replace text
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
//how to mortality rates, go to follow this link to the cdc website and fill out the form
//https://wonder.cdc.gov/controller/datarequest/D140

cd C:\Users\bjt72\Box\dataProject3
import delimited using  CompressedMortality.csv, clear
//should be multiplied by 100,000 accordign to the cdc https://www.cdc.gov/csels/dsepd/ss1978/lesson3/section3.html

gen mortalityRate = 100000 * deaths/population
rename countycode fips
collapse (mean) mortalityRate  , by(fips) //(max) geographicarea
keep mortalityRate fips

save "mortalityRateByCounty.dta", replace

///////////// step 3, preparing to convert zip codes to fip //////////////
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
import delimited using HPI_AT_BDL_ZIP3.csv, clear
keep if year == 2015 | year == 2013 |year == 2012 | year == 2011 
tab year
drop annualchange
drop hpiwith1990base
drop hpiwith2000base

reshape wide hpi, i(threedigitzipcode) j(year)
merge 1:m threedigitzipcode   using zipToCounty.dta

keep if _merge == 3
keep fips hpi2011 hpi2012 hpi2013 hpi2015 
collapse (mean) hpi2011 (mean) hpi2012 (mean) hpi2013 (mean) hpi2015   , by(fips)

////////////// step 5, combining mortality rates, house prices, and urban rural continuum codes ////////
merge 1:1 fips   using mortalityRateByCounty.dta
keep if _merge == 3
drop _merge
merge 1:m fips   using urbanRuralCodes.dta
keep if _merge == 3
drop _merge

////////////// step 6, generating state variable, do regression, and output results ////////
gen state = floor( fips / 1000)
reg hpi2015 mortalityRate hpi2013 hpi2012 hpi2011 rucc_2013 rucc_squared i.state , robust
putexcel set resultsRegression.xlsx, sheet(absolutePrices2015) modify
matrix results = r(table)'
putexcel A1 = matrix(results), names nformat(number_d2)

histogram mortalityRate

log close
