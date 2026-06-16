{{
    config(
        materialized='view',
        schema='silver',
        tags=['staging', 'manual', 'orders']
    )
}}

-- ============================================================
-- stg_manual__orders
-- ============================================================
-- Commandes saisies manuellement (drops physiques, ventes
-- directes, événements) importées depuis CSV V1 Supabase.
--
-- Source : lh_bronze.raw_manual_orders (Bronze)
-- Cible : wh_ameos.dbt_abakhti_silver.stg_manual__orders (Silver)
--
-- Normalisations appliquées :
--   - financial_status passé en lowercase (alignement avec Shopify)
--   - Cast des types numériques et timestamps
-- ============================================================

WITH source AS (
    SELECT
        manual_order_id,
        ordered_at,
        drop_id,
        notes,
        created_at,
        financial_status,
        total_gross,
        currency,
        updated_at,
        ingested_at,
        source,
        source_file
    FROM {{ source('manual', 'raw_manual_orders') }}
),

cleaned AS (
    SELECT
        -- ─── IDENTIFIANTS ─────────────────────────────────────
        CAST(manual_order_id AS VARCHAR(36))            AS manual_order_id,
        CAST(drop_id AS VARCHAR(36))                    AS source_drop_id,  -- UUID V1 legacy
        
        -- ─── DATES ────────────────────────────────────────────
        CAST(ordered_at AS DATETIME2(6))                AS ordered_at,
        CAST(created_at AS DATETIME2(6))                AS created_at,
        CAST(updated_at AS DATETIME2(6))                AS updated_at,
        
        -- ─── MONTANTS ─────────────────────────────────────────
        CAST(total_gross AS DECIMAL(10,2))              AS total_price,
        CAST(currency AS VARCHAR(3))                    AS currency,
        
        -- ─── STATUTS (normalisés) ─────────────────────────────
        LOWER(CAST(financial_status AS VARCHAR(50)))    AS financial_status,
        
        -- ─── CONTENU LIBRE ────────────────────────────────────
        CAST(notes AS VARCHAR(500))                     AS notes,
        
        -- ─── MÉTADONNÉES D'INGESTION ──────────────────────────
        ingested_at,
        source                                          AS source_system,
        source_file
        
    FROM source
)

SELECT * FROM cleaned