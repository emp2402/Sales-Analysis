/*
  ORDER REVIEWS DATA CLEANING

  The Data Cleaning pipeline will be broken down into the following steps:

  Step 1) Completeness check
  Step 2) Duplicate Check
  Step 3) IDs availability

*/

CREATE TABLE `sales-analysis-511312.cleaned_sales_dataset.CLEANED_ORDER_REVIEWS_DATASET` AS 
WITH

step_0 AS (
  SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
  FROM `sales-analysis-511312.sales_datasets.ORDER_REVIEWS`
),


/*
  STEP 1: Completness Check

  Check for NULL values in the dataset:


  SELECT
    COUNT(*) AS total_rows,
    COUNTIF(review_id IS NULL) AS missing_review_id,
    COUNTIF(order_id IS NULL) AS missing_order_id,
    COUNTIF(review_score IS NULL) AS missing_review_score,
    COUNTIF(review_comment_title IS NULL) AS missing_review_comment_title,
    COUNTIF(review_comment_message IS NULL) AS missing_review_comment_message,
    COUNTIF(review_creation_date IS NULL) AS missing_review_creation_date,
    COUNTIF(review_answer_timestamp IS NULL) AS missing_review_answer_timestamp,
  FROM step_0;


  The query returns missing_review_comment_title = 87658 and missing_review_comment_message = 58274.
  The dataset has 99224 records, which means around 88% of the records have a NULL review comment title
  and approximately 59% of the records have a NULLM review comment message. Further inspection reveals
  that 56537 records (~57% of the data) have missing values for both review title and message.
  All of these missing reviews might not be random; they could represent a specific user behavior as 
  customers who are happy or indifferent enough to click a star rating (e.g., 5 stars) could be unmotivated 
  to type a written review. The main purpose of the whole datawarehouse will be:
  - sales analysis & prediction
  - delivery performance
  - clustering

  In order to prserve the data and make it safely manageable by downstream pipelines.
  The query returns missing_review_comment_title review_comment_title will be
  imputed with 'no_title' and 'no_message' respectively.
*/

step_1 AS (
  SELECT 
    review_id,
    order_id,
    review_score,
    COALESCE(review_comment_title, "no_title") AS review_comment_title,
    COALESCE(review_comment_message, "no_message") AS review_comment_message,
    review_creation_date,
    review_answer_timestamp
  FROM step_0
),


/*
  STEP 2: Duplicate Check

  The following step identifies the presence of duplicate rows. 
  Two rows are considered duplicates if they have the same values for (review_id, order_id).
  The following query looks for duplicates:

  SELECT *
  FROM (
    SELECT 
      *,
      ROW_NUMBER() OVER (
        PARTITION BY review_id, order_id
        ORDER BY (SELECT NULL)
      ) AS row_num
    FROM step_1
  ) as t
  WHERE T.row_num > 1


  There are no matches --> there are no duplicates
*/


/*
  STEP 3: IDs Availability

  The next step ensures that the every record in the new table can be related 
  to the CLEANED_ORDERS_DATASET through the order_id.
 
*/

step_3 AS (
  SELECT *
  FROM step_1 as s1
  WHERE 
    NOT EXISTS (
      SELECT 1,
      FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_ORDERS` AS o
      WHERE s1.order_id = o.order_id
    )
)

/*
    Final Table Creation
*/

SELECT *
FROM step_3;





