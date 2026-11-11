#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
════════════════════════════════════════════════════════════════════════════
 NEXUS-SMI v1.0 — Moniteur système NEXUS (équivalent nvidia-smi, sans NVIDIA)

 nexus-smi surveille les nœuds Edge NEXUS : statut, latence p50/p95/p99,
 cache edge, santé de l'origine. Il n'a besoin d'aucun GPU : le nœud
 NEXUS tourne en mode CPU-only par conception.

 Usage :
   python3 nexus-smi.py                     # instantané du nœud par défaut
   python3 nexus-smi.py --node URL          # cible un nœud précis
   python3 nexus-smi.py --watch 2           # rafraîchit toutes les 2 secondes
   python3 nexus-smi.py --list              # tous les nœuds du registre
   python3 nexus-smi.py --json              # sortie machine
════════════════════════════════════════════════════════════════════════════
"""

import argparse
import http.client
import json
import os
import socket
import sys
import time
import urllib.parse
import urllib.request
from datetime import timedelta

VERSION = "nexus-smi/1.0.0"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
REGISTRY = os.path.join(BASE_DIR, "registry", "nodes.json")
TARGET_MS = 2.0

GREEN = "\033[0;32m"; RED = "\033[0;31m"; YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"; BOLD = "\033[1m"; DIM = "\033[2m"; NC = "\033[0m"
W = 74


def load_registry():
    if not os.path.exists(REGISTRY):
        return []
    try:
        with open(REGISTRY, "r", encoding="utf-8") as f:
            return json.load(f).get("nodes", [])
    except (OSError, ValueError):
        return []


def default_node_url():
    nodes = load_registry()
    if nodes:
        return nodes[0]["url"]
    return "http://127.0.0.1:8765"


def fetch_json(url, timeout=1.5):
    with urllib.request.urlopen(url, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def probe_rtt(url, n=5):
    """Mesure le RTT réseau réel nexus-smi → nœud (connexions persistantes)."""
    u = urllib.parse.urlparse(url)
    port = u.port or (443 if u.scheme == "https" else 80)
    try:
        if u.scheme == "https":
            conn = http.client.HTTPSConnection(u.hostname, port, timeout=1.5)
        else:
            conn = http.client.HTTPConnection(u.hostname, port, timeout=1.5)
    except (OSError, socket.gaierror):
        return []
    rtts = []
    for _ in range(n):
        try:
            t0 = time.perf_counter()
            conn.request("GET", "/nexus/health")
            conn.getresponse().read()
            rtts.append((time.perf_counter() - t0) * 1000.0)
        except (OSError, http.client.HTTPException):
            break
    try:
        conn.close()
    except OSError:
        pass
    return rtts


def fmt_pctl(rtts, p):
    if not rtts:
        return "—"
    data = sorted(rtts)
    k = max(0, min(len(data) - 1, int(round(p / 100.0 * (len(data) - 1)))))
    return "%.2fms" % data[k]


def verdict_p99(p99):
    if p99 is None:
        return ""
    if p99 <= TARGET_MS:
        return "  %s✅ OBJECTIF ATTEINT (p99 ≤ %.0fms)%s" % (GREEN, TARGET_MS, NC)
    if p99 <= TARGET_MS * 5:
        return "  %s⚠ PROCHE DE L'OBJECTIF%s" % (YELLOW, NC)
    return "  %s❌ HORS OBJECTIF%s" % (RED, NC)


def render(m, rtt, node_url):
    up = timedelta(seconds=int(m.get("uptime_s", 0)))
    lat = m.get("latency_ms", {})
    p99 = lat.get("p99")
    cache_pct = m.get("hit_ratio_pct", 0.0)
    cache_bar_n = int(round(cache_pct / 100.0 * 30))
    bar = "█" * cache_bar_n + "░" * (30 - cache_bar_n)
    cache_color = GREEN if cache_pct >= 80 else (YELLOW if cache_pct >= 50 else RED)

    o = []
    o.append("═" * W)
    o.append("  %sNEXUS-SMI%s  %s%s%s" % (CYAN, NC, DIM, VERSION, NC))
    o.append("═" * W)
    o.append("  %-14s %s%s%s" % ("Nœud", BOLD, m.get("node", "?"), NC))
    o.append("  %-14s %s✅ EN LIGNE%s     %-9s %s" %
             ("Statut", GREEN, NC, "Uptime", str(up)))
    o.append("  %-14s %s   %-9s %s" %
             ("Région", m.get("region", "—"), "Version", m.get("version", "—")))
    o.append("  %-14s %.1f req/s" % ("Débit", m.get("rps", 0.0)))
    o.append("─" * W)
    o.append("  %sLATENCE SERVEUR (chemin Nexus)%s          Objectif : ≤ %.2fms" %
             (CYAN, NC, TARGET_MS))
    o.append("    p50 : %-9s p95 : %-9s p99 : %-9s max : %s" %
             ("%.3fms" % lat.get("p50", 0.0),
              "%.3fms" % lat.get("p95", 0.0),
              "%.3fms" % lat.get("p99", 0.0),
              "%.3fms" % lat.get("max", 0.0)))
    if p99 is not None:
        o.append(verdict_p99(p99).rstrip())
    if rtt:
        o.append("  %sSONDE RÉSEAU nexus-smi → nœud (%d essais)%s" %
                 (CYAN, len(rtt), NC))
        o.append("    RTT p50 : %-9s p99 : %-9s" %
                 (fmt_pctl(rtt, 50), fmt_pctl(rtt, 99)))
        o.append(verdict_p99(sorted(rtt)[int(len(rtt) * 0.99) - 1 if len(rtt) > 1 else 0]).rstrip())
    o.append("─" * W)
    o.append("  %sCACHE EDGE%s" % (CYAN, NC))
    o.append("    Hit : %s%s %.1f%%%s  Entrées : %-6d Évictions : %-4d Stale : %d" %
             (cache_color, bar, cache_pct, NC,
              m.get("cache_entries", 0), m.get("evictions", 0), m.get("stales", 0)))
    o.append("    Données servies : %.1f MB   Requêtes totales : %d" %
             (m.get("bytes_served", 0) / 1048576.0, m.get("requests", 0)))
    ago = m.get("last_origin_ok_ago_s")
    o.append("  %sORIGINE%s" % (CYAN, NC))
    o.append("    Erreurs origine : %d   Dernière synchro OK : %s" %
             (m.get("origin_errors", 0),
              ("il y a %ss" % ago) if ago is not None else "jamais"))
    o.append("─" * W)
    o.append("  GPU : %saucun requis%s — les nœuds NEXUS tournent en mode CPU-only" %
             (DIM, NC))
    o.append("  %sCible : %s%s" % (DIM, node_url, NC))
    o.append("═" * W)
    return "\n".join(o)


def render_offline(node_url, err):
    o = []
    o.append("═" * W)
    o.append("  %sNEXUS-SMI%s  %s%s%s" % (CYAN, NC, DIM, VERSION, NC))
    o.append("═" * W)
    o.append("  Nœud   : %s%s%s" % (BOLD, node_url, NC))
    o.append("  Statut : %s❌ HORS LIGNE%s (%s)" % (RED, NC, err))
    o.append("")
    o.append("  %sAstuce : démarre le nœud avec%s" % (YELLOW, NC))
    o.append("    python3 nexusd.py --config config/nexus.json")
    o.append("  %sou%s python3 nexus-ctl.py start" % (YELLOW, NC))
    o.append("═" * W)
    return "\n".join(o)


def main():
    ap = argparse.ArgumentParser(description="NEXUS-SMI — moniteur de nœuds Edge")
    ap.add_argument("--node", default=None, help="URL du nœud (défaut : registre)")
    ap.add_argument("--watch", metavar="SEC", type=float, default=None,
                    help="rafraîchit toutes les SEC secondes")
    ap.add_argument("--list", action="store_true", help="état de tous les nœuds du registre")
    ap.add_argument("--json", action="store_true", help="sortie JSON brute")
    args = ap.parse_args()

    if args.list:
        nodes = load_registry()
        if not nodes:
            print("Registre vide (%s)" % REGISTRY)
            return
        print("  %-18s %-28s %-10s %s" % ("NŒUD", "URL", "STATUT", "P99"))
        for n in nodes:
            url = n["url"]
            try:
                m = fetch_json(url.rstrip("/") + "/nexus/metrics")
                p99 = m["latency_ms"]["p99"]
                v = (GREEN + "✅ %.2fms" % p99 + NC) if p99 <= TARGET_MS \
                    else (YELLOW + "%.2fms" % p99 + NC)
                print("  %-18s %-28s %s✅ EN LIGNE%s   %s" %
                      (n["name"], url, GREEN, NC, v))
            except Exception as exc:  # noqa: BLE001
                print("  %-18s %-28s %s❌ HORS LIGNE%s   —"
                      % (n["name"], url, RED, NC))
        return

    node_url = args.node or default_node_url()
    base = node_url.rstrip("/")

    while True:
        try:
            m = fetch_json(base + "/nexus/metrics")
            if args.json:
                out = json.dumps(m, indent=2)
            else:
                out = render(m, probe_rtt(base), node_url)
        except Exception as exc:  # noqa: BLE001
            if args.json:
                out = json.dumps({"error": "offline", "detail": str(exc)})
            else:
                out = render_offline(node_url, str(exc))
        if args.watch:
            sys.stdout.write("\033[2J\033[H" + out + "\n")
            sys.stdout.flush()
            time.sleep(args.watch)
        else:
            print(out)
            return


if __name__ == "__main__":
    main()
