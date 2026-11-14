/*
===============================================================================
 Script: init_database.sql
   Crea la base de datos DataWarehouse y los tres esquemas de la
   arquitectura Medallion: bronze, silver y gold.
 ADVERTENCIA:
   Si la base DataWarehouse ya existe, se BORRA con todos sus datos
   y se vuelve a crear. Ejecutar solo para iniciar desde cero.
===============================================================================
*/

USE master;
GO

-- Si la base ya existe, cerrar conexiones abiertas y borrarla
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO

-- Crear la base de datos
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Crear un esquema por capa
CREATE SCHEMA bronze;   -- Datos originales, tal como llegan de los CSV
GO
CREATE SCHEMA silver;   -- Datos limpios y estandarizados
GO
CREATE SCHEMA gold;     -- Datos listos para el análisis (vistas)
GO