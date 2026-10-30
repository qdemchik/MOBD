WITH ranked_products AS (
    SELECT 
        c.name AS category_name, 
        p.name AS product_name, 
        p.price,
        ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY p.price DESC) AS rn
    FROM products p
    JOIN product_categories pc ON p.id = pc.product_id
    JOIN categories c ON pc.category_id = c.id
)
SELECT category_name, product_name, price
FROM ranked_products
WHERE rn <= 3
ORDER BY category_name, rn;