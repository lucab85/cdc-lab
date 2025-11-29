-- Insert orders data into Iceberg table (for M1V2 Step 5)
-- Run this after creating iceberg catalog and orders_raw table

INSERT INTO lakehouse.demo.orders_iceberg
SELECT
  order_id,
  customer_id,
  order_total,
  status
FROM orders_raw;
