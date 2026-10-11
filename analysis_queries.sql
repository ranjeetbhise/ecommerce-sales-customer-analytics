-- E-Commerce Sales & Customer Analytics
-- PostgreSQL-style examples. Create/load tables using the exact CSV column names.
-- Metric note: item sales value is based on item price; it is NOT profit.

-- 1. Monthly item sales value and distinct orders
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(SUM(oi.price)::numeric, 2) AS item_sales_value,
    ROUND(SUM(oi.freight_value)::numeric, 2) AS freight_value
FROM olist_orders_dataset o
JOIN olist_order_items_dataset oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- 2. Top 10 product categories by item sales value
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
    ROUND(SUM(oi.price)::numeric, 2) AS item_sales_value,
    COUNT(DISTINCT oi.order_id) AS orders
FROM olist_order_items_dataset oi
JOIN olist_products_dataset p ON p.product_id = oi.product_id
LEFT JOIN product_category_name_translation t
    ON t.product_category_name = p.product_category_name
GROUP BY 1
ORDER BY item_sales_value DESC
LIMIT 10;

-- 3. Delivery performance for orders with actual and estimated delivery dates
SELECT
    CASE
      WHEN order_delivered_customer_date::timestamp
           <= order_estimated_delivery_date::timestamp THEN 'On time or early'
      ELSE 'Late'
    END AS delivery_status,
    COUNT(*) AS order_count,
    ROUND(AVG(
      EXTRACT(EPOCH FROM (
        order_delivered_customer_date::timestamp -
        order_purchase_timestamp::timestamp
      )) / 86400.0
    )::numeric, 1) AS avg_days_from_purchase_to_delivery
FROM olist_orders_dataset
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- 4. Average review score by delivery status
-- Deduplicate reviews to one row per order before joining if needed.
WITH review_per_order AS (
    SELECT order_id, AVG(review_score::numeric) AS avg_review_score
    FROM olist_order_reviews_dataset
    GROUP BY order_id
),
delivery AS (
    SELECT order_id,
           CASE
             WHEN order_delivered_customer_date::timestamp
                  <= order_estimated_delivery_date::timestamp THEN 'On time or early'
             ELSE 'Late'
           END AS delivery_status
    FROM olist_orders_dataset
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT d.delivery_status,
       COUNT(*) AS reviewed_orders,
       ROUND(AVG(r.avg_review_score)::numeric, 2) AS avg_review_score
FROM delivery d
JOIN review_per_order r ON r.order_id = d.order_id
GROUP BY d.delivery_status;

-- 5. Customer repeat-order analysis using customer_unique_id
WITH customer_orders AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS order_count
    FROM olist_orders_dataset o
    JOIN olist_customers_dataset c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS unique_customers,
    COUNT(*) FILTER (WHERE order_count > 1) AS repeat_customers,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE order_count > 1) / NULLIF(COUNT(*), 0),
      2
    ) AS repeat_customer_pct
FROM customer_orders;

-- 6. Data quality: duplicate order IDs in the orders table
SELECT order_id, COUNT(*) AS row_count
FROM olist_orders_dataset
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 7. Data quality: missing critical fields
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS missing_order_id,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS missing_customer_id,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS missing_purchase_timestamp
FROM olist_orders_dataset;

-- 8. Data quality: delivered date earlier than purchase date
SELECT order_id, order_purchase_timestamp, order_delivered_customer_date
FROM olist_orders_dataset
WHERE order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date < order_purchase_timestamp;
