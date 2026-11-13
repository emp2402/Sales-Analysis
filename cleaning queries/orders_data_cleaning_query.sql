/*
  
  ORDERS DATA CLEANING

  The Data Cleaning pipeline will follow the following steps:

  step 1) Completeness Check
  step 2) Duplicate Control
  Step 3) IDs Consistency Check
  Step 4) IDs Availability
  step 5) Date Consistency
 
*/


CREATE TABLE `sales-analysis-511312.cleaned_sales_dataset.CLEANED_ORDERS_DATASET` AS
WITH

step_0 AS (
    SELECT *
    FROM `sales-analysis-511312.sales_datasets.OLIST_ORDERS`
),

/*
  STEP 1: Completness Check

  The dataset is inspected for missing values through the following query:

  SELECT COUNT(*)   
  FROM `sales-analysis-511312.sales_datasets.OLIST_ORDERS`
  WHERE 
      order_id IS NULL OR
      customer_id IS NULL OR
      order_status IS NULL OR
      order_approved_at IS NULL OR 
      order_delivered_carrier_date IS NULL OR
      order_delivered_customer_date IS NULL OR
      order_estimated_delivery_date IS NULL

  There are 2980 records (2.99 % of the data) with at least a missing attribute. 
  Upon further inspection it emerged that the only missing attributes are order_approved_at, 
  order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date.
  Because the final cleaned table have the goal of providing as much information
  for later purposes (Data Analytics, Sales Prediction, Delivery Performance, etc...)
  the records with at least a NULL column will be removed.

*/

step_1 AS (
  SELECT *
  FROM step_0
  WHERE 
    NOT (
      order_approved_at IS NULL OR 
      order_delivered_carrier_date IS NULL OR
      order_delivered_customer_date IS NULL OR
      order_estimated_delivery_date IS NULL
    )
),

/*
  STEP 2: Duplicate check

  Two records are considered duplicates if they have the same values for order_id
  This is checked by the following query:


  SELECT * 
  FROM (
        SELECT 
            *,
            ROW_NUMBER() OVER (
                PARTITION BY  order_id
                ORDER BY (SELECT NULL)                 
            ) AS row_num
        FROM step_1
  ) t
  WHERE t.row_num > 1


  There are no matches, which means there are no duplicates.
*/


/*
    STEP 3: IDs Consistency Check

    In the next step the pipeline will look for any inconsistency in the id attributes.
    By id attributes we refer to order_id, customer_id

    The pipeline will explore 2 types of inconsistency:
    Type 1) Inconsistent Characters
    Type 2) Incosistent Length




    -- TYPE 1 --

    All of the id attributes are supposedly strings of alphanumeric chracters.
    The following query checks the presence of non-alphanumeric characters
    in the strings that make up the id attributes.

    SELECT 
        order_id, customer_id
    FROM 
        step_0
    WHERE 
        REGEXP_CONTAINS(order_id, r'[^a-zA-Z0-9]') OR
        REGEXP_CONTAINS(customer_id, r'[^a-zA-Z0-9]')

    No records are returned, implying the attributes have consistent characters.

    
    
    
    -- TYPE 2 --

    The next queries will screen the id attributes to find if there records 
    have varying string lengths for the same attribute. In order to do that
    each query will simply compute and compare the minimum and maximum lengths
    of the strings of a given column.


    -- CHECK 1: order_id

    SELECT 
        MIN(LENGTH(order_id)) AS min_length,
        MAX(LENGTH(order_id)) AS max_length,
        CASE 
            WHEN MIN(LENGTH(order_id)) = MAX(LENGTH(order_id)) THEN 'Yes, all are the same length'
            ELSE 'No, lengths vary'
        END AS length_check
    FROM step_1


    -- CHECK 2: customer_id

    SELECT 
        MIN(LENGTH(customer_id)) AS min_length,
        MAX(LENGTH(customer_id)) AS max_length,
        CASE 
            WHEN MIN(LENGTH(customer_id)) = MAX(LENGTH(customer_id)) THEN 'Yes, all are the same length'
            ELSE 'No, lengths vary'
        END AS length_check
    FROM step_1 

    None of the queries return differences in the maximum and minimum values of 
    the strings, which means the id attributes have length consistency. 
*/




/*
    STEP 4: IDs availability

    The next step consists in checking which records can be related to other 
    tables. This is how each of the ID attributes relates to other tables:

    order_id        --->        CLEANED_ORDER_ITEMS_DATASET
    customer_id     --->        CLEANED_CUSTOMER_DATASET

    The current table is linked through order_id and customer_id to cleaned tables.

    The following queries will inspect if every distinct value of each 
    id attribute can be referenced to a target table.


    -- order_id --

    SELECT o.order_id
    FROM step_1 o
    WHERE 
      NOT EXISTS (
        SELECT 1 
        FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_ORDER_ITEMS_DATASET` as p
        WHERE p.order_id = o.order_id
    )


    step_1 has 214 order_ids which are not present in the CLEANED_ORDER_ITEMS_DATASET,
    which means that data is not useful for sales forecast or analysis as it cannot
    be joined to the CLEANED_ORDER_ITEMS_DATASET to access seller data and item price.



    -- customer_id --

    SELECT o.customer_id
    FROM step_1 o
    WHERE 
    NOT EXISTS (
        SELECT 1 
        FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_CUSTOMER_DATASET` as p
        WHERE p.order_id = o.customer_id
    )


    step_1 has 264 customer_ids which are not present in the CLEANED_CUSTOMER_DATASET,
    which means that data cannot be used if the goal involves using customer data as well.
*/


step_4 AS (
    SELECT *
    FROM step_1 s1
    WHERE 
        EXISTS(
            SELECT 1 
            FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_ORDER_ITEMS_DATASET` as o
            WHERE o.order_id = s1.order_id
            )
        AND
        EXISTS (
            SELECT 1 
            FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_CUSTOMER_DATASET` as c
            WHERE c.order_id = s1.customer_id
        )
),


/*
    STEP 5: Date Consistency

    The final step of the data cleaning query consists in making sure all of the timestamps
    are consistent. For the timestamps in a record to be consistent the following criteria
    must be met:
    - a purchase cannot be made before the order is approved;
    - the delivery must take place after the logistics operator was handed the order;
    - the estimated delivery date must be after the the purchase timestamp because
      it is estimated at that moment.

    The following operation criteria are enforced in the data through the step_5 CTE.
*/

step_5 AS (
    SELECT *
    FROM step_4
    WHERE order_purchase_timestamp <= order_approved_at AND
    order_delivered_carrier_date <= order_delivered_customer_date AND
    order_estimated_delivery_date >= order_purchase_timestamp
)

/*
    Final Table Creation
*/

SELECT *
FROM step_5;

