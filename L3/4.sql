SELECT 
    s.name AS shop_name,
    SUM(oi.quantity * oi.price_at_purchase) AS total_revenue
FROM shops s
JOIN products p ON s.id = p.shop_id
JOIN order_items oi ON p.id = oi.product_id
GROUP BY s.id, s.name
HAVING SUM(oi.quantity * oi.price_at_purchase) > 500000
ORDER BY total_revenue DESC;