/*
===============================================================================
 Script: quality_checks_bronze.sql
 Capa: Bronze
  Valida que la carga de la capa Bronze quedó completa y correcta:
     1. Integridad: cada tabla tiene las mismas filas que su archivo CSV.
     2. Esquema: cada tabla tiene las columnas esperadas.
     3. Contenido: los datos quedaron en la columna correcta y con tildes.
   Cada chequeo muestra 'OK' o 'REVISAR'.
===============================================================================
*/

USE DataWarehouse;
GO

-- ====================================================================
-- 1. Integridad: filas cargadas vs filas del CSV (sin encabezado)
-- ====================================================================
SELECT tabla, filas_cargadas, filas_esperadas,
       CASE WHEN filas_cargadas = filas_esperadas THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM (
    SELECT 'crm_cust_info' AS tabla, (SELECT COUNT(*) FROM bronze.crm_cust_info) AS filas_cargadas, 18494 AS filas_esperadas
    UNION ALL SELECT 'crm_prd_info',      (SELECT COUNT(*) FROM bronze.crm_prd_info),      397
    UNION ALL SELECT 'crm_sales_details', (SELECT COUNT(*) FROM bronze.crm_sales_details), 60398
    UNION ALL SELECT 'erp_cust_az12',     (SELECT COUNT(*) FROM bronze.erp_cust_az12),     18484
    UNION ALL SELECT 'erp_loc_a101',      (SELECT COUNT(*) FROM bronze.erp_loc_a101),      18484
    UNION ALL SELECT 'erp_px_cat_g1v2',   (SELECT COUNT(*) FROM bronze.erp_px_cat_g1v2),   37
) AS conteos;

-- ====================================================================
-- 2. Esquema: cantidad de columnas por tabla
-- ====================================================================
SELECT e.tabla, ISNULL(c.columnas, 0) AS columnas_reales, e.columnas_esperadas,
       CASE WHEN ISNULL(c.columnas, 0) = e.columnas_esperadas THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM (
    SELECT 'crm_cust_info' AS tabla, 7 AS columnas_esperadas
    UNION ALL SELECT 'crm_prd_info', 7
    UNION ALL SELECT 'crm_sales_details', 9
    UNION ALL SELECT 'erp_cust_az12', 3
    UNION ALL SELECT 'erp_loc_a101', 2
    UNION ALL SELECT 'erp_px_cat_g1v2', 4
) AS e
LEFT JOIN (
    SELECT TABLE_NAME, COUNT(*) AS columnas
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'bronze'
    GROUP BY TABLE_NAME
) AS c ON c.TABLE_NAME = e.tabla;

-- Detalle de columnas y tipos (para revisar a ojo)
SELECT TABLE_NAME AS tabla, ORDINAL_POSITION AS posicion, COLUMN_NAME AS columna,
       DATA_TYPE AS tipo, CHARACTER_MAXIMUM_LENGTH AS largo
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bronze'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- ====================================================================
-- 3. Contenido: datos en la columna correcta, tildes y valores originales
-- ====================================================================
SELECT chequeo, valor_real, valor_esperado,
       CASE WHEN valor_real = valor_esperado THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM (
    -- Las tildes se leyeron bien (UTF-8)
    SELECT 'Cliente con nombre Andrés' AS chequeo,
           (SELECT COUNT(*) FROM bronze.crm_cust_info WHERE cst_firstname = N'Andrés') AS valor_real,
           1 AS valor_esperado
    -- Los vacíos del CSV quedaron como NULL (no se inventan datos)
    UNION ALL SELECT 'Clientes sin cst_id (NULL)',
           (SELECT COUNT(*) FROM bronze.crm_cust_info WHERE cst_id IS NULL), 4
    UNION ALL SELECT 'Productos sin fecha de fin (NULL)',
           (SELECT COUNT(*) FROM bronze.crm_prd_info WHERE prd_end_dt IS NULL), 197
    -- Bronze conserva los valores originales, aunque estén mal
    UNION ALL SELECT 'Ventas con fecha de orden en 0',
           (SELECT COUNT(*) FROM bronze.crm_sales_details WHERE sls_order_dt = 0), 17
    -- La última columna de cada archivo quedó llena (las columnas no se corrieron)
    UNION ALL SELECT 'Ventas sin cantidad (NULL)',
           (SELECT COUNT(*) FROM bronze.crm_sales_details WHERE sls_quantity IS NULL), 0
    UNION ALL SELECT 'Categorías sin maintenance (NULL)',
           (SELECT COUNT(*) FROM bronze.erp_px_cat_g1v2 WHERE maintenance IS NULL), 0
) AS chequeos;

-- Muestra de 5 filas por tabla (para revisar a ojo)
SELECT TOP 5 * FROM bronze.crm_cust_info;
SELECT TOP 5 * FROM bronze.crm_prd_info;
SELECT TOP 5 * FROM bronze.crm_sales_details;
SELECT TOP 5 * FROM bronze.erp_cust_az12;
SELECT TOP 5 * FROM bronze.erp_loc_a101;
SELECT TOP 5 * FROM bronze.erp_px_cat_g1v2;
GO