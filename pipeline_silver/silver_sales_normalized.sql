CREATE OR REFRESH STREAMING LIVE TABLE lakehouse.silver.sales_normalized
TBLPROPERTIES ("quality" = "silver")
AS
SELECT
    b.transaction_id,
    -- hora truncada (para joins e partições)
    date_trunc('hour', b.data_hora)           AS data_hora_h,
    -- componentes úteis de data
    date(b.data_hora)                         AS data_dia,
    year(b.data_hora)                         AS ano,
    month(b.data_hora)                        AS mes,
    day(b.data_hora)                          AS dia,
    hour(b.data_hora)                         AS hora,

    trim(b.ativo) AS asset_raw,
    CASE
        WHEN upper(trim(b.ativo)) = 'BTC'     THEN 'BTC-USD'
        WHEN upper(trim(b.ativo)) = 'GOLD'    THEN 'GC=F'
        WHEN upper(trim(b.ativo)) = 'OIL'     THEN 'CL=F'
        WHEN upper(trim(b.ativo)) = 'SILVER'  THEN 'SI=F'
        ELSE trim(b.ativo)
    END AS symbol_cotacao_norm,

    b.quantidade,
    b.tipo_operacao,
    b.moeda,
    b.cliente_id,
    b.canal,
    b.mercado,
    'BTC' AS fonte_dados
FROM STREAM(lakehouse.bronze.sales_btc) b

UNION ALL

SELECT
    c.transaction_id,
    date_trunc('hour', c.data_hora)           AS data_hora_h,
    date(c.data_hora)                         AS data_dia,
    year(c.data_hora)                         AS ano,
    month(c.data_hora)                        AS mes,
    day(c.data_hora)                          AS dia,
    hour(c.data_hora)                         AS hora,

    trim(c.commodity_code) AS asset_raw,
    CASE
        WHEN upper(trim(c.commodity_code)) = 'BTC'     THEN 'BTC-USD'
        WHEN upper(trim(c.commodity_code)) = 'GOLD'    THEN 'GC=F'
        WHEN upper(trim(c.commodity_code)) = 'OIL'     THEN 'CL=F'
        WHEN upper(trim(c.commodity_code)) = 'SILVER'  THEN 'SI=F'
        ELSE trim(c.commodity_code)
    END AS symbol_cotacao_norm,

    c.quantidade,
    c.tipo_operacao,
    c.moeda,
    c.cliente_id,
    c.canal,
    c.mercado,
    'COMMODITIES' AS fonte_dados
FROM STREAM(lakehouse.bronze.sales_commodities) c