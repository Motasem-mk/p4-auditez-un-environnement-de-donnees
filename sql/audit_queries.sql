/*
===============================================================================
P4 — Auditez un environnement de données
SuperSmartMarket — OLAP cube audit and log analysis
===============================================================================

Purpose:
  Clean SQL companion file extracted and reorganized from the project notebook,
  audit presentation, and official project requirements.

Scope:
  - Validate the turnover for 14 August 2024.
  - Analyze the OLAP prototype tables and the database logs.
  - Detect inconsistencies between logs and business/dimension tables.
  - Provide monitoring views and proposed resilience measures.

SQL dialect:
  MySQL 8.x / MySQL Workbench style SQL.

Assumed tables:
  - sales_details  : fact table for sales
  - products       : product dimension
  - clients        : client dimension
  - employee       : employee dimension
  - calendar       : calendar dimension
  - logs           : imported log table

Important note:
  Logs are treated as audit evidence. The queries below prioritize detection and
  monitoring. Correction queries are provided in a dedicated section and should
  be reviewed before execution in a real production environment.
===============================================================================
*/


/*=============================================================================
SECTION 1 — Revenue validation queries
=============================================================================*/

-- 1.1 Confirm total turnover for 14 August 2024.
-- Expected confirmed result in the project: 284,243.88 €.
SELECT
    ROUND(SUM(p.prix), 2) AS total_revenue_14_august
FROM sales_details AS s
JOIN products AS p
    ON s.EAN = p.EAN
WHERE DATE(s.Date_achat) = '2024-08-14';


-- 1.2 Top 10 customers by revenue.
SELECT
    s.CUSTOMER_ID,
    ROUND(SUM(p.prix), 2) AS customer_revenue
FROM sales_details AS s
JOIN products AS p
    ON s.EAN = p.EAN
GROUP BY s.CUSTOMER_ID
ORDER BY customer_revenue DESC
LIMIT 10;


-- 1.3 Revenue collected by employee.
SELECT
    e.id_employe,
    CONCAT(e.prenom, ' ', e.nom) AS employee_name,
    ROUND(SUM(p.prix), 2) AS revenue_collected
FROM sales_details AS s
JOIN products AS p
    ON s.EAN = p.EAN
JOIN employee AS e
    ON s.id_employe = e.id_employe
GROUP BY
    e.id_employe,
    e.prenom,
    e.nom
ORDER BY revenue_collected DESC;


/*=============================================================================
SECTION 2 — Initial logs exploration
=============================================================================*/

-- 2.1 Preview logs with a row number.
SELECT
    l.*,
    ROW_NUMBER() OVER (ORDER BY l.id_user, l.date) AS row_number_in_logs
FROM logs AS l;


-- 2.2 Total number of logs.
-- Project result: 207,489 logs.
SELECT
    COUNT(*) AS total_logs
FROM logs;


-- 2.3 Number of logs by action.
-- Project result: INSERT = 206,885, UPDATE = 582, DELETE = 2.
SELECT
    action,
    COUNT(*) AS log_count
FROM logs
GROUP BY action
ORDER BY log_count DESC;


-- 2.4 Number of INSERT logs by target table.
SELECT
    table_insert,
    COUNT(*) AS insert_count
FROM logs
WHERE action = 'INSERT'
GROUP BY table_insert
ORDER BY insert_count DESC;


-- 2.5 Number of UPDATE logs by target table.
SELECT
    table_insert,
    COUNT(*) AS update_count
FROM logs
WHERE action = 'UPDATE'
GROUP BY table_insert
ORDER BY update_count DESC;


-- 2.6 Number of DELETE logs by target table.
SELECT
    table_insert,
    COUNT(*) AS delete_count
FROM logs
WHERE action = 'DELETE'
GROUP BY table_insert
ORDER BY delete_count DESC;


/*=============================================================================
SECTION 3 — INSERT log analysis
=============================================================================*/

-- 3.1 Count INSERT logs for sales.
-- Project observation: INSERT logs for 'Ventes' are consistent with sales_details.
SELECT
    COUNT(*) AS sales_insert_logs
FROM logs
WHERE action = 'INSERT'
  AND table_insert = 'Ventes';


-- 3.2 Count distinct sales records referenced in INSERT logs.
-- Project observation: unique id_ligne values matched the number of records in
-- the sales_details fact table.
SELECT
    COUNT(DISTINCT id_ligne) AS unique_sales_records_in_logs
FROM logs
WHERE action = 'INSERT'
  AND table_insert = 'Ventes';


-- 3.3 Count records in the sales_details fact table for comparison.
SELECT
    COUNT(*) AS sales_details_records
FROM sales_details;


-- 3.4 Identify client INSERT logs that are not reflected in the clients table.
-- Project result: 20 missing clients.
-- Assumption: logs.id_ligne stores the client identifier.
SELECT
    l.*
FROM logs AS l
WHERE l.action = 'INSERT'
  AND l.table_insert = 'Client'
  AND NOT EXISTS (
      SELECT 1
      FROM clients AS c
      WHERE c.CUSTOMER_ID = l.id_ligne
  );


-- 3.5 Count missing clients detected from logs.
SELECT
    COUNT(*) AS missing_clients_from_logs
FROM logs AS l
WHERE l.action = 'INSERT'
  AND l.table_insert = 'Client'
  AND NOT EXISTS (
      SELECT 1
      FROM clients AS c
      WHERE c.CUSTOMER_ID = l.id_ligne
  );


/*=============================================================================
SECTION 4 — UPDATE log analysis: products
=============================================================================*/

-- 4.1 List product price UPDATE logs.
-- Project observation: 575 product updates were recorded in the logs.
SELECT
    l.id_ligne AS EAN,
    l.detail AS log_prix,
    p.prix AS products_prix,
    l.date AS log_date
FROM logs AS l
LEFT JOIN products AS p
    ON l.id_ligne = p.EAN
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Produits'
  AND l.champs = 'prix';


-- 4.2 Detect invalid product price values in logs.
-- Project result: 136 invalid entries where log_prix contained dates or
-- non-numeric values instead of prices.
SELECT
    l.id_ligne AS EAN,
    l.detail AS invalid_log_prix,
    p.prix AS products_prix,
    l.date AS log_date
FROM logs AS l
LEFT JOIN products AS p
    ON l.id_ligne = p.EAN
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Produits'
  AND l.champs = 'prix'
  AND NOT REGEXP_LIKE(l.detail, '^[0-9]+(\\.[0-9]+)?$');


-- 4.3 Count invalid product price values in logs.
SELECT
    COUNT(*) AS invalid_product_price_logs
FROM logs AS l
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Produits'
  AND l.champs = 'prix'
  AND NOT REGEXP_LIKE(l.detail, '^[0-9]+(\\.[0-9]+)?$');


-- 4.4 Verify whether all product UPDATE logs reference existing products.
SELECT
    l.id_ligne AS EAN,
    l.detail AS log_prix,
    p.prix AS products_prix
FROM logs AS l
LEFT JOIN products AS p
    ON l.id_ligne = p.EAN
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Produits'
  AND l.champs = 'prix'
  AND p.EAN IS NULL;


/*=============================================================================
SECTION 5 — UPDATE log analysis: employee hash_mdp
=============================================================================*/

-- 5.1 Detect mismatched employee hash_mdp values.
-- Project result: 7 mismatches.
SELECT
    e.id_employe,
    e.hash_mdp AS db_hash_mdp,
    l.detail AS log_hash_mdp,
    l.date AS log_date
FROM employee AS e
JOIN logs AS l
    ON e.id_employe = l.id_ligne
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Employé'
  AND l.champs = 'hash_mdp'
  AND e.hash_mdp <> l.detail;


-- 5.2 Count mismatched employee hash_mdp values.
SELECT
    COUNT(*) AS employee_hash_mismatches
FROM employee AS e
JOIN logs AS l
    ON e.id_employe = l.id_ligne
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Employé'
  AND l.champs = 'hash_mdp'
  AND e.hash_mdp <> l.detail;


/*=============================================================================
SECTION 6 — DELETE log analysis: employees
=============================================================================*/

-- 6.1 Analyze DELETE actions on the employee table.
-- Project observation: corresponding employee records were deleted from the
-- employee table.
SELECT
    l.*
FROM logs AS l
WHERE l.action = 'DELETE'
  AND l.table_insert = 'Employé';


-- 6.2 Verify deleted employees are absent from the employee table.
SELECT
    l.id_ligne AS deleted_employee_id,
    l.date AS deletion_log_date,
    e.id_employe AS employee_table_match
FROM logs AS l
LEFT JOIN employee AS e
    ON e.id_employe = l.id_ligne
WHERE l.action = 'DELETE'
  AND l.table_insert = 'Employé'
  AND e.id_employe IS NULL;


/*=============================================================================
SECTION 7 — Monitoring views for dynamic audit
=============================================================================*/

-- 7.1 View: invalid product price values in logs.
DROP VIEW IF EXISTS v_audit_invalid_product_price_logs;

CREATE VIEW v_audit_invalid_product_price_logs AS
SELECT
    'Invalid product price in logs' AS issue_type,
    'Produits' AS entity_table,
    l.id_ligne AS entity_id,
    l.action AS log_action,
    l.champs AS log_field,
    l.detail AS log_value,
    CAST(p.prix AS CHAR) AS current_database_value,
    l.date AS log_date,
    'The log contains a non-numeric price value; logs should be investigated, not silently overwritten.' AS explanation
FROM logs AS l
LEFT JOIN products AS p
    ON l.id_ligne = p.EAN
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Produits'
  AND l.champs = 'prix'
  AND NOT REGEXP_LIKE(l.detail, '^[0-9]+(\\.[0-9]+)?$');


-- 7.2 View: clients inserted in logs but missing from clients table.
DROP VIEW IF EXISTS v_audit_missing_clients;

CREATE VIEW v_audit_missing_clients AS
SELECT
    'Missing client in dimension table' AS issue_type,
    'Client' AS entity_table,
    l.id_ligne AS entity_id,
    l.action AS log_action,
    l.champs AS log_field,
    l.detail AS log_value,
    NULL AS current_database_value,
    l.date AS log_date,
    'The log indicates a client INSERT, but the client is absent from the clients table.' AS explanation
FROM logs AS l
WHERE l.action = 'INSERT'
  AND l.table_insert = 'Client'
  AND NOT EXISTS (
      SELECT 1
      FROM clients AS c
      WHERE c.CUSTOMER_ID = l.id_ligne
  );


-- 7.3 View: employee password hash mismatches.
DROP VIEW IF EXISTS v_audit_employee_hash_mismatch;

CREATE VIEW v_audit_employee_hash_mismatch AS
SELECT
    'Employee hash_mdp mismatch' AS issue_type,
    'Employé' AS entity_table,
    l.id_ligne AS entity_id,
    l.action AS log_action,
    l.champs AS log_field,
    l.detail AS log_value,
    e.hash_mdp AS current_database_value,
    l.date AS log_date,
    'The hash_mdp value in logs does not match the current employee table value.' AS explanation
FROM logs AS l
JOIN employee AS e
    ON e.id_employe = l.id_ligne
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Employé'
  AND l.champs = 'hash_mdp'
  AND e.hash_mdp <> l.detail;


-- 7.4 View: deleted employees confirmed as absent from employee table.
DROP VIEW IF EXISTS v_audit_deleted_employees;

CREATE VIEW v_audit_deleted_employees AS
SELECT
    'Employee deletion confirmed' AS issue_type,
    'Employé' AS entity_table,
    l.id_ligne AS entity_id,
    l.action AS log_action,
    l.champs AS log_field,
    l.detail AS log_value,
    NULL AS current_database_value,
    l.date AS log_date,
    'The employee DELETE action is logged and the record is absent from the employee table.' AS explanation
FROM logs AS l
LEFT JOIN employee AS e
    ON e.id_employe = l.id_ligne
WHERE l.action = 'DELETE'
  AND l.table_insert = 'Employé'
  AND e.id_employe IS NULL;


-- 7.5 Consolidated monitoring view.
DROP VIEW IF EXISTS v_audit_all_log_issues;

CREATE VIEW v_audit_all_log_issues AS
SELECT * FROM v_audit_invalid_product_price_logs
UNION ALL
SELECT * FROM v_audit_missing_clients
UNION ALL
SELECT * FROM v_audit_employee_hash_mismatch
UNION ALL
SELECT * FROM v_audit_deleted_employees;


-- 7.6 Summary of detected issues.
SELECT
    issue_type,
    COUNT(*) AS issue_count
FROM v_audit_all_log_issues
GROUP BY issue_type
ORDER BY issue_count DESC;


/*=============================================================================
SECTION 8 — Proposed corrective measures
===============================================================================

The following queries are examples of corrective measures for the prototype.
In a real production system, they should be validated by the OLTP/DBA team,
executed in a transaction, tested on a copy first, and audited afterwards.
=============================================================================*/

-- 8.1 Optional correction: insert missing clients from logs.
-- Review the mapping of logs.detail before running. In this prototype, id_ligne
-- is treated as CUSTOMER_ID and detail can be used as the inscription date if
-- that is how the logs were imported.
/*
START TRANSACTION;

INSERT INTO clients (CUSTOMER_ID, date_inscription)
SELECT
    l.id_ligne AS CUSTOMER_ID,
    l.detail AS date_inscription
FROM logs AS l
WHERE l.action = 'INSERT'
  AND l.table_insert = 'Client'
  AND NOT EXISTS (
      SELECT 1
      FROM clients AS c
      WHERE c.CUSTOMER_ID = l.id_ligne
  );

-- Validate after correction:
SELECT COUNT(*) AS remaining_missing_clients
FROM v_audit_missing_clients;

COMMIT;
*/


-- 8.2 Optional correction: synchronize employee hash_mdp from logs.
-- This should be reviewed carefully because automatic password/hash updates can
-- create security and governance risks.
/*
START TRANSACTION;

UPDATE employee AS e
JOIN logs AS l
    ON l.id_ligne = e.id_employe
SET e.hash_mdp = l.detail
WHERE l.action = 'UPDATE'
  AND l.table_insert = 'Employé'
  AND l.champs = 'hash_mdp'
  AND e.hash_mdp <> l.detail;

-- Validate after correction:
SELECT COUNT(*) AS remaining_employee_hash_mismatches
FROM v_audit_employee_hash_mismatch;

COMMIT;
*/


-- 8.3 Product price logs.
-- Recommendation: do not directly overwrite audit logs. Logs are evidence.
-- Invalid product price logs should be flagged, escalated to the OLTP/DBA team,
-- and corrected at the source or in a controlled reconciliation workflow.


/*=============================================================================
SECTION 9 — Prototype resilience measures: alerts, triggers, constraints
=============================================================================*/

-- 9.1 Table for audit alerts generated by triggers.
CREATE TABLE IF NOT EXISTS audit_alerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    issue_type VARCHAR(255) NOT NULL,
    entity_table VARCHAR(100),
    entity_id VARCHAR(255),
    log_action VARCHAR(50),
    log_field VARCHAR(100),
    details TEXT,
    severity VARCHAR(50) DEFAULT 'warning',
    detected_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


-- 9.2 Trigger: flag invalid product price values when a new log is inserted.
DROP TRIGGER IF EXISTS trg_logs_flag_invalid_product_price_after_insert;

DELIMITER //
CREATE TRIGGER trg_logs_flag_invalid_product_price_after_insert
AFTER INSERT ON logs
FOR EACH ROW
BEGIN
    IF NEW.table_insert = 'Produits'
       AND NEW.action = 'UPDATE'
       AND NEW.champs = 'prix'
       AND NOT REGEXP_LIKE(NEW.detail, '^[0-9]+(\\.[0-9]+)?$') THEN

        INSERT INTO audit_alerts (
            issue_type,
            entity_table,
            entity_id,
            log_action,
            log_field,
            details,
            severity
        )
        VALUES (
            'Invalid product price in logs',
            NEW.table_insert,
            NEW.id_ligne,
            NEW.action,
            NEW.champs,
            CONCAT('Non-numeric price value detected in logs: ', NEW.detail),
            'warning'
        );
    END IF;
END //
DELIMITER ;


-- 9.3 Trigger: flag client INSERT logs when the client is absent from clients.
DROP TRIGGER IF EXISTS trg_logs_flag_missing_client_after_insert;

DELIMITER //
CREATE TRIGGER trg_logs_flag_missing_client_after_insert
AFTER INSERT ON logs
FOR EACH ROW
BEGIN
    IF NEW.table_insert = 'Client'
       AND NEW.action = 'INSERT'
       AND NOT EXISTS (
           SELECT 1
           FROM clients AS c
           WHERE c.CUSTOMER_ID = NEW.id_ligne
       ) THEN

        INSERT INTO audit_alerts (
            issue_type,
            entity_table,
            entity_id,
            log_action,
            log_field,
            details,
            severity
        )
        VALUES (
            'Missing client in dimension table',
            NEW.table_insert,
            NEW.id_ligne,
            NEW.action,
            NEW.champs,
            'Client INSERT found in logs but missing from clients table.',
            'critical'
        );
    END IF;
END //
DELIMITER ;


-- 9.4 Trigger: flag employee hash_mdp mismatch when a new log is inserted.
DROP TRIGGER IF EXISTS trg_logs_flag_employee_hash_mismatch_after_insert;

DELIMITER //
CREATE TRIGGER trg_logs_flag_employee_hash_mismatch_after_insert
AFTER INSERT ON logs
FOR EACH ROW
BEGIN
    IF NEW.table_insert = 'Employé'
       AND NEW.action = 'UPDATE'
       AND NEW.champs = 'hash_mdp'
       AND EXISTS (
           SELECT 1
           FROM employee AS e
           WHERE e.id_employe = NEW.id_ligne
             AND e.hash_mdp <> NEW.detail
       ) THEN

        INSERT INTO audit_alerts (
            issue_type,
            entity_table,
            entity_id,
            log_action,
            log_field,
            details,
            severity
        )
        VALUES (
            'Employee hash_mdp mismatch',
            NEW.table_insert,
            NEW.id_ligne,
            NEW.action,
            NEW.champs,
            'hash_mdp value in logs does not match employee table value.',
            'warning'
        );
    END IF;
END //
DELIMITER ;


-- 9.5 Constraint proposal: product price must be positive and not null.
-- Note: run only after confirming all existing rows satisfy the condition.
/*
ALTER TABLE products
    MODIFY COLUMN prix FLOAT NOT NULL,
    ADD CONSTRAINT chk_products_positive_price CHECK (prix > 0);
*/


/*=============================================================================
SECTION 10 — Audit review queries after monitoring/corrections
=============================================================================*/

-- 10.1 Review all current audit issues.
SELECT *
FROM v_audit_all_log_issues
ORDER BY issue_type, log_date;


-- 10.2 Review alerts generated by triggers.
SELECT *
FROM audit_alerts
ORDER BY detected_at DESC;


-- 10.3 Summary of alert types.
SELECT
    issue_type,
    severity,
    COUNT(*) AS alert_count
FROM audit_alerts
GROUP BY issue_type, severity
ORDER BY alert_count DESC;
