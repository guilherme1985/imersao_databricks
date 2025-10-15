# Por que existem essas tabelas SILVER?

## 1) `silver_sales_normalized` (vendas normalizadas)

**Objetivo:** unificar e padronizar as transações de **BTC** (planilha) e **commodities** (SQL) numa estrutura única, já com:

* **símbolo normalizado** para casar com preços (`BTC-USD`, `GC=F`, `CL=F`, `SI=F`);
* **tempo truncado à hora** (`data_hora_h`) e derivados úteis (`data_dia`, `ano`, `mes`, `dia`, `hora`);
* limpeza mínima (trim, upper/case, etc.).

**Por que precisa?**
Transações vêm de fontes diferentes e com “nomes” diferentes de ativos. Se não normalizar, o `JOIN` com preços **quebra** (ex.: `BTC` vs `BTC-USD`). Também antecipamos o **grão por hora** para bater com a tabela de preços.

---

## 2) `silver_prices_hourly` (preço por hora)

```sql
DROP TABLE IF EXISTS silver_prices_hourly CASCADE;

-- DISTINCT ON pega a última cotação dentro da mesma hora
CREATE TABLE silver_prices_hourly AS
SELECT DISTINCT ON (ativo, moeda, date_trunc('hour', horario_coleta))
       ativo,
       moeda,
       date_trunc('hour', horario_coleta) AS hora,
       preco,
       horario_coleta AS cotacao_ts,
       id AS cotacao_id
FROM bronze_cotacoes
ORDER BY ativo, moeda, date_trunc('hour', horario_coleta), horario_coleta DESC;

-- Índice para acelerar o join por hora
CREATE INDEX IF NOT EXISTS idx_prices_hourly_key
  ON silver_prices_hourly (ativo, moeda, hora);
```

**Objetivo:** reduzir a série de preços (que pode ter **várias cotações por hora**) para **uma cotação por hora e por ativo** (a **última** da hora).

* `hora` = chave horária para fazer o `JOIN` com as vendas truncadas.
* `cotacao_ts` = timestamp real de coleta (dentro da hora) para rastreabilidade.

**Por que precisa?**
Se você tentar juntar transação (1/h) com preços em granularidade “minuto” ou “segundo”, o `JOIN` vira **N×1** ou **N×N**. Ao “resumir” para 1 por **(ativo, hora)**, o `JOIN` fica **determinístico** e rápido. Além disso, usar a **última cotação da hora** é consistente com práticas de mercado e reduz “ruído”.

---

## 3) `silver_sales_enriched` (transações + preço)

**Objetivo:** enriquecer cada transação com **preço unitário USD** e calcular métricas de negócio:

* `preco_unitario_usd` (da `silver_prices_hourly`);
* `notional_abs_usd` (tamanho financeiro absoluto);
* `notional_signed_usd` (VENDA + / COMPRA −, para fluxo líquido/P\&L operacional).

**Por que precisa?**
Essa é a base pronta para **KPI e relatórios (camada GOLD)** — você não quer calcular preço e métricas a cada dashboard. A enriched encapsula a regra de precificação (por hora ou *as-of backward* quando não há cotação exata na hora, evitando “usar preço futuro”).

---

# O que cada comando faz (e por que está aí)

* `DROP TABLE IF EXISTS ... CASCADE;`
  Remove a tabela se existir (e, com `CASCADE`, derruba objetos dependentes como views/índices que apontam para ela). Útil para **reprocessar** a SILVER do zero quando muda a regra.

* `CREATE TABLE ... AS SELECT ...` (**CTAS**)
  Cria e **materializa** uma nova tabela a partir de uma consulta. É a forma mais rápida de “congelar” o resultado transformado — ideal para camadas **SILVER**.

* `SELECT DISTINCT ON ( ... )` (PostgreSQL)
  Mantém **somente uma linha** por chave. Em conjunto com `ORDER BY ... horario_coleta DESC`, fica: **“para cada (ativo, moeda, hora), pegue a linha mais recente”**. Perfeito para escolher **1 preço por hora**.

* `date_trunc('hour', horario_coleta) AS hora`
  Trunca o timestamp para a **hora cheia** (ex.: 10:37 → 10:00). Isso define a **chave temporal** que vai casar com a hora das transações.

* `ORDER BY ativo, moeda, date_trunc('hour', horario_coleta), horario_coleta DESC`
  A ordem **é crucial com `DISTINCT ON`**: garante que, dentro de cada grupo (ativo, moeda, hora), a **primeira linha** é a de **maior `horario_coleta`** (ou seja, a **última cotação daquela hora**).

* `CREATE INDEX ... (ativo, moeda, hora)`
  Índice para acelerar filtros/junções por essas colunas. Como o `JOIN` com vendas usa exatamente `(ativo, 'USD', hora)`, esse índice **derruba o tempo de consulta**.

---

## Resumão “por que assim?”

* **Normalizamos** símbolos e **alinhamos grão temporal** na `silver_sales_normalized` para garantir que vendas e preços **falam a mesma língua**.
* **Compactamos** o histórico de preços para **1 por hora** na `silver_prices_hourly` (última da hora) para `JOIN` previsível e mais leve.
* **Enriquecemos** as vendas com preço e calculamos **métricas de negócio** na `silver_sales_enriched`, virando base única para **KPIs** (GOLD).

Se quiser, eu coloco esse texto já no formato README (com mini-diagramazinho ASCII do fluxo Bronze → Silver → Gold).