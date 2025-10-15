CREATE OR REFRESH STREAMING LIVE TABLE lakehouse.bronze.sales_btc 
TBLPROPERTIES ("quality" = "bronze")
AS
SELECT
  *,
  current_timestamp() AS ingestion_ts_utc
FROM STREAM(lakehouse.postgres_public.sales_btc);