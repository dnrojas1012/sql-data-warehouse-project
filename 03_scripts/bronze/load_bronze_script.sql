/*
===============================================================================
 Script: load_bronze_script.sql
 Capa: Bronze
 
 Carga los 6 archivos CSV en las tablas de la capa Bronze.
 Método: carga completa (Truncate & Insert): primero se vacía la tabla y luego se insertan todos los registros del archivo con BULK INSERT.
 
===============================================================================
*/

USE DataWarehouse;
GO

-- ============================== CRM ==============================

PRINT '>> Cargando bronze.crm_cust_info';
TRUNCATE TABLE bronze.crm_cust_info;
BULK INSERT bronze.crm_cust_info
FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_crm\cust_info.csv'
WITH (
    FIRSTROW = 2,            -- la fila 1 trae los encabezados
    FIELDTERMINATOR = ',',   -- columnas separadas por coma
    CODEPAGE = '65001',      -- UTF-8, para tildes como en "Andrés"
    TABLOCK                  -- bloquea la tabla durante la carga (más rápido)
);

PRINT '>> Cargando bronze.crm_prd_info';
TRUNCATE TABLE bronze.crm_prd_info;
BULK INSERT bronze.crm_prd_info
FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_crm\prd_info.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', CODEPAGE = '65001', TABLOCK);

PRINT '>> Cargando bronze.crm_sales_details';
TRUNCATE TABLE bronze.crm_sales_details;
BULK INSERT bronze.crm_sales_details
FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_crm\sales_details.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', CODEPAGE = '65001', TABLOCK);

-- ============================== ERP ==============================

PRINT '>> Cargando bronze.erp_cust_az12';
TRUNCATE TABLE bronze.erp_cust_az12;
BULK INSERT bronze.erp_cust_az12
FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_erp\CUST_AZ12.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', CODEPAGE = '65001', TABLOCK);

PRINT '>> Cargando bronze.erp_loc_a101';
TRUNCATE TABLE bronze.erp_loc_a101;
BULK INSERT bronze.erp_loc_a101
FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_erp\LOC_A101.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', CODEPAGE = '65001', TABLOCK);

PRINT '>> Cargando bronze.erp_px_cat_g1v2';
TRUNCATE TABLE bronze.erp_px_cat_g1v2;
BULK INSERT bronze.erp_px_cat_g1v2
FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_erp\PX_CAT_G1V2.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', CODEPAGE = '65001', TABLOCK);
GO