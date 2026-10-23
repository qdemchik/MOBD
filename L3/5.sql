SELECT name, price FROM products 
WHERE price > (SELECT AVG(price) FROM products) 
LIMIT 5;

SELECT name FROM products 
WHERE id IN (
    SELECT product_id FROM product_categories 
    WHERE category_id IN (SELECT id FROM categories WHERE name IN ('Смартфоны', 'Ноутбуки'))
) LIMIT 5;

SELECT name FROM shops s 
WHERE EXISTS (SELECT 1 FROM products p WHERE p.shop_id = s.id) 
LIMIT 5;