CREATE OR REPLACE MATERIALIZED VIEW lakehouse.silver.sales_enriched_mv
COMMENT 'Enriquecimento das transações com cotação mais próxima no tempo'
AS
WITH
-- 1) Transações
n AS (
  SELECT
    transaction_id,
    data_hora_h                         AS ts_ref_str,    -- string ISO
    data_hora_h                         AS data_hora_h,
    asset_raw,
    symbol_cotacao_norm,
    quantidade,
    tipo_operacao,
    UPPER(TRIM(moeda))                  AS moeda_norm,
    cliente_id,
    canal,
    mercado
  FROM lakehouse.silver.sales_normalized
),

-- 2) Cotações
p AS (
  SELECT
    id                                  AS cotacao_id,
    UPPER(TRIM(ativo))                  AS ativo_norm,
    UPPER(TRIM(moeda))                  AS moeda_norm,
    CAST(preco AS DECIMAL(18,6))        AS preco,
    horario_coleta                      AS cotacao_ts_str -- string ISO
  FROM lakehouse.silver.cotation_union
),

-- 3) Conversão para TIMESTAMP (sem try_to_timestamp)
n_ts AS (
  SELECT
    n.*,
    COALESCE(
      to_timestamp(ts_ref_str,      "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX"),
      to_timestamp(ts_ref_str,      "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"),
      to_timestamp(
        regexp_replace(substr(ts_ref_str,1,19),'T',' '),
        "yyyy-MM-dd HH:mm:ss"
      )
    ) AS ts_ref
  FROM n
),
p_ts AS (
  SELECT
    p.*,
    COALESCE(
      to_timestamp(cotacao_ts_str,  "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX"),
      to_timestamp(cotacao_ts_str,  "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"),
      to_timestamp(
        regexp_replace(substr(cotacao_ts_str,1,19),'T',' '),
        "yyyy-MM-dd HH:mm:ss"
      )
    ) AS cotacao_ts
  FROM p
),

-- 4) Candidatos por proximidade temporal (mesmo ativo e moeda)
cand AS (
  SELECT
    n_ts.*,
    p_ts.cotacao_id,
    p_ts.cotacao_ts,
    p_ts.preco,
    ROW_NUMBER() OVER (
      PARTITION BY n_ts.transaction_id
      ORDER BY ABS(unix_timestamp(n_ts.ts_ref) - unix_timestamp(p_ts.cotacao_ts)) ASC
    ) AS rn
  FROM n_ts
  LEFT JOIN p_ts
    ON p_ts.ativo_norm = UPPER(TRIM(n_ts.symbol_cotacao_norm))
   AND p_ts.moeda_norm = n_ts.moeda_norm
   AND p_ts.cotacao_ts BETWEEN n_ts.ts_ref - INTERVAL 12 HOURS AND n_ts.ts_ref + INTERVAL 12 HOURS
  WHERE n_ts.ts_ref IS NOT NULL
    AND p_ts.cotacao_ts IS NOT NULL
)

-- 5) Escolhe a cotação mais próxima e calcula métricas
SELECT
  transaction_id,
  data_hora_h,
  ts_ref                                AS transaction_ts,
  asset_raw,
  symbol_cotacao_norm,
  quantidade,
  tipo_operacao,
  moeda_norm                             AS moeda,
  cliente_id,
  canal,
  mercado,

  cotacao_id,
  cotacao_ts,
  preco                                  AS preco_unitario_usd,
  CASE
    WHEN UPPER(tipo_operacao) = 'VENDA'  THEN  preco
    WHEN UPPER(tipo_operacao) = 'COMPRA' THEN -preco
    ELSE NULL
  END                                    AS preco_unitario_signed_usd,

  CAST(quantidade * preco AS DECIMAL(38,6)) AS notional_abs_usd,
  CAST(quantidade * (
        CASE WHEN UPPER(tipo_operacao) = 'VENDA' THEN  preco
             WHEN UPPER(tipo_operacao) = 'COMPRA' THEN -preco
             ELSE NULL END
      ) AS DECIMAL(38,6)) AS notional_signed_usd
FROM cand
WHERE rn = 1;