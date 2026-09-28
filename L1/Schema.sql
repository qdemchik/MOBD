
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS product_categories CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS shops CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS users CASCADE;


CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE shops (
    id SERIAL PRIMARY KEY,
    owner_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT
);


CREATE TABLE addresses (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    city VARCHAR(100) NOT NULL,
    street VARCHAR(255) NOT NULL,
    zip_code VARCHAR(20) NOT NULL,
    CONSTRAINT chk_zip_code CHECK (zip_code ~ '^[0-9]{6}$') -- Пример CHECK: только 6 цифр
);


CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    parent_category_id INT REFERENCES categories(id) ON DELETE SET NULL ON UPDATE CASCADE,
    name VARCHAR(100) NOT NULL UNIQUE
);


CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    shop_id INT NOT NULL REFERENCES shops(id) ON DELETE CASCADE ON UPDATE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,
    CONSTRAINT chk_price_positive CHECK (price >= 0)
);


CREATE TABLE product_categories (
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    category_id INT NOT NULL REFERENCES categories(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (product_id, category_id) -- Естественный составной ключ
);


CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE, -- RESTRICT, чтобы не удалить пользователя с заказами
    address_id INT NOT NULL REFERENCES addresses(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'new',
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_order_status CHECK (status IN ('new', 'paid', 'shipped', 'delivered', 'cancelled'))
);


CREATE TABLE order_items (
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    quantity INT NOT NULL,
    price_at_purchase NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT chk_quantity_positive CHECK (quantity > 0),
    CONSTRAINT chk_item_price_positive CHECK (price_at_purchase >= 0)
);


CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    rating SMALLINT NOT NULL,
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_product_review UNIQUE (user_id, product_id), -- Один отзыв от юзера на товар
    CONSTRAINT chk_rating_range CHECK (rating BETWEEN 1 AND 5)
);


CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE, -- 1 к 1
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    amount NUMERIC(12, 2) NOT NULL,
    paid_at TIMESTAMPTZ,
    CONSTRAINT chk_payment_status CHECK (status IN ('pending', 'success', 'failed', 'refunded')),
    CONSTRAINT chk_payment_amount CHECK (amount >= 0)
);


CREATE INDEX idx_products_shop_id ON products(shop_id);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_reviews_product_id ON reviews(product_id);