-- Insert customers data into Iceberg table (for M1V3 and M3V3)
-- Run this after creating iceberg catalog and customers_raw table

INSERT INTO lakehouse.demo.customers_iceberg
SELECT
  customer_id,
  COALESCE(full_name, first_name || ' ' || last_name) AS full_name,
  COALESCE(email, CAST(customer_id AS STRING) || '@example.local') AS primary_email,
  CAST(country AS STRING) AS country_code
FROM customers_raw;
