WITH seller_category_revenue AS (
    SELECT 
        c.name AS category_name, 
        s.name AS shop_name,
        SUM(oi.quantity * oi.price_at_purchase) AS revenue
    FROM shops s
    JOIN products p ON s.id = p.shop_id
    JOIN product_categories pc ON p.id = pc.product_id
    JOIN categories c ON pc.category_id = c.id
    JOIN order_items oi ON p.id = oi.product_id
    GROUP BY c.name, s.name
)
SELECT 
    category_name, 
    shop_name, 
    revenue,
    ROUND((revenue / SUM(revenue) OVER (PARTITION BY category_name)) * 100, 2) AS revenue_share_percent
FROM seller_category_revenue
ORDER BY category_name, revenue DESC;