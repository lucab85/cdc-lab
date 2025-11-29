-- Source table reading orders CDC events from Kafka (Debezium JSON format)
-- Used in M1V2 demo
CREATE TABLE orders_raw (
  order_id     BIGINT,
  customer_id  INT,
  order_total  DECIMAL(10,2),
  status       STRING,
  PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
  'connector' = 'kafka',
  'topic' = 'appdb.public.orders',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'flink-orders-consumer',
  'format' = 'debezium-json',
  'debezium-json.schema-include' = 'false',
  'scan.startup.mode' = 'earliest-offset'
);
