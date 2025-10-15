CREATE OR REFRESH STREAMING LIVE TABLE bitcoin
TBLPROPERTIES("quality" = "bronze")
AS
-- Lê os arquivos JSON da pasta RAW usando cloud_files (Auto Loader)
SELECT * 
FROM cloud_files(
  '/Volumes/lakehouse/raw_public/coinbase/coinbase/bitcoin_spot/', -- caminho origem
  'json', -- formato do arquivo
  map(
    -- Ingestão incremental:
    -- Se "false", o DLT vai processar apenas os novos arquivos
    -- que chegarem após o pipeline começar.
    'cloudFiles.includeExistingFiles', 'false',

    -- Detecta automaticamente o tipo das colunas (útil em JSON)
    'cloudFiles.inferColumnTypes', 'true',

    -- Permite adicionar novas colunas automaticamente (tem também o rescue)
    -- se o schema do JSON mudar no futuro
    'cloudFiles.schemaEvolutionMode', 'addNewColumns'
  )
);