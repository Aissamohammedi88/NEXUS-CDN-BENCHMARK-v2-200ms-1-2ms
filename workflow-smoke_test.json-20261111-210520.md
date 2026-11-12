# Workflow : smoke_test.json

**Description** : Validation rapide (~15s) : nœud en ligne, cache chaud, latence ≤ 2ms, résilience de base

**Verdict** : ✅ PASS — 9/9 étapes réussies

| # | Action | Libellé | OK | Garde |
|---|---|---|---|---|
| 1 | PROBE-001 | Santé du nœud | ✅ | ok_is=True |
| 2 | CACHE-001 | Warm-up jQuery | ✅ | passed_is=True |
| 3 | LAT-002 | Bench Edge 30 échantillons | ✅ | p99_ms_max=0.23; hit_ratio_min=100.0 |
| 4 | HDR-002 | X-Nexus-Cache = HIT | ✅ | passed_is=True |
| 5 | HTTP-001 | Statut 200 | ✅ | status_code_is=200 |
| 6 | HTTP-013 | HEAD cohérent avec GET | ✅ | passed_is=True |
| 7 | RESIL-001 | Stale-if-error (origine coupée) | ✅ | passed_is=True |
| 8 | LAT-046 | Garde contractuelle p99 ≤ 2ms | ✅ | passed_is=True |
| 9 | RPT-014 | Synthèse de session | ✅ | — |

Généré par NEXUS STUDIO v1.1 — 2026-11-11 21:05:20
