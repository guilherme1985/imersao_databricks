CREATE OR REFRESH STREAMING LIVE TABLE lakehouse.bronze.sales_commodities
TBLPROPERTIES ("quality" = "bronze")
AS
SELECT *
FROM cloud_files(
  '/Volumes/lakehouse/raw_public/yfinance/commodities/latest_prices/',
  'json'
);