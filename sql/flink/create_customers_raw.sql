CREATE TABLE customers_raw (
  customer_id INT,
  first_name  STRING,
  last_name   STRING,
  email       STRING,
  country     STRING,
  full_name   STRING,
  PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
  'connector' = 'kafka',
  'topic' = 'appdb.public.customers',
  'format' = 'avro',
  'scan.startup.mode' = 'earliest-offset'
);
