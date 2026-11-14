/*
===============================================================================
 Script: proc_load_silver.sql
 Capa: Silver
 Propósito:
   Crea el procedimiento almacenado silver.load_silver, que toma los datos
   de la capa Bronze, aplica las reglas de limpieza y los carga en Silver
   con el método Truncate & Insert.
   Muestra cuánto dura cada carga y, si algo falla, muestra el error.
 Uso:
   EXEC silver.load_silver;
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME,
            @batch_start_time DATETIME, @batch_end_time DATETIME;

    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Cargando la capa Silver';
        PRINT '================================================';

        -- ====================================================================
        -- 1. silver.crm_cust_info
        --    - Quita los cst_id NULL
        --    - Si un cst_id se repite, se queda con el registro más reciente
        --    - TRIM a nombres y apellidos
        --    - Estado civil y género con valores descriptivos
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Cargando silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;
        INSERT INTO silver.crm_cust_info (
            cst_id, cst_key, cst_firstname, cst_lastname,
            cst_marital_status, cst_gndr, cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname)  AS cst_lastname,
            CASE UPPER(TRIM(cst_marital_status))
                WHEN 'S' THEN 'Single'
                WHEN 'M' THEN 'Married'
                ELSE 'n/a'
            END AS cst_marital_status,
            CASE UPPER(TRIM(cst_gndr))
                WHEN 'F' THEN 'Female'
                WHEN 'M' THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,
            cst_create_date
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) AS t
        WHERE flag_last = 1;

        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        -- ====================================================================
        -- 2. silver.crm_prd_info
        --    - Separa prd_key en cat_id (categoría) y prd_key (producto)
        --    - Costo NULL -> 0
        --    - Línea de producto con valores descriptivos
        --    - Fecha de fin = día anterior al inicio de la siguiente versión
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Cargando silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;
        INSERT INTO silver.crm_prd_info (
            prd_id, cat_id, prd_key, prd_nm, prd_cost,
            prd_line, prd_start_dt, prd_end_dt
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
            SUBSTRING(prd_key, 7, LEN(prd_key))          AS prd_key,
            prd_nm,
            ISNULL(prd_cost, 0) AS prd_cost,
            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,
            prd_start_dt,
            DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)) AS prd_end_dt
        FROM bronze.crm_prd_info;

        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        -- ====================================================================
        -- 3. silver.crm_sales_details
        --    - Fechas AAAAMMDD (INT) -> DATE; si son 0 o no tienen 8 dígitos -> NULL
        --    - Ventas inválidas se recalculan como cantidad x |precio|
        --    - Precio inválido se calcula como ventas / cantidad
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Cargando silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;
        INSERT INTO silver.crm_sales_details (
            sls_ord_num, sls_prd_key, sls_cust_id,
            sls_order_dt, sls_ship_dt, sls_due_dt,
            sls_sales, sls_quantity, sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            CASE WHEN sls_price IS NULL OR sls_price <= 0
                 THEN sls_sales / NULLIF(sls_quantity, 0)
                 ELSE sls_price
            END AS sls_price
        FROM (
            SELECT
                sls_ord_num,
                sls_prd_key,
                sls_cust_id,
                CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) <> 8 THEN NULL
                     ELSE CAST(CAST(sls_order_dt AS VARCHAR(8)) AS DATE)
                END AS sls_order_dt,
                CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) <> 8 THEN NULL
                     ELSE CAST(CAST(sls_ship_dt AS VARCHAR(8)) AS DATE)
                END AS sls_ship_dt,
                CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) <> 8 THEN NULL
                     ELSE CAST(CAST(sls_due_dt AS VARCHAR(8)) AS DATE)
                END AS sls_due_dt,
                CASE WHEN sls_sales IS NULL OR sls_sales <= 0
                          OR sls_sales <> sls_quantity * ABS(sls_price)
                     THEN sls_quantity * ABS(sls_price)
                     ELSE sls_sales
                END AS sls_sales,
                sls_quantity,
                sls_price
            FROM bronze.crm_sales_details
        ) AS t;

        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        -- ====================================================================
        -- 4. silver.erp_cust_az12
        --    - Quita el prefijo 'NAS' de cid (para unir con crm_cust_info.cst_key)
        --    - Fecha de nacimiento en el futuro -> NULL
        --    - Género estandarizado
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Cargando silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;
        INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
        SELECT
            CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                 ELSE cid
            END AS cid,
            CASE WHEN bdate > GETDATE() THEN NULL
                 ELSE bdate
            END AS bdate,
            CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                 WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
                 ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12;

        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        -- ====================================================================
        -- 5. silver.erp_loc_a101
        --    - Quita el guion de cid (para unir con crm_cust_info.cst_key)
        --    - País estandarizado
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Cargando silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;
        INSERT INTO silver.erp_loc_a101 (cid, cntry)
        SELECT
            REPLACE(cid, '-', '') AS cid,
            CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
                 WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
                 WHEN cntry IS NULL OR TRIM(cntry) = '' THEN 'n/a'
                 ELSE TRIM(cntry)
            END AS cntry
        FROM bronze.erp_loc_a101;

        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        -- ====================================================================
        -- 6. silver.erp_px_cat_g1v2
        --    - Sin problemas de calidad: se copia tal cual
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Cargando silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;
        INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
        SELECT id, cat, subcat, maintenance
        FROM bronze.erp_px_cat_g1v2;
        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        SET @batch_end_time = GETDATE();
        PRINT '================================================';
        PRINT 'Carga de la capa Silver completada';
        PRINT 'Duración total: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' segundos';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '================================================';
        PRINT 'OCURRIÓ UN ERROR AL CARGAR LA CAPA SILVER';
        PRINT 'Mensaje: ' + ERROR_MESSAGE();
        PRINT 'Número: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Estado: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '================================================';
    END CATCH
END;
GO
