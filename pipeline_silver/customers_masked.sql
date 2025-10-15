CREATE OR REFRESH STREAMING LIVE TABLE silver.customers_masked
TBLPROPERTIES ("quality" = "silver")
AS
SELECT
    customer_id,
    -- Hash do nome (normaliza antes do hash)
    sha2(upper(trim(customer_name)), 256) AS customer_hash,

    -- Demais colunas não sensíveis
    documento,
    segmento,
    pais,
    estado,
    cidade,
    created_at,
    ingestion_ts_utc
FROM STREAM(lakehouse.bronze.customers);  -- sua tabela de origem com PII no pipeline