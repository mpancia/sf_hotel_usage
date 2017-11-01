library(tidyverse)
library(sf)
library(magrittr)
library(ggmap)
library(glue)
library(here)
library(curl)
library(futile.logger)

# Set data/log directories
DATA_DIR <- here("data")
LOG_DIR <- here("logs")

# Read in parcel information from SF Open Data, downloading locally if it doesn't exist
PARCEL_DATA_LOCATION <-
  "https://data.sfgov.org/api/geospatial/us3s-fp9q?method=export&format=GeoJSON"
PARCEL_SAVE_DATA_LOCATION <-
  glue("{data_dir}/parcel_data.json", data_dir = DATA_DIR)

if (!file.exists(PARCEL_SAVE_DATA_LOCATION)) {
  curl_download(PARCEL_DATA_LOCATION, PARCEL_SAVE_DATA_LOCATION)
}

parcels <- st_read(PARCEL_SAVE_DATA_LOCATION,
                   stringsAsFactors = FALSE)

# Fix data type of street addresses in parcel data
parcels %<>%
  mutate(from_st = as.numeric(from_st)) %>%
  mutate(to_st = as.numeric(to_st))


FILENAMES <- c("for_profit_jul_2017", "for_profit_aug_2017")

# Function to process each file
process_file <- function(FILENAME) {
  # Set save location and logger
  LOG_LOCATION <- glue("{log_dir}/{filename}_log.txt",
                       filename = FILENAME,
                       log_dir = LOG_DIR)
  DATA_LOCATION <- glue("{data_dir}/{filename}.csv",
                        data_dir = DATA_DIR,
                        filename = FILENAME)
  flog.logger("logger", INFO, appender = appender.file(LOG_LOCATION))
  # Read in hotel data
  hotels <- read_csv(DATA_LOCATION)


  # Split out the block specification in the DBI data
  hotels %<>%
    separate(block_lot, c("block_num", "lot_num", "unit_num"), sep = " ")

  flog.info(glue("There are {num} total hotels.", num = nrow(hotels)), name = "logger")

  # Join on the block specification
  block_join_hotels <- hotels %>%
    inner_join(parcels, by = c("block_num" = "block_num", "lot_num" = "lot_num")) %>%
    filter(address_number >= from_st) %>%
    filter(address_number <= to_st) %>%
    st_as_sf() %>%
    mutate(wkt = st_as_text(geometry)) %>%
    as.data.frame

  flog.info(glue(
    "There are {num} hotels joined by block number.",
    num = nrow(block_join_hotels)
  ),
  name = "logger")

  # Find unmatched hotels
  unmatched_hotels <- hotels %>%
    filter(!for_profit_hotel_id %in% block_join_hotels$for_profit_hotel_id)

  flog.info(glue(
    "There are {num} hotels unmatched by block number.",
    num = nrow(unmatched_hotels)
  ),
  name = "logger")

  # Create an address string to geocode
  unmatched_hotels %<>%
    mutate(
      address = glue(
        "{number} {street}, SAN FRANCISCO, CA",
        number = address_number,
        street = address_street
      )
    )

  # Geocode the addresses in the DBI data using DSTK
  unmatched_addresses <-
    geocode(unmatched_hotels$address,
            output = "latlon",
            source = "dsk")
  # Add the geocoded addresses to the DBI data
  unmatched_hotels %<>%
    bind_cols(unmatched_addresses)
  # Filter out hotels that were not coded
  geocoded_hotels <- unmatched_hotels %>%
    filter(!is.na(lat)) %>%
    st_as_sf(coords = c("lon", "lat")) %>%
    st_set_crs(st_crs(parcels)$epsg)

  # Spatial join with the parcel data to find which parcels the geocoded points are contained in
  containment <- st_contains(parcels, geocoded_hotels, sparse = F)
  join_matches <- apply(
    X = containment,
    FUN = function(x)
      which(x == TRUE),
    MARGIN = 2
  )
  geocoded_hotels$matched_index <- join_matches
  geocode_joined <- geocoded_hotels %>%
    filter(matched_index > 0) %>%
    mutate(matched_index = unlist(matched_index)) %>%
    as.data.frame() %>%
    select(-geometry)

  geocode_match_parcels <- parcels[geocode_joined$matched_index,]
  geocode_joined %<>%
    bind_cols(geocode_match_parcels) %>%
    st_as_sf() %>%
    mutate(wkt = st_as_text(geometry)) %>%
    as.data.frame() %>%
    select(colnames(hotels), wkt)

  flog.info(glue(
    "There are {num} hotels found by geocoding.",
    num = nrow(geocode_joined)
  ),
  name = "logger")

  # For those that don't match, make a small 10m box around the lat/lon as a proxy for the parcel
  # Requires temporary conversion to a CRS that uses meters as the unit - UTM10 26910
  imputed_geocoded <- geocoded_hotels %>%
    filter(!for_profit_hotel_id %in% geocode_joined$for_profit_hotel_id) %>%
    st_transform(26910) %>%
    mutate(wkt = st_as_text(st_buffer(geometry, 10))) %>%
    as.data.frame() %>%
    st_as_sf(wkt = "wkt") %>%
    st_set_crs(26910) %>%
    st_transform(st_crs(parcels)$epsg) %>%
    as.data.frame() %>%
    mutate(wkt = st_as_text(wkt)) %>%
    select(colnames(hotels), wkt)

  flog.info(glue(
    "There are {num} hotels with imputed shapes.",
    num = nrow(imputed_geocoded)
  ),
  name = "logger")

  # Join everything and convert back to sf after converting LOGI columns to integer
  all_joined <-
    bind_rows(geocode_joined, block_join_hotels, imputed_geocoded) %>%
    select(colnames(hotels), wkt) %>%
    mutate_at(c("aaur_filing_received", "aaur_sufficient"), as.integer) %>%
    st_as_sf(wkt = "wkt") %>%
    st_set_crs(st_crs(parcels)$epsg)

  # Save to GeoJSON
  st_write(
    obj = all_joined,
    dsn = paste0(here("data"), "/", FILENAME, ".json"),
    driver = "GeoJSON",
    delete_dsn = TRUE
  )
}

# Process the files
out <- lapply(FILENAMES, process_file)
