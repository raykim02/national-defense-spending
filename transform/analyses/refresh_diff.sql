-- Ad hoc analysis (not used by any model or dashboard) that shows, by source and fiscal year, how the USASpending publish set in refresh_publish changed the data compared with the publish before it.
-- Rerun after each monthly load and record the results in docs/refresh_log.md.
-- Compares the live data as of the previous publish (files dated before refresh_publish) with the live data
-- as of refresh_publish (files dated on or before it), with the same dedupe and delete rules as staging.
-- Publish date comes from the 8-digit suffix every prestaged file name has (..._Delta_20261106.csv, ..._Full_20260906.csv).
-- new_ids / removed_ids show gross movement. USASpending sometimes deletes transactions and reissues them under
-- new IDs (Nov 2026: ~$298B for FY2017-FY2025), so look at net_b, not new_ids_b, for real growth.
-- Usage, from transform/:
--   dotenv -f ../.env run -- dbt compile --select refresh_diff --vars "{refresh_publish: '20261106'}"
-- then run target/compiled/nds/analyses/refresh_diff.sql in Redshift.

{% set publish = var('refresh_publish', '20261106') %}

with raw as (

    select
        contract_transaction_unique_key as k,
        source,
        action_date_fiscal_year::integer as fy,
        federal_action_obligation::numeric(23, 2) as amt,
        last_modified_date::timestamp as lm,
        correction_delete_ind as d,
        source_file,
        left(regexp_substr(source_file, '[0-9]{8}[.]csv$'), 8) as file_publish
    from {{ source('raw_nds', 'contract_transactions') }}

),

-- latest version of each transaction, Delta row wins ties (same order as stg_contract_transactions)
before_ranked as (

    select
        *,
        row_number() over (
            partition by k
            order by lm desc, case when source_file like '%/delta/%' then 0 else 1 end
        ) as rn
    from raw
    where file_publish < '{{ publish }}'

),

after_ranked as (

    select
        *,
        row_number() over (
            partition by k
            order by lm desc, case when source_file like '%/delta/%' then 0 else 1 end
        ) as rn
    from raw
    where file_publish <= '{{ publish }}'

),

before_live as (

    select k, source, fy, amt from before_ranked
    where rn = 1 and (d is null or d <> 'D')

),

after_live as (

    select k, source, fy, amt from after_ranked
    where rn = 1 and (d is null or d <> 'D')

),

sides as (

    select
        a.source,
        a.fy,
        0 as before_n,
        1 as after_n,
        0 as before_amt,
        a.amt as after_amt,
        case when b.k is null then 1 else 0 end as new_id,
        case when b.k is null then a.amt else 0 end as new_id_amt,
        0 as removed_id,
        0 as removed_id_amt
    from after_live as a
    left join before_live as b on a.k = b.k

    union all

    select
        b.source,
        b.fy,
        1,
        0,
        b.amt,
        0,
        0,
        0,
        case when a.k is null then 1 else 0 end,
        case when a.k is null then b.amt else 0 end
    from before_live as b
    left join after_live as a on a.k = b.k

)

select
    source,
    fy,
    sum(before_n) as before_n,
    sum(after_n) as after_n,
    sum(after_n) - sum(before_n) as net_n,
    round(sum(before_amt) / 1e9, 2) as before_b,
    round(sum(after_amt) / 1e9, 2) as after_b,
    round((sum(after_amt) - sum(before_amt)) / 1e9, 2) as net_b,
    round(100.0 * (sum(after_amt) - sum(before_amt)) / nullif(sum(before_amt), 0), 2) as net_pct,
    sum(new_id) as new_ids,
    round(sum(new_id_amt) / 1e9, 2) as new_ids_b,
    sum(removed_id) as removed_ids,
    round(sum(removed_id_amt) / 1e9, 2) as removed_ids_b
from sides
group by 1, 2
order by 1, 2
