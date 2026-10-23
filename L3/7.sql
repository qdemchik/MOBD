CREATE OR REPLACE VIEW shop_revenue_view AS
SELECT s.id, s.name, SUM(oi.quantity * oi.price_at_purchase) AS revenue
FROM shops s
JOIN products p ON s.id = p.shop_id
JOIN order_items oi ON p.id = oi.product_id
GROUP BY s.id, s.name;


CREATE OR REPLACE VIEW products_without_reviews_view AS
SELECT p.id, p.name, p.price, s.name AS shop_name
FROM products p
JOIN shops s ON p.shop_id = s.id
LEFT JOIN reviews r ON p.id = r.product_id
WHERE r.id IS NULL;


SELECT * FROM shop_revenue_view ORDER BY revenue DESC LIMIT 5;
SELECT * FROM products_without_reviews_view LIMIT 5;