-- Source table reading CDC events from Kafka (Debezium JSON format)
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
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'flink-customers-consumer',
  'format' = 'debezium-json',
  'debezium-json.schema-include' = 'false',
  'scan.startup.mode' = 'earliest-offset'
);
