-- Trino Demo Queries for Iceberg Tables
-- Run with: docker exec -it cdc-lab-trino-1 trino --catalog lakehouse

-- ============================================
-- Basic Catalog and Schema Discovery
-- ============================================
SHOW CATALOGS;
SHOW SCHEMAS FROM lakehouse;
SHOW TABLES FROM lakehouse.demo;

-- ============================================
-- Query Iceberg Tables
-- ============================================

-- Query customers
SELECT * FROM lakehouse.demo.customers_iceberg ORDER BY customer_id;

-- Query orders
SELECT * FROM lakehouse.demo.orders_iceberg ORDER BY order_id;

-- Join customers and orders
SELECT 
    c.customer_id,
    c.full_name,
    c.primary_email,
    o.order_id,
    o.order_total,
    o.status
FROM lakehouse.demo.customers_iceberg c
JOIN lakehouse.demo.orders_iceberg o ON c.customer_id = o.customer_id
ORDER BY c.customer_id, o.order_id;

-- ============================================
-- Time Travel Queries
-- ============================================

-- View all snapshots for customers table
SELECT snapshot_id, committed_at, operation, summary
FROM "lakehouse"."demo"."customers_iceberg$snapshots"
ORDER BY committed_at DESC;

-- Query a specific snapshot (replace <snapshot_id> with actual BIGINT value)
-- SELECT * FROM lakehouse.demo.customers_iceberg FOR VERSION AS OF <snapshot_id>;

-- ============================================
-- Iceberg Metadata Tables
-- ============================================

-- View table history
SELECT * FROM "lakehouse"."demo"."customers_iceberg$history";

-- View data files
SELECT file_path, record_count, file_size_in_bytes
FROM "lakehouse"."demo"."customers_iceberg$files";

-- View manifests
SELECT path, length, partition_spec_id, added_rows_count
FROM "lakehouse"."demo"."customers_iceberg$manifests";

-- ============================================
-- Aggregations
-- ============================================

-- Orders by status
SELECT status, COUNT(*) as order_count, SUM(order_total) as total_revenue
FROM lakehouse.demo.orders_iceberg
GROUP BY status
ORDER BY order_count DESC;

-- Customers by country
SELECT country_code, COUNT(*) as customer_count
FROM lakehouse.demo.customers_iceberg
GROUP BY country_code
ORDER BY customer_count DESC;
