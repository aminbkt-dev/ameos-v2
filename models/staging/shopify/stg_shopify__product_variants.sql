{{
    config(
        materialized='view',
        schema='silver',
        tags=['staging', 'shopify', 'variants']
    )
}}

-- ============================================================
-- stg_shopify__product_variants
-- ============================================================
-- Source : lh_bronze.raw_shopify_product_variants
--   - Une row par variant, pre-extraite du JSON parent au
--     moment de l'ingestion Spark.
--   - raw_json contient le JSON complet du variant.
--
-- Cible : wh_ameos.dbt_abakhti_silver.stg_shopify__product_variants
--
-- 226 variants au total pour 28 produits. Chaque variant
-- correspond typiquement à une combinaison taille × couleur.
-- ============================================================

WITH source AS (
    SELECT
        CAST(parent_id AS BIGINT) AS product_id,
        raw_json,
        ingested_at
    FROM {{ source('shopify', 'raw_shopify_product_variants') }}
),

parsed AS (
    SELECT
        -- ─── IDENTIFIANTS ─────────────────────────────────────
        product_id,                                                                 -- FK vers stg_shopify__products
        CAST(JSON_VALUE(raw_json, '$.id') AS BIGINT)             AS variant_id,    -- PK native Shopify
        JSON_VALUE(raw_json, '$.sku')                            AS sku,
        JSON_VALUE(raw_json, '$.barcode')                        AS barcode,
        
        -- ─── DESCRIPTIF ──────────────────────────────────────
        JSON_VALUE(raw_json, '$.title')                          AS variant_title,  -- ex: "Black / M"
        JSON_VALUE(raw_json, '$.option1')                        AS option1,        -- ex: "Black" (couleur)
        JSON_VALUE(raw_json, '$.option2')                        AS option2,        -- ex: "M" (taille)
        JSON_VALUE(raw_json, '$.option3')                        AS option3,        -- 3e dimension (rare)
        
        -- ─── PRIX ────────────────────────────────────────────
        CAST(JSON_VALUE(raw_json, '$.price') AS DECIMAL(10,2))           AS price,
        TRY_CAST(JSON_VALUE(raw_json, '$.compare_at_price') AS DECIMAL(10,2)) AS compare_at_price,  -- prix "barré" pour les promos
        
        -- ─── INVENTAIRE ──────────────────────────────────────
        CAST(JSON_VALUE(raw_json, '$.inventory_quantity') AS INT)        AS inventory_quantity,
        JSON_VALUE(raw_json, '$.inventory_management')                   AS inventory_management,  -- "shopify" ou null
        JSON_VALUE(raw_json, '$.inventory_policy')                       AS inventory_policy,       -- "deny" ou "continue"
        TRY_CAST(JSON_VALUE(raw_json, '$.inventory_item_id') AS BIGINT)  AS inventory_item_id,
        
        -- ─── LOGISTIQUE ──────────────────────────────────────
        CAST(JSON_VALUE(raw_json, '$.weight') AS DECIMAL(8,3))           AS weight,
        JSON_VALUE(raw_json, '$.weight_unit')                            AS weight_unit,
        CAST(JSON_VALUE(raw_json, '$.requires_shipping') AS BIT)         AS requires_shipping,
        CAST(JSON_VALUE(raw_json, '$.taxable') AS BIT)                   AS is_taxable,
        
        -- ─── ÉTAT ────────────────────────────────────────────
        JSON_VALUE(raw_json, '$.fulfillment_service')                    AS fulfillment_service,
        
        -- ─── DATES ───────────────────────────────────────────
        TRY_CAST(JSON_VALUE(raw_json, '$.created_at') AS DATETIME2(6))   AS created_at,
        TRY_CAST(JSON_VALUE(raw_json, '$.updated_at') AS DATETIME2(6))   AS updated_at,
        
        -- ─── MÉTADONNÉES ─────────────────────────────────────
        ingested_at
        
    FROM source
)

SELECT * FROM parsed