/*
  
  PRODUCTS DATA CLEANING

  The Data Cleaning pipeline will follow the following steps:

  Step 1a) Completeness check
  Step 1b) Duplicate check
  Step 2) 'unknown' class creation
  Step 3) Global & 'Bebes' Medians Imputation
 
*/

CREATE TABLE `sales-analysis-511312.cleaned_sales_dataset.CLEANED_PRODUCTS_DATASET` AS
WITH

/*
  STEP 1a: Completness check

  Check Missing Values on the keys: product_id, product_category_name. 
  This is done with the following block of code:

  SELECT
    COUNT(*) AS total_rows,
    COUNTIF(product_id IS NULL) AS missing_product_id,
    COUNTIF(product_category_name IS NULL) AS missing_cat_name,
  FROM `sales-analysis-511312.sales_datasets.OLIST_PRODUCTS`;

  The previous query shows that there are 610 records missing the product_category_name.
  These records represent around 1.9% (610/32951 * 100) of the total number of records.

  Every record in the dataset OLIST_PRODUCTS has a unique value for product_id, which means
  removing even one of them would prevent us from retrieving product data if were starting 
  an order items record. This can be derived because the following query returns no matches:

  SELECT DISTINCT product_id
  FROM `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`
  WHERE product_id NOT IN (
    SELECT DISTINCT product_id
    FROM `sales-analysis-511312.sales_datasets.OLIST_PRODUCTS`
  )

  Discarding records with missing product category would make it impossible to query 
  the OLIST_ORDER_ITEMS to retrieve information about a specific product, so the null values in
  the product_category_name are replaced by a new product category called "unknown" to
  allow further analysis through joins with other tables.

*/

step_1 AS (
  SELECT *
  FROM `sales-analysis-511312.sales_datasets.OLIST_PRODUCTS`
),


/*
  STEP 1b: Duplicate Check

  Two records are considered duplicates if they have the same values for product_id.
  The following query performs this check:

  SELECT *
  FROM (
    SELECT 
      *,
      ROW_NUMBER() OVER (
        PARTITION BY product_id
        ORDER BY (SELECT NULL)
      ) AS row_num
    FROM
      `sales-analysis-511312.sales_datasets.OLIST_PRODUCTS`
    ) AS t 
  WHERE t.row_num > 1;


  There are no matches --> there are no duplicates

*/


/*
  STEP 2: 'unknown' class creation

  As mentioned previously all of the the products having a NULL product_category_name
  are assigned to a new category called 'unknown'

  Every record having a NULL value for product_category_name has also missing values for 
  the columns product_name_length, product_description_length and product_photos_qty.
  
  The product_name_length attribute is irrevelevant as we cannot retrieve the actual
  product name from any other table. Because of this the attribute product_name_length 
  is not selected.
  
  The product_description_length is set to 0. The reason behind this is that any
  record with a non-null category has at minimum a product_description_length equal 
  to 4. During any analysis relative to product_description_length this choice must 
  be considered.

  The product_photos_qty is set to 0 for NULL values because the minimum value for 
  product_photos_qty is 1. When performing queries and analysis this must be taken
  into account.

*/

step_2 AS (
  SELECT 
    product_id,
    COALESCE(product_category_name, "unknown") AS product_category_name,
    CASE
      WHEN product_description_lenght IS NULL THEN 0
      ELSE product_description_lenght
    END AS product_description_lenght,
    CASE
      WHEN product_photos_qty IS NULL THEN 0
      ELSE product_photos_qty
    END AS product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
  FROM 
    step_1
),


/*
  STEP 3: Global & 'Bebes' Medians Imputation

  There are two records with missing values for the attributes: product_weight_g,
  product_length_cm, product_height_cm and product_width_cm. 
  One of these records, which will be referred to as record A, is a ghost record,
  which means all of its attributes are NULL. The other record, however, which will be 
  referred to as record B, belongs to the 'bebes' product category.

  Every NULL values will be updated with the median values of the columns they 
  belong to. The median was picked over the mean to ensure more robustness to outliers.
  The medians for record A will be the overall medians of the entire table. 
  The medians for record B will be computed on the medians of the products that belong to
  the 'bebes' category.

  The following CTEs will do the following: compute the global median and the median 
  for the category 'bebes' for each of the four attibutes product_weight_g, 
  product_length_cm, product_height_cm and product_width_cm.

*/

/*
  ATTRIBUTE 1: product_weight_g (Global & Bebes Medians)
*/

col1_global_ord AS (
    SELECT product_weight_g, ROW_NUMBER() OVER (ORDER BY product_weight_g) AS row_num, COUNT(*) OVER () AS total_count
    FROM step_2 WHERE product_weight_g IS NOT NULL
),
col1_global_med AS (
    SELECT AVG(product_weight_g) AS median_val FROM col1_global_ord 
    WHERE row_num BETWEEN total_count / 2.0 AND (total_count / 2.0) + 1
),
col1_bebes_ord AS (
    SELECT product_weight_g, ROW_NUMBER() OVER (ORDER BY product_weight_g) AS row_num, COUNT(*) OVER () AS total_count
    FROM step_2 WHERE product_category_name = 'bebes' AND product_weight_g IS NOT NULL
),
col1_bebes_med AS (
    SELECT AVG(product_weight_g) AS median_val FROM col1_bebes_ord 
    WHERE row_num BETWEEN total_count / 2.0 AND (total_count / 2.0) + 1
),

/*
  ATTRIBUTE 2: product_length_cm (Global & Bebes Medians)
*/

col2_global_ord AS (
    SELECT product_length_cm, ROW_NUMBER() OVER (ORDER BY product_length_cm) AS row_num, COUNT(*) OVER () AS total_count
    FROM step_2 WHERE product_length_cm IS NOT NULL
),
col2_global_med AS (
    SELECT AVG(product_length_cm) AS median_val FROM col2_global_ord 
    WHERE row_num BETWEEN total_count / 2.0 AND (total_count / 2.0) + 1
),
col2_bebes_ord AS (
    SELECT product_length_cm, ROW_NUMBER() OVER (ORDER BY product_length_cm) AS row_num, COUNT(*) OVER () AS total_count
    FROM step_2 WHERE  product_category_name = 'bebes' AND product_length_cm IS NOT NULL
),
col2_bebes_med AS (
    SELECT AVG(product_length_cm) AS median_val FROM col2_bebes_ord 
    WHERE row_num BETWEEN total_count / 2.0 AND (total_count / 2.0) + 1
),

/*
  ATTRIBUTE 3: product_height_cm (Global & Bebes Medians)
*/

col3_global_ord AS (
    SELECT product_height_cm, ROW_NUMBER() OVER (ORDER BY product_height_cm) AS row_num, COUNT(*) OVER () AS total_count
    FROM step_2 WHERE product_height_cm IS NOT NULL
),
col3_global_med AS (
    SELECT AVG(product_height_cm) AS median_val FROM col3_global_ord 
    WHERE row_num BETWEEN total_count / 2.0 AND (total_count / 2.0) + 1
),
col3_bebes_ord AS (
    SELECT product_height_cm, ROW_NUMBER() OVER (ORDER BY product_height_cm) AS row_num, COUNT(*) OVER () AS total_count
    FROM step_2 WHERE product_category_name = 'bebes' AND product_height_cm IS NOT NULL
),
col3_bebes_med AS (
    SELECT AVG(product_height_cm) AS median_val FROM col3_bebes_ord 
    WHERE row_num BETWEEN total_count / 2.0 AND (total_count / 2.0) + 1
),


/*
  ATTRIBUTE 4 : product_width_cm (Global & Bebes Medians)
*/

col4_global_ord AS (
    SELECT product_width_cm, ROW_NUMBER() OVER (ORDER BY product_width_cm) AS row_num, COUNT(*) OVER () AS total_count
    FROM step_2 WHERE product_width_cm IS NOT NULL
),
col4_global_med AS (
    SELECT AVG(product_width_cm) AS median_val FROM col4_global_ord 
    WHERE row_num BETWEEN total_count / 2.0 AND (total_count / 2.0) + 1
),
col4_bebes_ord AS (
    SELECT product_width_cm, ROW_NUMBER() OVER (ORDER BY product_width_cm) AS row_num, COUNT(*) OVER () AS total_count
    FROM step_2 WHERE product_category_name = 'bebes' AND product_width_cm IS NOT NULL
),
col4_bebes_med AS (
    SELECT AVG(product_width_cm) AS median_val FROM col4_bebes_ord 
    WHERE row_num BETWEEN total_count / 2.0 AND (total_count / 2.0) + 1
),

/*
  FINAL CTE (step_3) : putting eveything together

  The step_3 CTE CROSS JOINS the step_2 table with all of the median values obtained
  in the previous CTEs. The result of the CROSS JOINS is a the step_2 table with 8 extra
  columns, with each one having the same value repeating for every row.
  The COALESCE + CASE projection checks the presence of a NULL value, if it exists
  the CASE statement picks either the 'bebes' median or the global median.
*/

step_3 AS (
    SELECT 
        s2.product_id,
        s2.product_category_name,
        s2.product_description_lenght,
        s2.product_photos_qty,
        
        COALESCE(
            s2.product_weight_g, 
            CASE WHEN s2.product_category_name = 'bebes' THEN c1_b.median_val ELSE c1_g.median_val END
        ) AS product_weight_g,
        
        COALESCE(
            s2.product_length_cm, 
            CASE WHEN s2.product_category_name = 'bebes' THEN c2_b.median_val ELSE c2_g.median_val END
        ) AS product_length_cm,

        COALESCE(
            s2.product_height_cm, 
            CASE WHEN s2.product_category_name = 'bebes' THEN c3_b.median_val ELSE c3_g.median_val END
        ) AS product_height_cm,
        
        COALESCE(
            s2.product_width_cm, 
            CASE WHEN s2.product_category_name = 'bebes' THEN c4_b.median_val ELSE c4_g.median_val END
        ) AS product_width_cm

    FROM step_2 AS s2
    CROSS JOIN col1_global_med AS c1_g CROSS JOIN col1_bebes_med AS c1_b
    CROSS JOIN col2_global_med AS c2_g CROSS JOIN col2_bebes_med AS c2_b
    CROSS JOIN col3_global_med AS c3_g CROSS JOIN col3_bebes_med AS c3_b
    CROSS JOIN col4_global_med AS c4_g CROSS JOIN col4_bebes_med AS c4_b
)

/*
  FINAL STEP: Materialize the final clean table
*/

SELECT *
FROM step_3;


