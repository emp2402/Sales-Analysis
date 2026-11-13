/*
  
  PRODUCTS NAME TRANSLATION DATA CLEANING

  The Data Cleaning pipeline will follow the following steps:

  Step 1) Columns Rename
  Step 2) Missing Values Check
  Step 3) Duplicate check
  Step 4) New Products Addition 
 
*/

CREATE TABLE `sales-analysis-511312.cleaned_sales_dataset.CLEANED_TRANSLATION_DATASET` AS
WITH


/*
  STEP 1: Columns Rename

  The first step in the data cleaning pipeline consists in projecting
  and renaming the attributes from the PRODUCT_NAME_TRANSLATION dataset.
*/


step_1 AS (
  SELECT 
    string_field_0 AS category_portuguese,
    string_field_1 AS category_english
  FROM 
    `sales-analysis-511312.sales_datasets.PRODUCT_NAME_TRANSLATION`
),


/*
  STEP 2: Missing Values Check

  The following CTE explores the presence of any missing value in the 
  dataset.
*/

step_2 AS (
  SELECT *
  FROM 
    step_1 
  WHERE
    step_1.category_portuguese IS NULL OR step_1.category_english IS NULL
),

/*
  step_2 doesn't return ant records, meaning there are no missing values
*/


/*
  STEP 3: Duplicate Check

  The following CTE looks for duplicate values, two records are considered 
  duplicates if they have the same values for both attributes.
*/


step_3 AS (
  SELECT
    category_portuguese, 
    category_english,
    ROW_NUMBER() OVER (
      PARTITION BY category_portuguese, category_english
      ORDER BY category_portuguese                  
    ) AS row_num
  FROM step_1 
)


/*
  step_3 doesn't return any record, which implies there are no duplicates.
*/


/*
  STEP 4: New Products Addition 

  The new product translation dataset must contain every distinct
  product_category_name in the CLEANED_PRODUCTS_DATASET. Most of 
  the categories are already present in the PRODUCT_NAME_TRANSLATION
  table. There are only three missing categories, namely
  'unknown', 'pc_gamer', 'portateis_cozinha_e_preparadores_de_alimentos',
  which will be added with their english translations, respectively 
  'unknown', 'pc_gaming' and 'cooking''.

  The new records are appended to the last CTE through UNION ALL statements
  so that final the final cleaned table is created directly with all
  of the required categories.

*/

/*
  Selecting results from step_1
*/

SELECT *
FROM step_1 

UNION ALL

/*
  Appending the new records
*/

SELECT 'unknown', 'unknown'
UNION ALL
SELECT 'pc_gamer', 'pc_gaming'
UNION ALL
SELECT 'portateis_cozinha_e_preparadores_de_alimentos', 'cooking';




