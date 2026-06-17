{{
    config(
        materialized='view',
        schema='silver',
        tags=['staging', 'shopify', 'products']
    )
}}

-- ============================================================
-- stg_shopify__products
-- ============================================================
-- Source : lh_bronze.raw_shopify_products (JSON sans variants)
-- Cible  : wh_ameos.dbt_abakhti_silver.stg_shopify__products
--
-- 28 produits du catalogue Ame Sportswear. Chaque produit a
-- N variants (taille × couleur typiquement) — voir
-- stg_shopify__product_variants pour le détail variant.
-- ============================================================

WITH source AS (
    SELECT
        CAST(id AS BIGINT) AS product_id,
        raw_json,
        ingested_at
    FROM {{ source('shopify', 'raw_shopify_products') }}
),

parsed AS (
    SELECT
        -- ─── IDENTIFIANT ─────────────────────────────────────
        product_id,
        JSON_VALUE(raw_json, '$.handle')                                AS handle,           -- slug URL (ex: "hoodie-drop3-black")
        
        -- ─── DESCRIPTIF ──────────────────────────────────────
        JSON_VALUE(raw_json, '$.title')                                 AS title,
        JSON_VALUE(raw_json, '$.product_type')                          AS product_type,     -- ex: "Hoodie", "T-shirt"
        JSON_VALUE(raw_json, '$.vendor')                                AS vendor,           -- marque/fournisseur
        JSON_VALUE(raw_json, '$.tags')                                  AS tags,             -- string CSV multi-tags
        
        -- ─── STATUT ──────────────────────────────────────────
        JSON_VALUE(raw_json, '$.status')                                AS status,           -- "active", "draft", "archived"
        JSON_VALUE(raw_json, '$.published_scope')                       AS published_scope,
        
        -- ─── DATES ───────────────────────────────────────────
        TRY_CAST(JSON_VALUE(raw_json, '$.created_at') AS DATETIME2(6))  AS created_at,
        TRY_CAST(JSON_VALUE(raw_json, '$.updated_at') AS DATETIME2(6))  AS updated_at,
        TRY_CAST(JSON_VALUE(raw_json, '$.published_at') AS DATETIME2(6)) AS published_at,
        
        -- ─── MÉTADONNÉES ─────────────────────────────────────
        ingested_at
        
    FROM source
)

SELECT * FROM parsed