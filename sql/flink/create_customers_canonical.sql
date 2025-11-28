CREATE TABLE customers_canonical (
  customer_id   INT,
  full_name     STRING,
  primary_email STRING,
  country_code  STRING,
  PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
  'connector' = 'upsert-kafka',
  'topic' = 'customers_canonical',
  'key.format' = 'avro',
  'value.format' = 'avro'
);

INSERT INTO customers_canonical
SELECT
  customer_id,
  COALESCE(full_name, first_name || ' ' || last_name) AS full_name,
  COALESCE(email, customer_id || '@example.local')    AS primary_email,
  CAST(country AS STRING)                             AS country_code
FROM customers_raw;
