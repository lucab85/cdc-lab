-- Example Trino queries for demo

SHOW CATALOGS;
SHOW SCHEMAS FROM lakehouse;
SHOW TABLES FROM lakehouse.demo;

SELECT * FROM lakehouse.demo.customers_canonical;

-- Time travel example (replace <snapshot_id> with actual value)
SELECT * FROM lakehouse.demo.customers_canonical FOR VERSION AS OF <snapshot_id>;
