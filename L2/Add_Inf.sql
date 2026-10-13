-- 1. Очищаем ВСЁ в правильном порядке (от дочерних к родителям)
TRUNCATE TABLE payments, reviews, order_items, orders, 
             product_categories, products, addresses, shops, 
             categories, users RESTART IDENTITY CASCADE;

-- 2. Пользователи (100 шт.)
INSERT INTO users (email, password_hash)
SELECT 'user_' || g || '@marketplace.com', md5(random()::text)
FROM generate_series(1, 100) AS g;

-- 3. Магазины (10 шт.)
INSERT INTO shops (owner_id, name, description)
SELECT (random() * 99 + 1)::int, 'Магазин №' || g, 'Описание магазина ' || g
FROM generate_series(1, 10) AS g;

-- 4. Адреса (100 шт.)
INSERT INTO addresses (user_id, city, street, zip_code)
SELECT (random() * 99 + 1)::int, 'Москва', 'ул. Пушкина, д. ' || g, '101000'
FROM generate_series(1, 100) AS g;

-- 5. Категории (иерархия)
INSERT INTO categories (name, parent_category_id) VALUES 
('Электроника', NULL), ('Одежда', NULL), ('Книги', NULL);
INSERT INTO categories (name, parent_category_id) VALUES 
('Смартфоны', 1), ('Ноутбуки', 1), ('Футболки', 2);

-- 6. Товары (1500 шт.)
INSERT INTO products (shop_id, name, description, price)
SELECT 
    (random() * 9 + 1)::int,
    'Товар_' || g,
    'Описание товара номер ' || g,
    (random() * 10000 + 100)::numeric(10, 2)
FROM generate_series(1, 1500) AS g;

-- 7. Связь товар-категория
INSERT INTO product_categories (product_id, category_id)
SELECT id, (random() * 5 + 1)::int FROM products
ON CONFLICT DO NOTHING;

-- 8. ЗАКАЗЫ (1200 шт.) — ВАЖНО: user_id и address_id должны существовать!
INSERT INTO orders (user_id, address_id, status, total_amount, created_at)
SELECT 
    (random() * 99 + 1)::int,
    (random() * 99 + 1)::int,
    (ARRAY['new', 'paid', 'shipped', 'delivered'])[floor(random() * 4 + 1)::int],
    (random() * 20000 + 500)::numeric(12, 2),
    NOW() - (random() * 365 || ' days')::interval
FROM generate_series(1, 1200) AS g;

-- 9. ПОЗИЦИИ ЗАКАЗОВ — теперь order_id точно существует!
INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase)
SELECT 
    (random() * 1199 + 1)::int,  -- от 1 до 1200 (как в orders)
    (random() * 1499 + 1)::int,  -- от 1 до 1500 (как в products)
    (random() * 3 + 1)::int,
    (random() * 10000 + 100)::numeric(10, 2)
FROM generate_series(1, 5000) AS g
ON CONFLICT (order_id, product_id) DO NOTHING;

-- 10. Обнуляем описания у части товаров (для демонстрации IS NULL)
UPDATE products SET description = NULL WHERE id % 10 = 0;