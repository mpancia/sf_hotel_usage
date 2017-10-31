# San Francisco Hotel Usage Data

## Background 
This repository contains Annual Unit Usage Report Status (AAURS) data from both for-profit and non-profit hotels in San Francisco. This data is self-reported and a requirement of [Chapter 41](http://library.amlegal.com/nxt/gateway.dll/California/administrative/chapter41residentialhotelunitconversiona?f=templates$fn=default.htm$3.0$vid=amlegal:sanfrancisco_ca$anc=JD_41.10) of the San Francisco Administrative Code.

Every year, hotels are required to report:

* The total number of units in the hotel as of October 15 of the year of filing;
* The number of residential and tourist units as of October 15 of the year of filing;
* The number of vacant residential units as of October 15 of the year of filing; if more than 50% of the units are vacant, explain why;
* The average rent for the residential hotel units as of October 15 of the year of filing;
* The number of residential units rented by week or month as of October 15 of the year of filing; and
* The designation by room number and location of the residential units and tourist units as of October 15 of the year of filing, along with a graphic floorplan reflecting room designations for each floor. The owner or operator shall maintain such designated units as tourist or residential units for the following  year unless the owner or operator notifies in writing the Department of Building Inspection of a redesignation of units; the owner or operator may redesignate units throughout the year, provided they notify the Department of Building Inspection in writing by the next business day following such redesignation,  and update the graphic floorplan on file with the Department of Building Inspection and maintain the proper number of residential and tourist units at all times. The purpose of this provision is to simplify enforcement efforts while providing the owner or operator with reasonable and sufficient flexibility in  designation and renting of rooms;
* The nature of services provided to the permanent residents and whether there has been an increase or decrease in the services so provided;
* A copy of the Daily Log, showing the number of units which are residential, tourist, or vacant on the first Friday of each month of the year of filing.

## Contents of data

The data is obtained from reports created on  July 18th and August 29th, 2017, based on AAURS data that was due Nov 1, 2016. See the data dictionary section below for descriptions of the fields in the output data.

This data was obtained on October 26th, 2017 upon e-mail request from the Department of Building Inspection of San Francisco. 

**NB:** There are some minor problems with the data:

1. There are 2 properties that have a changing address from July/August in the data, and 1 property that has a changing block number. This is likely due to manual error, but they seem to represent the same property.
2. There is no change in the non-profit report from July/August, so the final joined file contains all of the information about non-profit hotels. 

# Usage

The raw data is found in the file `/data/2016_Annual_Data_Comparison.xls`. 

## Parsing data

The raw data can be parsed by running the R script `R/parse_data.R`. There are some dependencies which are managed by `packrat`, and the easiest way to get everything working is to use `RStudio` and open up the `Rproj` file in this folder. From there, you can simply open `parse_data.R` and run it from within RStudio.  

## Viewing data

The parsed data can be viewed in CSV form in the `data` folder. There are 2 files for each month:

1. `for_profit_MONTH_2017.csv` 
2. `non_profit_MONTH_2017.csv`

And 2 joined files:

1. `for_profit_joined.csv`
2. `non_profit_joined.csv`

# Data dictionary

| Column Name | Description | Type | 
| --- | --- | --- | 
| TYPE_hotel_id | The ID of the hotel, either non_profit or for_profit | INTEGER | 
| address_number | The address number of the hotel | NUMERIC | 
| address_street | The street of the hotel | TEXT |  
| block_lot | The block lot ID of the hotel | TEXT | 
|cofu_tourist|The number of tourist units allowed in the certificate of use | NUMERIC | 
|cofu_residential|The number of residential units allowed in the certificate of use | NUMERIC | 
|reported_occupied_residential |The reported number of occupied residential units | NUMERIC | 
|reported_occupied_tourist |The reported number of occupied tourist units | NUMERIC | 
|total_reported_hotel_units | The reported total number of units | NUMERIC | 
|vacant_residential|The number of vacant residential units | NUMERIC | 
|vacant_tourist|The number of vacant tourist units | NUMERIC | 
|average_rent_dollars | The average rent for the residential hotel units| NUMERIC (dollars) | 
| auur_filing_received | Whether or not the AAUR filing was received. | LOGICAL | 
| auur_sufficient | Whether or not the AAUR filing was sufficient for compliance. | LOGICAL | 
| became_compliant | If there was a status change in the compiance between July and August | LOGICAL | 
