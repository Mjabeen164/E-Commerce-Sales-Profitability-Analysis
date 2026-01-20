-- Base CTE
WITH base_sales AS (
    SELECT
        Order_ID,
        DATE_TRUNC('month', Order_Date) AS order_month,
        Segment,
        Category,
        Subcategory,
        Product,
        Region,
        State,
        Quantity,
        Sales,
        Discount,
        Profit
    FROM ecommerce_sales
)

-- 2️ Executive KPIs + Profit Margin (window aggregation)
, kpi_summary AS (
    SELECT
        SUM(Sales) OVER () AS total_sales,
        SUM(Profit) OVER () AS total_profit,
        COUNT(DISTINCT Order_ID) OVER () AS total_orders,
        SUM(Quantity) OVER () AS total_quantity,
        ROUND(
            SUM(Profit) OVER () / NULLIF(SUM(Sales) OVER (), 0), 2
        ) AS profit_margin
    FROM base_sales
)
SELECT DISTINCT * FROM kpi_summary;

-- 3️ Month-over-Month Growth
WITH monthly_sales AS (
    SELECT
        order_month,
        SUM(Sales) AS monthly_sales,
        SUM(Profit) AS monthly_profit
    FROM base_sales
    GROUP BY order_month
)
SELECT
    order_month,
    monthly_sales,
    monthly_profit,
    LAG(monthly_sales) OVER (ORDER BY order_month) AS prev_month_sales,
    ROUND(
        (monthly_sales - LAG(monthly_sales) OVER (ORDER BY order_month))
        / NULLIF(LAG(monthly_sales) OVER (ORDER BY order_month), 0) * 100, 2
    ) AS mom_growth_pct
FROM monthly_sales
ORDER BY order_month;

-- 4️ Category Contribution to Total Profit (% Share)

WITH category_profit AS (
    SELECT
        Category,
        SUM(Profit) AS category_profit
    FROM base_sales
    GROUP BY Category
)
SELECT
    Category,
    category_profit,
    ROUND(
        category_profit / SUM(category_profit) OVER () * 100, 2
    ) AS profit_contribution_pct
FROM category_profit
ORDER BY profit_contribution_pct DESC;

-- 5 Product Ranking within Category (Top & Bottom performers)
WITH product_perf AS (
    SELECT
        Category,
        Product,
        SUM(Sales) AS total_sales,
        SUM(Profit) AS total_profit
    FROM base_sales
    GROUP BY Category, Product
)
SELECT
    Category,
    Product,
    total_sales,
    total_profit,
    RANK() OVER (PARTITION BY Category ORDER BY total_profit DESC) AS profit_rank,
    RANK() OVER (PARTITION BY Category ORDER BY total_profit ASC) AS loss_rank
FROM product_perf;

-- 6 Discount Elasticity Analysis (advanced business logic)
WITH discount_buckets AS (
    SELECT
        Product,
        CASE
            WHEN Discount = 0 THEN 'No Discount'
            WHEN Discount BETWEEN 0.01 AND 0.10 THEN 'Low Discount'
            WHEN Discount BETWEEN 0.11 AND 0.30 THEN 'Medium Discount'
            ELSE 'High Discount'
        END AS discount_bucket,
        Sales,
        Profit
    FROM base_sales
)
SELECT
    discount_bucket,
    COUNT(DISTINCT Product) AS product_count,
    ROUND(AVG(Sales), 2) AS avg_sales,
    ROUND(AVG(Profit), 2) AS avg_profit,
    ROUND(
        AVG(Profit) / NULLIF(AVG(Sales), 0), 2
    ) AS avg_profit_margin
FROM discount_buckets
GROUP BY discount_bucket
ORDER BY avg_profit_margin DESC;


-- 7 Underperforming Regions (Profit leakage detection)
WITH regional_perf AS (
    SELECT
        Region,
        SUM(Sales) AS total_sales,
        SUM(Profit) AS total_profit
    FROM base_sales
    GROUP BY Region
)
SELECT
    Region,
    total_sales,
    total_profit,
    ROUND(
        total_profit / NULLIF(total_sales, 0), 2
    ) AS profit_margin,
    NTILE(4) OVER (ORDER BY total_profit) AS performance_quartile
FROM regional_perf
ORDER BY performance_quartile, total_profit;

-- 8 Customer Segment Lifetime Value Proxy (advanced thinking)
WITH segment_value AS (
    SELECT
        Segment,
        COUNT(DISTINCT Order_ID) AS orders,
        SUM(Sales) AS total_sales,
        SUM(Profit) AS total_profit
    FROM base_sales
    GROUP BY Segment
)
SELECT
    Segment,
    orders,
    total_sales,
    total_profit,
    ROUND(total_sales / orders, 2) AS avg_order_value,
    ROUND(total_profit / orders, 2) AS profit_per_order
FROM segment_value
ORDER BY profit_per_order DESC;

-- 9 Top 20% Products Driving 80% of Profit (Pareto Analysis)
WITH product_profit AS (
    SELECT
        Product,
        SUM(Profit) AS total_profit
    FROM base_sales
    GROUP BY Product
),
profit_cumsum AS (
    SELECT
        Product,
        total_profit,
        SUM(total_profit) OVER (ORDER BY total_profit DESC) AS running_profit,
        SUM(total_profit) OVER () AS overall_profit
    FROM product_profit
)
SELECT
    Product,
    total_profit,
    ROUND(running_profit / overall_profit * 100, 2) AS cumulative_profit_pct
FROM profit_cumsum
WHERE running_profit / overall_profit <= 0.80;
