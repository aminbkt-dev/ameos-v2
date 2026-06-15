-- ============================================================
-- AmeOS v2 — Test setup model
-- Premier model du projet pour valider la pipeline end-to-end :
-- dbt Cloud → Fabric Warehouse (wh_ameos.<dev>_gold.test_setup)
-- ============================================================

SELECT 
    1 AS test_id,
    'AmeOS v2 setup OK' AS test_message,
    CAST(SYSDATETIME() AS datetime2(6)) AS created_at