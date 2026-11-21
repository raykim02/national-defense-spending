# Refresh log

What each monthly pipeline run changed after the October 2026 publish. The README, [findings.md](findings.md), and the Power BI dashboard stay a consistent snapshot of the October 2026 publish until the dashboard is refreshed. Redshift has the newer data, so rerunning a findings query today gives slightly different numbers than the doc.

Each entry's net change by source and fiscal year comes from [`transform/analyses/refresh_diff.sql`](../transform/analyses/refresh_diff.sql), run with that publish's date.

---

## November 2026 publish

USASpending publish of Nov 6, 2026, loaded by the `nds_monthly` run on Nov 15, 2026. Analyzed Nov 18, 2026.

### Run

- One Delta file per source, 2,072,779 rows: DoD 2,066,690, DOE 5,588, DOT 478, DHS 23.
- `dbt build` passed: 20 models built and 96 tests passed.
- Live transactions went from 41,824,602 to 42,072,829 (+248,227). Total obligations went from $4,318.6B to $4,357.1B (+$38.5B).

### What was really new

Most of the DoD file was not new spending:

| DoD transaction IDs in the file | Count     |
|---------------------------------|-----------|
| Re-sent unchanged               | 1,382,648 |
| Updated with a newer version    | 118,978   |
| IDs never seen before           | 349,780   |
| Deletes of live transactions    | 101,837   |
| Deletes of IDs never loaded     | 10,595    |

- **Re-keying.** USASpending deleted about 102,000 existing DoD transactions ($338B) and reissued most of them under new IDs, usually with only the transaction number changed (for example `..._P00009_-NONE-_16` became `..._P00009_-NONE-_0`).
  - FY2017–FY2025: about 87,000 transactions and $298.3B deleted, the same $298.3B back under new IDs. Yearly totals are unchanged.
  - FY2026: $39.6B deleted, $73.0B under new IDs, a net gain of $33.5B.
  - A count of new IDs alone ($371B for DoD) overstates real growth more than tenfold.
- **Deletes applied.** 112,433 of 112,434 deleted IDs are gone from staging. The one left has a newer live version and carries $0.
- **No double counting.** Only one new ID matched an existing live transaction on award, modification, date, and amount, worth about $0.

### Net change

| Source / fiscal year | Net transactions | Net change                            |
|----------------------|------------------|---------------------------------------|
| DoD FY2026           | +247,658         | +$33.53B (+8.95%, $374.6B to $408.1B) |
| DOE FY2027           | +194             | +$4.60B                               |
| DoD FY2025           | +164             | +$0.35B                               |
| Everything else      | +211             | about $0                              |

### DoD FY2026 detail

- **July 2026 is most of it:** +$30.6B and 242,904 transactions. Then June +$1.1B, August +$0.9B, May +$0.6B.
- **Data cutoff is now about July 23, 2026.** Daily volume drops from about 20,000 transactions to about 600 after that date. Late July should fill in with the next publish.
- **Year over year, October through June:** dollars up 18.9% ($313.8B to $373.0B) on 3.8% fewer transactions.
- **By service:** Navy $15.1B (45%), Defense-Wide $7.5B (22%), Army $6.4B (19%), Air Force $4.6B (14%).
- **By product type:** supplies and equipment $20.9B (62%), services $7.9B (23%), R&D $2.8B (8%), construction $1.9B (6%).
- **By action type:** new orders under existing IDVs $10.4B (31%), other modifications $9.5B (28%), new contracts or IDVs $6.5B (19%), funding-only actions $4.6B (14%), option exercises $2.6B (8%).
- **By contractor:** Lockheed Martin $4.7B, RTX $4.5B, General Dynamics $2.5B, TOTE Services $2.2B, Northrop Grumman $1.6B. Together 48% of the increase.
- **Largest new transactions,** each found only in this publish (not re-keyed):
  - TOTE Services, $2.21B, new Navy contract (`N0002426C2421`), Jul 13
  - Raytheon, $1.81B (`N0002422C5500` P00040), Jul 15
  - Lockheed Martin, $1.60B (`N0001926F2171`), Jul 15
  - Lockheed Martin, $1.35B (`HQ014717C0032` P00128), Jul 20
  - RTX, $1.08B (`N0001926F2227`), Jul 30
- **Defense Logistics Agency** had about 238,000 of July's roughly 284,000 DoD transactions, but only $4.3B.
- **Top contractor groups so far in FY2026:** Lockheed Martin $53.3B, RTX $33.7B, Boeing $27.0B, General Dynamics $24.7B, Northrop Grumman $13.4B.

### DOE FY2027

$4.6B in October 2026, in line with past Octobers ($1.1B to $5.1B). Largest: $0.87B to Triad National Security on Oct 28.

### Effects on published findings

To fold into [findings.md](findings.md) and the README at the next dashboard refresh:

- Data through the November 2026 publish, about 42.1 million transactions.
- FY2027 is no longer "6 rows, $0": it is now 299 rows and about $4.6B.
- Recipient totals before FY2026 shifted where transactions were reissued under a different parent: $1.40B from Airbus U.S. Space & Defense to Airbus SE, and $0.32B from Day & Zimmermann to American Ordnance.
- FY2026 figures are still partial (DoD through about July 23, 2026).

### Open follow-ups

- [ ] Decide whether `seeds/recipient_group_overrides.csv` should merge the Raytheon/Lockheed Martin Javelin joint venture's two parent records (`WGB7GAKM7A68` for FY2024–FY2025, `GT2VX4J9UTR5` for FY2026, +$0.43B this run) or keep them separate.
- [ ] Check whether TOTE Services (+$2.2B, not in the seed) needs a group override if it reaches a yearly top 25.
- [ ] Refresh the Power BI dashboard, then update the README and findings and mark this entry as folded in.
