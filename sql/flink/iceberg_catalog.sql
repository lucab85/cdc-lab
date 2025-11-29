-- Create Iceberg catalog backed by REST catalog server
CREATE CATALOG lakehouse WITH (
  'type' = 'iceberg',
  'catalog-type' = 'rest',
  'uri' = 'http://iceberg-rest:8181',
  'warehouse' = 's3://warehouse/',
  'io-impl' = 'org.apache.iceberg.aws.s3.S3FileIO',
  's3.endpoint' = 'http://minio:9000',
  's3.access-key-id' = 'minioadmin',
  's3.secret-access-key' = 'minioadmin',
  's3.path-style-access' = 'true'
);

USE CATALOG lakehouse;
CREATE DATABASE IF NOT EXISTS demo;
USE demo;

-- Iceberg table for customers (used in M1V3 and M3V3 demos)
CREATE TABLE IF NOT EXISTS customers_iceberg (
  customer_id   INT,
  full_name     STRING,
  primary_email STRING,
  country_code  STRING,
  PRIMARY KEY (customer_id) NOT ENFORCED
);

-- Iceberg table for orders (used in M1V2 demo)
CREATE TABLE IF NOT EXISTS orders_iceberg (
  order_id      BIGINT,
  customer_id   INT,
  order_total   DECIMAL(10,2),
  status        STRING,
  PRIMARY KEY (order_id) NOT ENFORCED
);
