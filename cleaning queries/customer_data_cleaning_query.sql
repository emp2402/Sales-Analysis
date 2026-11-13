/*
  CUSTOMERS DATASET CLEANING

  The Data Cleaning pipeline will be broken down into the following steps:

  Step 1a) Completeness Check
  Step 1b) Duplicate Check
  Step 2) Zip Codes Standardization
  Step 3) Zip Codes Availability 
  Step 4) City and State Retrieval

  The pipeline is executed by a chained CTE, with the
  first three steps performed by a CTE.
*/

CREATE TABLE `sales-analysis-511312.cleaned_sales_dataset.CLEANED_CUSTOMER_DATASET` AS
WITH

/*
  STEP 1a: Completness check
  Check Missing Values on the keys: customer_id, customer_unique_id, customer_zip_code_prefix
  This is done with the following block of code:

  SELECT
    COUNT(*) AS total_rows,
    COUNTIF(customer_id IS NULL) AS missing_costumer_id,
    COUNTIF(customer_unique_id IS NULL) AS missing_costumer_unique_id,
    COUNTIF(customer_zip_code_prefix IS NULL) AS missing_zip_code
  FROM `sales-analysis-511312.sales_datasets.OLIST_CUSTOMERS`;

  Only the records having non-null values for the three attributes are kept.
*/

step_1 AS (
  SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
  FROM `sales-analysis-511312.sales_datasets.OLIST_CUSTOMERS`
  WHERE
    customer_zip_code_prefix IS NOT NULL 
      AND customer_id IS NOT NULL 
      AND customer_unique_id IS NOT NULL
),


/*
  STEP 1b: Duplicate Check

  Two records are considered duplicates if they have the same customer_id.
  The following query checks for the presence of duplicates:


  SELECT *
  FROM (
    SELECT 
      *,
      ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY (SELECT NULL)
      ) AS row_num
    FROM
      step_1
    ) AS t 
  WHERE t.row_num > 1;


  no matches returned --> there are no duplicates
*/


/*
  FORMAT CHECK ON customer_id AND customer_unique_id

  At this stage the customer_id and customer_unique_id attributes where
  checked for the presence of non-alphanumeric characters with the following query:

  SELECT 
    customer_id,
    customer_unique_id
  FROM 
   `sales-analysis-511312.sales_datasets.OLIST_CUSTOMERS`
  WHERE 
    REGEXP_CONTAINS(customer_id, r'[^a-zA-Z0-9]') 
    OR REGEXP_CONTAINS(customer_unique_id, r'[^a-zA-Z0-9]');

  The previous query doesn't match any row, which means both customer_id and customer_unique_id
  are correct.

*/


/*
  
  STEP 2: Zip Code Standardization

  Brazilian datasets where zip codes are represented by their first 5 digits (CEP).
  Because zip codes often get imported as integers, a zip code starting with 0
  (e.g., 01000) loses its leading zero and becomes 1000. They should always resolve 
  to 5 digits and contain only numbers. Plausible Range: Brazilian zip code prefixes
  range from 01000 to 99999. The following CTE performs zip code standardization.

*/


step_2 AS (
  SELECT 
    -- 1. Ensure it's converted to a string and padded back to 5 digits if leading zeros were lost
    LPAD(CAST(SAFE_CAST(customer_zip_code_prefix AS INT64) AS STRING), 5, '0') AS customer_zip_code_prefix,
    customer_id,
    customer_unique_id
  FROM 
    step_1
  WHERE 
    -- 2. Filter out NULLs or completely blank values
    customer_zip_code_prefix IS NOT NULL
    -- 3. Ensure the value is strictly numeric (5 digits long)
    AND REGEXP_CONTAINS(CAST(customer_zip_code_prefix AS STRING), r'^[0-9]{1,5}$')
    -- 4. Optional: Ensure it fits within plausible numeric range limits (1000 to 99999)
    AND SAFE_CAST(customer_zip_code_prefix AS INT64) BETWEEN 1000 AND 99999
),


/*
  STEP 3: Zip Code Availability
  The following CTE selects only the records with a zip code existing in the 
  CLEANED_GEOLOCATION_DATASET. This step is necessary because the the customer 
  city and state will be retrieved form that table. 
*/


step_3 AS (
  SELECT *
  FROM step_2 as S2
  WHERE S2.customer_zip_code_prefix IN (
    SELECT DISTINCT geolocation_zip_code_prefix
    FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_GEOLOCATION_DATASET`
  )
),

/*
  STEP 4: City and State Retrieval
  The costumer_city attribute in the raw dataset has several typos of different 
  kinds such as missing letters, wrong accents, etc... 
  Handling all of this problems would require multiple CTEs.
  This can be avoided by using the customer_zip_code_prefix attribute to retrieve
  the correct city names from the CLEANED_GEOLOCATION_DATASET dataset.
*/

step_4 AS (
  SELECT S3.customer_id, S3.customer_unique_id, S3.customer_zip_code_prefix,
    G.geolocation_city, G.geolocation_state
  FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_GEOLOCATION_DATASET` AS G 
    JOIN step_3 AS S3 ON S3.customer_zip_code_prefix = G.geolocation_zip_code_prefix
)


/*
  FINAL STEP: Materialize the final clean table
*/


SELECT 
  customer_id AS order_id,
  customer_unique_id AS customer_id,
  customer_zip_code_prefix AS customer_zip_code, 
  geolocation_city AS customer_city,
  geolocation_state AS customer_state
FROM step_4





