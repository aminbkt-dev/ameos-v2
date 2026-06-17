{{
    config(
        materialized='view',
        schema='silver',
        tags=['staging', 'shopify', 'orders']
    )
}}

-- ============================================================
-- stg_shopify__orders
-- ============================================================
-- Parse le payload JSON brut de chaque commande Shopify
-- pour exposer les champs business critiques en colonnes typées.
--
-- Source : lh_bronze.raw_shopify_orders (Bronze)
-- Cible : wh_ameos.dbt_abakhti_silver.stg_shopify__orders (Silver)
--
-- Les champs imbriqués (line_items, customer, shipping_address...)
-- sont traités dans des modèles séparés dédiés.
-- ============================================================

WITH source AS (
    SELECT
        id,
        raw_json,
        ingested_at,
        source,
        api_version
    FROM {{ source('shopify', 'raw_shopify_orders') }}
),

parsed AS (
    SELECT
        -- ─── IDENTIFIANTS ─────────────────────────────────────
        CAST(id AS BIGINT)                                        AS order_id,
        JSON_VALUE(raw_json, '$.name')                                  AS order_name,           -- ex: "AME1711"
        JSON_VALUE(raw_json, '$.order_number')                          AS order_number,         -- ex: "1711"
        
        -- ─── DATES ────────────────────────────────────────────
        CAST(JSON_VALUE(raw_json, '$.created_at') AS DATETIME2(6))      AS created_at,
        CAST(JSON_VALUE(raw_json, '$.updated_at') AS DATETIME2(6))      AS updated_at,
        CAST(JSON_VALUE(raw_json, '$.processed_at') AS DATETIME2(6))    AS processed_at,
        TRY_CAST(JSON_VALUE(raw_json, '$.cancelled_at') AS DATETIME2(6)) AS cancelled_at,
        TRY_CAST(JSON_VALUE(raw_json, '$.closed_at') AS DATETIME2(6))   AS closed_at,
        
        -- ─── MONTANTS ─────────────────────────────────────────
        CAST(JSON_VALUE(raw_json, '$.total_price') AS DECIMAL(10,2))            AS total_price,
        CAST(JSON_VALUE(raw_json, '$.subtotal_price') AS DECIMAL(10,2))         AS subtotal_price,
        CAST(JSON_VALUE(raw_json, '$.total_tax') AS DECIMAL(10,2))              AS total_tax,
        CAST(JSON_VALUE(raw_json, '$.total_discounts') AS DECIMAL(10,2))        AS total_discounts,
        CAST(JSON_VALUE(raw_json, '$.total_shipping_price_set.shop_money.amount') AS DECIMAL(10,2)) AS total_shipping,
        JSON_VALUE(raw_json, '$.currency')                                      AS currency,
        
        -- ─── STATUTS ──────────────────────────────────────────
        JSON_VALUE(raw_json, '$.financial_status')                      AS financial_status,
        JSON_VALUE(raw_json, '$.fulfillment_status')                    AS fulfillment_status,
        CAST(JSON_VALUE(raw_json, '$.cancel_reason') AS VARCHAR(100))   AS cancel_reason,
        CAST(JSON_VALUE(raw_json, '$.test') AS BIT)                     AS is_test_order,
        
        -- ─── CUSTOMER (champs scalaires uniquement) ──────────
        TRY_CAST(JSON_VALUE(raw_json, '$.customer.id') AS BIGINT)       AS customer_id,
        JSON_VALUE(raw_json, '$.customer.email')                        AS customer_email,
        JSON_VALUE(raw_json, '$.email')                                 AS order_email,  -- email saisi à la commande
        JSON_VALUE(raw_json, '$.customer.first_name')                   AS customer_first_name,
        JSON_VALUE(raw_json, '$.customer.last_name')                    AS customer_last_name,
        
        -- ─── DIVERS ───────────────────────────────────────────
        JSON_VALUE(raw_json, '$.source_name')                           AS source_name,    -- "web", "pos", "shopify_draft_order"...
        CAST(JSON_VALUE(raw_json, '$.confirmed') AS BIT)                AS is_confirmed,
        
        -- ─── MÉTADONNÉES D'INGESTION ──────────────────────────
        ingested_at,
        source       AS source_system,
        api_version  AS source_api_version
        
    FROM source
)

SELECT * FROM parsed