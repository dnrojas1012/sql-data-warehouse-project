/*
===============================================================================
 Script: proc_load_bronze.sql
 Capa: Bronze
 
 Crea el procedimiento almacenado bronze.load_bronze, que carga los 6 CSV en la capa Bronze con el método Truncate & Insert (BULK INSERT).
 Muestra cuánto dura cada carga y, si algo falla, muestra el error.
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME,
            @batch_start_time DATETIME, @batch_end_time DATETIME;

    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Cargando la capa Bronze';
        PRINT '================================================';

        -- ============================== CRM ==============================
        PRINT '------------------------------------------------';
        PRINT 'Cargando tablas del CRM';
        PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        PRINT '>> Truncando e insertando: bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;
        BULK INSERT bronze.crm_cust_info
        FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_crm\cust_info.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', CODEPAGE = '65001', TABLOCK);
        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        SET @start_time = GETDATE();
        PRINT '>> Truncando e insertando: bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;
        BULK INSERT bronze.crm_prd_info
        FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_crm\prd_info.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', CODEPAGE = '65001', TABLOCK);
        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        SET @start_time = GETDATE();
        PRINT '>> Truncando e insertando: bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;
        BULK INSERT bronze.crm_sales_details
        FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_crm\sales_details.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', CODEPAGE = '65001', TABLOCK);
        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        -- ============================== ERP ==============================
        PRINT '------------------------------------------------';
        PRINT 'Cargando tablas del ERP';
        PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        PRINT '>> Truncando e insertando: bronze.erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;
        BULK INSERT bronze.erp_cust_az12
        FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_erp\CUST_AZ12.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', CODEPAGE = '65001', TABLOCK);
        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        SET @start_time = GETDATE();
        PRINT '>> Truncando e insertando: bronze.erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;
        BULK INSERT bronze.erp_loc_a101
        FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_erp\LOC_A101.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', CODEPAGE = '65001', TABLOCK);
        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        SET @start_time = GETDATE();
        PRINT '>> Truncando e insertando: bronze.erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;
        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'C:\ISW623\sql-data-warehouse-project\01_datasets\source_erp\PX_CAT_G1V2.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', CODEPAGE = '65001', TABLOCK);
        SET @end_time = GETDATE();
        PRINT '>> Duración: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' segundos';

        SET @batch_end_time = GETDATE();
        PRINT '================================================';
        PRINT 'Carga de la capa Bronze completada';
        PRINT 'Duración total: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' segundos';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '================================================';
        PRINT 'OCURRIÓ UN ERROR AL CARGAR LA CAPA BRONZE';
        PRINT 'Mensaje: ' + ERROR_MESSAGE();
        PRINT 'Número: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Estado: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '================================================';
    END CATCH
END;
GO