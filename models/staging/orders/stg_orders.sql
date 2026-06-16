{{
    config(
        materialized='view',
        schema='silver',
        tags=['staging', 'orders', 'unified']
    )
}}

-- ============================================================
-- stg_orders
-- ============================================================
-- Unification des commandes Shopify et manuelles dans un schéma
-- commun. C'est le modèle qui alimente toutes les analyses de
-- ventes cross-source (fct_orders, dashboards revenue, etc.).
--
-- Sources :
--   - stg_shopify__orders (711 commandes Shopify Admin API)
--   - stg_manual__orders  (15 commandes manuelles V1 legacy)
--
-- Clé primaire unifiée : order_key = source + '_' + native_id
-- ============================================================

WITH shopify AS (
    SELECT
        -- ─── CLÉ PRIMAIRE UNIFIÉE ─────────────────────────────
        CONCAT('shopify_', CAST(order_id AS VARCHAR(50)))   AS order_key,
        CAST('shopify' AS VARCHAR(20))                      AS order_source,
        CAST(order_id AS VARCHAR(50))                       AS source_order_id,
        
        -- ─── CHAMPS BUSINESS UNIFIÉS ──────────────────────────
        order_name                                          AS order_display_name,
        created_at                                          AS ordered_at,
        total_price,
        currency,
        financial_status,
        customer_email,
        
        -- ─── CHAMPS SOURCE-SPÉCIFIQUES ────────────────────────
        CAST(NULL AS VARCHAR(36))                           AS source_drop_id,
        CAST(NULL AS VARCHAR(500))                          AS notes,
        
        -- ─── MÉTADONNÉES ──────────────────────────────────────
        ingested_at,
        source_system
        
    FROM {{ ref('stg_shopify__orders') }}
),

manual AS (
    SELECT
        -- ─── CLÉ PRIMAIRE UNIFIÉE ─────────────────────────────
        CONCAT('manual_', manual_order_id)                  AS order_key,
        CAST('manual' AS VARCHAR(20))                       AS order_source,
        manual_order_id                                     AS source_order_id,
        
        -- ─── CHAMPS BUSINESS UNIFIÉS ──────────────────────────
        CAST(NULL AS VARCHAR(50))                           AS order_display_name,  -- pas de nom natif côté manual
        ordered_at,
        total_price,
        currency,
        financial_status,
        CAST(NULL AS VARCHAR(255))                          AS customer_email,
        
        -- ─── CHAMPS SOURCE-SPÉCIFIQUES ────────────────────────
        source_drop_id,
        notes,
        
        -- ─── MÉTADONNÉES ──────────────────────────────────────
        ingested_at,
        source_system
        
    FROM {{ ref('stg_manual__orders') }}
),

unified AS (
    SELECT * FROM shopify
    UNION ALL
    SELECT * FROM manual
)

SELECT * FROM unified