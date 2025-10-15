CREATE OR REFRESH STREAMING LIVE TABLE lakehouse.bronze.yfinance
TBLPROPERTIES ("quality" = "bronze")
AS
SELECT *
FROM cloud_files(
  '/Volumes/lakehouse/raw_public/yfinance/commodities/latest_prices/',
  'json'
);