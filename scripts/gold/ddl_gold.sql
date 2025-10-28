
/*
==============================================================================================================
DDL Script: Create Gold Views
==============================================================================================================
Script Purpose:
	This script creates views for the Gold Layer in the data warehouse.
	The Gold layer represents the final dimension and fact tables (start Schema)

	Each view performs transformations and combines data from the Silver layer to produce a clean, enriched, and
	business-ready dataset.

Usage:
    -These views can be required directly for analytics and reporting.
===============================================================================================================
*/

-- =============================================================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================================================

IF OBJECT_ID ('gold.dim_customers', 'V') IS NOT NULL   
   DROP VIEW gold.dim_customers;
  GO
CREATE VIEW gold.dim_customers AS  
SELECT  
ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,  --creation of surrogate key to connect my Data Model 
ci.cst_id AS customer_id,   --Renamed columns, looks really nice after running SQL.  
ci.cst_key AS customer_number, 
ci.cst_firstname AS first_name, 
ci.cst_lastname AS last_name, 
ci.cst_marital_status AS marital_status, 
CASE WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
     ELSE COALESCE(ca.gen, 'n/a')
END AS new_gen, --Have to change new_gen to gender, then DROP & CREATE View again 
ci.cst_create_date AS create_date, 
ca.bdate AS birthdate, 
la.cntry AS country  --Getting NULL that was discovered earlier
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca 
ON ci.cst_key = ca.cid  
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid  
--)t GROUP BY cst_id 
--HAVING COUNT(*) > 1

--#2. Create Dim Products View
IF OBJECT_ID ('gold.dim_products', 'V') IS NOT NULL   
   DROP VIEW gold.dim_products;
  GO
  CREATE VIEW gold.dim_products AS
SELECT
ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key, 
pn.prd_id AS product_id,
pn.prd_key AS prd_number,
pn.prd_nm AS product_name,
pn.cat_id AS category_id,
pc.cat AS category,
pc.subcat AS subcategory,
pc.maintenance,
pn.prd_cost AS cost,
pn.prd_line AS product_line,
pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL 

--#3. Create gold.fact_sales View
IF OBJECT_ID ('gold.fact_sales', 'V') IS NOT NULL   
   DROP VIEW gold.fact_sales;
  GO
CREATE VIEW gold.fact_sales AS
SELECT
sd.sls_ord_num AS order_number,
pr.product_key,
pr.prd_number, --this field does not exist in View list from Baraa, but had to add it on my end in order to Join & Create View.
cu.customer_key,
sd.sls_order_dt AS order_date,
sd.sls_ship_dt AS shipping_date,
sd.sls_due_dt AS due_date,
sd.sls_sales AS sales_amount,
sd.sls_quantity AS quantity,
sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr --These Joins are going to give me the 2 fields prodduct_key & customer_key to connect the Data Model, to connect the FACT to the Dimension tables. 
ON sd.sls_prd_key = pr.prd_number --I changed pr.product_number to pr.prd_number in the last Join in order to Create the View.  I was getting error message. So my join may be wrong since I am using a different field from Baraa.
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id = cu.customer_id
