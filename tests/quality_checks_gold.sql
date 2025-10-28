/*
===========================================================================================================================================================
Quality Checks
===========================================================================================================================================================
Script Purpose:
	This script performs quality checks to validate the integrity, consistency, and accuracy of the Gold Layer.  These checks ensure:
	- Uniqueness of surrogate keys in dimension tables.
	- Referential integrity between fact and dimension tables.
	- Validation of relationships in the data model for analytical purposes.

Usage Notes:
	- Run these checks after data loading Silver layer.
	- Investigate and resolve any discrepancies found during the checks.
==============================================================================================================================================================
*/

-- ===========================================================================================================================================================
-- Checking 'gold.dim_customers'
-- ===========================================================================================================================================================
-- Check for uniqueness of Customer Key in gold.dim_customers
-- Expectation: No Results
SELECT
	customer_key,
	COUNT() AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- =============================================================================================================================================================

--1. Dim Customers DQ & Worksheet
SELECT * FROM gold.dim_customers  --Overall Quality Check: NULLS showing up in the country column so that has to be fixed in Silver.
 SELECT DISTINCT new_gen FROM gold.dim_customers -- Quality Check to verify that Gender column is okay
--Original query without subquery, done to check that join was done correctly. Getting NULLs in cntry column which means my join or prep was done successful 
SELECT ci.cst_id, 
ci.cst_key, 
ci.cst_firstname, 
ci.cst_lastname, 
ci.cst_marital_status, 
ci.cst_gndr, 
ci.cst_create_date, 
ca.bdate, 
ca.gen, 
la.cntry
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca --Baraa avoid using INNER JOIN, he always try to have Bigger (Master Table) on left.  He is avoiding INNER JOINs because other Source may not all the Cust.
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key =la.cid

--Added subquery below to original query to, use this entire query to find out if we have any Duplicates in the results.  If no Results came back then Joing did not Duplicate the Data. 
SELECT cst_id, COUNT(*) FROM (
SELECT ci.cst_id, 
ci.cst_key, 
ci.cst_firstname, 
ci.cst_lastname, 
ci.cst_marital_status, 
ci.cst_gndr, 
ci.cst_create_date, 
ca.bdate, 
ca.gen, 
la.cntry
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca 
ON ci.cst_key = ca.cid  
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid  
)t GROUP BY cst_id 
HAVING COUNT(*) > 1 

--Data Integration Issue: There are 2 columns with gender information, 1 from each file. 
SELECT ci.cst_gndr, ca.gen,
CASE WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM is the Master for gender Info
      ELSE COALESCE(ca.gen, 'n/a')
	  END AS new_gen
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca 
ON ci.cst_key = ca.cid  
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid 
ORDER BY 1, 2 --gender columns don't look right after running this SQL

 --#2. Dim Products:  DQ & Worksheet  
SELECT * FROM gold.dim_products --everything should be good 

SELECT prd_number, COUNT(*) FROM ( --SELECT prd_key COUNT(*) FROM (  --Subquery was added to check if Join resulted in Duplicates, but it did not return any results, so no Duplicates.
SELECT
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
WHERE prd_end_dt IS NULL  --Current records have end date NULL, in order to filter out historical records, we have to use this criteria.
)t GROUP BY prd_number
HAVING COUNT(*) > 1

 --#3. Dim Fact Sales: DQ & Worksheet 
 SELECT * FROM gold.fact_sales --Looks good

--Foreign Key Integrity (Dimension)
SELECT * FROM gold.fact_sales f 
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key  --No results came back which means records are matching perfectly 
LEFT JOIN gold.dim_customers p
ON p.customer_key = f.customer_key  --No results came back which means records are matching perfectly 
WHERE c.customer_key IS NULL

SELECT * FROM gold.fact_sales f 
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key  --No results came back which means records are matching perfectly 
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key  --No results came back which means records are matching perfectly 
WHERE p.product_key IS NULL

