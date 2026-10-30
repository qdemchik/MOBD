SELECT 
    c.name AS category_name, 
    p.name AS product_name, 
    p.price,
    ROW_NUMBER() OVER w AS row_num,
    RANK() OVER w AS rnk,
    DENSE_RANK() OVER w AS dense_rnk
FROM products p
JOIN product_categories pc ON p.id = pc.product_id
JOIN categories c ON pc.category_id = c.id
WINDOW w AS (PARTITION BY c.id ORDER BY p.price DESC)
ORDER BY category_name, row_num
LIMIT 15;