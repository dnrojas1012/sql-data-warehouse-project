# Análisis de los sistemas de origen

Este documento describe los 6 archivos CSV que alimentan el almacén de datos: qué contiene cada uno, sus columnas, cómo se relacionan y qué problemas de calidad traen. La capa Bronze los carga tal como vienen; los problemas se corrigen en la capa Silver.

## 1. Sistemas de origen

| Sistema | Qué es | Formato | Archivos |
|---|---|---|---|
| CRM | Sistema de Gestión de Relaciones con Clientes | CSV en carpetas | `cust_info.csv`, `prd_info.csv`, `sales_details.csv` |
| ERP | Sistema de Planificación de Recursos Empresariales | CSV en carpetas | `CUST_AZ12.csv`, `LOC_A101.csv`, `PX_CAT_G1V2.csv` |

- **Tipo de carga:** completa (Truncate & Insert). Solo se trabaja con los datos más recientes, sin historial.
- **Tamaño:** cerca de 5 MB entre los 6 archivos, unas 116 000 filas.
- **Formato:** separador coma, primera fila con encabezados, fines de línea Windows (CRLF), codificación UTF-8.

## 2. Detalle de cada archivo

### 2.1 CRM: `cust_info.csv` → `bronze.crm_cust_info` (18 494 filas)
Información de los clientes.

| Columna | Contenido | Ejemplo |
|---|---|---|
| cst_id | Id numérico del cliente | 11000 |
| cst_key | Código del cliente | AW00011000 |
| cst_firstname | Nombre | Jon |
| cst_lastname | Apellido | Yang |
| cst_marital_status | Estado civil (M / S) | M |
| cst_gndr | Género (M / F) | M |
| cst_create_date | Fecha de creación | 2025-10-06 |

### 2.2 CRM: `prd_info.csv` → `bronze.crm_prd_info` (397 filas)
Información actual e histórica de los productos.

| Columna | Contenido | Ejemplo |
|---|---|---|
| prd_id | Id numérico del producto | 210 |
| prd_key | Código del producto (incluye la categoría) | CO-RF-FR-R92B-58 |
| prd_nm | Nombre | HL Road Frame - Black- 58 |
| prd_cost | Costo | 12 |
| prd_line | Línea de producto (R, M, S, T) | R |
| prd_start_dt | Fecha de inicio | 2003-07-01 |
| prd_end_dt | Fecha de fin | 2007-12-28 |

### 2.3 CRM: `sales_details.csv` → `bronze.crm_sales_details` (60 398 filas)
Registros transaccionales de ventas y pedidos.

| Columna | Contenido | Ejemplo |
|---|---|---|
| sls_ord_num | Número de orden | SO43697 |
| sls_prd_key | Código del producto | BK-R93R-62 |
| sls_cust_id | Id del cliente | 21768 |
| sls_order_dt | Fecha de la orden, como número AAAAMMDD | 20101229 |
| sls_ship_dt | Fecha de envío (AAAAMMDD) | 20110105 |
| sls_due_dt | Fecha de vencimiento (AAAAMMDD) | 20110110 |
| sls_sales | Monto total de la venta | 3578 |
| sls_quantity | Cantidad | 1 |
| sls_price | Precio unitario | 3578 |

### 2.4 ERP: `CUST_AZ12.csv` → `bronze.erp_cust_az12` (18 484 filas)
Información adicional del cliente.

| Columna | Contenido | Ejemplo |
|---|---|---|
| CID | Código del cliente, con prefijo "NAS" | NASAW00011000 |
| BDATE | Fecha de nacimiento | 1971-10-06 |
| GEN | Género | Male |

### 2.5 ERP: `LOC_A101.csv` → `bronze.erp_loc_a101` (18 484 filas)
Ubicación de los clientes.

| Columna | Contenido | Ejemplo |
|---|---|---|
| CID | Código del cliente, con guion | AW-00011000 |
| CNTRY | País | Australia |

### 2.6 ERP: `PX_CAT_G1V2.csv` → `bronze.erp_px_cat_g1v2` (37 filas)
Categorías de productos.

| Columna | Contenido | Ejemplo |
|---|---|---|
| ID | Código de la categoría | AC_BR |
| CAT | Categoría | Accessories |
| SUBCAT | Subcategoría | Bike Racks |
| MAINTENANCE | Requiere mantenimiento (Yes / No) | Yes |

## 3. Relaciones entre archivos

| Desde | Hacia | Por medio de | Observación |
|---|---|---|---|
| crm_sales_details | crm_prd_info | `sls_prd_key` = parte final de `prd_key` | `prd_key` trae la categoría al inicio |
| crm_sales_details | crm_cust_info | `sls_cust_id` = `cst_id` | |
| crm_cust_info | erp_cust_az12 | `cst_key` = `CID` | En ERP el código trae el prefijo "NAS" |
| crm_cust_info | erp_loc_a101 | `cst_key` = `CID` | En ERP el código trae un guion (AW-00011000) |
| crm_prd_info | erp_px_cat_g1v2 | primeros 5 caracteres de `prd_key` = `ID` | En CRM usan guion (CO-RF), en ERP guion bajo (CO_RF) |

## 4. Problemas de calidad detectados (se corrigen en Silver)

| Archivo | Problema | Cantidad |
|---|---|---|
| cust_info | `cst_id` vacío | 4 filas |
| cust_info | `cst_id` repetido | 5 ids |
| cust_info | Espacios sobrantes en nombres y apellidos (" Jon", "Yang ") | varias filas |
| cust_info | Género vacío | 4 578 filas |
| prd_info | `prd_line` con espacio al final ("R ") o vacío | 380 con espacio, 17 vacías |
| prd_info | Costo vacío | 2 filas |
| prd_info | Fecha de fin anterior a la de inicio | 200 filas |
| sales_details | Fechas como número AAAAMMDD; algunas en 0 | 19 fechas de orden en 0 |
| sales_details | `sls_sales` vacío, en 0 o negativo | 13 filas |
| sales_details | `sls_price` vacío, en 0 o negativo | 12 filas |
| sales_details | `sls_sales` distinto de cantidad × precio | 15 filas |
| CUST_AZ12 | Género con valores mezclados (Male, M, F, vacío, espacios) | 9 variantes |
| CUST_AZ12 | Fecha de nacimiento en el futuro | 16 filas |
| LOC_A101 | País con valores mezclados (USA, US, United States; DE, Germany) y vacíos | 13 variantes |

## 5. Decisión para la capa Bronze

- Una tabla por archivo, con el nombre `<sourcesystem>_<entity>` (convención del proyecto).
- Las columnas se llaman igual que en el CSV, sin cambios.
- Los datos se cargan tal como vienen, sin limpiar. La limpieza es tarea de Silver.
