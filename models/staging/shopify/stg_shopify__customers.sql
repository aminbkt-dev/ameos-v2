{{
    config(
        materialized='view',
        schema='silver',
        tags=['staging', 'shopify', 'customers']
    )
}}

-- ============================================================
-- stg_shopify__customers
-- ============================================================
-- Source : lh_bronze.raw_shopify_customers
-- Cible  : wh_ameos.dbt_abakhti_silver.stg_shopify__customers
--
-- ~3000 clients dont une majorité de leads newsletter (sans
-- commande). Un flag is_buyer en sortie permet de les segmenter
-- en aval (Gold) pour les analyses acheteurs vs leads.
-- ============================================================

WITH source AS (
    SELECT
        CAST(id AS BIGINT) AS customer_id,
        raw_json,
        ingested_at
    FROM {{ source('shopify', 'raw_shopify_customers') }}
),

parsed AS (
    SELECT
        -- ─── IDENTIFIANT ─────────────────────────────────────
        customer_id,
        
        -- ─── IDENTITÉ ────────────────────────────────────────
        JSON_VALUE(raw_json, '$.email')                                 AS email,
        JSON_VALUE(raw_json, '$.first_name')                            AS first_name,
        JSON_VALUE(raw_json, '$.last_name')                             AS last_name,
        JSON_VALUE(raw_json, '$.phone')                                 AS phone,
        
        -- ─── COMPORTEMENT D'ACHAT ────────────────────────────
        CAST(JSON_VALUE(raw_json, '$.orders_count') AS INT)             AS orders_count,
        CAST(JSON_VALUE(raw_json, '$.total_spent') AS DECIMAL(12,2))    AS total_spent,
        TRY_CAST(JSON_VALUE(raw_json, '$.last_order_id') AS BIGINT)     AS last_order_id,
        TRY_CAST(JSON_VALUE(raw_json, '$.last_order_name') AS VARCHAR(50)) AS last_order_name,
        
        -- ─── SEGMENT (calculé) ───────────────────────────────
        CASE 
            WHEN CAST(JSON_VALUE(raw_json, '$.orders_count') AS INT) > 0 THEN 1 
            ELSE 0 
        END AS is_buyer,  -- 1 = a déjà acheté, 0 = lead newsletter sans achat
        
        -- ─── ÉTAT DU COMPTE ──────────────────────────────────
        CAST(JSON_VALUE(raw_json, '$.verified_email') AS BIT)           AS is_email_verified,
        CAST(JSON_VALUE(raw_json, '$.accepts_marketing') AS BIT)        AS accepts_marketing,
        JSON_VALUE(raw_json, '$.state')                                 AS account_state,    -- "enabled", "disabled", "invited"
        JSON_VALUE(raw_json, '$.tags')                                  AS tags,             -- string CSV
        
        -- ─── ADRESSE PAR DÉFAUT (extraction partielle) ──────
        JSON_VALUE(raw_json, '$.default_address.city')                  AS default_city,
        JSON_VALUE(raw_json, '$.default_address.province')              AS default_province,
        JSON_VALUE(raw_json, '$.default_address.country')               AS default_country,
        JSON_VALUE(raw_json, '$.default_address.country_code')          AS default_country_code,
        JSON_VALUE(raw_json, '$.default_address.zip')                   AS default_zip,
        
        -- ─── DATES ───────────────────────────────────────────
        TRY_CAST(JSON_VALUE(raw_json, '$.created_at') AS DATETIME2(6))  AS created_at,
        TRY_CAST(JSON_VALUE(raw_json, '$.updated_at') AS DATETIME2(6))  AS updated_at,
        
        -- ─── MÉTADONNÉES ─────────────────────────────────────
        ingested_at
        
    FROM source
)

SELECT * FROM parsed