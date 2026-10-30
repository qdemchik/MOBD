# Отчёт по лабораторной работе №4
## Тема: Оконные функции и аналитика данных

### Выполнила: Овчинникова Анна БВТ2502

---

## 1. Постановка задачи

Реализовать набор аналитических запросов к базе данных маркетплейса с использованием оконных функций. Запросы должны:
- строить рейтинг товаров по цене внутри категории с помощью `ROW_NUMBER`, `RANK` и `DENSE_RANK`;
- выводить топ-3 самых дорогих товара в каждой категории с использованием CTE;
- вычислять нарастающий итог выручки по дням;
- рассчитывать долю выручки каждого продавца в общей выручке его категории;
- применять функции смещения `LAG` и `LEAD` для сравнения выручки текущего дня с предыдущим и последующим;
- решать одну из аналитических задач двумя способами (оконная функция и обычная группировка) с обоснованием выбора.

---

## 2. Реализация запросов и результаты

### Задание 1. Ранжирующие функции (ROW_NUMBER, RANK, DENSE_RANK)
**Текст запроса:**
```sql
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
```
**Назначение:** Проранжировать товары по убыванию цены внутри каждой категории. 
**Различие функций:** При одинаковых ценах `ROW_NUMBER` присвоит уникальные номера (1, 2, 3), `RANK` даст одинаковый ранг, но пропустит следующий номер (1, 1, 3), а `DENSE_RANK` даст одинаковый ранг без пропусков (1, 1, 2).
**Результат:**
![!\[alt text\](image.png)](<Снимок экрана 2026-10-30 в 17.50.31.png>)

---

### Задание 2. Топ-3 самых дорогих товара в категории (CTE + оконная функция)
**Текст запроса:**
```sql
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
```
**Назначение:** Отобрать только первые три строки (rn <= 3) для каждой категории, используя общее табличное выражение (CTE) для предварительной нумерации.
**Результат:**
![L4/Снимок экрана 2026-10-30 в 17.50.54.png](<Снимок экрана 2026-10-30 в 17.50.54.png>)

---

### Задание 3. Нарастающий итог выручки по дням
**Текст запроса:**
```sql
WITH daily_revenue AS (
    SELECT 
        o.created_at::DATE AS order_date,
        SUM(oi.quantity * oi.price_at_purchase) AS day_revenue
    FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    GROUP BY o.created_at::DATE
)
SELECT 
    order_date, 
    day_revenue,
    SUM(day_revenue) OVER (ORDER BY order_date ASC) AS running_total
FROM daily_revenue
ORDER BY order_date ASC;
```
**Назначение:** Сначала агрегировать выручку по дням, а затем с помощью оконной функции `SUM() OVER (ORDER BY ...)` вычислить кумулятивную (нарастающую) сумму от начала периода до текущего дня.
**Результат:**
![!\[!\[3\](<Нарастающий итог>)\](<Screenshots/lab4_running_total.png>)](<Снимок экрана 2026-10-30 в 17.51.14.png>)

---

### Задание 4. Доля выручки продавца в категории
**Текст запроса:**
```sql
WITH seller_category_revenue AS (
    SELECT 
        c.name AS category_name, 
        s.name AS shop_name,
        SUM(oi.quantity * oi.price_at_purchase) AS revenue
    FROM shops s
    JOIN products p ON s.id = p.shop_id
    JOIN product_categories pc ON p.id = pc.product_id
    JOIN categories c ON pc.category_id = c.id
    JOIN order_items oi ON p.id = oi.product_id
    GROUP BY c.name, s.name
)
SELECT 
    category_name, 
    shop_name, 
    revenue,
    ROUND((revenue / SUM(revenue) OVER (PARTITION BY category_name)) * 100, 2) AS revenue_share_percent
FROM seller_category_revenue
ORDER BY category_name, revenue DESC;
```
**Назначение:** Вычислить общую выручку категории с помощью `SUM() OVER (PARTITION BY category_name)` и разделить выручку конкретного магазина на эту сумму, получив процентный вклад.
**Результат:**
![!\[!\[4\](<Доля выручки>)\](<Screenshots/lab4_revenue_share.png>)](<Снимок экрана 2026-10-30 в 17.51.45.png>)

---

### Задание 5. Сравнение выручки с предыдущим днём (LAG / LEAD)
**Текст запроса:**
```sql
WITH daily_revenue AS (
    SELECT 
        o.created_at::DATE AS order_date,
        SUM(oi.quantity * oi.price_at_purchase) AS day_revenue
    FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    GROUP BY o.created_at::DATE
)
SELECT 
    order_date, 
    day_revenue,
    LAG(day_revenue) OVER (ORDER BY order_date) AS prev_day_revenue,
    LEAD(day_revenue) OVER (ORDER BY order_date) AS next_day_revenue,
    ROUND(
        ((day_revenue - LAG(day_revenue) OVER (ORDER BY order_date)) / 
        NULLIF(LAG(day_revenue) OVER (ORDER BY order_date), 0)) * 100, 2
    ) AS growth_percent
FROM daily_revenue
ORDER BY order_date ASC
LIMIT 10;
```
**Назначение:** Функции `LAG` и `LEAD` позволяют получить значения из предыдущей и следующей строк окна без самосоединения таблицы. `NULLIF` предотвращает ошибку деления на ноль.
**Результат:**
![!\[!\[5\](<LAG и LEAD>)\](<Screenshots/lab4_lag_lead.png>)](<Снимок экрана 2026-10-30 в 17.52.03.png>)

---

### Задание 6. Сравнение оконной функции и GROUP BY
**Текст запроса (Оконная функция - предпочтительный способ):**
```sql
SELECT 
    p.name AS product_name, 
    p.price, 
    c.name AS category_name,
    ROUND(AVG(p.price) OVER (PARTITION BY c.id), 2) AS avg_category_price
FROM products p
JOIN product_categories pc ON p.id = pc.product_id
JOIN categories c ON pc.category_id = c.id
ORDER BY category_name, p.price DESC
LIMIT 10;
```
**Текст запроса (Альтернатива через GROUP BY):**
```sql
WITH category_avg AS (
    SELECT c.id, ROUND(AVG(p.price), 2) AS avg_price
    FROM products p
    JOIN product_categories pc ON p.id = pc.product_id
    JOIN categories c ON pc.category_id = c.id
    GROUP BY c.id
)
SELECT 
    p.name AS product_name, 
    p.price, 
    c.name AS category_name,
    ca.avg_price AS avg_category_price
FROM products p
JOIN product_categories pc ON p.id = pc.product_id
JOIN categories c ON pc.category_id = c.id
JOIN category_avg ca ON c.id = ca.id
ORDER BY category_name, p.price DESC
LIMIT 10;
```
**Назначение и обоснование:** Задача: вывести список товаров с их ценой и средней ценой по их категории. Оконная функция предпочтительнее, так как она сохраняет детальные строки (товары) и добавляет агрегат как новый столбец в один проход. Использование `GROUP BY` требует создания временного набора данных (CTE) и последующего `JOIN` с исходной таблицей, что усложняет код и может снизить производительность.
**Результат:**
![!\[!\[6\](<Сравнение способов>)\](<Screenshots/lab4_comparison.png>)](<Снимок экрана 2026-10-30 в 17.52.22.png>)

---

## 3. Принятые проектные решения

- **Использование `WINDOW w AS (...)`:** Для запроса с тремя ранжирующими функциями (Задание 1) определение окна вынесено в отдельную секцию `WINDOW`. Это делает код чище, избавляет от дублирования длинной конструкции `OVER (PARTITION BY ... ORDER BY ...)` и облегчает его поддержку.
- **Применение `NULLIF` при расчёте процентов:** В Задании 5 при расчёте прироста (`growth_percent`) использована конструкция `NULLIF(значение, 0)`. Это предотвращает критическую ошибку `division by zero`, если выручка в предыдущий день была равна нулю, возвращая вместо этого корректный `NULL`.
- **Двухэтапная агрегация для нарастающего итога:** Для корректного расчёта (Задание 3) сначала применяется обычный `GROUP BY` по дате для получения дневной выручки, и только затем к этому результату применяется оконная функция. Попытка сделать всё в одном шаге привела бы к некорректным данным из-за смешения уровней детализации.

---

## 4. Ответы на контрольные вопросы

1. **Что такое оконная функция и чем она отличается от агрегатной функции с GROUP BY?**  
   Оконная функция выполняет вычисления над набором строк, связанных с текущей строкой (окном), но, в отличие от `GROUP BY`, не схлопывает строки в одну. Каждая исходная строка сохраняется в результате, а рядом появляется вычисленное значение.
2. **За что отвечает конструкция OVER?**  
   Она является обязательным синтаксическим элементом оконной функции и задаёт границы окна: как разделить строки (`PARTITION BY`), как их упорядочить (`ORDER BY`) и какие строки включать в расчёт относительно текущей (рамка окна).
3. **Что задаёт секция PARTITION BY и чем она похожа и непохожа на GROUP BY?**  
   `PARTITION BY` делит строки на независимые группы (разделы), внутри которых функция вычисляется отдельно. Она похожа на `GROUP BY` логикой группировки, но непохожа тем, что не агрегирует строки в одну, а сохраняет все детальные строки в выводе.
4. **Для чего нужна секция ORDER BY внутри OVER?**  
   Она задаёт порядок строк внутри окна. Это критически важно для ранжирующих функций (`ROW_NUMBER`, `RANK`) и функций накопительного итога, так как результат зависит от последовательности обработки строк.
5. **Чем различаются ROW_NUMBER, RANK и DENSE_RANK на строках с равными значениями?**  
   `ROW_NUMBER` присваивает уникальные номера (1, 2, 3, 4). `RANK` присваивает одинаковый ранг равным строкам, но пропускает следующие номера (1, 1, 3, 4). `DENSE_RANK` присваивает одинаковый ранг без пропусков (1, 1, 2, 3).
6. **Как с помощью оконной функции отобрать N лучших строк в каждой группе?**  
   Нужно использовать `ROW_NUMBER() OVER (PARTITION BY группа ORDER BY критерий DESC)` внутри CTE, а во внешнем запросе наложить фильтр `WHERE row_num <= N`.
7. **Как использовать агрегатную функцию в роли оконной и какой результат это даёт?**  
   Достаточно добавить конструкцию `OVER()` к стандартной агрегатной функции (например, `SUM(price) OVER(...)`). Это позволяет получить сводное значение (сумму, среднее) для каждой детальной строки, не удаляя остальные столбцы из выборки.
8. **Что такое нарастающий итог и как его получить оконной функцией?**  
   Это кумулятивная сумма значений, упорядоченных по времени или другому критерию. Получается с помощью `SUM(колонка) OVER (ORDER BY колонка_времени ASC)`.
9. **Что делают функции LAG и LEAD и для каких задач применяются?**  
   `LAG` возвращает значение из предыдущей строки окна, а `LEAD` — из следующей. Применяются для сравнения показателей текущего периода с предыдущим или последующим (например, месяц к месяцу, день ко дню) без необходимости делать `SELF JOIN`.
10. **В каких случаях оконная функция предпочтительнее обычной группировки?**  
   Когда требуется вывести детальные (построчные) данные вместе с агрегированными показателями по группе. Обычная группировка в этом случае потребовала бы сложных подзапросов или дополнительных `JOIN`, что ухудшает читаемость и производительность.


