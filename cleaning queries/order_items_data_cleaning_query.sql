/*
  
  ORDER ITEMS DATA CLEANING

  The Data Cleaning pipeline will follow the following steps:

  step 1) Completeness Check
  step 2) Duplicate Control
  Step 3) IDs Consistency Check
  Step 4) IDs Availability
  step 5) Numerical Columns Consistency Check
  step 6) Date Consistency
 
*/


CREATE TABLE `sales-analysis-511312.cleaned_sales_dataset.CLEANED_ORDER_ITEMS_DATASET` AS
WITH

step_0 AS (
    SELECT *
    FROM `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`
),

/*
    STEP 1: Completness check

    The following query checks every column of OLIST_ORDER_ITEMS for any missing value.

    SELECT *
    FROM `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`
    WHERE order_id IS NULL OR order_item_id IS NULL OR
        product_id IS NULL OR seller_id IS NULL OR 
        shipping_limit_date IS NULL OR shipping_limit_date IS NULL OR
        price IS NULL OR freight_value IS NULL

    The previous query returns no records, which means that there are no null values 
    in the table. 

*/


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
        FROM step_0
    ) t
    WHERE t.row_num > 1


    There are several duplicates and upon further inspection it emerged that the
    duplicates actually have the same values for every attribute other than order_item_id.
    A possible explanation for this is that if a customer sends an order for more than one
    item the system will generate multiple rows, each one with a different order_item_id.
    For instance if a customers makes an order with 10 items the system will automatically 
    generate 10 rows for the same order, with each row having order_item_id = 1, ..., until
    order_item_id = 20.
    This hypothesis is tested through the following query:


    WITH step1 AS (
        SELECT
            order_id,
            COUNT(order_item_id) AS total_rows_generated,
            MAX(order_item_id) AS max_item_id,
            CASE 
                WHEN COUNT(order_item_id) = MAX(order_item_id)
                THEN 'Hypothesis Proven True'
                ELSE 'Hypothesis False'
            END AS verification_status
        FROM
            `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`
        GROUP BY
            order_id
    )

    SELECT *
    FROM step1
    WHERE verification_status = "Hypothesis False";



    The query returns no matches, which means the hypothesis is verified for this dataset.
    The following policy will be applied:
    - group the records by order_id
    - select the row with the MAX(order_item_id) per group
    - create a new attribute called items_ordered to hold the MAX(order_item_id)

    This will return just one row for every order with an attribute (items_ordered) that
    will have the actual number of items ordered.
*/


step_2a AS (
  SELECT
    order_id,
    MAX(order_item_id) AS items_ordered
  FROM
    step_0
  GROUP BY
    order_id
),


step_2b AS (
  SELECT 
    s2.order_id,
    s2.items_ordered,
    o.seller_id,
    o.product_id,
    o.shipping_limit_date,
    o.price,
    o.freight_value
  FROM step_2a AS s2 LEFT JOIN step_0 AS o
    ON s2.order_id = o.order_id AND s2.items_ordered = o.order_item_id
),


/*
    STEP 3: IDs Consistency Check

    In the next step the pipeline will look for any inconsistency in the id attributes.
    By id attributes we refer to order_id, product_id, seller_id.

    The pipeline will explore 2 types of inconsistency:
    Type 1) Inconsistent Characters
    Type 2) Incosistent Length




    -- TYPE 1 --

    All of the id attributes are supposedly strings of alphanumeric chracters.
    The following query checks the presence of non-alphanumeric characters
    in the strings that make up the id attributes.

    SELECT 
        order_id, product_id, seller_id
    FROM 
        `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`
    WHERE 
        REGEXP_CONTAINS(order_id, r'[^a-zA-Z0-9]') OR
        REGEXP_CONTAINS(product_id, r'[^a-zA-Z0-9]') OR
        REGEXP_CONTAINS(seller_id, r'[^a-zA-Z0-9]')

    No records are returning, implying the attributes have consistent characters.




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
    FROM `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`


    -- CHECK 2: product_id

    SELECT 
        MIN(LENGTH(product_id)) AS min_length,
        MAX(LENGTH(product_id)) AS max_length,
        CASE 
            WHEN MIN(LENGTH(product_id)) = MAX(LENGTH(product_id)) THEN 'Yes, all are the same length'
            ELSE 'No, lengths vary'
        END AS length_check
    FROM `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`


    -- CHECK 3: seller_id

    SELECT 
        MIN(LENGTH(seller_id)) AS min_length,
        MAX(LENGTH(seller_id)) AS max_length,
        CASE 
            WHEN MIN(LENGTH(seller_id)) = MAX(LENGTH(seller_id)) THEN 'Yes, all are the same length'
            ELSE 'No, lengths vary'
        END AS length_check
    FROM `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`


    None of the queries return differences in the maximum and minimum values of 
    the strings, which means the id attributes have length consistency. 

*/


/*
    STEP 4: IDs availability

    The next step consists in checking which records can be related to other 
    tables. This is how each of the ID attributes relates to other tables:

    order_id        --->        OLIST_ORDERS
    product_id      --->        CLEANED_PRODUCTS_DATASET
    seller_id       --->        CLEANED_SELLER_DATASET

    The current table is linked through product_id and seller_id to cleaned tables.
    order_id, however, is linked to a raw data table as the OLIST_ORDERS table is
    not cleaned at the moment. After the creation of both CLEANED_ORDER_ITEMS_DATASET
    and CLEANED_ORDERS_DATASET the linked between the two cleaned tables through
    order_id will be checked.

    The following queries will inspect if every distinct value of each 
    id attribute can be referenced to a target table.


    -- order_id --

    SELECT DISTINCT order_id
    FROM `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`
    WHERE order_id NOT IN (
        SELECT DISTINCT order_id
        FROM `sales-analysis-511312.sales_datasets.OLIST_ORDERS`
    )


    -- product_id --

    SELECT DISTINCT product_id
    FROM `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`
    WHERE product_id NOT IN (
        SELECT DISTINCT product_id
        FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_PRODUCTS_DATASET`
    )


    -- seller_id --

    SELECT DISTINCT seller_id
    FROM `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`
    WHERE seller_id NOT IN (
        SELECT DISTINCT seller_id
        FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_SELLER_DATASET`
    )  


    Every order_id and product_id can be referenced to other tables, which means
    it is possible to retrieve more data about orders and products. For seller_id
    this is not possible because there are 7 seller IDs which do not appear in 
    the CLEANED_SELLER_DATASET. Upon further analysis it emerged that the missing 
    seller IDs were present in the original table OLIST_SELLERS, meaning they were
    discarded during the cleaning stage. 
    
    Because there is no information available about these records they are discarded
    from the table.
*/


step_4 AS (
    SELECT *
    FROM step_2b
    WHERE seller_id  IN (
        SELECT DISTINCT seller_id
        FROM `sales-analysis-511312.cleaned_sales_dataset.CLEANED_SELLER_DATASET`
    )
),


/*
    STEP 5: Numerical Columns Consistency Check

    This phase will focus on looking for incosistency in the following columns:
    
    - order_item_id (INTEGER)
    - price (FLOAT)
    - freight_value (FLOAT)

    Incostitencies are defined as values equal or smaller than zero because such values 
    make no sense when dealing with price, freight value and number of items per order (order_item_id).

    The following query returns the minimum value for each column:

    SELECT 
        MIN(order_item_id) AS minimum_items, 
        MIN(price) AS minimum_price, 
        MIN(freight_value) AS minimum_freight_value
    FROM 
        `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`




    The minimum for freight_value is 0.0 and upon further inspection it emerged that
    there are 383 records with such value. The freight charges are the fees paid to
    a carrier or a logistic carrier for transporting a good from  point of origin to a 
    destination by air, sea, rail, or road. These fees can be equal to zero for the
    following reasons:

    - Free Shipping Promotions
    - Minimum Spend Thresholds: Sellers often offer free shipping if the buyer’s total 
        order value crosses a certain threshold
    - Local Pickup / Store Pickup
    - Marketplace Subsidies: Olist runs subsidized shipping campaigns where 
        they offer lower courier costs then competitors, which might leave a recorded 
        freight value as low as zero for the buyer.

    We can conclude that a value of 0 means the the transaction explicitly recorded 
    zero shipping cost, which is not to be confuse with missing data or NULL values.

*/


/*
    STEP 6: Date Consistency

    The last stage of the data cleaning pipeline focuses on the following: 

    -- 1) Homogeneous date format --

    The dates recorded in the shipping_limit_date attribute are of the type TIMESTAMP,
    which follows the format 'YYYY-MM-DD hh:mm:ss UTC'. It is not necessary to check 
    the format because shipping_limit_date is native date/time type, which means
    BigQuery automatically enforces internal consistency.

    -- 2) Date Consistency --

    The original dataset has information collected from 2016 to 2018 according
    to the data card of the original dataset at the following link:
    https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce?select=olist_order_items_dataset.csv.

    In order to confirm this the next query will return the oldest and the 
    most recent timestamp:

    SELECT
        MIN(shipping_limit_date) AS first_date,
        MAX(shipping_limit_date) AS last_date,
    FROM
        `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`


    The output is the following:
    first_date: 2016-09-19 00:15:34 UTC
    last_date: 2020-04-09 22:35:08 UTC

    The earliest timestamp is in the required range, but the most recent is 
    about 16 months beyond the upper limit. This could be an entry error or 
    maybe the original dataset was updated. If the timestamps are ranked in 
    descending order it emerges that there are actually only 4 records 
    beyond the upper limit, with all of them being recorded in 2020.
    Further inspection on the Kaggle page of the original dataset reveals
    that the data was updated approximately in 2021. This finding confirms
    that the 2020 records are not entry error but they are results of an
    update of the original dataset. 

    The following query returns the number of records per year.


    SELECT 
        LEFT(CAST(shipping_limit_date AS STRING), 4) AS shipping_year,
        COUNT(*) AS total_records
    FROM `sales-analysis-511312.sales_datasets.OLIST_ORDER_ITEMS`
    GROUP BY LEFT(CAST(shipping_limit_date AS STRING), 4)
    ORDER BY shipping_year ASC; 
    


    The number of records for 2020 is 4, which is not enough to conduct 
    an extensive analysis if we consider that there are tens of thousands 
    of records for the years 2017-2018. Because of this the records from 2020
    won't be included in the final dataset.
*/


step_6 AS (
    SELECT *
    FROM step_4
    WHERE LEFT(CAST(shipping_limit_date AS STRING), 4) < '2020'
)


/*
  FINAL STEP: Materialize the final clean table
*/

SELECT *
FROM step_6;