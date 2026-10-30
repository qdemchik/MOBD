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