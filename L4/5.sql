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