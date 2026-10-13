SELECT name, price, shop_id 
FROM products 
WHERE (price > 5000 OR price < 200) 
  AND shop_id = 1;