CREATE OR REFRESH STREAMING LIVE TABLE silver.cotation_union
TBLPROPERTIES ("quality" = "silver")
AS

-- Fonte: BITCOIN
SELECT
    b.id,
    b.ativo,
    CAST(b.preco AS DECIMAL(18,2))      AS preco,
    b.moeda,
    b.horario_coleta
FROM stream(lakehouse.bronze.bitcoin) b

UNION ALL

-- Fonte: YFINANCE
SELECT
    y.id,
    y.ativo,
    CAST(y.preco AS DECIMAL(18,2))      AS preco,
    y.moeda,
    y.horario_coleta
FROM stream(lakehouse.bronze.yfinance) y;