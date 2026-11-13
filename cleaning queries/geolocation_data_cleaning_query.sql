/*
  GEOLOCATION DATASET CLEANING

  The Data Cleaning pipeline will be broken down into the following steps:

  STEP 1: Completness Check
  STEP 2: Zip Codes Standardization
  STEP 3: Zip Code Duplicate Removal
  STEP 4: City Name Normalization
  STEP 5: State Name Standardization

  The pipeline is executed through a chained CTE, with every step from 1 to
  4 performed by a dedicated CTE.

*/

CREATE TABLE `sales-analysis-511312.cleaned_sales_dataset.CLEANED_GEOLOCATION_DATASET` AS
WITH

/*
  STEP 1: Completness Check
  Check Missing Values on the keys: geolocation_zip_code_prefix, geolocation_city, geolocation_state
  The following query was used to perform this task:

  SELECT 
    COUNT(*) AS total_rows,
    COUNTIF(geolocation_zip_code_prefix IS NULL) AS missing_zipcode,
    COUNTIF(geolocation_city IS NULL) AS missing_city,
    COUNTIF(geolocation_state IS NULL) AS missing_zip_state,
  FROM `sales-analysis-511312.sales_datasets.OLIST_GEOLOCATION`  

  Only the records having non-null values for the three attributes are kept.
*/

step_1 AS (
  SELECT *
  FROM `sales-analysis-511312.sales_datasets.OLIST_GEOLOCATION`
  WHERE 
    geolocation_zip_code_prefix IS NOT NULL
    AND geolocation_city IS NOT NULL
    AND geolocation_state IS NOT NULL
),


/*
  STEP 2: Zip Codes Standardization
  Brazilian datasets where zip codes are represented by their first 5 digits (CEP).
  Because zip codes often get imported as integers, a zip code starting with 0
  (e.g., 01000) loses its leading zero and becomes 1000. They should always resolve 
  to 5 digits and contain only numbers. Plausible Range: Brazilian zip code prefixes
  range from 01000 to 99999.
*/


step_2 AS (
    SELECT 
        -- 1. Ensure it's converted to a string and padded back to 5 digits if leading zeros were lost
        LPAD(CAST(SAFE_CAST(geolocation_zip_code_prefix AS INT64) AS STRING), 5, '0') AS geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state,
    FROM 
        step_1
    WHERE 
        -- 2. Filter out NULLs or completely blank values
        geolocation_zip_code_prefix IS NOT NULL
        -- 3. Ensure the value is strictly numeric (5 digits long)
        AND REGEXP_CONTAINS(CAST(geolocation_zip_code_prefix AS STRING), r'^[0-9]{1,5}$')
        -- 4. Optional: Ensure it fits within plausible numeric range limits (1000 to 99999)
        AND SAFE_CAST(geolocation_zip_code_prefix AS INT64) BETWEEN 1000 AND 99999
),


/*
  STEP 3: Zip Code Duplicate Removal
  From a first analysis it emerges that for the same tuple (geolocation_state, geolocation_zip_code_prefix)
  several combinations of (geolocation_lng, geolocation_city) are available. The analysis 
  that will be performed on the dataset will not require multiple values of (geolocation_lng, geolocation_city)
  for the same zip code. Because of this only one record per zip code is kept.
*/


step_3 AS (
  SELECT 
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state,
    ROW_NUMBER() OVER (
      PARTITION BY geolocation_zip_code_prefix 
      ORDER BY geolocation_lat ASC, geolocation_lng ASC
    ) AS row_num
  FROM 
    step_2
),


/*
  STEP 4: City Name Normalization
  Many cities are present in the geolocation_city with the same letters but different accents.
  This problem is fixed through NFD unicode normalization, which strips the accents form 
  the city names.
*/


step_4 AS (
  SELECT 
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_state,
        -- 1. NORMALIZE(..., NFD) splits accented letters into base characters + accent marks
        -- 2. REGEXP_REPLACE removes all accent marks (\p{M})
        -- 3. LOWER converts everything to lowercase for full consistency
    LOWER(
      REGEXP_REPLACE(
        NORMALIZE(geolocation_city, NFD), 
        r'\p{M}', 
        ''
      )
    ) AS geolocation_city
  FROM step_3
  WHERE row_num = 1
)


/*
  STEP 5: State Name Standardization
  All of the values of geolocation_state where screened for the presence of
  non alphabetical characters and string's length greater than 2 with the following query:

  SELECT 
    geolocation_zip_code_prefix,
    geolocation_city,
    geolocation_state,
    CHAR_LENGTH(geolocation_state) AS state_length
  FROM 
    step4
  WHERE 
    REGEXP_CONTAINS(geolocation_state, r'[^a-zA-Z]') 
    OR CHAR_LENGTH(geolocation_state) > 2;

  The query didn't return any records, which means the values of geolocation_state are
  already in the desired format.
*/


/*
  FINAL STEP: Materialize the final clean table
*/

SELECT *
FROM step_4;



