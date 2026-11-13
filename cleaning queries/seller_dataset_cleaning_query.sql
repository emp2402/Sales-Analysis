/*
  
  SELLERS DATA CLEANING

  The Data Cleaning pipeline will follow the following steps:

  Step 1) Completeness check
  Step 2) Duplicate Check
  Step 2) Correctness of seller_id
  Step 2) Zip Codes Standardization
  Step 3) Zip Codes Availability 
  Step 4) City and State Retrieval 

*/


CREATE TABLE `sales-analysis-511312.cleaned_sales_dataset.CLEANED_SELLER_DATASET` AS
WITH


/*
  STEP 1: Completness check

  Check Missing Values on the keys: seller_id, seller_zip_code_prefix. 
  This is done with the following block of code:

  SELECT
    COUNT(*) AS total_rows,
    COUNTIF(seller_id IS NULL) AS missing_seller_id,
    COUNTIF(seller_zip_code_prefix IS NULL) AS missing_zip_code,
  FROM `sales-analysis-511312.sales_datasets.OLIST_SELLERS`;

  The previous query shows that there are no null values for the attributes 
  seller_id and seller_zip_code_prefix.

  The step_1 CTE retrieves seller_id and seller_zip_code_prefix from the 
  raw dataset.

*/


step_1 AS (
  SELECT 
    seller_id, seller_zip_code_prefix
  FROM
    `sales-analysis-511312.sales_datasets.OLIST_SELLERS`
),


/*
  STEP 2: Duplicate Check

  The next step looks for any duplicate row.
  Two rows are considered duplicates if they have the same (seller_id, seller_zip_code_prefix)
  The following query performs this operation:


  SELECT *
  FROM (
    SELECT 
      *,
      ROW_NUMBER() OVER (
        PARTITION BY seller_id, seller_zip_code_prefix
        ORDER BY (SELECT NULL)
      ) AS row_num
    FROM
      `sales-analysis-511312.sales_datasets.OLIST_SELLERS`
    ) AS t 
  WHERE t.row_num > 1


  No matches returned --> No duplicates

*/


/*
  STEP 3: Correctness of seller_id

  At this stage seller_id is screened for the presence of non-alphanumeric
  characters with the following query:

  SELECT 
    seller_id
  FROM 
    `sales-analysis-511312.sales_datasets.OLIST_SELLERS`
  WHERE 
    REGEXP_CONTAINS(seller_id, r'[^a-zA-Z0-9]');

  The previous query doesn't match any row, which means seller_id has the desired format.
*/


/*
  
  STEP 4: Zip Code Standardization

  Brazilian datasets where zip codes are represented by their first 5 digits (CEP).
  Because zip codes often get imported as integers, a zip code starting with 0
  (e.g., 01000) loses its leading zero and becomes 1000. They should always resolve 
  to 5 digits and contain only numbers. Plausible Range: Brazilian zip code prefixes
  range from 01000 to 99999. The following CTE performs zip code standardization.

*/

step_4 AS (
  SELECT 
    -- 1. Ensure it's converted to a string and padded back to 5 digits if leading zeros were lost
    LPAD(CAST(SAFE_CAST(seller_zip_code_prefix AS INT64) AS STRING), 5, '0') AS seller_zip_code_prefix,
    seller_id,
  FROM 
    step_1
  WHERE 
    -- 2. Filter out NULLs or completely blank values
    seller_zip_code_prefix IS NOT NULL
    -- 3. Ensure the value is strictly numeric (5 digits long)
    AND REGEXP_CONTAINS(CAST(seller_zip_code_prefix AS STRING), r'^[0-9]{1,5}$')
    -- 4. Optional: Ensure it fits within plausible numeric range limits (1000 to 99999)
    AND SAFE_CAST(seller_zip_code_prefix AS INT64) BETWEEN 1000 AND 99999
),


/*
  STEP 5: Zip Code Availability
  The following CTE selects only the records with a zip code existing in the 
  CLEANED_GEOLOCATION_DATASET. This step is necessary because the the seller
  city and state will be retrieved form that table. 
*/


step_5 AS (
  SELECT *
  FROM step_4 as S4
  WHERE S4.seller_zip_code_prefix IN (
    SELECT DISTINCT geolocation_zip_code_prefix
    FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_GEOLOCATION_DATASET`
  )
),


/*
  STEP 6: City and State Retrieval
  The seller_city attribute in the raw dataset has several typos of different 
  kinds such as missing letters, wrong accents, etc... 
  Handling all of this problems would require multiple CTEs.
  This can be avoided by using the seller_zip_code_prefix attribute to retrieve
  the correct city names from the CLEANED_GEOLOCATION_DATASET dataset.
*/

step_6 AS (
  SELECT S5.seller_id, S5.seller_zip_code_prefix,
    G.geolocation_city, G.geolocation_state
  FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_GEOLOCATION_DATASET` AS G 
    JOIN step_5 AS S5 ON S5.seller_zip_code_prefix = G.geolocation_zip_code_prefix
)


/*
  FINAL STEP: Materialize the final clean table
*/


SELECT 
  seller_id,
  seller_zip_code_prefix AS seller_zip_code, 
  geolocation_city AS seller_city,
  geolocation_state AS seller_state
FROM step_6

