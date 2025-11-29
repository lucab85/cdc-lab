-- Canonical customers table - upserts to a Kafka topic
CREATE TABLE customers_canonical (
  customer_id   INT,
  full_name     STRING,
  primary_email STRING,
  country_code  STRING,
  PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
  'connector' = 'upsert-kafka',
  'topic' = 'customers_canonical',
  'properties.bootstrap.servers' = 'kafka:9092',
  'key.format' = 'json',
  'value.format' = 'json'
);

-- Transform and load from raw to canonical
INSERT INTO customers_canonical
SELECT
  customer_id,
  COALESCE(full_name, first_name || ' ' || last_name) AS full_name,
  COALESCE(email, CAST(customer_id AS STRING) || '@example.local') AS primary_email,
  CAST(country AS STRING) AS country_code
FROM customers_raw;
