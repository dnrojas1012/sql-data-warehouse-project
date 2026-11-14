/*
===============================================================================
 Script: quality_checks_silver.sql
 Capa: Silver
 Propósito:
   Verifica que la capa Silver quedó limpia, estandarizada e integrada:
   unicidad de claves, espacios, valores estandarizados, fechas,
   reglas de negocio e integridad entre tablas.
   Cada chequeo muestra 'OK' o 'REVISAR'.
 Uso:
   Ejecutar después de EXEC silver.load_silver;
===============================================================================
*/

USE DataWarehouse;
GO

SELECT tabla, chequeo, valor_real, valor_esperado,
       CASE WHEN valor_real = valor_esperado THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM (
    -- ================================================================
    -- 1. Cantidad de filas
    -- ================================================================
    SELECT 'crm_cust_info' AS tabla, 'Filas (sin nulos ni duplicados)' AS chequeo,
           (SELECT COUNT(*) FROM silver.crm_cust_info) AS valor_real, 18484 AS valor_esperado
    UNION ALL SELECT 'crm_prd_info', 'Filas', (SELECT COUNT(*) FROM silver.crm_prd_info), 397
    UNION ALL SELECT 'crm_sales_details', 'Filas', (SELECT COUNT(*) FROM silver.crm_sales_details), 60398
    UNION ALL SELECT 'erp_cust_az12', 'Filas', (SELECT COUNT(*) FROM silver.erp_cust_az12), 18484
    UNION ALL SELECT 'erp_loc_a101', 'Filas', (SELECT COUNT(*) FROM silver.erp_loc_a101), 18484
    UNION ALL SELECT 'erp_px_cat_g1v2', 'Filas', (SELECT COUNT(*) FROM silver.erp_px_cat_g1v2), 37

    -- ================================================================
    -- 2. silver.crm_cust_info
    -- ================================================================
    UNION ALL SELECT 'crm_cust_info', 'cst_id repetido o NULL',
           (SELECT COUNT(*) FROM (SELECT cst_id FROM silver.crm_cust_info
                                  GROUP BY cst_id HAVING COUNT(*) > 1 OR cst_id IS NULL) AS x), 0
    UNION ALL SELECT 'crm_cust_info', 'Nombres o apellidos con espacios',
           (SELECT COUNT(*) FROM silver.crm_cust_info
            WHERE DATALENGTH(cst_firstname) <> DATALENGTH(TRIM(cst_firstname))
               OR DATALENGTH(cst_lastname)  <> DATALENGTH(TRIM(cst_lastname))), 0
    UNION ALL SELECT 'crm_cust_info', 'Estado civil fuera de Single/Married/n/a',
           (SELECT COUNT(*) FROM silver.crm_cust_info
            WHERE cst_marital_status NOT IN ('Single', 'Married', 'n/a')), 0
    UNION ALL SELECT 'crm_cust_info', 'Género fuera de Female/Male/n/a',
           (SELECT COUNT(*) FROM silver.crm_cust_info
            WHERE cst_gndr NOT IN ('Female', 'Male', 'n/a')), 0

    -- ================================================================
    -- 3. silver.crm_prd_info
    -- ================================================================
    UNION ALL SELECT 'crm_prd_info', 'prd_id repetido o NULL',
           (SELECT COUNT(*) FROM (SELECT prd_id FROM silver.crm_prd_info
                                  GROUP BY prd_id HAVING COUNT(*) > 1 OR prd_id IS NULL) AS x), 0
    UNION ALL SELECT 'crm_prd_info', 'Costo NULL o negativo',
           (SELECT COUNT(*) FROM silver.crm_prd_info WHERE prd_cost IS NULL OR prd_cost < 0), 0
    UNION ALL SELECT 'crm_prd_info', 'Línea de producto no estandarizada',
           (SELECT COUNT(*) FROM silver.crm_prd_info
            WHERE prd_line NOT IN ('Mountain', 'Road', 'Other Sales', 'Touring', 'n/a')), 0
    UNION ALL SELECT 'crm_prd_info', 'Fecha de fin anterior a la de inicio',
           (SELECT COUNT(*) FROM silver.crm_prd_info WHERE prd_end_dt < prd_start_dt), 0
    UNION ALL SELECT 'crm_prd_info', 'Productos sin categoría en ERP (CO_PE, conocido)',
           (SELECT COUNT(*) FROM silver.crm_prd_info
            WHERE cat_id NOT IN (SELECT id FROM silver.erp_px_cat_g1v2)), 7

    -- ================================================================
    -- 4. silver.crm_sales_details
    -- ================================================================
    UNION ALL SELECT 'crm_sales_details', 'Fecha de orden NULL (venían en 0 o inválidas)',
           (SELECT COUNT(*) FROM silver.crm_sales_details WHERE sls_order_dt IS NULL), 19
    UNION ALL SELECT 'crm_sales_details', 'Orden posterior a envío o vencimiento',
           (SELECT COUNT(*) FROM silver.crm_sales_details
            WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt), 0
    UNION ALL SELECT 'crm_sales_details', 'Ventas, cantidad o precio NULL o <= 0',
           (SELECT COUNT(*) FROM silver.crm_sales_details
            WHERE sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
               OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0), 0
    UNION ALL SELECT 'crm_sales_details', 'Ventas distinto de cantidad x precio',
           (SELECT COUNT(*) FROM silver.crm_sales_details
            WHERE sls_sales <> sls_quantity * sls_price), 0
    UNION ALL SELECT 'crm_sales_details', 'Ventas con producto inexistente',
           (SELECT COUNT(*) FROM silver.crm_sales_details
            WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)), 0
    UNION ALL SELECT 'crm_sales_details', 'Ventas con cliente inexistente',
           (SELECT COUNT(*) FROM silver.crm_sales_details
            WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info)), 0

    -- ================================================================
    -- 5. silver.erp_cust_az12
    -- ================================================================
    UNION ALL SELECT 'erp_cust_az12', 'cid con prefijo NAS',
           (SELECT COUNT(*) FROM silver.erp_cust_az12 WHERE cid LIKE 'NAS%'), 0
    UNION ALL SELECT 'erp_cust_az12', 'Fecha de nacimiento en el futuro',
           (SELECT COUNT(*) FROM silver.erp_cust_az12 WHERE bdate > GETDATE()), 0
    UNION ALL SELECT 'erp_cust_az12', 'Género fuera de Female/Male/n/a',
           (SELECT COUNT(*) FROM silver.erp_cust_az12 WHERE gen NOT IN ('Female', 'Male', 'n/a')), 0
    UNION ALL SELECT 'erp_cust_az12', 'cid sin cliente en CRM',
           (SELECT COUNT(*) FROM silver.erp_cust_az12
            WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info)), 0

    -- ================================================================
    -- 6. silver.erp_loc_a101
    -- ================================================================
    UNION ALL SELECT 'erp_loc_a101', 'cid con guion',
           (SELECT COUNT(*) FROM silver.erp_loc_a101 WHERE cid LIKE '%-%'), 0
    UNION ALL SELECT 'erp_loc_a101', 'Cantidad de países distintos',
           (SELECT COUNT(DISTINCT cntry) FROM silver.erp_loc_a101), 7
    UNION ALL SELECT 'erp_loc_a101', 'cid sin cliente en CRM',
           (SELECT COUNT(*) FROM silver.erp_loc_a101
            WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info)), 0

    -- ================================================================
    -- 7. Columna técnica dwh_create_date llena en todas las tablas
    -- ================================================================
    UNION ALL SELECT 'todas', 'dwh_create_date NULL',
           (SELECT COUNT(*) FROM silver.crm_cust_info     WHERE dwh_create_date IS NULL)
         + (SELECT COUNT(*) FROM silver.crm_prd_info      WHERE dwh_create_date IS NULL)
         + (SELECT COUNT(*) FROM silver.crm_sales_details WHERE dwh_create_date IS NULL)
         + (SELECT COUNT(*) FROM silver.erp_cust_az12     WHERE dwh_create_date IS NULL)
         + (SELECT COUNT(*) FROM silver.erp_loc_a101      WHERE dwh_create_date IS NULL)
         + (SELECT COUNT(*) FROM silver.erp_px_cat_g1v2   WHERE dwh_create_date IS NULL), 0
) AS chequeos;
GO
