*
  ORDER PAYMENTS DATASET CLEANING

  The Data Cleaning pipeline will be broken down into the following steps:

  Step 1) Completeness check
  Step 2) Duplicate Check
  Step 3) Id Availability

*/

CREATE TABLE `sales-analysis-511312.cleaned_sales_dataset.CLEANED_ORDER_PAYMENTS_DATASET`  AS 
WITH


/*
  STEP 0: Attribute Selection

  This dataset will be used to performs revenue analysis.
  The only attributes of interest are:
  - order_id
  - payment_sequential
  - payment_value

  The reason for this will be clear at the step2.

*/


step_0 AS (
  SELECT order_id, payment_sequential, payment_value
  FROM `sales-analysis-511312.sales_datasets.OLIST_ORDER_PAYMENTS`
),


/*
  STEP 1: Completness Check

  The first step consists in identifying any missing value.
  This is done with the following query:


  SELECT COUNT(*)
  FROM step_0
  WHERE payment_sequential IS NULL OR
    order_id IS NULL OR payment_type IS NULL OR
    payment_installments IS NULL OR payment_value IS NULL


  The query returns no matches, which mmeans there are no missing values.

*/


/*
  STEP 2: Duplicate Check

  The second step focuses in making sure every order in the there are no duplicate
  records. Two records are considered duplicates if they have the same values 
  for order_id
  The following query performs this task:


  SELECT *
  FROM (
    SELECT
      *,
      ROW_NUMBER() OVER (
        PARTITION BY order_id
        ORDER BY (SELECT NULL)
      ) AS row_num
    FROM
      step_0
  ) AS t
  WHERE t.row_num > 1;


  There are 4446 duplicates. By looking at the data description on Kaggle
  it emerges that if a customer pays an order with more than one payment method a 
  sequence will be created to accommodate all payments for the same order. 
  This statement is checked with the following query: 



  step_2 AS (
      SELECT
            order_id,
            COUNT(payment_sequential) AS total_rows_generated,
            MAX(payment_sequential) AS max_payments,
            CASE 
                WHEN COUNT(payment_sequential) = MAX(payment_sequential)
                THEN 'Hypothesis Proven True'
                ELSE 'Hypothesis False'
            END AS verification_status
      FROM
            step_0
      GROUP BY
            order_id
  )

  SELECT COUNT(*)
  FROM step_2
  WHERE verification_status = "Hypothesis False";


  There are 80 orders out of 99440 that do not meet this hypothesis. For some
  orders the payment is done with multiple methods but only a few of them are 
  recorded. In order to compute the total order value the following technique 
  will be applied:
  - group the records by the order_id
  - sum of the payment_values for the same order
  - the aforementioned sum is the total transaction value for the order


  NOTE: As mentioned in the previous paragraph the system fails to record 
  every payment within an order ~0.08% of the orders. This means that those
  order will have an underestimated value.

*/


step_2 AS (
  SELECT 
    order_id,
    SUM(payment_value) AS transaction_value
  FROM 
    step_0
  GROUP BY 
    order_id
),


/*
  STEP 3: IDs Availability

  The goal of the next stop is to ensure that every record can be referenced to
  the CLEANED_ORDERS table in order to retrieve orders data.

*/


step_3 AS (
  SELECT *
  FROM step_2 AS p
  WHERE EXISTS (
    SELECT 1
    FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_ORDERS_DATASET` AS o
    WHERE p.order_id = o.order_id
  )
)


/*
  Final Table Creation
*/


SELECT *
FROM step_3;


