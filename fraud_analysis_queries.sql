CREATE DATABASE fraud_analysis;

USE fraud_analysis;

CREATE TABLE transactions (
    transaction_id       BIGINT,
    customer_id          BIGINT,
    transaction_date     DATETIME,
    amount               DECIMAL(12,2),
    merchant_category    VARCHAR(50),
    merchant_id          BIGINT,
    card_type            VARCHAR(20),
    transaction_type     VARCHAR(20),
    country              VARCHAR(50),
    is_international     TINYINT(1),
    is_chip              TINYINT(1),
    is_pin_used          TINYINT(1),
    distance_from_home   DECIMAL(10,2),
    hour_of_day          TINYINT,
    device_type          VARCHAR(30),
    fraud_flag           TINYINT(1)
);

SELECT COUNT(*) FROM transactions;

SELECT
    SUM(CASE WHEN transaction_id IS NULL THEN 1 ELSE 0 END)     AS null_ids,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END)             AS null_amounts,
    SUM(CASE WHEN fraud_flag IS NULL THEN 1 ELSE 0 END)         AS null_fraud,
    SUM(CASE WHEN device_type IS NULL THEN 1 ELSE 0 END)        AS null_device,
    SUM(CASE WHEN distance_from_home IS NULL THEN 1 ELSE 0 END) AS null_distance,
    SUM(CASE WHEN transaction_date IS NULL THEN 1 ELSE 0 END)   AS null_dates
FROM transactions;

ALTER TABLE transactions ADD PRIMARY KEY (transaction_id);
CREATE INDEX idx_customer   ON transactions(customer_id);
CREATE INDEX idx_date       ON transactions(transaction_date);
CREATE INDEX idx_fraud      ON transactions(fraud_flag);
CREATE INDEX idx_merchant   ON transactions(merchant_category);
CREATE INDEX idx_country    ON transactions(country);
CREATE INDEX idx_device     ON transactions(device_type);
CREATE INDEX idx_hour       ON transactions(hour_of_day);


# Question 1: What's the scale of the problem? 

# Understanding the baseline before any segmentation.
# Including both avg amounts in one query answers whether bad actors
# are spending big or blending in, without needing a follow-up query. 

SELECT
    COUNT(*)                                                         AS total_transactions,
    SUM(fraud_flag)                                                  AS total_fraud,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 3)                    AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN fraud_flag = 1 THEN amount END), 2)         AS total_fraud_amount,
    ROUND(AVG(CASE WHEN fraud_flag = 1 THEN amount END), 2)         AS avg_fraud_amount,
    ROUND(AVG(CASE WHEN fraud_flag = 0 THEN amount END), 2)         AS avg_legit_amount
FROM transactions;

-- Finding: 1.5% fraud rate, $1.08M in losses. Avg fraud ($145.10) and legit ($145.27)
-- amounts are nearly identical, meaning simple threshold detection would catch almost nothing



# Question 2: Which merchant categories are bad actors targeting most?

# Ordered by fraud rate rather than count, because concentration of risk
# matters more than volume when deciding where to focus prevention efforts.

SELECT
    merchant_category,
    COUNT(*)                                                      AS total_txns,
    SUM(fraud_flag)                                              AS fraud_count,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2)                AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN fraud_flag = 1 THEN amount END), 2)     AS fraud_exposure
FROM transactions
GROUP BY merchant_category
ORDER BY fraud_rate_pct DESC;

-- Finding: Fraud rates are nearly identical across all categories (1.43% to 1.56%).
-- Bad actors are spreading activity broadly, making category-based detection ineffective.
-- Groceries lead in total exposure ($120K) due to volume, not a higher fraud rate.



# Question 3: Does the type of card or transaction method affect fraud likelihood?

# Combining both dimensions in one query to see if certain card and transaction
# combinations carry a noticeably higher risk than others.
SELECT
    card_type,
    transaction_type,
    COUNT(*)                                       AS total,
    SUM(fraud_flag)                               AS fraud_count,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY card_type, transaction_type
ORDER BY fraud_rate_pct DESC;

-- Finding: Credit Online tops the list at 1.62%, but the spread across all 12
-- combinations is narrow (1.41% to 1.62%). No card type or transaction method
-- is dramatically riskier than another, reinforcing that bad actors are not
-- exploiting a specific payment channel.



# Question 4: Does the device used to make a transaction influence fraud likelihood?

# Wanted to see if bad actors prefer a specific device type, which could
# inform where to tighten authentication requirements.

SELECT
    device_type,
    COUNT(*)                                                          AS total_txns,
    SUM(fraud_flag)                                                   AS fraud_count,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2)                     AS fraud_rate_pct,
    ROUND(AVG(CASE WHEN fraud_flag = 1 THEN amount END), 2)          AS avg_fraud_amount,
    ROUND(AVG(CASE WHEN fraud_flag = 1 THEN distance_from_home END), 2) AS avg_distance_when_fraud
FROM transactions
GROUP BY device_type
ORDER BY fraud_rate_pct DESC;

-- Finding: Terminal leads at 1.53% vs Web at 1.44%, but the gap is small.
-- More interesting is avg_distance_when_fraud sitting around 4.9km across all devices,
-- suggesting location proximity matters more than the device channel itself.



# Question 5: Does chip and PIN usage reduce fraud rates?

# Authentication method is one of the first things a risk team would look at.
# Grouping all four combinations to see if weaker auth methods
# are visibly more exploited by bad actors.

SELECT
    CASE
        WHEN is_chip = 1 AND is_pin_used = 1 THEN 'Chip + PIN'
        WHEN is_chip = 1 AND is_pin_used = 0 THEN 'Chip only'
        WHEN is_chip = 0 AND is_pin_used = 1 THEN 'PIN only'
        ELSE 'No chip, no PIN'
    END                                                          AS auth_method,
    COUNT(*)                                                     AS total_txns,
    SUM(fraud_flag)                                             AS fraud_count,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2)               AS fraud_rate_pct,
    ROUND(AVG(CASE WHEN fraud_flag = 1 THEN amount END), 2)    AS avg_fraud_amount
FROM transactions
GROUP BY is_chip, is_pin_used
ORDER BY fraud_rate_pct DESC;

-- Finding: Chip + PIN has the highest fraud rate at 1.59%, while PIN only sits lowest at 1.47%.
-- The differences are marginal across all four methods, meaning stronger authentication
-- alone is not stopping bad actors. This points to a social engineering or
-- account takeover problem rather than a card skimming one.



# Question 6: At what time of day does fraud peak?

# Bad actors often operate at specific hours to avoid detection.
# Mapping fraud rate by hour helps identify windows where
# monitoring should be tightened.

SELECT
    hour_of_day,
    COUNT(*)                                                    AS total_txns,
    SUM(fraud_flag)                                            AS fraud_count,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2)              AS fraud_rate_pct,
    ROUND(AVG(CASE WHEN fraud_flag = 1 THEN amount END), 2)   AS avg_fraud_amount
FROM transactions
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- Finding: Fraud peaks at hour 0 (1.67%), hour 5 (1.67%), and hour 11 (1.66%),
-- with the lowest activity at hour 8 (1.36%) and hour 4 (1.30%).
-- Late night and late morning are the highest risk windows.
-- This is a strong candidate for time-based alerting rules.



# Question 7: Does distance from home increase fraud risk?

# This is one of the strongest behavioral signals in the dataset.
# Banding distances into ranges to see at what point fraud risk
# starts climbing as transactions move further from the cardholder's home.

SELECT
    CASE
        WHEN distance_from_home < 5    THEN '< 5 km'
        WHEN distance_from_home < 20   THEN '5 - 20 km'
        WHEN distance_from_home < 50   THEN '20 - 50 km'
        WHEN distance_from_home < 100  THEN '50 - 100 km'
        ELSE '100+ km'
    END                                                       AS distance_band,
    COUNT(*)                                                  AS total_txns,
    SUM(fraud_flag)                                          AS fraud_count,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2)            AS fraud_rate_pct,
    ROUND(AVG(CASE WHEN fraud_flag = 1 THEN amount END), 2) AS avg_fraud_amount
FROM transactions
GROUP BY distance_band
ORDER BY MIN(distance_from_home);

-- Finding: Fraud is concentrated within 20 km of home (4,739 cases, 1.50% rate),
-- with a notable drop beyond 20 km (1.31%). The 50-100 km band had only 29 transactions
-- and zero fraud, suggesting this dataset reflects mostly local spending behavior.
-- Distance alone is not a strong standalone fraud signal in this dataset.



# Question 8: Does transaction amount influence fraud likelihood?

# Splitting amounts into bands to identify whether bad actors
# tend to operate at specific price points or spread evenly across all ranges.
SELECT
    CASE
        WHEN amount < 50    THEN 'Under $50'
        WHEN amount < 100   THEN '$50 - $99'
        WHEN amount < 200   THEN '$100 - $199'
        WHEN amount < 500   THEN '$200 - $499'
        WHEN amount < 1000  THEN '$500 - $999'
        ELSE '$1000+'
    END                                                       AS amount_band,
    COUNT(*)                                                  AS total_txns,
    SUM(fraud_flag)                                          AS fraud_count,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2)            AS fraud_rate_pct,
    ROUND(AVG(CASE WHEN fraud_flag = 1 THEN amount END), 2) AS avg_fraud_amount
FROM transactions
GROUP BY amount_band
ORDER BY MIN(amount);

-- Finding: Fraud peaks at $1000+ (2.04%) but with only 3 cases, it is not actionable.
-- The real risk sits in $50-$199, where volume is highest and bad actors blend in easily.



# Question 9: Which customers have been repeatedly targeted by fraud?

# Filtering for customers with 3 or more fraud cases to surface
# accounts that need immediate attention rather than one-off incidents.

WITH customer_summary AS (
    SELECT
        customer_id,
        COUNT(*)                                                         AS total_txns,
        SUM(fraud_flag)                                                 AS fraud_count,
        ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2)                   AS fraud_rate_pct,
        ROUND(SUM(CASE WHEN fraud_flag = 1 THEN amount END), 2)        AS total_fraud_amount,
        ROUND(AVG(CASE WHEN fraud_flag = 1 THEN distance_from_home END), 2) AS avg_fraud_distance
    FROM transactions
    GROUP BY customer_id
)
SELECT *
FROM customer_summary
WHERE fraud_count >= 3
ORDER BY total_fraud_amount DESC
LIMIT 20;

-- Finding: Only 6 customers had 3 or more fraud incidents, all with a 37.5% to 50%
-- personal fraud rate. Customer ID:87308 had the highest exposure at $551.92.
-- The low count suggests fraud is broadly distributed rather than targeting
-- specific accounts repeatedly.



# Question 10: How has fraud trended month by month?

# Before wrapping up the analysis, I wanted to check if fraud is growing
# over time or staying flat. A rising trend changes the business recommendation
# entirely compared to a stable but persistent problem.

SELECT
    DATE_FORMAT(transaction_date, '%Y-%m')                      AS month,
    COUNT(*)                                                    AS total_txns,
    SUM(fraud_flag)                                            AS fraud_count,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 3)              AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN fraud_flag = 1 THEN amount END), 2)   AS fraud_amount
FROM transactions
GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
ORDER BY month;

-- Finding: Fraud rate stayed flat between 1.32% and 1.61% across 21 months.
-- No meaningful upward trend, meaning this is a persistent baseline problem
-- rather than an escalating one. Steady monthly losses averaging around $51K.



# Question 11: Are international transactions riskier than domestic ones?

# Cross-border transactions are one of the oldest fraud signals in banking.
# Comparing fraud rates between domestic and international to see
# if geography adds meaningful risk beyond what we already found with distance.

SELECT
    CASE WHEN is_international = 1 THEN 'International' ELSE 'Domestic' END AS transaction_scope,
    COUNT(*)                                                   AS total_txns,
    SUM(fraud_flag)                                           AS fraud_count,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2)             AS fraud_rate_pct,
    ROUND(AVG(CASE WHEN fraud_flag = 1 THEN amount END), 2)  AS avg_fraud_amount
FROM transactions
GROUP BY is_international;

-- Finding: Domestic transactions (1.50%) actually have a slightly higher fraud rate
-- than international ones (1.48%). Geography alone is not a reliable fraud signal
-- in this dataset, which challenges a common assumption in fraud detection.



# Question 12: Which merchants carry the highest combined fraud risk?

# Removed the minimum transaction filter since merchants in this dataset
# have naturally low individual volume. Ranking by total fraud exposure
# to surface the highest risk merchants across all categories.

WITH merchant_stats AS (
    SELECT
        merchant_id,
        merchant_category,
        COUNT(*)                                                             AS total_txns,
        SUM(fraud_flag)                                                     AS fraud_count,
        ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2)                       AS fraud_rate,
        ROUND(SUM(CASE WHEN fraud_flag = 1 THEN amount END), 2)            AS fraud_exposure,
        ROUND(AVG(CASE WHEN fraud_flag = 1 THEN distance_from_home END), 2) AS avg_fraud_distance
    FROM transactions
    GROUP BY merchant_id, merchant_category
)
SELECT
    merchant_id,
    merchant_category,
    total_txns,
    fraud_count,
    fraud_rate,
    fraud_exposure,
    avg_fraud_distance,
    RANK() OVER (PARTITION BY merchant_category ORDER BY fraud_exposure DESC) AS risk_rank_in_category
FROM merchant_stats
ORDER BY fraud_exposure DESC
LIMIT 25;

-- Finding: Merchant 8680 (Online Services) tops the list with $1,040 in fraud exposure
-- despite only 3 transactions, driven by a 33% fraud rate.
-- Travel and Food merchants appear repeatedly in the top 25, suggesting
-- these categories attract higher-risk merchants, not just higher-risk customers.
