SELECT 
    p.name AS product_name, 
    c.name AS category_name, 
    s.name AS shop_name, 
    p.price
FROM products p
INNER JOIN product_categories pc ON p.id = pc.product_id
INNER JOIN categories c ON pc.category_id = c.id
INNER JOIN shops s ON p.shop_id = s.id
ORDER BY p.price DESC
LIMIT 10;