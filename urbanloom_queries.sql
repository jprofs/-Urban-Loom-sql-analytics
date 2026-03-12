## Insight 1: Marketing Channel ROI Analysis (for Kojo) Tables used: order_transactions , order_line , order_marketing 

-- Step 1: Created a CTE to calculate net revenue per transaction
WITH revenue_cte AS (
  SELECT 
    oli.order_transaction_id,
    SUM(oli.revenue) AS total_revenue,
    SUM(CASE WHEN ot.order_transaction_type = 'Return' THEN oli.revenue ELSE 0 END) AS total_returns
  FROM `wyk-jj.uloom.order line` oli
  JOIN `wyk-jj.uloom.order transactions` ot
    ON oli.order_transaction_id = ot.order_transaction_id
  GROUP BY oli.order_transaction_id
)
-- Step 2: Joined with marketing details and compute KPIs per channel
SELECT 
  omd.marketing_source AS marketing_channel,
  COUNT(DISTINCT ot.customer_id) AS customers_acquired,
  SUM(r.total_revenue - r.total_returns) AS net_revenue,
  AVG(r.total_revenue - r.total_returns) AS avg_order_value,
  SAFE_DIVIDE(SUM(r.total_returns), NULLIF(SUM(r.total_revenue),0)) * 100 AS return_rate_pct,
  SAFE_DIVIDE(SUM(r.total_revenue - r.total_returns), COUNT(DISTINCT ot.customer_id)) AS revenue_per_customer
FROM `wyk-jj.uloom.order transactions` ot
JOIN revenue_cte r
  ON ot.order_transaction_id = r.order_transaction_id
JOIN `wyk-jj.uloom.order marketing` omd
  ON ot.order_transaction_id = omd.transaction_id
GROUP BY marketing_channel
HAVING COUNT(DISTINCT ot.customer_id) >= 10
ORDER BY net_revenue DESC;

--------------------------------------------------
-- What This Query Delivers for Kojo:
  
--Focus: Evaluates marketing channel effectiveness.


-- Key metrics:


--Customers acquired: Number of distinct customers per marketing channel.


--Net revenue: Total revenue minus returns.


--Average order value (AOV): Revenue per transaction after returns.


--Return rate percentage: Proportion of returned revenue relative to total revenue.


--Revenue per customer: Net revenue divided by the number of customers.


-- Top channels: Google, Facebook, and Direct (based on net revenue).


--Insight summary: Google appears to be the most effective channel in terms of acquiring customers and generating net revenue, though return rates vary by channel. This can guide budget allocation toward high-performing channels.

--------------------------------------------------
## Insight 2: Product Performance & Return Analysis (for Jared) Tables used: order_transactions , order_line , products 

-- Step 1: Built base CTE with sales and returns per product
WITH product_sales AS (
  SELECT 
    oli.product_id,
    SUM(CASE WHEN ot.order_transaction_type = 'Sale' THEN oli.quantity ELSE 0 END) AS total_sold,
    SUM(CASE WHEN ot.order_transaction_type = 'Return' THEN oli.quantity ELSE 0 END) AS total_returned
  FROM `wyk-jj.uloom.order line` oli
  JOIN `wyk-jj.uloom.order transactions` ot
    ON oli.order_transaction_id = ot.order_transaction_id
  GROUP BY oli.product_id
)
-- Step 2: Calculate return rates and rank products
SELECT 
  p.product_name,
  ps.total_sold,
  ps.total_returned,
  SAFE_DIVIDE(ps.total_returned, NULLIF(ps.total_sold,0)) * 100 AS return_rate_pct,
  RANK() OVER (ORDER BY SAFE_DIVIDE(ps.total_returned, NULLIF(ps.total_sold,0)) DESC) AS return_rate_rank
FROM product_sales ps
JOIN `wyk-jj.uloom.products` p
  ON ps.product_id = p.product_id
WHERE ps.total_sold > 50  -- filter out low-volume products
ORDER BY return_rate_pct DESC
LIMIT 10;

---------------------------------------------------
-- What This Query Delivers for Jared:
  
--Focus: Identifies products with high return rates.


--Key metrics :


--Total sold and returned units per product.


--Return rate percentage: Returned units as a % of total sold units.


--Return rate rank: Ranking of products by return rate.


--Filtering: Only products with more than 50 units sold were considered to avoid skew from low-volume products.


--Top products by return rate: Oversized shirts and long-sleeved shirts appear to have the highest return rates.


--Insight summary: Certain apparel items have disproportionately high return rates. This may indicate sizing issues, product quality concerns, or customer expectations misalignment. Urban Loom will need to investigate these products to reduce returns.

---------------------------------------------------
## Insight 3: Geographic Delivery Performance (for Ameena) Tables used: order_transactions , customers

-- Step 1: CTE for delivery duration by customer region
WITH delivery_times AS (
  SELECT 
    ot.order_transaction_id,
    c.country,
    DATE_DIFF(ot.delivered_date, ot.shipped_date, DAY) AS delivery_days
  FROM `wyk-jj.uloom.order transactions` ot
  JOIN `wyk-jj.uloom.customers` c
    ON ot.customer_id = c.customer_id
  WHERE ot.delivered_date IS NOT NULL AND ot.shipped_date IS NOT NULL
)
-- Step 2: Aggregate by region, including 90th percentile
SELECT 
  country,
  COUNT(order_transaction_id) AS total_deliveries,
  AVG(delivery_days) AS avg_delivery_days,
  MAX(delivery_days) AS worst_case_days,
  -- Get approximate 90th percentile
  APPROX_QUANTILES(delivery_days, 10)[OFFSET(9)] AS p90_delivery_days
FROM delivery_times
GROUP BY country
ORDER BY avg_delivery_days DESC;

--What This Query Delivers for Ameena:

--Focus: Analyses delivery times across countries.


--Key metrics :


--Total deliveries per country.


--Average delivery days.


--Worst-case delivery days (max).


--Approximate 90th percentile delivery days (p90).


--Top findings:


--Greece has the longest average delivery times, despite only one delivery.


--The UK has the highest volume of deliveries, with an average delivery time of ~4.7 days.


--Other countries (UAE, Spain, Canada) have smaller volumes and faster delivery.


--Insight summary: Delivery performance varies significantly by region. High-volume regions like the UK are performing reasonably well, but low-volume or distant regions like Greece may require logistic improvements to meet service expectations.

-----------------------------------------------------------------------
