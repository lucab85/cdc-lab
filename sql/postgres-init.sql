CREATE TABLE IF NOT EXISTS customers (
  customer_id   INT PRIMARY KEY,
  first_name    VARCHAR(100),
  last_name     VARCHAR(100),
  email         VARCHAR(255),
  country       VARCHAR(50)
);

INSERT INTO customers (customer_id, first_name, last_name, email, country) VALUES
(1, 'Ana',  'Santos', 'ana@example.com', 'ES'),
(2, 'Bruno','Klein',  'bruno@example.com', 'DE'),
(3, 'Chloe','Nguyen','chloe@example.com', 'FR')
ON CONFLICT (customer_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS orders (
  order_id     INT PRIMARY KEY,
  customer_id  INT NOT NULL,
  order_total  NUMERIC(10,2) NOT NULL,
  order_ts     TIMESTAMPTZ DEFAULT NOW(),
  status       VARCHAR(20) DEFAULT 'PENDING'
);

INSERT INTO orders (order_id, customer_id, order_total, order_ts, status) VALUES
(101, 1, 125.50, NOW() - INTERVAL '2 days', 'SHIPPED'),
(102, 2, 89.99, NOW() - INTERVAL '1 day', 'PROCESSING'),
(103, 3, 42.00, NOW(), 'PENDING')
ON CONFLICT (order_id) DO NOTHING;

-- Enable REPLICA IDENTITY FULL for CDC to capture before/after states
ALTER TABLE customers REPLICA IDENTITY FULL;
ALTER TABLE orders REPLICA IDENTITY FULL;
