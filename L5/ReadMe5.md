
# Отчёт по лабораторной работе №5
## Тема: Транзакции, целостность данных и серверная логика

### Выполнила: Овчинникова Анна БВТ2502

---

## 1. Постановка задачи

Обеспечить согласованность данных и реализовать серверную логику для базы данных маркетплейса. В рамках работы необходимо:
1. Продемонстрировать работу транзакций с использованием `BEGIN`, `COMMIT` и `ROLLBACK`.
2. Реализовать атомарную функцию оформления заказа на PL/pgSQL с проверкой складских остатков.
3. Создать функцию, возвращающую сводный показатель (выручку продавца за период).
4. Настроить триггер аудита для логирования изменений цены товара.
5. Настроить триггер для поддержания денормализованного поля (средний рейтинг товара).
6. Обосновать разделение логики между базой данных и приложением.

---

## 2. Реализация запросов и результаты

### Подготовка данных (добавление недостающих сущностей)
```sql

CREATE TABLE IF NOT EXISTS stock (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 0 CHECK (quantity >= 0)
);

INSERT INTO stock (product_id, quantity)
SELECT id, (random() * 100 + 10)::int FROM products WHERE id <= 50
ON CONFLICT (product_id) DO NOTHING;

ALTER TABLE products ADD COLUMN IF NOT EXISTS avg_rating NUMERIC(3,2) DEFAULT 0;

CREATE TABLE IF NOT EXISTS price_audit_log (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(id),
    old_price NUMERIC(10,2),
    new_price NUMERIC(10,2),
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
```

### Задание 1. Демонстрация работы транзакции
**Текст запроса:**
```sql
BEGIN;
    UPDATE products SET price = price * 1.1 WHERE id = 1;
    UPDATE stock SET quantity = quantity - 1 WHERE product_id = 1;
COMMIT;

BEGIN;
    INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase) 
    VALUES (1, 9999, 1, 1000);
ROLLBACK;

SELECT id, price FROM products WHERE id = 1;
```
**Назначение:** Показать, что при возникновении ошибки или явном вызове `ROLLBACK` база данных возвращается к состоянию до начала транзакции (свойство атомарности).

---

### Задание 2. Атомарная функция оформления заказа
**Текст запроса:**
```sql
CREATE OR REPLACE FUNCTION place_order(p_user_id INT, p_product_id INT, p_qty INT)
RETURNS INT AS $$
DECLARE
    v_order_id INT;
    v_price NUMERIC(10,2);
    v_stock INT;
BEGIN
    SELECT price, (SELECT quantity FROM stock WHERE product_id = p_product_id) 
    INTO v_price, v_stock FROM products WHERE id = p_product_id;

    IF v_stock < p_qty THEN
        RAISE EXCEPTION 'Недостаточно товара на складе (id=%), доступно: %', p_product_id, v_stock;
    END IF;

    INSERT INTO orders (user_id, address_id, status, total_amount) 
    VALUES (p_user_id, 1, 'new', v_price * p_qty) 
    RETURNING id INTO v_order_id;

    INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase)
    VALUES (v_order_id, p_product_id, p_qty, v_price);

    UPDATE stock SET quantity = quantity - p_qty WHERE product_id = p_product_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

SELECT place_order(1, 1, 2);
SELECT place_order(1, 1, 999);
```
**Назначение:** Инкапсулировать бизнес-процесс покупки. Если товара не хватает, `RAISE EXCEPTION` прерывает выполнение, и PostgreSQL автоматически откатывает все сделанные внутри функции изменения (создание заказа и позиции).
**Результат:**
![alt text](<Снимок экрана 2026-11-04 в 13.00.07.png>)
---

### Задание 3. Функция расчёта выручки продавца
**Текст запроса:**
```sql
CREATE OR REPLACE FUNCTION get_seller_revenue(p_shop_id INT, p_start DATE, p_end DATE)
RETURNS NUMERIC AS $$
DECLARE
    v_total_revenue NUMERIC;
BEGIN
    SELECT COALESCE(SUM(oi.quantity * oi.price_at_purchase), 0)
    INTO v_total_revenue
    FROM order_items oi
    JOIN products p ON oi.product_id = p.id
    JOIN orders o ON oi.order_id = o.id
    WHERE p.shop_id = p_shop_id 
      AND o.created_at::DATE BETWEEN p_start AND p_end;
      
    RETURN v_total_revenue;
END;
$$ LANGUAGE plpgsql;

SELECT get_seller_revenue(1, '2025-01-01', '2026-12-31') AS revenue;
```
**Назначение:** Демонстрация использования локальных переменных (`DECLARE`) и оператора `SELECT ... INTO` внутри PL/pgSQL для возврата скалярного значения.
**Результат:**
![alt text](<Снимок экрана 2026-11-04 в 13.00.32.png>)

---

### Задание 4. Триггер аудита изменения цен
**Текст запроса:**
```sql
CREATE OR REPLACE FUNCTION log_price_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.price IS DISTINCT FROM NEW.price THEN
        INSERT INTO price_audit_log (product_id, old_price, new_price)
        VALUES (NEW.id, OLD.price, NEW.price);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_price_audit
AFTER UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION log_price_change();
UPDATE products SET price = 99999.00 WHERE id = 1;
SELECT * FROM price_audit_log;
```
**Назначение:** Автоматическое ведение журнала изменений. Триггер срабатывает `AFTER UPDATE` и сравнивает старое (`OLD`) и новое (`NEW`) значения цены.
**Результат:**
![alt text](<Снимок экрана 2026-11-04 в 13.00.56.png>)

---

### Задание 5. Триггер пересчёта среднего рейтинга
**Текст запроса:**
```sql
CREATE OR REPLACE FUNCTION update_avg_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products 
    SET avg_rating = (SELECT ROUND(AVG(rating)::numeric, 2) FROM reviews WHERE product_id = NEW.product_id)
    WHERE id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_rating
AFTER INSERT OR UPDATE OR DELETE ON reviews
FOR EACH ROW
EXECUTE FUNCTION update_avg_rating();

INSERT INTO reviews (user_id, product_id, rating, comment) VALUES (1, 1, 4, 'Хорошо');
SELECT id, name, avg_rating FROM products WHERE id = 1;
```
**Назначение:** Поддержание денормализованного поля `avg_rating` в актуальном состоянии без необходимости пересчитывать `AVG()` при каждом чтении карточки товара.
**Результат:**
![alt text](<Снимок экрана 2026-11-04 в 13.01.24.png>)

---

### Задание 6. Разделение логики (Обоснование)
* **В базе данных (PL/pgSQL, триггеры):** Хранится логика, критичная для целостности данных (атомарное списание остатков, запрет отрицательных цен, аудит изменений, пересчёт агрегатов). Это гарантирует, что правила не будут нарушены, даже если к базе подключатся несколько разных приложений (веб-сайт, мобильное приложение, админка).
* **В приложении (Python/JS/Java):** Хранится прикладная бизнес-логика (валидация форм, расчёт скидок по промокодам, интеграция с платёжными шлюзами, отправка email-уведомлений). Это упрощает тестирование, деплой и миграцию на другие СУБД в будущем.

---

## 3. Принятые проектные решения

- **Добавление таблицы `stock`:** В схеме 1-й лабораторной складские остатки не были выделены в отдельную сущность. Для корректного выполнения задания 2 (атомарное оформление заказа) таблица была добавлена, так как хранение остатка прямо в `products` нарушало бы принципы нормализации при расширении ассортимента.
- **Использование `IS DISTINCT FROM` в триггере аудита:** В PostgreSQL обычное сравнение `OLD.price <> NEW.price` вернёт `UNKNOWN`, если одно из значений `NULL`. Оператор `IS DISTINCT FROM` корректно обрабатывает `NULL` и предотвращает ложные срабатывания триггера.
- **Триггер рейтинга на `AFTER INSERT OR UPDATE OR DELETE`:** Средний рейтинг должен пересчитываться не только при добавлении нового отзыва, но и при его редактировании или удалении модератором.

---

## 4. Ответы на контрольные вопросы

1. **Что такое транзакция и какими свойствами ACID она обладает?**  
   Транзакция — это последовательность операций, выполняемая как единое целое. Свойства ACID: Атомарность (всё или ничего), Согласованность (не нарушает ограничений БД), Изоляция (параллельные транзакции не мешают друг другу), Долговечность (зафиксированные изменения сохраняются при сбоях).
2. **Что делают команды COMMIT и ROLLBACK? Для чего нужен SAVEPOINT?**  
   `COMMIT` фиксирует изменения, делая их постоянными. `ROLLBACK` отменяет все изменения текущей транзакции. `SAVEPOINT` создаёт контрольную точку внутри транзакции, позволяя откатиться к ней частично, не отменяя всю транзакцию целиком.
3. **Приведите пример сценария в маркетплейсе, где необходима транзакция.**  
   Оформление заказа: нужно создать запись в `orders`, добавить позиции в `order_items` и уменьшить количество товара в `stock`. Если на шаге списания остатка произойдёт ошибка (товар закончился), транзакция откатится, и мы не получим «висящий» заказ без товара.
4. **Что обеспечивает свойство атомарности и что — свойство изоляции транзакции?**  
   Атомарность обеспечивается механизмами отката (undo-log) при ошибках. Изоляция в PostgreSQL обеспечивается механизмом MVCC (многоверсионность), когда каждая транзакция видит согласованный снимок данных на момент своего начала.
5. **Что такое функция в PostgreSQL и какие конструкции предоставляет язык PL/pgSQL?**  
   Функция — именованный блок кода, сохраняемый на сервере. PL/pgSQL добавляет к SQL процедурные конструкции: переменные (`DECLARE`), ветвления (`IF...THEN`), циклы (`LOOP`, `FOR`), обработку исключений (`EXCEPTION`).
6. **Как в функции PL/pgSQL обработать ошибочную ситуацию и прервать выполнение?**  
   С помощью команды `RAISE EXCEPTION 'Текст ошибки'`. Она немедленно прерывает выполнение функции и инициирует откат текущей транзакции.
7. **Что такое триггер и в ответ на какие события он срабатывает?**  
   Триггер — это механизм, автоматически запускающий функцию при изменении данных. События: `INSERT`, `UPDATE`, `DELETE`.
8. **Чем различаются триггеры BEFORE и AFTER, а также уровня строки и уровня оператора? Что такое NEW и OLD?**  
   `BEFORE` срабатывает до изменения данных (позволяет изменить вставляемые данные), `AFTER` — после (для аудита). Уровень строки (`FOR EACH ROW`) срабатывает для каждой изменённой строки, уровня оператора — один раз на весь SQL-запрос. `NEW` — новые данные строки, `OLD` — старые (до изменения).
9. **Для каких задач применяют триггеры? Приведите примеры из кейса маркетплейса.**  
   Аудит (логирование изменения цен), поддержание денормализованных полей (пересчёт среднего рейтинга товара), автоматическое заполнение полей (например, `updated_at`).
10. **Каковы достоинства и недостатки размещения бизнес-логики на стороне СУБД?**  
    *Достоинства:* гарантия целостности, высокая скорость (данные не гоняются по сети), единообразие правил для всех клиентов. *Недостатки:* сложность отладки и тестирования, привязка к конкретному диалекту SQL (PL/pgSQL), повышенная нагрузка на сервер БД.


