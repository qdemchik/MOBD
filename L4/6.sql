SELECT 
    p.name AS product_name, 
    p.price, 
    c.name AS category_name,
    ROUND(AVG(p.price) OVER (PARTITION BY c.id), 2) AS avg_category_price
FROM products p
JOIN product_categories pc ON p.id = pc.product_id
JOIN categories c ON pc.category_id = c.id
ORDER BY category_name, p.price DESC
LIMIT 10;