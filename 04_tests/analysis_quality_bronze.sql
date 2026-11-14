/*
===============================================================================
 Script: analysis_quality_bronze.sql
 Analiza la calidad de los datos que quedaron en la capa Bronze para decidir qué reglas de limpieza se aplican en la capa Silver.
 Cada consulta indica en el comentario el resultado esperado.
 Al final hay un resumen con las reglas que se aplicarán en Silver.
===============================================================================
*/

USE DataWarehouse;
GO

-- ====================================================================
-- 1. bronze.crm_cust_info
-- ====================================================================

-- 1.1 cst_id repetido o NULL (debería ser único y no nulo)
-- Esperado: 6 filas (NULL con 4, y los ids 29433, 29449, 29466, 29473, 29483 repetidos)
SELECT cst_id, COUNT(*) AS veces
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- 1.2 Ejemplo de un id repetido: hay que quedarse con el registro más reciente
SELECT * FROM bronze.crm_cust_info WHERE cst_id = 29466 ORDER BY cst_create_date DESC;

-- 1.3 Espacios sobrantes al inicio o al final de nombres y apellidos
-- Esperado: 17 nombres y 22 apellidos
SELECT
    SUM(CASE WHEN DATALENGTH(cst_firstname) <> DATALENGTH(TRIM(cst_firstname)) THEN 1 ELSE 0 END) AS nombres_con_espacios,
    SUM(CASE WHEN DATALENGTH(cst_lastname)  <> DATALENGTH(TRIM(cst_lastname))  THEN 1 ELSE 0 END) AS apellidos_con_espacios
FROM bronze.crm_cust_info;

-- 1.4 Valores de género y estado civil (vienen abreviados y con NULL)
-- Esperado: cst_gndr = F, M, NULL ; cst_marital_status = M, S, NULL
SELECT DISTINCT cst_gndr FROM bronze.crm_cust_info;
SELECT DISTINCT cst_marital_status FROM bronze.crm_cust_info;

-- ====================================================================
-- 2. bronze.crm_prd_info
-- ====================================================================

-- 2.1 prd_id repetido o NULL. Esperado: 0 filas
SELECT prd_id, COUNT(*) AS veces
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- 2.2 Costo NULL o negativo. Esperado: 2
SELECT COUNT(*) AS costos_invalidos
FROM bronze.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost < 0;

-- 2.3 Valores de línea de producto (abreviados). Esperado: M, R, S, T, NULL
SELECT DISTINCT prd_line FROM bronze.crm_prd_info;

-- 2.4 Fecha de fin anterior a la de inicio. Esperado: 200
SELECT COUNT(*) AS fechas_invertidas
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- 2.5 prd_key junta la categoría (5 primeros caracteres) y el código del producto
SELECT TOP 5 prd_key,
       REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,       -- se une con erp_px_cat_g1v2.id
       SUBSTRING(prd_key, 7, LEN(prd_key))          AS prd_key_venta -- se une con crm_sales_details.sls_prd_key
FROM bronze.crm_prd_info;

-- ====================================================================
-- 3. bronze.crm_sales_details
-- ====================================================================

-- 3.1 Fechas inválidas (0, largo distinto de 8 o fuera de rango)
-- Esperado: orden = 19, envío = 0, vencimiento = 0
SELECT
    SUM(CASE WHEN sls_order_dt <= 0 OR LEN(sls_order_dt) <> 8 OR sls_order_dt > 20500101 OR sls_order_dt < 19000101 THEN 1 ELSE 0 END) AS orden_invalida,
    SUM(CASE WHEN sls_ship_dt  <= 0 OR LEN(sls_ship_dt)  <> 8 OR sls_ship_dt  > 20500101 OR sls_ship_dt  < 19000101 THEN 1 ELSE 0 END) AS envio_invalido,
    SUM(CASE WHEN sls_due_dt   <= 0 OR LEN(sls_due_dt)   <> 8 OR sls_due_dt   > 20500101 OR sls_due_dt   < 19000101 THEN 1 ELSE 0 END) AS vencimiento_invalido
FROM bronze.crm_sales_details;

-- 3.2 Fecha de orden posterior a envío o vencimiento. Esperado: 0
SELECT COUNT(*) AS orden_despues_de_envio
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- 3.3 Regla de negocio: ventas = cantidad x precio, y ninguno nulo, cero o negativo
-- Esperado: 35 filas
SELECT sls_sales, sls_quantity, sls_price
FROM bronze.crm_sales_details
WHERE sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
   OR sls_sales <> sls_quantity * sls_price
ORDER BY sls_sales, sls_quantity, sls_price;

-- ====================================================================
-- 4. bronze.erp_cust_az12
-- ====================================================================

-- 4.1 cid con prefijo 'NAS' (en el CRM el código no lo trae). Esperado: 11042
SELECT COUNT(*) AS con_prefijo_nas FROM bronze.erp_cust_az12 WHERE cid LIKE 'NAS%';

-- 4.2 Fechas de nacimiento fuera de rango. Esperado: muy_antiguas = 15, futuras = 16
SELECT
    SUM(CASE WHEN bdate < '1924-01-01' THEN 1 ELSE 0 END) AS muy_antiguas,
    SUM(CASE WHEN bdate > GETDATE()    THEN 1 ELSE 0 END) AS futuras
FROM bronze.erp_cust_az12;

-- 4.3 Valores de género mezclados. Esperado: Male, Female, F, M, vacío y NULL
SELECT DISTINCT gen FROM bronze.erp_cust_az12;

-- ====================================================================
-- 5. bronze.erp_loc_a101
-- ====================================================================

-- 5.1 cid con guion (en el CRM es AW00011000, aquí AW-00011000). Esperado: 18484
SELECT COUNT(*) AS con_guion FROM bronze.erp_loc_a101 WHERE cid LIKE '%-%';

-- 5.2 Países escritos de varias formas. Esperado: 11 valores (US, USA, United States, DE, Germany, vacío, NULL...)
SELECT DISTINCT cntry FROM bronze.erp_loc_a101 ORDER BY cntry;

-- ====================================================================
-- 6. bronze.erp_px_cat_g1v2
-- ====================================================================

-- 6.1 Espacios sobrantes. Esperado: 0
SELECT COUNT(*) AS con_espacios
FROM bronze.erp_px_cat_g1v2
WHERE DATALENGTH(cat) <> DATALENGTH(TRIM(cat))
   OR DATALENGTH(subcat) <> DATALENGTH(TRIM(subcat))
   OR DATALENGTH(maintenance) <> DATALENGTH(TRIM(maintenance));

-- 6.2 Valores. Esperado: 4 categorías y maintenance = Yes / No
SELECT DISTINCT cat FROM bronze.erp_px_cat_g1v2;
SELECT DISTINCT maintenance FROM bronze.erp_px_cat_g1v2;

-- ====================================================================
-- 7. Integración: ¿las claves se pueden unir entre sistemas?
-- ====================================================================

-- 7.1 Clientes del ERP que no existen en el CRM después de quitar 'NAS'. Esperado: 0
SELECT COUNT(*) AS az12_sin_cliente_crm
FROM bronze.erp_cust_az12
WHERE CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) ELSE cid END
      NOT IN (SELECT cst_key FROM bronze.crm_cust_info WHERE cst_key IS NOT NULL);

-- 7.2 Ubicaciones que no existen en el CRM después de quitar el guion. Esperado: 0
SELECT COUNT(*) AS loc_sin_cliente_crm
FROM bronze.erp_loc_a101
WHERE REPLACE(cid, '-', '')
      NOT IN (SELECT cst_key FROM bronze.crm_cust_info WHERE cst_key IS NOT NULL);

-- 7.3 Productos cuya categoría no existe en el ERP. Esperado: 7 (todos de la categoría CO_PE)
SELECT COUNT(*) AS productos_sin_categoria
FROM bronze.crm_prd_info
WHERE REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_')
      NOT IN (SELECT id FROM bronze.erp_px_cat_g1v2);

GO

/*
===============================================================================
 RESUMEN: reglas que se aplicarán en la capa Silver
-------------------------------------------------------------------------------
 crm_cust_info
   - Quitar filas con cst_id NULL.
   - Si un cst_id se repite, quedarse con el registro más reciente (cst_create_date).
   - TRIM a nombres y apellidos.
   - cst_marital_status: S -> Single, M -> Married, otro -> n/a.
   - cst_gndr: F -> Female, M -> Male, otro -> n/a.
 crm_prd_info
   - Separar prd_key en cat_id (5 primeros caracteres, '-' -> '_') y prd_key.
   - prd_cost NULL -> 0.
   - prd_line: M -> Mountain, R -> Road, S -> Other Sales, T -> Touring, otro -> n/a.
   - prd_end_dt = día anterior al prd_start_dt de la siguiente versión del producto.
 crm_sales_details
   - Fechas en 0 o con largo distinto de 8 -> NULL; las demás, INT -> DATE.
   - Si sls_sales es NULL, <= 0 o distinto de cantidad x precio -> cantidad x |precio|.
   - Si sls_price es NULL o <= 0 -> sls_sales / cantidad.
 erp_cust_az12
   - Quitar el prefijo 'NAS' de cid.
   - bdate en el futuro -> NULL.
   - gen: F/Female -> Female, M/Male -> Male, otro -> n/a.
 erp_loc_a101
   - Quitar el guion de cid.
   - cntry: DE -> Germany, US/USA -> United States, vacío o NULL -> n/a, TRIM al resto.
 erp_px_cat_g1v2
   - Sin problemas: se carga tal cual.
 Todas las tablas Silver llevan la columna técnica dwh_create_date (fecha de carga).
===============================================================================
*/
