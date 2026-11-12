# NEXUS EDGE PLATFORM

**Nœuds Edge micro-latence — objectif 1-2ms, de la performance mesurée, pas de la simulation.**

NEXUS est un logiciel serveur réel : il se déploie sur n'importe quelle machine proche des
utilisateurs (datacenter FAI, VPS régional, micro-node) et sert les contenus en 1-2ms.
Ce qui est mesuré ici est le même code que celui qui tournerait en production — seule la
distance réseau change.

---

## 1. Les composants

| Composant | Rôle | Équivalent |
|---|---|---|
| `nexusd.py` | Nœud Edge : serveur HTTP/1.1 asyncio, cache RAM chaud, warm-up, stale-if-error, métriques intégrées | le produit (le cœur) |
| `nexus-smi.py` | Moniteur de nœuds : statut, latence p50/p95/p99, cache, origine, sonde réseau | `nvidia-smi` — sans NVIDIA |
| `nexus-ctl.py` | Plan de contrôle : start/stop, registre des nœuds, warm, bench | orchestrateur v1 |
| `nexus-bench.py` | Preuve de latence : Nexus Edge vs Origine CDN, connexions persistantes des deux côtés | chiffres pour le pitch |

Aucune dépendance externe : Python 3.8+ uniquement (stdlib). Le port Go/Rust est prévu
en v2 pour la densité (voir feuille de route).

---

## 2. Démarrage rapide

```bash
# Tout en un (démo complète) :
bash run_demo.sh

# Ou étape par étape :
python3 nexus-ctl.py start                          # démarre nexusd + l'enregistre
python3 nexus-ctl.py warm /npm/jquery@3.7.1/dist/jquery.min.js
python3 nexus-ctl.py bench --samples 30             # preuve : Edge vs Origine
python3 nexus-smi.py                                # moniteur (instantané)
python3 nexus-smi.py --watch 2                      # moniteur continu
python3 nexus-ctl.py stop                           # arrêt propre
```

Test manuel d'une requête :

```bash
curl -s -o /dev/null -D - http://127.0.0.1:8765/npm/jquery@3.7.1/dist/jquery.min.js
# X-Nexus-Cache: HIT
# X-Nexus-Latency: 0.05ms      ← temps de traitement serveur
```

Endpoints de supervision intégrés : `/nexus/health`, `/nexus/metrics`
(+/nexus/shutdown, réservé à localhost).

---

## 3. Architecture

```
                         ┌──────────────────────────────┐
                         │        ORIGINE / CDN         │
                         │   (ex. cdn.partenaire.com)   │
                         └──────────────┬───────────────┘
                                        │ remplissage (MISS, TTL)
                         ┌──────────────┴───────────────┐
        NEXUS-CTL        │      NŒUD EDGE nexusd        │       NEXUS-SMI
   (start/stop/warm) ───►│  cache RAM chaud (≤2ms)      │◄─── (latence p50/p99,
   (registre nœuds)      │  keep-alive, stale-if-error  │       cache, hit %)
                         └──────────────┬───────────────┘
                                        │ fibre < 50 km (~0.2ms)
                         ┌──────────────┴───────────────┐
                         │      UTILISATEURS FINAUX     │
                         └──────────────────────────────┘
```

Un registre (`registry/nodes.json`) liste les nœuds ; `nexus-ctl list` sonde leur santé ;
`nexus-smi --list` donne la vue de flotte. En v2, le registre devient un plan de contrôle
distribué (voir §6).

---

## 4. Comment on atteint 1-2ms

La latence totale = **réseau + traitement**. Les deux sont attaqués séparément.

**Réseau** — physique, non compressible : lumière dans la fibre ≈ 0.2ms par 50km.
C'est pour cela que le nœud doit être **proche de l'utilisateur** (micro-node chez le FAI,
VPS régional). Un CDN distant ne pourra jamais descendre sous la distance ; NEXUS la supprime.

**Traitement** — c'est le travail de `nexusd`, et il est déjà sous la milliseconde :

1. **Keep-alive systématique** : la connexion TCP (et TLS en production) reste ouverte —
   zéro handshake par requête. C'est là que les 80-120ms vers les CDN publics s'évaporent.
2. **Cache 100% RAM** : un HIT ne touche ni disque ni réseau — une recherche en mémoire
   et une écriture socket, quelques dizaines de microsecondes.
3. **Warm-up (Priorisation)** : les assets critiques sont préchargés au boot — le premier
   utilisateur du jour n'est plus le mal-aimé.
4. **Headers corrects (Correction)** : `Cache-Control`, `ETag`, `X-Nexus-Cache`,
   `X-Nexus-Latency` — les clients et l'équipe savent toujours ce qui a été servi.
5. **Stale-if-error (Validation)** : si l'origine tombe, le nœud sert le cache périmé
   au lieu d'un 5xx — la qualité de service ne dépend plus d'un serveur distant.

Sur loopback, le chemin complet mesuré est ~0.3-1ms. En production, ajouter le RTT fibre :
**un nœud à <50km de l'utilisateur = 1-2ms garantis, au sol.**

---

## 5. Ce que le benchmark prouve (et ne prouve pas)

`nexus-bench.py` compare, à connexion persistante égale :

- **Nexus Edge** (nœud local, cache chaud) → attendu : p99 < 2ms
- **Origine CDN** (ex. jsDelivr) → typiquement 100-200ms depuis un réseau grand public

Ce que ça prouve : le temps de traitement NEXUS est sous la milliseconde et la valeur
différenciante est le **dernier hop**. Ce que ça ne prouve pas : la physique du déploiement
final — pour le pitch, annoncer « 1-2ms à <50km, mesuré en traitement, déployable dès
l'implantation du premier micro-node ».

---

## 6. Feuille de route

| Version | Contenu | Objectif |
|---|---|---|
| **v1.0** (ce dépôt) | nœud edge mono-machine, registre fichier, nexus-smi, bench | preuve de concept chiffrée |
| **v1.5** | multi-nœuds avec réplication du cache (gossip), TLS natif, warm-up prédictif | flotte régionale |
| **v2.0** | port Go/Rust du nœud (densité 10x), plan de contrôle distribué, API partenaire | production opérateur |
| **v3.0** | micro-nodes chez les FAI, routage anycast, SLA 1-2ms contractuel | « classe Google/Oracle/Nvidia » |

La logique fondatrice reste la même à chaque échelon : **Priorisation → Correction →
Validation**.

---

## 7. Déploiement réel d'un nœud

Sur un serveur (VPS régional, machine FAI) avec systemd :

```ini
# /etc/systemd/system/nexusd.service
[Unit]
Description=NEXUS Edge Node
After=network-online.target

[Service]
WorkingDirectory=/opt/nexus-edge
ExecStart=/usr/bin/python3 /opt/nexus-edge/nexusd.py --config /opt/nexus-edge/config/nexus.json
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now nexusd
python3 nexus-ctl.py list      # depuis le poste de contrôle
python3 nexus-smi.py --list    # vue de flotte
```

Adapter `config/nexus.json` : nom du nœud, région, port, origine du partenaire, liste de
warm-up. Un nœud = 4 lignes de configuration.
