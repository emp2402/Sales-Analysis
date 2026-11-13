# Sales-Analysis

## Project Overview & Business Objective
A Brazilian enterprise exploring entry into the e-commerce market wants to maximize its chances of launch success by identifying the key drivers behind top-performing online merchants. The primary objective of this project is to analyze historical marketplace data to uncover actionable patterns, operational traits, and best practices among the most successful sellers that the company can replicate as a competitive advantage.

## Dataset & Data Engineering Pipeline
This analysis utilizes the public **Brazilian E-Commerce Public Dataset by Olist** (via Kaggle), encompassing over **100,000 real commercial orders** placed between 2016 and 2018.

* **Data Warehousing:** Raw relational tables were ingested and hosted in a cloud data warehouse using **Google BigQuery**.
* **SQL Cleaning Pipelines:** Modular, production-style SQL scripts were developed using chained Common Table Expressions (CTEs) to transform raw data into analytics-ready tables. Key pipeline stages include:
  * **Data Integrity & Deduplication:** Resolving duplicate records and validating primary/foreign key relationships across order, seller, and product tables.
  * **Imputation & Null Handling:** Standardizing missing values to preserve analytical accuracy.
  * **Temporal Standardization:** Ensuring timestamp consistency across order approval, carrier handoff, and customer delivery milestones.
  * **Feature Engineering:** Deriving key business metrics (e.g., number of items per order, order transaction value) to support downstream exploratory analysis.
