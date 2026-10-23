SELECT 
    p.id AS product_id, 
    p.name AS product_name, 
    r.id AS review_id
FROM products p
LEFT JOIN reviews r ON p.id = r.product_id
WHERE r.id IS NULL
LIMIT 10;