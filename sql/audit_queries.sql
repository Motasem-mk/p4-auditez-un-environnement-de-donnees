/*
===============================================================================
P4 — Auditez un environnement de données
===============================================================================
*/


/* ============================================================================
1. REVENUE VALIDATION QUERIES
============================================================================ */


/* 1.1 Total revenue for 14 August */
SELECT
    SUM(p.prix) AS total_revenue
FROM
    sales_details s
JOIN
    products p ON s.EAN = p.EAN
WHERE
    s.Date_achat = '2024-08-14';

-- total_revenue = 284243.8790573478


/* 1.2 Revenue by customer — Top 10 customers */
SELECT
    s.CUSTOMER_ID,
    SUM(p.prix) AS revenue_per_customer
FROM
    sales_details s
JOIN
    products p ON s.EAN = p.EAN
GROUP BY
    s.CUSTOMER_ID
ORDER BY
    revenue_per_customer DESC
LIMIT 10;


/* 1.3 Revenue share collected by employee */
SELECT
    CONCAT(e.prenom, ' ', e.nom) AS 'employee name',
    (SUM(p.prix) / (
        SELECT SUM(p2.prix)
        FROM sales_details s2
        JOIN products p2 ON s2.EAN = p2.EAN
    )) * 100 AS revenue_share
FROM sales_details s
JOIN products p ON s.EAN = p.EAN
JOIN employee e ON s.id_employe = e.id_employe
GROUP BY e.id_employe
ORDER BY revenue_share DESC;


/* ============================================================================
2. LOGS DICTIONARY AND GENERAL LOG EXPLORATION
============================================================================ */


/* 2.1 Total number of logs */
SELECT
    COUNT(*)
FROM
    logs;

-- 207,489 logs total


/* 2.2 Number of logs by action */
SELECT
    action,
    COUNT(*) AS log_count
FROM
    logs
GROUP BY
    action;

-- INSERT = 206905
-- DELETE = 2
-- UPDATE = 582


/* 2.3 Count INSERT actions by table */
SELECT
    table_insert,
    COUNT(*) AS insert_count
FROM logs
WHERE action = 'INSERT'
GROUP BY table_insert;

-- Client = 20
-- Ventes = 206885


/* 2.4 Count UPDATE actions by table */
SELECT
    table_insert,
    COUNT(*) AS update_count
FROM logs
WHERE action = 'UPDATE'
GROUP BY table_insert;

-- Employé = 7
-- Produits = 575


/* 2.5 Count DELETE actions by table */
SELECT
    table_insert,
    COUNT(*) AS delete_count
FROM logs
WHERE action = 'DELETE'
GROUP BY table_insert;

-- Employé = 2


/* ============================================================================
3. INSERT LOG ANALYSIS — SALES
============================================================================ */


/* 3.1 Inspect INSERT logs for sales records */
SELECT *,
       ROW_NUMBER() OVER (ORDER BY l.id_ligne) AS n
FROM logs l
WHERE l.table_insert = 'Ventes'
  AND l.action = 'INSERT';

-- logs has 206885 rows for INSERT and Ventes


/* 3.2 Count unique sales records in INSERT logs */
SELECT
    COUNT(DISTINCT id_ligne) AS unique_id_count
FROM logs l
WHERE l.table_insert = 'Ventes'
  AND l.action = 'INSERT';

-- 41377 unique records


/* 3.3 Inspect records in sales_details */
SELECT *,
       ROW_NUMBER() OVER (ORDER BY ID_BDD) AS n
FROM sales_details;

-- 41377 rows


/* 3.4 Check for missing records in sales_details compared to logs */
SELECT *
FROM logs l
WHERE l.table_insert = 'Ventes'
  AND l.action = 'INSERT'
  AND NOT EXISTS (
      SELECT 1
      FROM sales_details sd
      WHERE sd.ID_BDD = l.id_ligne
  );

-- No missing records


/* 3.5 Check for redundant records in sales_details compared to logs */
SELECT *
FROM sales_details sd
WHERE NOT EXISTS (
    SELECT *
    FROM logs l
    WHERE l.table_insert = 'Ventes'
      AND l.action = 'INSERT'
      AND sd.ID_BDD = l.id_ligne
);

-- No redundant records


/* ============================================================================
4. INSERT LOG ANALYSIS — CLIENTS
============================================================================ */


/* 4.1 Check missing client records from INSERT logs */
SELECT *
FROM logs l
WHERE l.action = 'INSERT'
  AND l.table_insert = 'Client'
  AND l.champs = 'date_inscription'
  AND NOT EXISTS (
      SELECT 1
      FROM clients c
      WHERE c.CUSTOMER_ID = l.detail
  );

-- 20 client records in logs do not exist in the clients table


/* ============================================================================
5. UPDATE LOG ANALYSIS — PRODUCTS
============================================================================ */


/* 5.1 Cross-reference product UPDATE actions */
SELECT
    p.EAN,
    p.prix AS products_prix,
    l.detail AS log_prix,
    ROW_NUMBER() OVER (ORDER BY l.id_ligne) AS n
FROM products p
JOIN logs l ON p.EAN = l.id_ligne
WHERE l.action = 'UPDATE'
  AND table_insert = 'Produits'
  AND l.champs = 'prix';



/* 5.2 Count invalid product price updates in logs */
SELECT
    COUNT(*)
FROM logs l
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Produits'
  AND l.champs = 'prix'
  AND NOT l.detail REGEXP '^[0-9]+(\\.[0-9]+)?$';

-- 136 records have date values instead of price values


/* 5.3 Check missing product records compared to product UPDATE logs */
SELECT *
FROM logs l
WHERE table_insert = 'Produits'
  AND NOT EXISTS (
      SELECT *
      FROM products p
      WHERE p.EAN = l.id_ligne
  );

-- No missing records


/* ============================================================================
6. UPDATE LOG ANALYSIS — EMPLOYEE HASH_MDP
============================================================================ */


/* 6.1 Verify employee hash_mdp integrity */
SELECT
    e.id_employe,
    e.hash_mdp AS db_hash_mdp,
    MAX(CASE WHEN l.champs = 'hash_mdp' THEN l.detail END) AS log_hash_mdp
FROM employee e
LEFT JOIN logs l
ON e.id_employe = l.id_ligne
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Employé'
GROUP BY e.id_employe
HAVING db_hash_mdp <> log_hash_mdp;

-- 7 employee hash_mdp mismatches


/* ============================================================================
7. DELETE LOG ANALYSIS — EMPLOYEES
============================================================================ */


/* 7.1 Verify deleted employee records */
SELECT *
FROM logs l
WHERE l.table_insert = 'Employé'
  AND l.action = 'DELETE'
  AND NOT EXISTS (
      SELECT 1
      FROM employee e
      WHERE e.id_employe = l.id_ligne
  );

-- 2 records returned, confirming that corresponding employees were deleted


/* ============================================================================
8. MONITORING VIEWS AND CORRECTIVE QUERIES FROM THE PRESENTATION
============================================================================ */


/* 8.1 View to monitor invalid product price values in logs */
CREATE VIEW log_prix_issues AS
SELECT
    l.id_user,
    l.date,
    l.action,
    l.table_insert,
    l.id_ligne,
    l.champs,
    l.detail AS log_prix,
    'Non-numeric price' AS issue_type
FROM logs l
WHERE l.table_insert = 'Produits'
  AND l.action = 'UPDATE'
  AND l.champs = 'prix'
  AND NOT l.detail REGEXP '^[0-9]+(\\.[0-9]+)?$';

SELECT *
FROM log_prix_issues;


/* 8.2 View to monitor missing client records */
CREATE VIEW log_audit_clients AS
SELECT
    l.id_ligne AS missing_customer_id,
    l.detail AS log_date_inscription
FROM logs l
WHERE l.action = 'INSERT'
  AND l.table_insert = 'Client'
  AND l.champs = 'date_inscription'
  AND NOT EXISTS (
      SELECT 1
      FROM clients c
      WHERE c.CUSTOMER_ID = l.id_ligne
        AND DATE(c.date_inscription) = DATE(l.detail)
  );

SELECT *
FROM log_audit_clients;


/* 8.3 Optional correction for missing client records */
INSERT INTO clients (CUSTOMER_ID, date_inscription)
SELECT
    l.id_ligne,
    DATE(l.detail)
FROM logs l
WHERE l.action = 'INSERT'
  AND l.table_insert = 'Client'
  AND l.champs = 'date_inscription'
  AND NOT EXISTS (
      SELECT 1
      FROM clients c
      WHERE c.CUSTOMER_ID = l.id_ligne
  );

SELECT *
FROM log_audit_clients;


/* 8.4 View to monitor employee hash_mdp mismatches */
CREATE VIEW log_audit_employees AS
SELECT
    e.id_employe,
    e.hash_mdp AS db_hash_mdp,
    l.detail AS log_hash_mdp
FROM employee e
LEFT JOIN logs l
ON e.id_employe = l.id_ligne
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Employé'
  AND l.champs = 'hash_mdp'
  AND e.hash_mdp <> l.detail;

SELECT *
FROM log_audit_employees;


/* 8.5 Dynamic correction for employee hash_mdp mismatches */
UPDATE employee e
JOIN logs l
ON e.id_employe = l.id_ligne
SET e.hash_mdp = l.detail
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Employé'
  AND l.champs = 'hash_mdp'
  AND e.hash_mdp <> l.detail;

SELECT *
FROM log_audit_employees;
