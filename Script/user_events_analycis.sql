
SELECT event_type,count(*) AS nb_events
  FROM [user_events].[dbo].[user_events]
  GROUP BY event_type
  Order BY nb_events DESC;


/*WITH funnel_stage AS (
    SELECT
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS funnel_type_1,
        COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS funnel_type_2,
        COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS funnel_type_3,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS funnel_type_4,
        COUNT(DISTINCT CASE WHEN event_type = 'payment_info' THEN user_id END) AS funnel_type_5
    FROM [user_events].[dbo].[user_events]
 )
SELECT *
FROM funnel_stage;*/
--funnel for differant event type
WITH funnel_stage AS (
    SELECT
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS funnel_type_1,
        COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS funnel_type_2,
        COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS funnel_type_3,
        COUNT(DISTINCT CASE WHEN event_type = 'payment_info' THEN user_id END) AS funnel_type_4,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS funnel_type_5
    FROM [user_events].[dbo].[user_events]
)

SELECT
    --funnel_type_1 AS page_views,
    --funnel_type_2 AS add_to_cart,
    ROUND(funnel_type_2 * 100.0 / NULLIF(funnel_type_1, 0), 2) AS view_to_cart_rate,

    --funnel_type_3 AS checkout_start,
    ROUND(funnel_type_3 * 100.0 / NULLIF(funnel_type_2, 0), 2) AS cart_to_checkout_rate,

    --funnel_type_4 AS payment_info,
    ROUND(funnel_type_4 * 100.0 / NULLIF(funnel_type_3, 0), 2) AS checkout_to_payment_rate,

    --funnel_type_5 AS purchase,
    ROUND(funnel_type_5 * 100.0 / NULLIF(funnel_type_4, 0), 2) AS payment_to_purchase_rate,

    ROUND(funnel_type_5 * 100.0 / NULLIF(funnel_type_1, 0), 2) AS overall_conversion_rate
FROM funnel_stage;
--funnel by source
WITH source_funnel AS (
    SELECT
        traffic_source,
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS views,
        COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS carts,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchases
    FROM [user_events].[dbo].[user_events]
    GROUP BY traffic_source
)
SELECT
    traffic_source,
    views,
    carts,
    ROUND(carts * 100.0 / NULLIF(views, 0), 2) AS view_to_cart_rate,
    purchases,
    ROUND(purchases * 100.0 / NULLIF(carts, 0), 2) AS cart_to_purchase_rate,
    ROUND(purchases * 100.0 / NULLIF(views, 0), 2) AS overall_conversion_rate
FROM source_funnel
ORDER BY purchases DESC;
--time to conversion analysis
WITH user_journey AS (
    SELECT
        user_id,
        MIN(CASE WHEN event_type = 'page_view' THEN event_date END) AS view_time,
        MIN(CASE WHEN event_type = 'add_to_cart' THEN event_date END) AS cart_time,
        MIN(CASE WHEN event_type = 'purchase' THEN event_date END) AS purchase_time
    FROM [user_events].[dbo].[user_events]
    GROUP BY user_id
    HAVING MIN(CASE WHEN event_type = 'purchase' THEN event_date END) IS NOT NULL
)

SELECT
    COUNT(*) AS converted_users,
    ROUND(AVG(CAST(DATEDIFF(MINUTE, view_time, cart_time) AS FLOAT)), 2) AS avg_view_to_cart_minutes,
    ROUND(AVG(CAST(DATEDIFF(MINUTE, cart_time, purchase_time) AS FLOAT)), 2) AS avg_cart_to_purchase_minutes,
    ROUND(AVG(CAST(DATEDIFF(MINUTE, view_time, purchase_time) AS FLOAT)), 2) AS avg_total_journey_minutes
FROM user_journey;
--revenue funnel
WITH funnel_revenue AS (
    SELECT
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS total_visitors,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS total_buyers,
		SUM(
			CASE
				WHEN event_type = 'purchase'
				THEN CAST(amount AS DECIMAL(18,2))
			END
		) AS total_revenue,
		COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS total_orders
    FROM [user_events].[dbo].[user_events]
)

SELECT
    total_visitors,
    total_buyers,
    total_orders,
    total_revenue,
    ROUND(total_revenue * 1.0 / NULLIF(total_orders, 0), 2) AS avg_order_value,
    ROUND(total_revenue * 1.0 / NULLIF(total_buyers, 0), 2) AS revenue_per_buyer,
    ROUND(total_revenue * 1.0 / NULLIF(total_visitors, 0), 2) AS revenue_per_visitor
FROM funnel_revenue;