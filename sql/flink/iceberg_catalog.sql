CREATE CATALOG lakehouse WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 's3a://iceberg-warehouse/',
  's3.endpoint' = 'http://minio:9000',
  's3.access-key' = 'minioadmin',
  's3.secret-key' = 'minioadmin',
  's3.path-style-access' = 'true'
);

USE CATALOG lakehouse;
CREATE DATABASE IF NOT EXISTS demo;
USE demo;

CREATE TABLE customers_canonical (
  customer_id   INT,
  full_name     STRING,
  primary_email STRING,
  country_code  STRING,
  PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
  'connector' = 'iceberg',
  'format-version' = '2'
);
