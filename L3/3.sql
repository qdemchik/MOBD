SELECT 
    c.name AS category_name,
    COUNT(p.id) AS products_count,
    ROUND(AVG(p.price), 2) AS avg_price
FROM categories c
LEFT JOIN product_categories pc ON c.id = pc.category_id
LEFT JOIN products p ON pc.product_id = p.id
GROUP BY c.id, c.name
ORDER BY products_count DESC;