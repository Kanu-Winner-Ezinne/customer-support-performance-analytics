
/*
PROJECT: THE SLOW SUPPORT QUEUE
COMPANY: BRAMBLEWICK
DATABASE: PostgreSQL
ANALYSIS PERIOD: May 1 - August 31, 2026
DATA EXPORT DATE: September 6, 2026
HELPDESK LAUNCH DATE: July 1, 2026

BUSINESS PROBLEM
----------------
Bramblewick reported that average ticket resolution time increased from
approximately 20 hours in June to 27 hours in July after introducing a new
helpdesk tool.

One enterprise customer was migrating data during July. This analysis tests
whether that account contributed substantially to the increase and whether
the typical ticket also became slower.

OBJECTIVES
----------
Inspect and validate ticket and customer data.
Calculate resolution time in hours.
Compare monthly mean and median resolution times.
Analyse regular and reopened tickets separately.
Examine ticket priority, channel and customer plan.
Quantify the impact of each enterprise account on July's mean.
Inspect unresolved tickets.
Produce evidence for a rollback recommendation.

ASSUMPTIONS
-----------
The tables tickets and customers already exist.
Timestamps are PostgreSQL TIMESTAMP values representing UTC.
Each ticket_id should identify one ticket row.
A non-NULL reopened_from identifies a reopened/follow-up ticket.
Open tickets are excluded from completed resolution-time calculations.
The primary monthly comparison groups tickets by opened_at.
Confirm the dashboard's date definition before comparing results.
*/




/*
Create the tables and load the data.
Run these CREATE TABLE statements only if the tables do not already exist.
*/

CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    plan VARCHAR(50),
    region VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS tickets (
    ticket_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    opened_at TIMESTAMP,
    resolved_at TIMESTAMP,
    status VARCHAR(20),
    priority VARCHAR(10),
    channel VARCHAR(50),
    reopened_from VARCHAR(50)
);


/*
UNDERSTAND THE DATA
*/

-- Total number of ticket and customer records.

SELECT COUNT(*) AS total_ticket_rows
FROM tickets;

SELECT COUNT(*) AS total_customer_rows
FROM customers;


-- Inspect ticket records.

SELECT *
FROM tickets
ORDER BY opened_at
LIMIT 20;


-- Inspect customer records.

SELECT *
FROM customers
ORDER BY customer_id
LIMIT 20;


-- Check the date range covered by the ticket data.

SELECT
    MIN(opened_at) AS first_ticket_opened,
    MAX(opened_at) AS last_ticket_opened,
    MIN(resolved_at) AS first_ticket_resolved,
    MAX(resolved_at) AS last_ticket_resolved
FROM tickets;


-- Examine status values.

SELECT
    status,
    COUNT(*) AS ticket_count
FROM tickets
GROUP BY status
ORDER BY ticket_count DESC;


-- Examine ticket priorities.

SELECT
    priority,
    COUNT(*) AS ticket_count
FROM tickets
GROUP BY priority
ORDER BY priority;


-- Examine ticket channels.

SELECT
    channel,
    COUNT(*) AS ticket_count
FROM tickets
GROUP BY channel
ORDER BY ticket_count DESC;

-- Chat: 1,919 tickets.
-- Email: 3,227 tickets.
-- Portal: 1,310 tickets.


-- Examine customer plans.

SELECT
    plan,
    COUNT(*) AS customer_count
FROM customers
GROUP BY plan
ORDER BY customer_count DESC;

-- Starter: 259 customers.
-- Growth: 116 customers.
-- Enterprise: 45 customers.


-- Examine customer regions.

SELECT
    region,
    COUNT(*) AS customer_count
FROM customers
GROUP BY region
ORDER BY customer_count DESC;

-- EMEA: 154 customers.
-- America: 140 customers.
-- APAC: 126 customers.


/*
DATA QUALITY CHECKS
*/

-- Find duplicate ticket IDs.
-- A ticket ID should identify only one row.

SELECT
    ticket_id,
    COUNT(*) AS occurrences
FROM tickets
GROUP BY ticket_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- No duplicate ticket IDs were reported.


-- Find duplicate customer IDs in the customer table.

SELECT
    customer_id,
    COUNT(*) AS occurrences
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- No duplicate customer IDs were reported.


-- Check for missing important ticket fields.

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE ticket_id IS NULL) AS missing_ticket_id,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS missing_customer_id,
    COUNT(*) FILTER (WHERE opened_at IS NULL) AS missing_opened_at,
    COUNT(*) FILTER (WHERE status IS NULL) AS missing_status,
    COUNT(*) FILTER (WHERE priority IS NULL) AS missing_priority,
    COUNT(*) FILTER (WHERE channel IS NULL) AS missing_channel
FROM tickets;


-- find resolved tickets without a resolution timestamp.

SELECT *
FROM tickets
WHERE LOWER(TRIM(status)) = 'resolved'
  AND resolved_at IS NULL;


-- Check tickets marked open that already have a resolution timestamp.

SELECT *
FROM tickets
WHERE LOWER(TRIM(status)) = 'open'
  AND resolved_at IS NOT NULL;-- there are none ticke marked open without resolution timestamp


-- Find negative resolution durations.

SELECT
    ticket_id,
    customer_id,
    opened_at,
    resolved_at
FROM tickets
WHERE opened_at IS NOT NULL
  AND resolved_at IS NOT NULL
  AND resolved_at < opened_at;

-- No negative resolution durations were reported.


-- Find tickets without a matching customer record.

SELECT
    t.ticket_id,
    t.customer_id
FROM tickets AS t
LEFT JOIN customers AS c
    ON t.customer_id = c.customer_id
WHERE c.customer_id IS NULL; -- there are no ticket without a matching customer record


-- Check for unexpected status values.

SELECT
    status,
    COUNT(*) AS ticket_count
FROM tickets
WHERE LOWER(TRIM(status)) NOT IN ('open', 'resolved')
   OR status IS NULL
GROUP BY status;

-- No unexpected status values were reported.


-- Check for reopened tickets whose original ticket ID is missing.

SELECT
    t.ticket_id,
    t.reopened_from
FROM tickets AS t
LEFT JOIN tickets AS original
    ON t.reopened_from = original.ticket_id
WHERE t.reopened_from IS NOT NULL
  AND original.ticket_id IS NULL;-- there are none



-- Inspect the distribution of regular and reopened tickets.
-- A regular ticket is a ticket that was opened as a new support request, not as a follow-up to an earlier ticket.
-- A reopened ticket  is identified by the reopened_from column containing the ID of an earlier ticket.

SELECT
    CASE
        WHEN NULLIF(BTRIM(reopened_from), '') IS NULL
            THEN 'regular'
        ELSE 'reopened'
    END AS ticket_type,
    COUNT(*) AS ticket_count
FROM tickets
GROUP BY
    CASE
        WHEN NULLIF(BTRIM(reopened_from), '') IS NULL
            THEN 'regular'
        ELSE 'reopened'
    END
ORDER BY ticket_type; -- there 5844 regular ticket and 612 reopened tickett


/*
CREATE THE ANALYSIS VIEW

The view joins ticket data with customer information, classifies tickets,
and calculates completed resolution time in hours.

Open or invalid-duration tickets are excluded because their completed
resolution duration cannot be calculated reliably.
*/

CREATE OR REPLACE VIEW resolved_ticket_analysis AS
SELECT
    t.ticket_id,
    t.customer_id,
    c.plan,
    c.region,
    t.opened_at,
    t.resolved_at,
    DATE_TRUNC('month', t.opened_at)::date AS opened_month,
    DATE_TRUNC('month', t.resolved_at)::date AS resolved_month,
    t.priority,
    t.channel,
    t.reopened_from,

    CASE
        WHEN t.reopened_from IS NULL THEN 'regular'
        ELSE 'reopened'
    END AS ticket_type,

    EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 3600.0
        AS resolution_hours

FROM tickets AS t
LEFT JOIN customers AS c
    ON t.customer_id = c.customer_id
WHERE t.opened_at IS NOT NULL
  AND t.resolved_at IS NOT NULL
  AND t.resolved_at >= t.opened_at
  AND LOWER(TRIM(t.status)) = 'resolved';


-- Preview the analysis view.

SELECT *
FROM resolved_ticket_analysis
ORDER BY opened_at
LIMIT 20;


-- Count records included in the completed-ticket analysis.

SELECT
    COUNT(*) AS valid_resolved_tickets,
    COUNT(DISTINCT ticket_id) AS distinct_ticket_ids,
    ROUND(AVG(resolution_hours)::numeric, 2) AS overall_mean_hours
FROM resolved_ticket_analysis;

-- Previously reported: 6,456 valid resolved tickets.
-- Previously reported overall mean resolution time: 19.78 hours.
-- Rerun this query to verify the current results.


/*
OVERALL MONTHLY PERFORMANCE

The primary comparison groups tickets by the month in which they were opened.
*/

SELECT
    opened_month AS ticket_month,
    COUNT(*) AS resolved_ticket_count,
    ROUND(AVG(resolution_hours)::numeric, 2) AS mean_resolution_hours,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resolution_hours)::numeric,
        2
    ) AS median_resolution_hours,
    ROUND(
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY resolution_hours)::numeric,
        2
    ) AS p90_resolution_hours,
    ROUND(MIN(resolution_hours)::numeric, 2) AS minimum_hours,
    ROUND(MAX(resolution_hours)::numeric, 2) AS maximum_hours
FROM resolved_ticket_analysis
WHERE opened_at >= TIMESTAMP '2026-06-01 00:00:00'
  AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
GROUP BY opened_month
ORDER BY opened_month;

-- June: 1,582 tickets, mean 18.51 hours, median 15.37 hours.
-- July: 1,642 tickets, mean 24.92 hours, median 13.58 hours.

-- Mean: the average resolution time across included tickets.
-- Median: the middle resolution time.
-- P90: the time below which 90% of included tickets were resolved.
-- Maximum: helps identify unusually long tickets.

-- The mean increased while the median decreased.
-- This suggests that some unusually long tickets may have influenced
-- July's average. This is a clue to investigate, not proof.





/*
CALCULATE THE CHANGE FROM JUNE TO JULY
*/

WITH monthly_metrics AS (
    SELECT
        opened_month AS ticket_month,
        COUNT(*) AS ticket_count,
        AVG(resolution_hours) AS mean_hours,
        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY resolution_hours) AS median_hours
    FROM resolved_ticket_analysis
    WHERE opened_at >= TIMESTAMP '2026-06-01 00:00:00'
      AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
    GROUP BY opened_month
),
june AS (
    SELECT *
    FROM monthly_metrics
    WHERE ticket_month = DATE '2026-06-01'
),
july AS (
    SELECT *
    FROM monthly_metrics
    WHERE ticket_month = DATE '2026-07-01'
)
SELECT
    june.ticket_count AS june_ticket_count,
    july.ticket_count AS july_ticket_count,
    ROUND(june.mean_hours::numeric, 2) AS june_mean_hours,
    ROUND(july.mean_hours::numeric, 2) AS july_mean_hours,
    ROUND((july.mean_hours - june.mean_hours)::numeric, 2)
        AS mean_change_hours,
    ROUND(
        (
            100.0 * (july.mean_hours - june.mean_hours)
            / NULLIF(june.mean_hours, 0)
        )::numeric,
        2
    ) AS mean_change_percent,
    ROUND(june.median_hours::numeric, 2) AS june_median_hours,
    ROUND(july.median_hours::numeric, 2) AS july_median_hours,
    ROUND((july.median_hours - june.median_hours)::numeric, 2)
        AS median_change_hours
FROM june
CROSS JOIN july;

-- June: 1,582 tickets, mean 18.51 hours, median 15.37 hours.
-- July: 1,642 tickets, mean 24.92 hours, median 13.58 hours.
-- Ticket volume increased by 60 tickets (3.79%).
-- Mean resolution time increased by 6.41 hours (34.61%).
-- Median resolution time decreased by 1.79 hours.


/*
REGULAR VERSUS REOPENED TICKETS

Check whether reopened tickets have different resolution times from
regular tickets, and whether their contribution changed in July.
*/

SELECT
    opened_month AS ticket_month,
    ticket_type,
    COUNT(*) AS ticket_count,
    ROUND(
        100.0 * COUNT(*) /
        NULLIF(SUM(COUNT(*)) OVER (PARTITION BY opened_month), 0),
        2
    ) AS percent_of_monthly_tickets,
    ROUND(AVG(resolution_hours)::numeric, 2) AS mean_hours,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resolution_hours)::numeric,
        2
    ) AS median_hours
FROM resolved_ticket_analysis
WHERE opened_at >= TIMESTAMP '2026-06-01 00:00:00'
  AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
GROUP BY opened_month, ticket_type
ORDER BY opened_month, ticket_type;


/*
COMPARE TICKET PRIORITIES

A change in the mix of urgent and low-priority tickets may affect
the overall average.
*/

SELECT
    opened_month AS ticket_month,
    priority,
    COUNT(*) AS ticket_count,
    ROUND(AVG(resolution_hours)::numeric, 2) AS mean_hours,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resolution_hours)::numeric,
        2
    ) AS median_hours
FROM resolved_ticket_analysis
WHERE opened_at >= TIMESTAMP '2026-06-01 00:00:00'
  AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
GROUP BY opened_month, priority
ORDER BY opened_month, priority;

-- Comparing ticket priority.
-- Format: ticket_month, priority, ticket_count, mean_hours, median_hours
--
-- June P1: 89 tickets, 6.28 mean hours, 5.76 median hours.
-- June P2: 388 tickets, 13.74 mean hours, 12.07 median hours.
-- June P3: 885 tickets, 18.78 mean hours, 16.54 median hours.
-- June P4: 220 tickets, 30.80 mean hours, 27.37 median hours.
--
-- July P1: 68 tickets, 6.49 mean hours, 5.66 median hours.
-- July P2: 401 tickets, 25.67 mean hours, 10.20 median hours.
-- July P3: 944 tickets, 25.61 mean hours, 14.35 median hours.
-- July P4: 229 tickets, 26.22 mean hours, 23.07 median hours.
--
-- P2 and P3 show increases in their mean resolution times,
-- despite decreases in their medians. Some unusually long tickets
-- may be influencing their averages.


/*
COMPARE TICKET CHANNELS

Check whether the volume or resolution times for different channels
changed after launch.
*/

SELECT
    opened_month AS ticket_month,
    channel,
    COUNT(*) AS ticket_count,
    ROUND(AVG(resolution_hours)::numeric, 2) AS mean_hours,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resolution_hours)::numeric,
        2
    ) AS median_hours
FROM resolved_ticket_analysis
WHERE opened_at >= TIMESTAMP '2026-06-01 00:00:00'
  AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
GROUP BY opened_month, channel
ORDER BY opened_month, channel;

-- Comparing ticket resolution time by support channel.
-- Format: ticket_month, channel, ticket_count, mean_hours, median_hours
--
-- June chat: 488 tickets, 18.14 mean hours, 15.59 median hours.
-- June email: 788 tickets, 18.81 mean hours, 15.20 median hours.
-- June portal: 306 tickets, 18.31 mean hours, 15.31 median hours.
--
-- July chat: 500 tickets, 16.66 mean hours, 13.59 median hours.
-- July email: 820 tickets, 33.83 mean hours, 14.18 median hours.
-- July portal: 322 tickets, 15.03 mean hours, 12.42 median hours.
--
-- Email had the highest ticket volume in both months.
-- Email's mean increased by 79.85%, while its median decreased.
-- Chat and portal mean resolution times both decreased.
-- The difference between email's mean and median suggests that
-- unusually long email tickets may have raised the average.
-- Investigate the longest-running email tickets to confirm.


/*
COMPARE CUSTOMER PLANS

Determine whether the change is concentrated in enterprise customers
or appears across customer plans.
*/

SELECT
    opened_month AS ticket_month,
    plan,
    COUNT(*) AS ticket_count,
    ROUND(AVG(resolution_hours)::numeric, 2) AS mean_hours,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resolution_hours)::numeric,
        2
    ) AS median_hours
FROM resolved_ticket_analysis
WHERE opened_at >= TIMESTAMP '2026-06-01 00:00:00'
  AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
GROUP BY opened_month, plan
ORDER BY opened_month, plan;

-- Comparing ticket resolution time by customer plan.
-- Format: ticket_month, plan, ticket_count, mean_hours, median_hours
--
-- June enterprise: 172 tickets, 19.14 mean hours, 13.82 median hours.
-- June growth: 445 tickets, 17.48 mean hours, 14.79 median hours.
-- June starter: 965 tickets, 18.87 mean hours, 15.62 median hours.
--
-- July enterprise: 210 tickets, 84.23 mean hours, 15.55 median hours.
-- July growth: 427 tickets, 16.25 mean hours, 13.56 median hours.
-- July starter: 1,005 tickets, 16.20 mean hours, 13.34 median hours.
--
-- Enterprise ticket volume increased from 172 to 210.
-- Enterprise mean resolution time increased sharply, while its median
-- increased only slightly. This suggests that some long-running
-- enterprise tickets may be influencing the mean.
-- Growth and starter mean resolution times decreased.
-- These figures do not prove that the migration caused the increase.


/*
INVESTIGATE ENTERPRISE CUSTOMERS IN JULY

Use this output alongside the case description to identify the migration
account. Do not assume the account with the most tickets is necessarily
the migration account.
*/

SELECT
    customer_id,
    COUNT(*) AS resolved_ticket_count,
    COUNT(*) FILTER (
        WHERE ticket_type = 'reopened'
    ) AS reopened_ticket_count,
    ROUND(AVG(resolution_hours)::numeric, 2) AS mean_hours,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resolution_hours)::numeric,
        2
    ) AS median_hours,
    ROUND(MAX(resolution_hours)::numeric, 2) AS longest_ticket_hours
FROM resolved_ticket_analysis
WHERE plan = 'enterprise'
  AND opened_at >= TIMESTAMP '2026-07-01 00:00:00'
  AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
GROUP BY customer_id
ORDER BY mean_hours DESC;

-- C000017 stands out in the supplied results with 45 tickets,
-- a reported mean of 333.27 hours and a maximum of 509.10 hours.
-- Verify these figures against the ticket-level records.
-- Confirm whether C000017 is the migration customer before
-- attributing these results to the migration.


/*
ENTERPRISE ACCOUNT TICKET DETAILS

Replace the placeholder with the verified migration account ID.
*/

SELECT
    ticket_id,
    customer_id,
    plan,
    region,
    opened_at,
    resolved_at,
    priority,
    channel,
    reopened_from,
    ticket_type,
    ROUND(resolution_hours::numeric, 2) AS resolution_hours
FROM resolved_ticket_analysis
WHERE customer_id = 'MIGRATION_CUSTOMER_ID'
  AND opened_at >= TIMESTAMP '2026-07-01 00:00:00'
  AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
ORDER BY resolution_hours DESC;


/*
MEASURE EACH ENTERPRISE ACCOUNT'S IMPACT ON JULY'S MEAN

This calculates July's overall mean and recalculates the mean after
excluding each enterprise customer in turn.
*/

WITH july_tickets AS (
    SELECT *
    FROM resolved_ticket_analysis
    WHERE opened_at >= TIMESTAMP '2026-07-01 00:00:00'
      AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
),
june_baseline AS (
    SELECT AVG(resolution_hours) AS june_mean_hours
    FROM resolved_ticket_analysis
    WHERE opened_at >= TIMESTAMP '2026-06-01 00:00:00'
      AND opened_at < TIMESTAMP '2026-07-01 00:00:00'
),
july_baseline AS (
    SELECT
        COUNT(*) AS july_ticket_count,
        AVG(resolution_hours) AS july_mean_hours
    FROM july_tickets
),
enterprise_accounts AS (
    SELECT DISTINCT customer_id
    FROM july_tickets
    WHERE plan = 'enterprise'
      AND customer_id IS NOT NULL
),
account_impact AS (
    SELECT
        e.customer_id,
        COUNT(j.ticket_id) FILTER (
            WHERE j.customer_id = e.customer_id
        ) AS account_ticket_count,
        AVG(j.resolution_hours) FILTER (
            WHERE j.customer_id = e.customer_id
        ) AS account_mean_hours,
        AVG(j.resolution_hours) FILTER (
            WHERE j.customer_id <> e.customer_id
        ) AS mean_without_account
    FROM enterprise_accounts AS e
    CROSS JOIN july_tickets AS j
    GROUP BY e.customer_id
)
SELECT
    a.customer_id,
    a.account_ticket_count,
    ROUND(a.account_mean_hours::numeric, 2) AS account_mean_hours,
    b.july_ticket_count,
    ROUND(b.july_mean_hours::numeric, 2) AS overall_july_mean_hours,
    ROUND(a.mean_without_account::numeric, 2) AS july_mean_without_account,
    ROUND(
        (b.july_mean_hours - a.mean_without_account)::numeric,
        2
    ) AS reduction_in_mean_hours,
    ROUND(
        (
            100.0 * (b.july_mean_hours - a.mean_without_account)
            / NULLIF(b.july_mean_hours, 0)
        )::numeric,
        2
    ) AS reduction_as_percent_of_july_mean,
    ROUND(
        (
            100.0 * (b.july_mean_hours - a.mean_without_account)
            / NULLIF(b.july_mean_hours - j.june_mean_hours, 0)
        )::numeric,
        2
    ) AS reduction_as_percent_of_june_july_gap
FROM account_impact AS a
CROSS JOIN july_baseline AS b
CROSS JOIN june_baseline AS j
ORDER BY reduction_in_mean_hours DESC NULLS LAST;

-- This measures how much each enterprise account influences July's mean.
-- A reduction after excluding an account indicates that the account's
-- tickets contribute to the high overall mean.
-- This is a descriptive comparison, not proof of causation.


/*
COMPARE THE MIGRATION ACCOUNT WITH OTHER CUSTOMERS

Replace the placeholder with the verified migration account ID.
*/

WITH july_tickets AS (
    SELECT *
    FROM resolved_ticket_analysis
    WHERE opened_at >= TIMESTAMP '2026-07-01 00:00:00'
      AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
)
SELECT
    CASE
        WHEN customer_id = 'MIGRATION_CUSTOMER_ID'
            THEN 'migration_account'
        ELSE 'other_customers'
    END AS customer_group,
    COUNT(*) AS ticket_count,
    ROUND(AVG(resolution_hours)::numeric, 2) AS mean_hours,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resolution_hours)::numeric,
        2
    ) AS median_hours,
    ROUND(
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY resolution_hours)::numeric,
        2
    ) AS p90_hours
FROM july_tickets
GROUP BY
    CASE
        WHEN customer_id = 'MIGRATION_CUSTOMER_ID'
            THEN 'migration_account'
        ELSE 'other_customers'
    END
ORDER BY customer_group;

-- Confirm that the customer ID has been replaced before interpreting
-- the comparison. If the placeholder is unchanged, all real customers
-- will be grouped as other_customers.


/*
INVESTIGATE UNRESOLVED TICKETS

Open tickets do not have a completed resolution time and should not be
included in completed resolution-time averages.
*/

SELECT
    DATE_TRUNC('month', opened_at)::date AS opened_month,
    COUNT(*) AS tickets_opened,
    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) = 'open'
           OR resolved_at IS NULL
    ) AS unresolved_tickets,
    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) = 'resolved'
          AND resolved_at IS NOT NULL
    ) AS marked_resolved_with_timestamp
FROM tickets
WHERE opened_at >= TIMESTAMP '2026-06-01 00:00:00'
  AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
GROUP BY DATE_TRUNC('month', opened_at)::date
ORDER BY opened_month;

-- Previously reported: June had 1,582 tickets and July had 1,642.
-- Both months showed zero unresolved tickets in this result.
-- This describes the exported data, not necessarily the backlog
-- at each month-end.


-- Calculate the age of tickets still open at the September 6 export.

SELECT
    ticket_id,
    customer_id,
    opened_at,
    priority,
    channel,
    ROUND(
        (
            EXTRACT(
                EPOCH FROM (
                    TIMESTAMP '2026-09-06 00:00:00' - opened_at
                )
            ) / 3600.0
        )::numeric,
        2
    ) AS age_at_export_hours
FROM tickets
WHERE LOWER(TRIM(status)) = 'open'
  AND opened_at IS NOT NULL
  AND opened_at <= TIMESTAMP '2026-09-06 00:00:00'
ORDER BY age_at_export_hours DESC;


/*
CHECK WHETHER THE CHANGE IS BROAD OR CONCENTRATED

Compare regular tickets by priority, excluding reopened tickets.
*/

SELECT
    opened_month AS ticket_month,
    priority,
    COUNT(*) AS regular_ticket_count,
    ROUND(AVG(resolution_hours)::numeric, 2) AS mean_hours,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resolution_hours)::numeric,
        2
    ) AS median_hours
FROM resolved_ticket_analysis
WHERE ticket_type = 'regular'
  AND opened_at >= TIMESTAMP '2026-06-01 00:00:00'
  AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
GROUP BY opened_month, priority
ORDER BY opened_month, priority;

-- Comparing resolution time by priority for regular tickets.
-- Format: ticket_month, priority, ticket_count, mean_hours, median_hours
--
-- June P1: 77 tickets, 6.55 mean hours, 6.15 median hours.
-- June P2: 361 tickets, 14.36 mean hours, 12.63 median hours.
-- June P3: 791 tickets, 20.49 mean hours, 17.95 median hours.
-- June P4: 204 tickets, 32.92 mean hours, 28.39 median hours.
--
-- July P1: 66 tickets, 6.49 mean hours, 5.66 median hours.
-- July P2: 366 tickets, 27.70 mean hours, 10.84 median hours.
-- July P3: 853 tickets, 27.82 mean hours, 15.20 median hours.
-- July P4: 207 tickets, 28.56 mean hours, 25.12 median hours.
--
-- P2 and P3 show increased means but lower medians.
-- This suggests a subset of long-running regular tickets may be
-- affecting the averages. Investigate the longest tickets to confirm.


/*
FINAL METRICS SUMMARY

This summary uses the month in which tickets were opened.
*/

WITH monthly AS (
    SELECT
        opened_month AS ticket_month,
        COUNT(*) AS ticket_count,
        AVG(resolution_hours) AS mean_hours,
        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY resolution_hours) AS median_hours
    FROM resolved_ticket_analysis
    WHERE opened_at >= TIMESTAMP '2026-06-01 00:00:00'
      AND opened_at < TIMESTAMP '2026-08-01 00:00:00'
    GROUP BY opened_month
)
SELECT
    ticket_month,
    ticket_count,
    ROUND(mean_hours::numeric, 2) AS mean_hours,
    ROUND(median_hours::numeric, 2) AS median_hours,
    ROUND(
        (
            100.0 * (
                mean_hours - LAG(mean_hours) OVER (ORDER BY ticket_month)
            )
            / NULLIF(
                LAG(mean_hours) OVER (ORDER BY ticket_month),
                0
            )
        )::numeric,
        2
    ) AS mean_change_percent_from_previous_month
FROM monthly
ORDER BY ticket_month;

-- June 2026: 1,582 tickets, mean 18.51 hours, median 15.37 hours.
-- July 2026: 1,642 tickets, mean 24.92 hours, median 13.58 hours.
-- July mean increased by approximately 34.61% from June.


-- Calculate the age of tickets still open at the September 6 export.
-- The export timestamp is used as the reference point.

SELECT
    ticket_id,
    customer_id,
    opened_at,
    priority,
    channel,
    ROUND(
        (
            EXTRACT(
                EPOCH FROM (
                    TIMESTAMP '2026-09-06 00:00:00' - opened_at
                )
            ) / 3600.0
        )::numeric,
        2
    ) AS age_at_export_hours
FROM tickets
WHERE LOWER(TRIM(status)) = 'open'
  AND opened_at IS NOT NULL
  AND opened_at <= TIMESTAMP '2026-09-06 00:00:00'
ORDER BY age_at_export_hours DESC;

/*
We calculates the typical time taken to resolve tickets in June and July,
counts new tickets in July, and identifies how much of July’s total resolution time came from the customer that consumed the most support time.

*/


WITH regular_resolved AS (
    SELECT
        ticket_id,
        customer_id,
        opened_at,
        resolved_at,
        EXTRACT(EPOCH FROM (resolved_at - opened_at)) / 3600.0
            AS resolution_hours
    FROM tickets
    WHERE status = 'resolved'
      AND (reopened_from IS NULL OR TRIM(reopened_from::text) = '')
      AND resolved_at IS NOT NULL
      AND resolved_at >= opened_at
),

monthly_medians AS (
    SELECT
        DATE_TRUNC('month', opened_at) AS ticket_month,
        ROUND(
            (PERCENTILE_CONT(0.5) WITHIN GROUP (
                ORDER BY resolution_hours
            ))::numeric,
            1
        ) AS median_hours
    FROM regular_resolved
    WHERE opened_at >= '2026-06-01'
      AND opened_at < '2026-08-01'
    GROUP BY DATE_TRUNC('month', opened_at)
),

july_customer_hours AS (
    SELECT
        customer_id,
        SUM(resolution_hours) AS total_hours
    FROM regular_resolved
    WHERE opened_at >= '2026-07-01'
      AND opened_at < '2026-08-01'
    GROUP BY customer_id
),

july_totals AS (
    SELECT SUM(total_hours) AS grand_total_hours
    FROM july_customer_hours
)

SELECT
    (SELECT median_hours
     FROM monthly_medians
     WHERE ticket_month = '2026-06-01') AS june_median_hours,

    (SELECT median_hours
     FROM monthly_medians
     WHERE ticket_month = '2026-07-01') AS july_median_hours,

    (SELECT COUNT(*)
     FROM tickets
     WHERE opened_at >= '2026-07-01'
       AND opened_at < '2026-08-01'
       AND (reopened_from IS NULL
            OR TRIM(reopened_from::text) = '')
    ) AS july_new_tickets,

    ROUND(
        (
            SELECT total_hours
            FROM july_customer_hours
            ORDER BY total_hours DESC
            LIMIT 1
        ) * 100.0
        / NULLIF((SELECT grand_total_hours FROM july_totals), 0),
        1
    ) AS largest_customer_share_percent;


	-- July's median resolution time improved from June, 
	-- but one customer accounted for 37.3% of total resolution hours, 
	--potentially contributing to the increase in average resolution time.