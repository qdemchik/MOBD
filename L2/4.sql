SELECT id, name, price, description 
FROM products 
WHERE price BETWEEN 1000 AND 3000        
  AND shop_id IN (1, 2, 3)               
  AND name ILIKE '%Товар_1%'             
  AND description IS NULL;               