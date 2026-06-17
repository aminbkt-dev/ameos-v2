{{
    config(
        materialized='view',
        schema='silver',
        tags=['staging', 'shopify', 'order_items']
    )
}}

-- ============================================================
-- stg_shopify__order_items
-- ============================================================
-- Une row par line item de commande Shopify.
-- 
-- Source : lh_bronze.raw_shopify_order_items (Bronze)
--   - Une row par item, pre-extraite du JSON parent au moment
--     de l'ingestion Spark (pour contourner la limitation
--     VARCHAR(8000) du SQL Endpoint Lakehouse).
--   - raw_json contient le JSON complet du line item.
--
-- Cible : wh_ameos.dbt_abakhti_silver.stg_shopify__order_items
--
-- Note : le parsing utilise JSON_VALUE (pas OPENJSON) car
-- chaque item est déjà sur sa propre row. Plus simple, plus
-- performant.
-- ============================================================

WITH source AS (
    SELECT
        CAST(parent_id AS BIGINT)  AS order_id,
        raw_json,
        ingested_at
    FROM {{ source('shopify', 'raw_shopify_order_items') }}
),

parsed AS (
    SELECT
        -- ─── IDENTIFIANTS ─────────────────────────────────────
        order_id,                                                       -- FK vers stg_shopify__orders
        CAST(JSON_VALUE(raw_json, '$.id') AS BIGINT)             AS line_item_id,    -- PK native Shopify
        TRY_CAST(JSON_VALUE(raw_json, '$.product_id') AS BIGINT) AS product_id,
        TRY_CAST(JSON_VALUE(raw_json, '$.variant_id') AS BIGINT) AS variant_id,
        
        -- ─── DESCRIPTIF PRODUIT (snapshot au moment de la vente) ──
        JSON_VALUE(raw_json, '$.title')                          AS product_title,
        JSON_VALUE(raw_json, '$.variant_title')                  AS variant_title,
        JSON_VALUE(raw_json, '$.sku')                            AS sku,
        JSON_VALUE(raw_json, '$.vendor')                         AS vendor,
        JSON_VALUE(raw_json, '$.name')                           AS line_name,         -- ex: "Hoodie Drop3 - Black / M"
        
        -- ─── QUANTITÉ & PRIX ──────────────────────────────────
        CAST(JSON_VALUE(raw_json, '$.quantity') AS INT)                  AS quantity,
        CAST(JSON_VALUE(raw_json, '$.price') AS DECIMAL(10,2))           AS unit_price,
        CAST(JSON_VALUE(raw_json, '$.total_discount') AS DECIMAL(10,2))  AS line_discount,
        
        -- ─── MONTANTS CALCULÉS ────────────────────────────────
        CAST(JSON_VALUE(raw_json, '$.quantity') AS INT) 
            * CAST(JSON_VALUE(raw_json, '$.price') AS DECIMAL(10,2))     AS gross_line_amount,
        
        CAST(JSON_VALUE(raw_json, '$.quantity') AS INT) 
            * CAST(JSON_VALUE(raw_json, '$.price') AS DECIMAL(10,2))
            - CAST(JSON_VALUE(raw_json, '$.total_discount') AS DECIMAL(10,2)) AS net_line_amount,
        
        -- ─── FLAGS ────────────────────────────────────────────
        CAST(JSON_VALUE(raw_json, '$.requires_shipping') AS BIT)         AS requires_shipping,
        CAST(JSON_VALUE(raw_json, '$.taxable') AS BIT)                   AS is_taxable,
        CAST(JSON_VALUE(raw_json, '$.gift_card') AS BIT)                 AS is_gift_card,
        
        -- ─── DIVERS ───────────────────────────────────────────
        JSON_VALUE(raw_json, '$.fulfillment_service')            AS fulfillment_service,
        JSON_VALUE(raw_json, '$.fulfillment_status')             AS fulfillment_status,
        
        -- ─── MÉTADONNÉES D'INGESTION ──────────────────────────
        ingested_at
        
    FROM source
)

SELECT * FROM parsed