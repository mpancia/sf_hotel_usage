library(here)
library(tidyverse)

# A function to recode Yes/No strings to TRUE/FALSE booleans
yes_to_boolean <- function(col){
  col %>%
    forcats::fct_recode("TRUE" = "Yes", "FALSE" = "No") %>%
    as.logical}

# Define location of raw data and size of tables
XLS_DATA_LOCATION <- here("data", "2016_Annual_Data_Comparison.xls")
NUM_FOR_PROFIT_HOTELS <- 404
NUM_NON_PROFIT_HOTELS <- 96

# Define column ranges
FOR_PROFIT_JUL_2017_RANGE <- "A9:M412"
FOR_PROFIT_AUG_2017_RANGE <- "O9:AB412"
NON_PROFIT_JUL_2017_RANGE <- "A420:F515"
NON_PROFIT_AUG_2017_RANGE <- "O420:T515"
range_list <- list(FOR_PROFIT_JUL_2017_RANGE, FOR_PROFIT_AUG_2017_RANGE, NON_PROFIT_JUL_2017_RANGE, NON_PROFIT_AUG_2017_RANGE )

# Define the column names
FOR_PROFIT_JUL_2017_COLUMNS <- c("for_profit_hotel_id",
                             "address_number",
                             "address_street",
                             "block_lot",
                             "cofu_residential",
                             "cofu_tourist",
                             "reported_residential",
                             "reported_tourist",
                             "vacant_residential",
                             "vacant_tourist",
                             "total_reported_hotel_units",
                             "aaur_filing_received",
                             "aaur_sufficient")
# AUG_2017 has an extra column for the average rent
FOR_PROFIT_AUG_2017_COLUMNS <- FOR_PROFIT_JUL_2017_COLUMNS %>%
  append("average_rent_dollars", 11)
# The columns for the non-profits are the same
NON_PROFIT_AUG_2017_COLUMNS <- FOR_PROFIT_AUG_2017_COLUMNS %>%
  replace(1, "non_profit_hotel_id") %>%
  head(6)
NON_PROFIT_JUL_2017_COLUMNS <- FOR_PROFIT_JUL_2017_COLUMNS %>%
  replace(1, "non_profit_hotel_id") %>%
  head(6)
column_list <- list(FOR_PROFIT_JUL_2017_COLUMNS, FOR_PROFIT_AUG_2017_COLUMNS, NON_PROFIT_JUL_2017_COLUMNS, NON_PROFIT_AUG_2017_COLUMNS )

# Define the column types
FOR_PROFIT_JUL_2017_TYPES <- c("numeric",
                           "numeric",
                           "text",
                           "text",
                           "numeric",
                           "numeric",
                           "numeric",
                           "numeric",
                           "numeric",
                           "numeric",
                           "numeric",
                           "text",
                           "text"
                           )
# AUG_2017 has an extra column for rent which is numeric
FOR_PROFIT_AUG_2017_TYPES <- FOR_PROFIT_JUL_2017_TYPES %>%
  append("numeric", 11)
# Non-profits don't report vacancy rates or compliance, so only the first 6 columns are populated
NON_PROFIT_JUL_2017_TYPES <- FOR_PROFIT_JUL_2017_TYPES %>%
  head(6)
NON_PROFIT_AUG_2017_TYPES <- FOR_PROFIT_AUG_2017_TYPES %>%
  head(6)

type_list <- list(FOR_PROFIT_JUL_2017_TYPES,
                  FOR_PROFIT_AUG_2017_TYPES,
                  NON_PROFIT_JUL_2017_TYPES,
                  NON_PROFIT_AUG_2017_TYPES)

# Read in the data by mapping over the ranges, columns, and types of the 4 tables
data_list <- purrr::pmap(list(range_list, column_list, type_list),
     function(range,columns,types) readxl::read_xls(XLS_DATA_LOCATION,
                                      range = range,
                                      col_names = columns,
                                      col_types = types))
# Convert the "aaur_sufficient" and "aaur_filing_received" columns to boolean from Yes/No
data_list[[1]] <- data_list[[1]] %>%
  mutate_at(c("aaur_sufficient", "aaur_filing_received"), yes_to_boolean)
data_list[[2]] <- data_list[[2]] %>%
  mutate_at(c("aaur_sufficient", "aaur_filing_received"), yes_to_boolean)

split_insert <- function(x, text, position) {
  split_string <- strsplit(x, "_")[[1]]
  added_string <- append(split_string, text, position)
  paste(added_string, collapse = "_")
}

# Rename the "reported_residential" and "reported_tourist" columns to be more obvious
data_list[[1]] <- data_list[[1]] %>%
  rename("reported_occupied_residential" = reported_residential,
         "reported_occupied_tourist" = reported_tourist)
data_list[[2]] <- data_list[[2]] %>%
  rename("reported_occupied_residential" = reported_residential,
         "reported_occupied_tourist" = reported_tourist)

# Check for length
assertthat::assert_that(nrow(data_list[[1]]) == NUM_FOR_PROFIT_HOTELS)
assertthat::assert_that(nrow(data_list[[2]]) == NUM_FOR_PROFIT_HOTELS)
assertthat::assert_that(nrow(data_list[[3]]) == NUM_NON_PROFIT_HOTELS)
assertthat::assert_that(nrow(data_list[[4]]) == NUM_NON_PROFIT_HOTELS)

# Join the monthly tables
joined_for_profit <- inner_join(data_list[[1]], data_list[[2]],
                                by = c("for_profit_hotel_id",
                                       "cofu_residential",
                                       "cofu_tourist"),
                                suffix = c("_july", "_august")) %>%
  mutate(became_compliant = if_else((aaur_sufficient_august == TRUE) & (aaur_sufficient_july == FALSE), TRUE, FALSE))

joined_non_profit <- inner_join(data_list[[3]], data_list[[4]],
                                by = c("non_profit_hotel_id",
                                       "address_number",
                                       "address_street",
                                       "block_lot",
                                       "cofu_residential",
                                       "cofu_tourist"),
                                suffix = c("_july", "_august"))

# Check length
assertthat::assert_that(nrow(joined_for_profit) == NUM_FOR_PROFIT_HOTELS)
assertthat::assert_that(nrow(joined_non_profit) == NUM_NON_PROFIT_HOTELS)

# Write separate files to CSV
data_name_list <- c("for_profit_jul_2017", "for_profit_aug_2017", "non_profit_jul_2017", "non_profit_aug_2017")
data_list <- pmap(list(data_list, data_name_list),
     function(data, name) write_csv(x = data, path = here("data", paste0(name,".csv"))))

# Write joined files to CSV
joined_for_profit %>%
  write_csv(path = here("data", "for_profit_joined.csv"))

joined_non_profit %>%
  write_csv(path = here("data", "non_profit_joined.csv"))
