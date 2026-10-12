
# 🔍 The Slow Support Queue: Investigating Rising Resolution Times with SQL

##  Project Overview

Bramblewick, a  B2B software company, noticed an increase in its average customer support ticket resolution time after launching a new helpdesk tool on July 1, 2026.

The reported average resolution time increased from approximately 20 hours in June to 27 hours in July. This raised concerns about whether the new helpdesk tool had made customer support less efficient.

However, an increase in average resolution time does not necessarily mean that most tickets are taking longer to resolve. A small number of tickets with unusually long resolution times can significantly increase the average.

This project uses **PostgreSQL and SQL** to investigate the increase, compare monthly support performance, identify customers contributing the most to total resolution hours, and provide data-driven recommendations to management.

**The central question:** Did the new helpdesk tool make customer support slower, or did a small number of unusually delayed tickets drive the increase in the average?

---

##  Business Problem

Following the introduction of the new helpdesk tool, Bramblewick reported an increase in average ticket resolution time. Management needed to determine whether this represented a general decline in support performance or whether the increase was driven by specific customers, unusually delayed tickets, or other operational factors.

Rolling back the new tool without understanding the underlying cause could be costly and unnecessary. However, ignoring a genuine performance problem could negatively affect customer satisfaction and operational efficiency.

The business therefore needed a data-driven investigation to:

- Determine whether typical tickets were taking longer to resolve.
- Compare support performance before and after the tool's introduction.
- Identify customers contributing disproportionately to total resolution hours.
- Investigate whether unusually long tickets influenced the overall average.
- Recommend appropriate next steps based on the available evidence.

### Why This Problem Matters

Understanding the cause of longer resolution times helps the company distinguish between a potential system problem and an operational problem. This supports better decisions about software investments, customer support processes, and resource allocation.

---

##  Project Objectives

The primary objective is to investigate the change in customer support ticket resolution times between June and July 2026 using SQL.

The specific objectives are to:

1. Calculate the median resolution time for eligible tickets opened in June 2026.
2. Calculate the median resolution time for eligible tickets opened in July 2026.
3. Count new tickets opened in July, including unresolved tickets.
4. Identify the customer responsible for the largest share of total resolution hours among eligible July tickets.
5. Calculate that customer's percentage contribution to total July resolution hours.
6. Use the findings to assess whether the evidence supports rolling back the new helpdesk tool.

---

##  Project Goals

This project aims to achieve the following outcomes:

- **Measure typical performance:** Use the median to understand how long a typical ticket takes to resolve.
- **Compare monthly performance:** Determine whether typical resolution time improved or worsened between June and July.
- **Measure support demand:** Establish the number of new tickets opened in July.
- **Identify concentrated delays:** Determine whether one customer accounts for a substantial proportion of resolution hours.
- **Support management decisions:** Translate SQL results into practical recommendations.
- **Demonstrate SQL proficiency:** Apply filtering, aggregation, date-based analysis, timestamp calculations, and statistical functions to a business problem.

---

##  Business Questions

| No. | Business Question | Purpose |
|---|---|---|
| 1 | What was the median resolution time for tickets opened in June? | Establish a baseline for typical performance. |
| 2 | What was the median resolution time for tickets opened in July? | Measure typical performance after launch. |
| 3 | How many new tickets were opened in July? | Understand incoming support demand. |
| 4 | What percentage of July resolution hours came from the highest-contributing customer? | Identify concentration of resolution time. |
| 5 | Should Bramblewick roll back the new helpdesk tool? | Support a business decision using evidence. |

---

##  Dataset Overview

The dataset covers **May 1 to August 31, 2026**. The data export was created on September 6, 2026, and all timestamps are recorded in UTC.

The project uses two tables: `tickets` and `customers`.

###  Tickets Table

The `tickets` table contains customer support ticket records.

| Column | Description |
|---|---|
| `ticket_id` | Unique identifier for each ticket. |
| `customer_id` | Identifies the customer associated with the ticket. |
| `opened_at` | Date and time the ticket was opened. |
| `resolved_at` | Date and time the ticket was resolved; blank for unresolved tickets. |
| `status` | Indicates whether the ticket is open or resolved. |
| `priority` | Ticket priority, from P1 to P4. |
| `channel` | Support channel used to submit the ticket. |
| `reopened_from` | References an earlier ticket when the record represents a reopened or follow-up ticket. |

###  Customers Table

The `customers` table provides additional information about each customer.

| Column | Description |
|---|---|
| `customer_id` | Unique customer identifier. |
| `plan` | Customer subscription plan. |
| `region` | Customer's region. |

###  Important Data Definitions

- **New ticket:** A ticket with a blank `reopened_from` field.
- **Reopened ticket:** A ticket linked to an earlier ticket through `reopened_from`.
- **Resolved ticket:** A ticket with a resolved status and a valid resolution timestamp.
- **Resolution time:** The number of hours between `opened_at` and `resolved_at`.

For the June and July median calculations and the July customer contribution analysis, the analysis includes resolved tickets with valid timestamps, nonnegative resolution durations, and blank `reopened_from` values.

For the July new-ticket count, both open and resolved tickets are included, provided they have a blank `reopened_from` field.

---

##  Analysis Framework

The investigation follows a structured analytical process, from understanding the data to interpreting the results and recommending action.

###  Data Understanding and Preparation

The first step was to inspect the available tables, understand the fields, and establish how tickets relate to customers.

The analysis focused on:

- Reviewing ticket statuses and timestamps.
- Identifying unresolved tickets.
- Distinguishing new tickets from reopened tickets.
- Checking for missing or invalid resolution timestamps.
- Calculating resolution durations in hours.
- Ensuring consistent definitions across the monthly comparison.

**Purpose:** Establish a consistent dataset for reliable analysis.

###  Median Resolution Time Analysis

The median resolution time was calculated for tickets opened in June and July.

The median is the middle value when resolution times are arranged from shortest to longest. Unlike the average, it is less affected by a small number of extremely long tickets.

**Purpose:** Determine whether the typical eligible ticket was resolved faster or slower after the helpdesk launch.

### New Ticket Volume Analysis

The number of new tickets opened during July was counted, including tickets that remained open.

Reopened tickets were excluded because they represent follow-up activity rather than new tickets under the project's definition.

**Purpose:** Measure incoming support demand during July.

###  Customer-Level Resolution Analysis

The total resolution hours were calculated for each customer with eligible resolved tickets opened in July.

The customer with the largest total was identified, and its share of total July resolution hours was calculated.

**Calculation:**

`Customer Share (%) = (Top Customer's Resolution Hours / Total Resolution Hours) * 100`

**Purpose:** Determine whether resolution time was concentrated in one customer account.

###  Interpretation of Findings

The June and July median resolution times were compared with the customer-level results.

The analysis considered whether the increase in average resolution time necessarily represented a general decline in support performance.

**Purpose:** Avoid making a decision based on a single metric.

###  Business Recommendation

The findings were used to assess whether Bramblewick should immediately roll back the helpdesk tool or investigate the main sources of delay before making a final decision.

**Purpose:** Turn SQL results into actionable business recommendations.

---

## SQL Techniques Used

| SQL Technique | Application |
|---|---|
| `SELECT` | Retrieve relevant fields from the dataset. |
| `WHERE` | Filter records by date, status, and ticket type. |
| `JOIN` | Combine ticket records with customer information when needed. |
| Date and timestamp filtering | Identify tickets opened within June and July. |
| Timestamp arithmetic | Calculate the time between ticket opening and resolution. |
| `EXTRACT` | Convert timestamp differences into hours where appropriate. |
| `COUNT` | Count new tickets opened in July. |
| `PERCENTILE_CONT` | Calculate the median resolution time. |
| `GROUP BY` | Aggregate resolution hours by customer. |
| `SUM` | Calculate total resolution hours. |
| `ORDER BY` | Rank customers by total resolution hours. |
| Common Table Expressions (CTEs) | Organize multi-step queries into readable sections. |
| Percentage calculations | Measure the contribution of the highest-contributing customer. |

---

##  Key Findings

The analysis produced the following results:

| Metric | Result |
|---|---:|
| June median resolution time | 16.6 hours |
| July median resolution time | 14.6 hours |
| Change in median resolution time | -2.0 hours |
| Percentage change in median | -12.0% |
| New tickets opened in July | 1,492 |
| Top customer's share of July resolution hours | 37.3% |

### Finding 

##### 1. Typical Resolution Time Decreased

The median resolution time decreased from 16.6 hours in June to 14.6 hours in July.

This represents a reduction of 2.0 hours, or approximately 12.0%.

**Business interpretation:** The typical eligible ticket was resolved faster in July. This does not support the conclusion that support resolution became slower for the typical ticket after the new tool was introduced.

##### 2.  Bramblewick Received 1,492 New Tickets in July

The analysis identified 1,492 new tickets opened during July, including both resolved and unresolved tickets.

**Business interpretation:** This provides a measure of incoming support demand. Ticket volume should be considered alongside resolution time when evaluating support performance.

##### 3. One Customer Accounted for 37.3% of Resolution Hours

The customer with the highest total accounted for 37.3% of all resolution hours for eligible July tickets.

**Business interpretation:** A substantial share of resolution time was concentrated in one customer account. This makes that customer's tickets an important area for further investigation.

However, this result does not independently establish why those tickets took so long to resolve or whether the customer was involved in the migration.

##### 4. The Average and Median Tell Different Stories

The company reported an increase in average resolution time, while the median for the defined ticket population decreased.

- **Average:** Total resolution hours divided by the number of tickets. Extremely long tickets can increase it substantially.
- **Median:** The middle resolution time when tickets are ordered by duration. It is less sensitive to extreme values.

**Business interpretation:** The reported increase in the average should be investigated, but it should not automatically be interpreted as evidence that typical ticket resolution became slower.

---

## Business Recommendation

**Final Decision: Do NOT roll back the new helpdesk tool.**

## Recommendations

The business should prioritize improving the support experience for customer C000017, whose unusually long resolution times contributed significantly to July's average. Email support processes should be strengthened through timely ticket assignment, follow-ups, and escalation procedures. Clear resolution-time targets should also be established to prevent prolonged delays. Finally, the business should continue monitoring support performance and assess the impact of the new helpdesk tool before deciding whether further changes or a rollback are necessary.


### Final Takeaway

> Look beyond the average. Investigate the underlying data, identify where delays are concentrated, and use evidence to guide business decisions.

---

## 13. Project Information

- **Project:** The Slow Support Queue
- **Category:** Data Analytics
- **Database:** PostgreSQL
- **Language:** SQL
- **Dataset:** Fictional B2B customer support data
- **Analysis period:** May–August 2026
- **Primary focus:** Resolution time analysis and customer-level investigation

*This project was completed as a practical SQL business analysis exercise using fictional company data.*
