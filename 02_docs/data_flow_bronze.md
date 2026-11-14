# Flujo de datos: capa Bronze

Este diagrama muestra cómo viajan los datos desde los archivos CSV de los sistemas de origen hasta las tablas de la capa Bronze.

```mermaid
flowchart LR
    subgraph SRC["Fuentes de datos (archivos CSV)"]
        subgraph CRM["CRM"]
            A1["cust_info.csv"]
            A2["prd_info.csv"]
            A3["sales_details.csv"]
        end
        subgraph ERP["ERP"]
            B1["CUST_AZ12.csv"]
            B2["LOC_A101.csv"]
            B3["PX_CAT_G1V2.csv"]
        end
    end

    P{{"bronze.load_bronze<br/>BULK INSERT<br/>Truncate and Insert"}}

    subgraph BRZ["Capa Bronze (DataWarehouse.bronze)"]
        T1["crm_cust_info"]
        T2["crm_prd_info"]
        T3["crm_sales_details"]
        T4["erp_cust_az12"]
        T5["erp_loc_a101"]
        T6["erp_px_cat_g1v2"]
    end

    A1 --> P
    A2 --> P
    A3 --> P
    B1 --> P
    B2 --> P
    B3 --> P
    P --> T1
    P --> T2
    P --> T3
    P --> T4
    P --> T5
    P --> T6
```

## Correspondencia archivo → tabla

| Sistema | Archivo CSV | Tabla Bronze | Filas |
|---|---|---|---|
| CRM | `cust_info.csv` | `bronze.crm_cust_info` | 18 494 |
| CRM | `prd_info.csv` | `bronze.crm_prd_info` | 397 |
| CRM | `sales_details.csv` | `bronze.crm_sales_details` | 60 398 |
| ERP | `CUST_AZ12.csv` | `bronze.erp_cust_az12` | 18 484 |
| ERP | `LOC_A101.csv` | `bronze.erp_loc_a101` | 18 484 |
| ERP | `PX_CAT_G1V2.csv` | `bronze.erp_px_cat_g1v2` | 37 |

## Cómo se ejecuta

1. `03_scripts/init_database.sql`: crea la base `DataWarehouse` y los esquemas.
2. `03_scripts/bronze/ddl_bronze.sql`: crea las 6 tablas Bronze.
3. `03_scripts/bronze/proc_load_bronze.sql`: crea el procedimiento.
4. `EXEC bronze.load_bronze;`: carga los 6 CSV (carga completa, Truncate & Insert).
5. `04_tests/quality_checks_bronze.sql`: valida filas, columnas y contenido.

## Características de la capa

- **Objeto:** tablas.
- **Carga:** por lotes, completa (Truncate & Insert).
- **Transformación:** ninguna; los datos quedan tal como llegan.
- **Modelo de datos:** ninguno.
- **Siguiente capa:** Silver, que toma estas tablas y limpia los problemas de calidad documentados en `analisis_origenes.md`.
