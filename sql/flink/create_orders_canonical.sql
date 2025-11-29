-- Canonical orders table - writes to Iceberg via Kafka upserts
-- Used in M1V2 demo

-- First, create the sink table (upsert to Kafka topic)
CREATE TABLE orders_canonical (
  order_id      BIGINT,
  customer_id   INT,
  order_total   DECIMAL(10,2),
  status        STRING,
  PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
  'connector' = 'upsert-kafka',
  'topic' = 'orders_canonical',
  'properties.bootstrap.servers' = 'kafka:9092',
  'key.format' = 'json',
  'value.format' = 'json'
);

-- Transform and load from raw to canonical
INSERT INTO orders_canonical
SELECT
  order_id,
  customer_id,
  order_total,
  status
FROM orders_raw;
